// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation

public enum AppleBinaryDiffError: Error, Equatable, LocalizedError, Sendable {
    case fileNotFound
    case unsupportedArtifact
    case executableNotFound
    case malformedInfoPlist
    case outputTooLarge
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Binary diff artifact was not found."
        case .unsupportedArtifact:
            return "Binary diff accepts a regular Mach-O file, an .app bundle, or a .dSYM bundle."
        case .executableNotFound:
            return "The app or dSYM bundle does not contain a readable Mach-O executable."
        case .malformedInfoPlist:
            return "The app bundle Info.plist is malformed or unavailable."
        case .outputTooLarge:
            return "The binary diff helper output exceeds the analysis limit."
        case .commandFailed(let message):
            return "Binary diff helper failed: \(message)"
        }
    }
}

public enum AppleArtifactKind: String, Codable, Equatable, Sendable {
    case binary
    case app
    case dSYM
}

public struct AppleArtifactDescriptor: Codable, Equatable, Sendable {
    public let path: String
    public let kind: AppleArtifactKind
    public let executablePath: String
    public let executableName: String?
    public let bundleIdentifier: String?
    public let bundleVersion: String?
    public let shortVersion: String?
    public let fileSize: Int64
    public let sha256: String
    public let uuids: [String]

    public init(
        path: String,
        kind: AppleArtifactKind,
        executablePath: String,
        executableName: String?,
        bundleIdentifier: String?,
        bundleVersion: String?,
        shortVersion: String?,
        fileSize: Int64,
        sha256: String,
        uuids: [String]
    ) {
        self.path = path
        self.kind = kind
        self.executablePath = executablePath
        self.executableName = executableName
        self.bundleIdentifier = bundleIdentifier
        self.bundleVersion = bundleVersion
        self.shortVersion = shortVersion
        self.fileSize = fileSize
        self.sha256 = sha256
        self.uuids = uuids
    }
}

public struct AppleBinarySymbolChange: Codable, Equatable, Sendable {
    public let name: String
    public let architecture: String?
    public let leftAddress: String?
    public let rightAddress: String?
    public let leftKind: String?
    public let rightKind: String?

    public init(
        name: String,
        architecture: String?,
        leftAddress: String?,
        rightAddress: String?,
        leftKind: String?,
        rightKind: String?
    ) {
        self.name = name
        self.architecture = architecture
        self.leftAddress = leftAddress
        self.rightAddress = rightAddress
        self.leftKind = leftKind
        self.rightKind = rightKind
    }
}

public struct AppleDyldExportChange: Codable, Equatable, Sendable {
    public let symbol: String
    public let architecture: String?
    public let leftOffset: String?
    public let rightOffset: String?

    public init(
        symbol: String,
        architecture: String?,
        leftOffset: String?,
        rightOffset: String?
    ) {
        self.symbol = symbol
        self.architecture = architecture
        self.leftOffset = leftOffset
        self.rightOffset = rightOffset
    }
}

public struct AppleBinaryDiffReport: Codable, Equatable, Sendable {
    public let left: AppleArtifactDescriptor
    public let right: AppleArtifactDescriptor
    public let binaryChanged: Bool
    public let debugSymbolsChanged: Bool
    public let signatureChanged: Bool
    public let entitlementsChanged: Bool
    public let bundleMetadataChanged: Bool
    public let architecturesAdded: [String]
    public let architecturesRemoved: [String]
    public let linkedLibrariesAdded: [String]
    public let linkedLibrariesRemoved: [String]
    public let addedSymbols: [AppleBinarySymbol]
    public let removedSymbols: [AppleBinarySymbol]
    public let changedSymbols: [AppleBinarySymbolChange]
    public let addedExports: [DyldExport]
    public let removedExports: [DyldExport]
    public let changedExports: [AppleDyldExportChange]
    public let addedStrings: [String]
    public let removedStrings: [String]
    public let changed: Bool

    public init(
        left: AppleArtifactDescriptor,
        right: AppleArtifactDescriptor,
        binaryChanged: Bool,
        debugSymbolsChanged: Bool,
        signatureChanged: Bool,
        entitlementsChanged: Bool,
        bundleMetadataChanged: Bool,
        architecturesAdded: [String],
        architecturesRemoved: [String],
        linkedLibrariesAdded: [String],
        linkedLibrariesRemoved: [String],
        addedSymbols: [AppleBinarySymbol],
        removedSymbols: [AppleBinarySymbol],
        changedSymbols: [AppleBinarySymbolChange],
        addedExports: [DyldExport],
        removedExports: [DyldExport],
        changedExports: [AppleDyldExportChange],
        addedStrings: [String],
        removedStrings: [String],
        changed: Bool
    ) {
        self.left = left
        self.right = right
        self.binaryChanged = binaryChanged
        self.debugSymbolsChanged = debugSymbolsChanged
        self.signatureChanged = signatureChanged
        self.entitlementsChanged = entitlementsChanged
        self.bundleMetadataChanged = bundleMetadataChanged
        self.architecturesAdded = architecturesAdded
        self.architecturesRemoved = architecturesRemoved
        self.linkedLibrariesAdded = linkedLibrariesAdded
        self.linkedLibrariesRemoved = linkedLibrariesRemoved
        self.addedSymbols = addedSymbols
        self.removedSymbols = removedSymbols
        self.changedSymbols = changedSymbols
        self.addedExports = addedExports
        self.removedExports = removedExports
        self.changedExports = changedExports
        self.addedStrings = addedStrings
        self.removedStrings = removedStrings
        self.changed = changed
    }
}

public enum AppleBinaryDiffService {
    private struct ResolvedArtifact {
        let descriptor: AppleArtifactDescriptor
        let binary: AppleBinaryReport
        let bundleMetadata: [String: String]
        let signature: CodeSignatureReport
    }

    private struct SymbolIdentity: Hashable {
        let name: String
        let architecture: String?
    }

    private struct ExportIdentity: Hashable {
        let symbol: String
        let architecture: String?
    }

    private static let maximumDiffItems = 10_000

    public static func diff(
        leftPath: String,
        rightPath: String,
        architecture: String? = nil
    ) throws -> AppleBinaryDiffReport {
        let left = try resolve(path: leftPath, architecture: architecture)
        let right = try resolve(path: rightPath, architecture: architecture)

        let leftArchitectures = Set(left.binary.macho.architectures.map(\.name))
        let rightArchitectures = Set(right.binary.macho.architectures.map(\.name))
        let architecturesAdded = bounded(rightArchitectures.subtracting(leftArchitectures))
        let architecturesRemoved = bounded(leftArchitectures.subtracting(rightArchitectures))

        let linkedLibrariesAdded = bounded(
            Set(right.binary.linkedLibraries).subtracting(left.binary.linkedLibraries)
        )
        let linkedLibrariesRemoved = bounded(
            Set(left.binary.linkedLibraries).subtracting(right.binary.linkedLibraries)
        )

        let leftSymbols = symbolMap(left.binary.symbols)
        let rightSymbols = symbolMap(right.binary.symbols)
        let symbolKeys = Set(leftSymbols.keys).union(rightSymbols.keys)
        let addedSymbols = boundedSymbols(symbolKeys.compactMap { key in
            guard leftSymbols[key] == nil else { return nil }
            return rightSymbols[key]
        })
        let removedSymbols = boundedSymbols(symbolKeys.compactMap { key in
            guard rightSymbols[key] == nil else { return nil }
            return leftSymbols[key]
        })
        let changedSymbols = boundedSymbolChanges(symbolKeys.compactMap { key in
            guard let leftSymbol = leftSymbols[key], let rightSymbol = rightSymbols[key],
                  leftSymbol.address != rightSymbol.address || leftSymbol.kind != rightSymbol.kind ||
                  leftSymbol.undefined != rightSymbol.undefined else { return nil }
            return AppleBinarySymbolChange(
                name: key.name,
                architecture: key.architecture,
                leftAddress: leftSymbol.address,
                rightAddress: rightSymbol.address,
                leftKind: leftSymbol.kind,
                rightKind: rightSymbol.kind
            )
        })

        let leftExports = exportMap(left.binary.dyldExports)
        let rightExports = exportMap(right.binary.dyldExports)
        let exportKeys = Set(leftExports.keys).union(rightExports.keys)
        let addedExports = boundedExports(exportKeys.compactMap { key in
            guard leftExports[key] == nil else { return nil }
            return rightExports[key]
        })
        let removedExports = boundedExports(exportKeys.compactMap { key in
            guard rightExports[key] == nil else { return nil }
            return leftExports[key]
        })
        let changedExports = boundedExportChanges(exportKeys.compactMap { key in
            guard let leftExport = leftExports[key], let rightExport = rightExports[key],
                  leftExport.offset != rightExport.offset else { return nil }
            return AppleDyldExportChange(
                symbol: key.symbol,
                architecture: key.architecture,
                leftOffset: leftExport.offset,
                rightOffset: rightExport.offset
            )
        })

        let addedStrings = bounded(Set(right.binary.macho.strings).subtracting(left.binary.macho.strings))
        let removedStrings = bounded(Set(left.binary.macho.strings).subtracting(right.binary.macho.strings))
        let binaryChanged = left.descriptor.sha256 != right.descriptor.sha256
        let debugSymbolsChanged = (left.descriptor.kind == .dSYM || right.descriptor.kind == .dSYM)
            && left.descriptor.uuids != right.descriptor.uuids
        let signatureChanged = left.signature.signed != right.signature.signed
            || left.signature.metadata != right.signature.metadata
        let entitlementsChanged = left.signature.entitlements != right.signature.entitlements
        let bundleMetadataChanged = left.bundleMetadata != right.bundleMetadata
            || left.descriptor.kind != right.descriptor.kind

        let changed = binaryChanged || debugSymbolsChanged || signatureChanged || entitlementsChanged
            || bundleMetadataChanged || !architecturesAdded.isEmpty || !architecturesRemoved.isEmpty
            || !linkedLibrariesAdded.isEmpty || !linkedLibrariesRemoved.isEmpty
            || !addedSymbols.isEmpty || !removedSymbols.isEmpty || !changedSymbols.isEmpty
            || !addedExports.isEmpty || !removedExports.isEmpty || !changedExports.isEmpty
            || !addedStrings.isEmpty || !removedStrings.isEmpty

        return AppleBinaryDiffReport(
            left: left.descriptor,
            right: right.descriptor,
            binaryChanged: binaryChanged,
            debugSymbolsChanged: debugSymbolsChanged,
            signatureChanged: signatureChanged,
            entitlementsChanged: entitlementsChanged,
            bundleMetadataChanged: bundleMetadataChanged,
            architecturesAdded: architecturesAdded,
            architecturesRemoved: architecturesRemoved,
            linkedLibrariesAdded: linkedLibrariesAdded,
            linkedLibrariesRemoved: linkedLibrariesRemoved,
            addedSymbols: addedSymbols,
            removedSymbols: removedSymbols,
            changedSymbols: changedSymbols,
            addedExports: addedExports,
            removedExports: removedExports,
            changedExports: changedExports,
            addedStrings: addedStrings,
            removedStrings: removedStrings,
            changed: changed
        )
    }

    private static func resolve(path: String, architecture: String?) throws -> ResolvedArtifact {
        guard FileManager.default.fileExists(atPath: path) else {
            throw AppleBinaryDiffError.fileNotFound
        }

        var kind: AppleArtifactKind
        var binaryPath = path
        var bundleMetadata: [String: String] = [:]
        switch try fileType(path: path) {
        case .regular:
            kind = .binary
        case .directory:
            if path.hasSuffix(".app") {
                kind = .app
                let info = try readInfoPlist(path: path, appBundle: true)
                bundleMetadata = info.metadata
                binaryPath = try appExecutable(path: path, metadata: info.metadata)
            } else if path.hasSuffix(".dSYM") {
                kind = .dSYM
                binaryPath = try dSYMExecutable(path: path)
            } else {
                throw AppleBinaryDiffError.unsupportedArtifact
            }
        }

        let binary = try AppleBinaryIntelligenceService.inspect(
            path: binaryPath,
            architecture: architecture
        )
        let signature = binary.codeSignature
        let attributes = try FileManager.default.attributesOfItem(atPath: binaryPath)
        guard let fileSize = attributes[.size] as? NSNumber else {
            throw AppleBinaryDiffError.executableNotFound
        }
        let executableName = URL(fileURLWithPath: binaryPath).lastPathComponent
        let uuids = (try? dwarfdumpUUIDs(path: path)) ?? []
        let descriptor = AppleArtifactDescriptor(
            path: path,
            kind: kind,
            executablePath: binaryPath,
            executableName: bundleMetadata["CFBundleExecutable"] ?? executableName,
            bundleIdentifier: bundleMetadata["CFBundleIdentifier"],
            bundleVersion: bundleMetadata["CFBundleVersion"],
            shortVersion: bundleMetadata["CFBundleShortVersionString"],
            fileSize: fileSize.int64Value,
            sha256: try sha256(path: binaryPath),
            uuids: uuids
        )
        return ResolvedArtifact(
            descriptor: descriptor,
            binary: binary,
            bundleMetadata: bundleMetadata,
            signature: signature
        )
    }

    private enum FileType {
        case regular
        case directory
    }

    private static func fileType(path: String) throws -> FileType {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let type = attributes[.type] as? FileAttributeType else {
            throw AppleBinaryDiffError.unsupportedArtifact
        }
        if type == .typeRegular { return .regular }
        if type == .typeDirectory { return .directory }
        throw AppleBinaryDiffError.unsupportedArtifact
    }

    private static func readInfoPlist(path: String, appBundle: Bool) throws -> (metadata: [String: String], plist: [String: Any]) {
        let root = URL(fileURLWithPath: path)
        let candidates = appBundle
            ? [root.appendingPathComponent("Contents/Info.plist"), root.appendingPathComponent("Info.plist")]
            : [root.appendingPathComponent("Contents/Info.plist")]
        guard let infoURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let values = plist as? [String: Any] else {
            throw AppleBinaryDiffError.malformedInfoPlist
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

    private static func appExecutable(path: String, metadata: [String: String]) throws -> String {
        let name = metadata["CFBundleExecutable"] ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        let root = URL(fileURLWithPath: path)
        let candidates = [
            root.appendingPathComponent(name),
            root.appendingPathComponent("Contents/MacOS").appendingPathComponent(name)
        ]
        guard let candidate = candidates.first(where: { isRegularFile($0.path) }) else {
            throw AppleBinaryDiffError.executableNotFound
        }
        return candidate.path
    }

    private static func dSYMExecutable(path: String) throws -> String {
        let dwarfURL = URL(fileURLWithPath: path).appendingPathComponent("Contents/Resources/DWARF")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dwarfURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AppleBinaryDiffError.executableNotFound
        }
        for entry in entries.sorted(by: { $0.path < $1.path }) where isRegularFile(entry.path) {
            if (try? MachOInspector.inspect(path: entry.path)) != nil {
                return entry.path
            }
        }
        throw AppleBinaryDiffError.executableNotFound
    }

    private static func isRegularFile(_ path: String) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let type = attributes[.type] as? FileAttributeType else { return false }
        return type == .typeRegular
    }

    private static func sha256(path: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func dwarfdumpUUIDs(path: String) throws -> [String] {
        let result = try runXcrun(arguments: ["dwarfdump", "--uuid", path])
        return result.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard let uuidIndex = parts.firstIndex(of: "UUID:"), parts.count > uuidIndex + 1 else { return nil }
            return String(parts[uuidIndex + 1])
        }.sorted()
    }

    private static func runXcrun(arguments: [String]) throws -> String {
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: "/usr/bin/xcrun",
                arguments: arguments,
                maximumOutputSize: 2 * 1024 * 1024
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw AppleBinaryDiffError.outputTooLarge
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw AppleBinaryDiffError.commandFailed(message)
        } catch {
            throw AppleBinaryDiffError.commandFailed(error.localizedDescription)
        }
        guard result.terminationStatus == 0 else { return "" }
        return String(decoding: result.stdout, as: UTF8.self)
    }

    private static func bounded(_ values: Set<String>) -> [String] {
        Array(values.sorted().prefix(maximumDiffItems))
    }

    private static func symbolMap(_ symbols: [AppleBinarySymbol]) -> [SymbolIdentity: AppleBinarySymbol] {
        symbols.reduce(into: [SymbolIdentity: AppleBinarySymbol]()) { result, symbol in
            result[SymbolIdentity(name: symbol.name, architecture: symbol.architecture)] = symbol
        }
    }

    private static func exportMap(_ exports: [DyldExport]) -> [ExportIdentity: DyldExport] {
        exports.reduce(into: [ExportIdentity: DyldExport]()) { result, export in
            result[ExportIdentity(symbol: export.symbol, architecture: export.architecture)] = export
        }
    }

    private static func boundedSymbols(_ values: [AppleBinarySymbol?]) -> [AppleBinarySymbol] {
        values.compactMap { $0 }
            .sorted { ($0.architecture ?? "", $0.name) < ($1.architecture ?? "", $1.name) }
            .prefix(maximumDiffItems)
            .map { $0 }
    }

    private static func boundedSymbolChanges(_ values: [AppleBinarySymbolChange]) -> [AppleBinarySymbolChange] {
        values.sorted { ($0.architecture ?? "", $0.name) < ($1.architecture ?? "", $1.name) }
            .prefix(maximumDiffItems)
            .map { $0 }
    }

    private static func boundedExports(_ values: [DyldExport?]) -> [DyldExport] {
        values.compactMap { $0 }
            .sorted { ($0.architecture ?? "", $0.symbol) < ($1.architecture ?? "", $1.symbol) }
            .prefix(maximumDiffItems)
            .map { $0 }
    }

    private static func boundedExportChanges(_ values: [AppleDyldExportChange]) -> [AppleDyldExportChange] {
        values.sorted { ($0.architecture ?? "", $0.symbol) < ($1.architecture ?? "", $1.symbol) }
            .prefix(maximumDiffItems)
            .map { $0 }
    }
}
