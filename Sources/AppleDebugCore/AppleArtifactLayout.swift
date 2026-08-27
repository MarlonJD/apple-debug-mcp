// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation

public enum AppleArtifactKind: String, Codable, Equatable, Sendable {
    case binary
    case app
    case dSYM
}

public enum AppleArtifactLayoutError: Error, Equatable, LocalizedError, Sendable {
    case invalidPath
    case fileNotFound
    case notRegularFile
    case unsupportedArtifact
    case malformedBundle
    case executableNotFound
    case ambiguousDwarf
    case symlinkEscapesBundle
    case fileTooLarge
    case invalidArchitecture
    case tooManyDwarfEntries

    public var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Apple artifact paths must be absolute and non-empty."
        case .fileNotFound:
            return "Apple artifact was not found."
        case .notRegularFile:
            return "Apple artifact payload is not a regular file."
        case .unsupportedArtifact:
            return "Apple artifact must be a regular Mach-O, .app, or .dSYM bundle."
        case .malformedBundle:
            return "Apple artifact bundle metadata is malformed."
        case .executableNotFound:
            return "Apple artifact bundle does not contain its main Mach-O payload."
        case .ambiguousDwarf:
            return "Apple dSYM contains more than one direct Mach-O DWARF payload."
        case .symlinkEscapesBundle:
            return "Apple artifact symlink resolves outside its supplied bundle root."
        case .fileTooLarge:
            return "Apple artifact payload exceeds the configured identity limit."
        case .invalidArchitecture:
            return "Apple artifact architecture input is empty, oversized, or malformed."
        case .tooManyDwarfEntries:
            return "Apple dSYM contains more direct entries than the bounded resolver allows."
        }
    }
}

public struct AppleArtifactFileIdentity: Codable, Equatable, Sendable {
    public let canonicalPath: String
    public let device: UInt64?
    public let inode: UInt64?
    public let size: UInt64
    public let modificationTime: Double?
    public let sha256: String

    public init(
        canonicalPath: String,
        device: UInt64?,
        inode: UInt64?,
        size: UInt64,
        modificationTime: Double?,
        sha256: String = ""
    ) {
        self.canonicalPath = canonicalPath
        self.device = device
        self.inode = inode
        self.size = size
        self.modificationTime = modificationTime
        self.sha256 = sha256
    }
}

public struct AppleArtifactLayout: Codable, Equatable, Sendable {
    public let inputPath: String
    public let canonicalInputPath: String
    public let kind: AppleArtifactKind
    public let resolvedBinaryPath: String
    public let canonicalBinaryPath: String
    public let bundleMetadata: [String: String]
    public let macho: MachOReport
    public let fileIdentity: AppleArtifactFileIdentity

    public init(
        inputPath: String,
        canonicalInputPath: String,
        kind: AppleArtifactKind,
        resolvedBinaryPath: String,
        canonicalBinaryPath: String,
        bundleMetadata: [String: String],
        macho: MachOReport,
        fileIdentity: AppleArtifactFileIdentity
    ) {
        self.inputPath = inputPath
        self.canonicalInputPath = canonicalInputPath
        self.kind = kind
        self.resolvedBinaryPath = resolvedBinaryPath
        self.canonicalBinaryPath = canonicalBinaryPath
        self.bundleMetadata = bundleMetadata
        self.macho = macho
        self.fileIdentity = fileIdentity
    }

    public func slice(for architecture: String) -> MachOSliceReport? {
        macho.slices.first(where: { $0.architecture.name == architecture })
    }
}

public enum AppleArtifactLayoutResolver {
    private static let maximumInfoPlistSize = 1 * 1024 * 1024
    private static let maximumDwarfEntries = 256
    private static let maximumIdentityFileSize = 128 * 1024 * 1024

    /// Symlinks are accepted only when their canonical target remains inside
    /// the supplied bundle root. Regular-file inputs are resolved to their
    /// canonical target. No recursive symbol or framework search is done.
    public static func resolve(path: String, architecture: String? = nil) throws -> AppleArtifactLayout {
        guard !path.isEmpty, path.utf8.count <= 4_096, path.hasPrefix("/"), !path.contains("\0") else {
            throw AppleArtifactLayoutError.invalidPath
        }
        if let architecture,
           architecture.isEmpty || architecture.utf8.count > 64 || architecture.contains("\0") {
            throw AppleArtifactLayoutError.invalidArchitecture
        }
        let inputURL = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw AppleArtifactLayoutError.fileNotFound
        }
        let canonicalInput = inputURL.resolvingSymlinksInPath().standardizedFileURL
        let inputAttributes = try FileManager.default.attributesOfItem(atPath: canonicalInput.path)
        guard let inputType = inputAttributes[.type] as? FileAttributeType else {
            throw AppleArtifactLayoutError.unsupportedArtifact
        }

        let kind: AppleArtifactKind
        let binaryURL: URL
        var preResolvedMacho: MachOReport?
        var metadata: [String: String] = [:]
        if inputType == .typeRegular {
            kind = .binary
            binaryURL = canonicalInput
        } else if inputType == .typeDirectory {
            switch inputURL.pathExtension.lowercased() {
            case "app":
                kind = .app
                let info = try readInfoPlist(root: canonicalInput, appBundle: true)
                metadata = info.metadata
                binaryURL = try appExecutable(root: canonicalInput, metadata: info.metadata)
            case "dsym":
                kind = .dSYM
                let resolved = try dSYMExecutable(root: canonicalInput, architecture: architecture)
                binaryURL = resolved.url
                preResolvedMacho = resolved.report
            default:
                throw AppleArtifactLayoutError.unsupportedArtifact
            }
        } else {
            throw AppleArtifactLayoutError.notRegularFile
        }

        let canonicalBinary = binaryURL.resolvingSymlinksInPath().standardizedFileURL
        guard isContained(canonicalBinary, in: canonicalInput) || kind == .binary else {
            throw AppleArtifactLayoutError.symlinkEscapesBundle
        }
        guard isRegularFile(canonicalBinary.path) else {
            throw AppleArtifactLayoutError.notRegularFile
        }
        let macho: MachOReport
        if let preResolvedMacho {
            macho = preResolvedMacho
        } else {
            macho = try MachOInspector.inspect(path: canonicalBinary.path)
        }
        if let architecture,
           !macho.architectures.contains(where: { $0.name == architecture }) {
            throw MachOError.invalidArchitecture
        }
        let identity = try snapshot(path: canonicalBinary.path)
        return AppleArtifactLayout(
            inputPath: path,
            canonicalInputPath: canonicalInput.path,
            kind: kind,
            resolvedBinaryPath: binaryURL.path,
            canonicalBinaryPath: canonicalBinary.path,
            bundleMetadata: metadata,
            macho: macho,
            fileIdentity: identity
        )
    }

    public static func snapshot(path: String) throws -> AppleArtifactFileIdentity {
        guard !path.isEmpty, path.utf8.count <= 4_096, path.hasPrefix("/"), !path.contains("\0") else {
            throw AppleArtifactLayoutError.invalidPath
        }
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let type = attributes[.type] as? FileAttributeType, type == .typeRegular else {
            throw AppleArtifactLayoutError.notRegularFile
        }
        guard let size = (attributes[.size] as? NSNumber)?.uint64Value else {
            throw AppleArtifactLayoutError.notRegularFile
        }
        guard size <= UInt64(maximumIdentityFileSize) else {
            throw AppleArtifactLayoutError.fileTooLarge
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return AppleArtifactFileIdentity(
            canonicalPath: url.path,
            device: number(attributes[.systemNumber]),
            inode: number(attributes[.systemFileNumber]),
            size: size,
            modificationTime: (attributes[.modificationDate] as? Date)?.timeIntervalSince1970,
            sha256: digest
        )
    }

    public static func revalidate(_ identity: AppleArtifactFileIdentity) -> Bool {
        guard let current = try? snapshot(path: identity.canonicalPath) else { return false }
        return current == identity
    }

    private static func appExecutable(root: URL, metadata: [String: String]) throws -> URL {
        let fallback = root.deletingPathExtension().lastPathComponent
        let name = metadata["CFBundleExecutable"] ?? fallback
        guard !name.isEmpty, !name.contains("/"), !name.contains("\0") else {
            throw AppleArtifactLayoutError.malformedBundle
        }
        let candidates = [
            root.appendingPathComponent(name),
            root.appendingPathComponent("Contents/MacOS").appendingPathComponent(name)
        ]
        for candidate in candidates {
            guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
            let canonical = try canonicalChild(candidate, root: root)
            guard isRegularFile(canonical.path) else { continue }
            return candidate
        }
        throw AppleArtifactLayoutError.executableNotFound
    }

    private static func dSYMExecutable(root: URL, architecture: String?) throws -> (url: URL, report: MachOReport) {
        let dwarfDirectory = try canonicalChild(
            root.appendingPathComponent("Contents/Resources/DWARF"),
            root: root
        )
        guard isDirectory(dwarfDirectory.path) else {
            throw AppleArtifactLayoutError.executableNotFound
        }
        guard let enumerator = FileManager.default.enumerator(
            at: dwarfDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AppleArtifactLayoutError.executableNotFound
        }
        var entries: [(url: URL, report: MachOReport)] = []
        var examinedEntries = 0
        while let object = enumerator.nextObject() {
            guard let entry = object as? URL else { continue }
            examinedEntries += 1
            guard examinedEntries <= maximumDwarfEntries else {
                throw AppleArtifactLayoutError.tooManyDwarfEntries
            }
            let canonical = try canonicalChild(entry, root: root)
            if isDirectory(canonical.path) {
                enumerator.skipDescendants()
                continue
            }
            guard isRegularFile(canonical.path),
                  let report = try? MachOInspector.inspect(path: canonical.path) else {
                continue
            }
            if let architecture,
               !report.architectures.contains(where: { $0.name == architecture }) {
                continue
            }
            entries.append((entry, report))
        }
        let candidates = entries.sorted { $0.url.path < $1.url.path }
        guard candidates.count == 1, let candidate = candidates.first else {
            if candidates.count > 1 { throw AppleArtifactLayoutError.ambiguousDwarf }
            throw AppleArtifactLayoutError.executableNotFound
        }
        return candidate
    }

    private static func readInfoPlist(root: URL, appBundle: Bool) throws -> (metadata: [String: String], values: [String: Any]) {
        let candidates = appBundle
            ? [root.appendingPathComponent("Contents/Info.plist"), root.appendingPathComponent("Info.plist")]
            : [root.appendingPathComponent("Contents/Info.plist")]
        guard let infoURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let canonicalInfoURL = try? canonicalChild(infoURL, root: root),
              let data = try? Data(contentsOf: canonicalInfoURL),
              data.count <= maximumInfoPlistSize,
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let values = plist as? [String: Any] else {
            throw AppleArtifactLayoutError.malformedBundle
        }
        let keys = [
            "CFBundleIdentifier", "CFBundleExecutable", "CFBundleVersion",
            "CFBundleShortVersionString", "MinimumOSVersion", "DTPlatformName"
        ]
        let metadata = keys.reduce(into: [String: String]()) { result, key in
            if let value = values[key] as? String, !value.isEmpty {
                result[key] = value
            }
        }
        return (metadata, values)
    }

    private static func canonicalChild(_ child: URL, root: URL) throws -> URL {
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let canonicalChild = child.resolvingSymlinksInPath().standardizedFileURL
        guard isContained(canonicalChild, in: canonicalRoot) else {
            throw AppleArtifactLayoutError.symlinkEscapesBundle
        }
        return canonicalChild
    }

    private static func isContained(_ child: URL, in root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return child.path == root.path || child.path.hasPrefix(rootPath)
    }

    private static func isRegularFile(_ path: String) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let type = attributes[.type] as? FileAttributeType else { return false }
        return type == .typeRegular
    }

    private static func isDirectory(_ path: String) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let type = attributes[.type] as? FileAttributeType else { return false }
        return type == .typeDirectory
    }

    private static func number(_ value: Any?) -> UInt64? {
        (value as? NSNumber)?.uint64Value
    }
}
