// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum SymbolicationError: Error, Equatable, LocalizedError, Sendable {
    case binaryNotFound
    case binaryNotRegularFile
    case invalidAddress
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Symbolication binary was not found."
        case .binaryNotRegularFile:
            return "Symbolication input is not a regular file."
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
        let url = URL(fileURLWithPath: binaryPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SymbolicationError.binaryNotFound
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let type = attributes[.type] as? FileAttributeType, type == .typeRegular else {
            throw SymbolicationError.binaryNotRegularFile
        }
        guard isAddress(address), loadAddress.map(isAddress) ?? true else {
            throw SymbolicationError.invalidAddress
        }

        var arguments = ["atos", "-o", binaryPath, "-arch", architecture]
        if let loadAddress {
            arguments += ["-l", loadAddress]
        }
        arguments.append(address)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw SymbolicationError.commandFailed(error.localizedDescription)
        }

        let stdout = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let stderr = String(
            data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        guard process.terminationStatus == 0 else {
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

    private static func isAddress(_ value: String) -> Bool {
        let normalized = value.hasPrefix("0x") ? String(value.dropFirst(2)) : value
        return !normalized.isEmpty && UInt64(normalized, radix: 16) != nil
    }
}
