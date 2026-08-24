// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum AppleBinaryError: Error, Equatable, LocalizedError, Sendable {
    case fileNotFound
    case notRegularFile
    case invalidArchitecture
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Apple binary was not found."
        case .notRegularFile:
            return "Apple binary path is not a regular file."
        case .invalidArchitecture:
            return "The requested architecture is invalid or unavailable."
        case .commandFailed(let message):
            return "Apple binary tool failed: \(message)"
        case .outputTooLarge:
            return "Apple binary tool output exceeds the analysis limit."
        }
    }
}

public struct CodeSignatureReport: Codable, Equatable, Sendable {
    public let path: String
    public let signed: Bool
    public let metadata: [String: String]
    public let entitlements: DAPValue?
    public let diagnostic: String?

    public init(
        path: String,
        signed: Bool,
        metadata: [String: String],
        entitlements: DAPValue?,
        diagnostic: String?
    ) {
        self.path = path
        self.signed = signed
        self.metadata = metadata
        self.entitlements = entitlements
        self.diagnostic = diagnostic
    }
}

public struct AppleBinarySymbol: Codable, Equatable, Sendable {
    public let name: String
    public let address: String?
    public let kind: String
    public let architecture: String?
    public let undefined: Bool

    public init(
        name: String,
        address: String?,
        kind: String,
        architecture: String?,
        undefined: Bool
    ) {
        self.name = name
        self.address = address
        self.kind = kind
        self.architecture = architecture
        self.undefined = undefined
    }
}

public struct DyldExport: Codable, Equatable, Sendable {
    public let architecture: String?
    public let offset: String
    public let symbol: String

    public init(architecture: String?, offset: String, symbol: String) {
        self.architecture = architecture
        self.offset = offset
        self.symbol = symbol
    }
}

public struct AppleBinaryReport: Codable, Equatable, Sendable {
    public let path: String
    public let macho: MachOReport
    public let codeSignature: CodeSignatureReport
    public let linkedLibraries: [String]
    public let symbols: [AppleBinarySymbol]
    public let dyldExports: [DyldExport]

    public init(
        path: String,
        macho: MachOReport,
        codeSignature: CodeSignatureReport,
        linkedLibraries: [String],
        symbols: [AppleBinarySymbol],
        dyldExports: [DyldExport]
    ) {
        self.path = path
        self.macho = macho
        self.codeSignature = codeSignature
        self.linkedLibraries = linkedLibraries
        self.symbols = symbols
        self.dyldExports = dyldExports
    }
}

public enum CodeSignatureService {
    public static func inspect(path: String) throws -> CodeSignatureReport {
        try validateFile(path: path)
        let result = try run(
            executable: "/usr/bin/codesign",
            arguments: ["-dvvv", "--entitlements", ":-", path]
        )
        var metadata: [String: String] = [:]
        for line in result.stderr.split(whereSeparator: \.isNewline) {
            let text = String(line)
            guard let separator = text.firstIndex(of: "=") else { continue }
            let key = String(text[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(text[text.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, !value.isEmpty {
                metadata[key] = value
            }
        }
        let entitlements = try parseEntitlements(data: Data(result.stdout.utf8))
        let diagnostic = result.terminationStatus == 0 ? nil : result.stderr
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return CodeSignatureReport(
            path: path,
            signed: result.terminationStatus == 0,
            metadata: metadata,
            entitlements: entitlements,
            diagnostic: diagnostic?.isEmpty == true ? nil : diagnostic
        )
    }

    private static func parseEntitlements(data: Data) throws -> DAPValue? {
        guard !data.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) else {
            return nil
        }
        return convert(plist)
    }

    private static func convert(_ value: Any) -> DAPValue? {
        if let value = value as? [String: Any] {
            return .object(value.compactMapValues(convert))
        }
        if let value = value as? [Any] {
            return .array(value.compactMap(convert))
        }
        if let value = value as? String { return .string(value) }
        if let value = value as? Bool { return .boolean(value) }
        if let value = value as? Int { return .integer(value) }
        if let value = value as? NSNumber { return .double(value.doubleValue) }
        if let value = value as? Data { return .string(value.base64EncodedString()) }
        if let value = value as? Date { return .string(ISO8601DateFormatter().string(from: value)) }
        return nil
    }

    private static func validateFile(path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw AppleBinaryError.fileNotFound
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard let type = attributes[.type] as? FileAttributeType, type == .typeRegular else {
            throw AppleBinaryError.notRegularFile
        }
    }

    private struct CommandResult {
        let stdout: String
        let stderr: String
        let terminationStatus: Int32
    }

    private static func run(executable: String, arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw AppleBinaryError.commandFailed(error.localizedDescription)
        }
        let stdoutData = output.fileHandleForReading.readDataToEndOfFile()
        let stderrData = error.fileHandleForReading.readDataToEndOfFile()
        guard stdoutData.count <= 2 * 1024 * 1024,
              stderrData.count <= 2 * 1024 * 1024 else {
            throw AppleBinaryError.outputTooLarge
        }
        return CommandResult(
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self),
            terminationStatus: process.terminationStatus
        )
    }
}

public enum AppleBinaryIntelligenceService {
    public static func inspect(path: String, architecture: String? = nil) throws -> AppleBinaryReport {
        let macho = try MachOInspector.inspect(path: path)
        if let architecture,
           !macho.architectures.contains(where: { $0.name == architecture }) {
            throw AppleBinaryError.invalidArchitecture
        }
        let signature = try CodeSignatureService.inspect(path: path)
        let libraries = try linkedLibraries(path: path, architecture: architecture)
        let symbols = try nmSymbols(path: path, architecture: architecture)
        let exports = try dyldExports(path: path, architecture: architecture)
        return AppleBinaryReport(
            path: path,
            macho: macho,
            codeSignature: signature,
            linkedLibraries: libraries,
            symbols: symbols,
            dyldExports: exports
        )
    }

    private static func linkedLibraries(path: String, architecture: String?) throws -> [String] {
        var arguments = ["otool"]
        if let architecture { arguments += ["-arch", architecture] }
        arguments += ["-L", path]
        let output = try runXcrun(arguments: arguments)
        return output.split(whereSeparator: \.isNewline).dropFirst().compactMap { line in
            let value = line.trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { return nil }
            return value.split(separator: " ").first.map(String.init)
        }
    }

    private static func nmSymbols(path: String, architecture: String?) throws -> [AppleBinarySymbol] {
        var arguments = ["nm", "-g"]
        if let architecture { arguments += ["-arch", architecture] }
        arguments.append(path)
        let output = try runXcrun(arguments: arguments)
        var currentArchitecture: String?
        var symbols: [AppleBinarySymbol] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line)
            if let start = text.range(of: "(for architecture "),
               let end = text.firstIndex(of: ")"), end > start.lowerBound {
                let value = text[start.upperBound..<end]
                currentArchitecture = String(value)
                continue
            }
            let parts = text.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2 else { continue }
            let hasAddress = parts.count >= 3 && parts[1].count == 1
            let typeIndex = hasAddress ? 1 : 0
            let kind = String(parts[typeIndex])
            guard kind.count == 1 else { continue }
            let name = String(parts.last!)
            let address = hasAddress ? String(parts[0]) : nil
            symbols.append(
                AppleBinarySymbol(
                    name: name,
                    address: address,
                    kind: kind,
                    architecture: currentArchitecture,
                    undefined: kind.caseInsensitiveCompare("U") == .orderedSame
                )
            )
            if symbols.count >= 50_000 { break }
        }
        return symbols
    }

    private static func dyldExports(path: String, architecture: String?) throws -> [DyldExport] {
        var arguments = ["dyld_info"]
        if let architecture { arguments += ["-arch", architecture] }
        arguments += ["-exports", path]
        let output = try runXcrun(arguments: arguments)
        var currentArchitecture: String?
        var exports: [DyldExport] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let text = String(line).trimmingCharacters(in: .whitespaces)
            if text.contains("[") && text.hasSuffix("]:") {
                currentArchitecture = text.split(separator: "[").last.map {
                    String($0.dropLast())
                }
                continue
            }
            let parts = text.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 2, parts[0].hasPrefix("0x") else { continue }
            exports.append(
                DyldExport(
                    architecture: currentArchitecture,
                    offset: String(parts[0]),
                    symbol: String(parts[1])
                )
            )
            if exports.count >= 50_000 { break }
        }
        return exports
    }

    private static func runXcrun(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw AppleBinaryError.commandFailed(error.localizedDescription)
        }
        let stdout = output.fileHandleForReading.readDataToEndOfFile()
        let stderr = error.fileHandleForReading.readDataToEndOfFile()
        guard stdout.count <= 4 * 1024 * 1024,
              stderr.count <= 4 * 1024 * 1024 else {
            throw AppleBinaryError.outputTooLarge
        }
        guard process.terminationStatus == 0 else {
            throw AppleBinaryError.commandFailed(
                String(decoding: stderr, as: UTF8.self)
            )
        }
        return String(decoding: stdout, as: UTF8.self)
    }
}
