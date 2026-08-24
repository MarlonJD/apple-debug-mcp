// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum SymbolicationError: Error, Equatable, LocalizedError, Sendable {
    case binaryNotFound
    case binaryNotRegularFile
    case unsupportedArtifact
    case invalidAddress
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Symbolication binary was not found."
        case .binaryNotRegularFile:
            return "Symbolication input is not a regular file."
        case .unsupportedArtifact:
            return "Symbolication accepts a Mach-O file, an .app bundle, or a .dSYM bundle."
        case .invalidAddress:
            return "Symbolication address is not a valid hexadecimal address."
        case .commandFailed(let message):
            return "atos symbolication failed: \(message)"
        }
    }
}

public struct SymbolicationResult: Codable, Equatable, Sendable {
    public let binaryPath: String
    public let architecture: String
    public let address: String
    public let loadAddress: String?
    public let symbol: String

    public init(
        binaryPath: String,
        architecture: String,
        address: String,
        loadAddress: String?,
        symbol: String
    ) {
        self.binaryPath = binaryPath
        self.architecture = architecture
        self.address = address
        self.loadAddress = loadAddress
        self.symbol = symbol
    }
}

public enum SymbolicationService {
    public static func symbolize(
        binaryPath: String,
        architecture: String,
        address: String,
        loadAddress: String? = nil
    ) throws -> SymbolicationResult {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw SymbolicationError.binaryNotFound
        }
        let resolvedBinaryPath = try resolveBinary(path: binaryPath)
        guard isAddress(address), loadAddress.map(isAddress) ?? true else {
            throw SymbolicationError.invalidAddress
        }

        var arguments = ["atos", "-o", resolvedBinaryPath, "-arch", architecture]
        if let loadAddress {
            arguments += ["-l", loadAddress]
        }
        arguments.append(address)
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: "/usr/bin/xcrun",
                arguments: arguments,
                maximumOutputSize: 2 * 1024 * 1024
            )
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw SymbolicationError.commandFailed(message)
        } catch AppleProcessRunnerError.outputTooLarge {
            throw SymbolicationError.commandFailed("atos output exceeds the 2 MB analysis limit.")
        } catch {
            throw SymbolicationError.commandFailed(error.localizedDescription)
        }

        let stdout = String(decoding: result.stdout, as: UTF8.self)
        let stderr = String(decoding: result.stderr, as: UTF8.self)
        guard result.terminationStatus == 0 else {
            throw SymbolicationError.commandFailed(
                stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? stdout : stderr
            )
        }
        return SymbolicationResult(
            binaryPath: binaryPath,
            architecture: architecture,
            address: address,
            loadAddress: loadAddress,
            symbol: stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func resolveBinary(path: String) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let type = attributes[.type] as? FileAttributeType else {
            throw SymbolicationError.unsupportedArtifact
        }
        if type == .typeRegular {
            return path
        }
        guard type == .typeDirectory else {
            throw SymbolicationError.binaryNotRegularFile
        }

        let root = URL(fileURLWithPath: path)
        if path.hasSuffix(".dSYM") {
            let dwarfDirectory = root.appendingPathComponent("Contents/Resources/DWARF")
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dwarfDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                throw SymbolicationError.unsupportedArtifact
            }
            for entry in entries.sorted(by: { $0.path < $1.path }) where isRegularFile(entry.path) {
                if (try? MachOInspector.inspect(path: entry.path)) != nil {
                    return entry.path
                }
            }
            throw SymbolicationError.unsupportedArtifact
        }

        guard path.hasSuffix(".app") else {
            throw SymbolicationError.unsupportedArtifact
        }
        let executableName = bundleExecutableName(root: root)
            ?? root.deletingPathExtension().lastPathComponent
        let candidates = [
            root.appendingPathComponent(executableName),
            root.appendingPathComponent("Contents/MacOS").appendingPathComponent(executableName)
        ]
        guard let executable = candidates.first(where: { isRegularFile($0.path) }),
              (try? MachOInspector.inspect(path: executable.path)) != nil else {
            throw SymbolicationError.unsupportedArtifact
        }
        return executable.path
    }

    private static func bundleExecutableName(root: URL) -> String? {
        let candidates = [
            root.appendingPathComponent("Info.plist"),
            root.appendingPathComponent("Contents/Info.plist")
        ]
        guard let infoURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let values = plist as? [String: Any] else {
            return nil
        }
        return values["CFBundleExecutable"] as? String
    }

    private static func isRegularFile(_ path: String) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let type = attributes[.type] as? FileAttributeType else { return false }
        return type == .typeRegular
    }

    private static func isAddress(_ value: String) -> Bool {
        let normalized = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
        return !normalized.isEmpty && UInt64(normalized, radix: 16) != nil
    }
}
