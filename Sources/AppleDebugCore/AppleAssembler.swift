// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum AppleAssemblerError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case toolUnavailable(String)
    case assemblyFailed(String)
    case outputTooLarge
    case noTextSection

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Assembly request is invalid, unsupported, or exceeds the bounded limits."
        case .toolUnavailable(let tool):
            return "The local assembler tool is unavailable: \(tool)."
        case .assemblyFailed(let message):
            return "Apple assembler failed: \(message)"
        case .outputTooLarge:
            return "Assembler output exceeds the configured limit."
        case .noTextSection:
            return "The assembler produced no executable __TEXT,__text section."
        }
    }
}

public struct AssembledCode: Codable, Equatable, Sendable {
    public let architecture: String
    public let source: String
    public let byteCount: Int
    public let bytesHex: String
    public let bytesBase64: String
    public let disassembly: String

    public init(
        architecture: String,
        source: String,
        byteCount: Int,
        bytesHex: String,
        bytesBase64: String,
        disassembly: String
    ) {
        self.architecture = architecture
        self.source = source
        self.byteCount = byteCount
        self.bytesHex = bytesHex
        self.bytesBase64 = bytesBase64
        self.disassembly = disassembly
    }
}

public struct AssemblerPatchResult: Codable, Equatable, Sendable {
    public let assembled: AssembledCode
    public let patch: MemoryPatchResult

    public init(assembled: AssembledCode, patch: MemoryPatchResult) {
        self.assembled = assembled
        self.patch = patch
    }
}

public enum AppleAssemblerService {
    private static let maximumSourceSize = 64 * 1024
    private static let maximumBytes = 4 * 1024
    private static let maximumCommandOutput = 2 * 1024 * 1024

    public static func assemble(source: String, architecture: String) throws -> AssembledCode {
        guard ["arm64", "x86_64"].contains(architecture),
              !source.isEmpty,
              source.utf8.count <= maximumSourceSize,
              !source.contains("\0"),
              isSelfContained(source) else {
            throw AppleAssemblerError.invalidRequest
        }
        guard let clang = ToolchainProbe.path(for: "clang"),
              let otool = ToolchainProbe.path(for: "otool"),
              let objdump = ToolchainProbe.path(for: "llvm-objdump") else {
            throw AppleAssemblerError.toolUnavailable("clang/otool/llvm-objdump")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-assembler-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceURL = root.appendingPathComponent("input.s")
        let objectURL = root.appendingPathComponent("output.o")
        try Data(source.utf8).write(to: sourceURL, options: .atomic)

        let target = architecture == "arm64" ? "arm64-apple-macos14" : "x86_64-apple-macos14"
        let compileArguments = [
            "-target", target,
            "-c", "-x", "assembler",
            "-o", objectURL.path,
            sourceURL.path
        ]
        _ = try run(
            executable: clang,
            arguments: compileArguments,
            failureLabel: "clang"
        )

        let sectionResult = try run(
            executable: otool,
            arguments: ["-X", "-s", "__TEXT", "__text", objectURL.path],
            failureLabel: "otool"
        )
        let bytes = try parseTextSection(sectionResult.stdout)
        guard !bytes.isEmpty else { throw AppleAssemblerError.noTextSection }
        guard bytes.count <= maximumBytes else { throw AppleAssemblerError.outputTooLarge }

        let disassembly = try run(
            executable: objdump,
            arguments: ["--macho", "--disassemble", "--arch=\(architecture)", objectURL.path],
            failureLabel: "llvm-objdump"
        ).stdout
        return AssembledCode(
            architecture: architecture,
            source: source,
            byteCount: bytes.count,
            bytesHex: bytes.map { String(format: "%02x", $0) }.joined(),
            bytesBase64: bytes.base64EncodedString(),
            disassembly: disassembly
        )
    }

    private static func isSelfContained(_ source: String) -> Bool {
        let forbiddenTokens = [".include", ".incbin", "#include", " .include", " .incbin"]
        let lowercased = source.lowercased()
        return !forbiddenTokens.contains { lowercased.contains($0) }
    }

    private static func parseTextSection(_ output: String) throws -> Data {
        var bytes = Data()
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count >= 2,
                  fields[0].allSatisfy({ $0.isHexDigit }) else { continue }
            for token in fields.dropFirst() {
                let value = String(token)
                guard value.allSatisfy({ $0.isHexDigit }) else { break }
                if value.count == 2 {
                    guard let byte = UInt8(value, radix: 16) else { continue }
                    bytes.append(byte)
                } else if value.count == 8 {
                    let pairs = stride(from: 0, to: value.count, by: 2).compactMap { index -> UInt8? in
                        let start = value.index(value.startIndex, offsetBy: index)
                        let end = value.index(start, offsetBy: 2)
                        return UInt8(value[start..<end], radix: 16)
                    }
                    bytes.append(contentsOf: pairs.reversed())
                } else {
                    break
                }
            }
        }
        return bytes
    }

    private static func run(
        executable: String,
        arguments: [String],
        failureLabel: String
    ) throws -> (stdout: String, stderr: String) {
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: executable,
                arguments: arguments,
                maximumOutputSize: maximumCommandOutput
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw AppleAssemblerError.outputTooLarge
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw AppleAssemblerError.assemblyFailed(message)
        } catch {
            throw AppleAssemblerError.assemblyFailed(error.localizedDescription)
        }
        let stdout = String(decoding: result.stdout, as: UTF8.self)
        let stderr = String(decoding: result.stderr, as: UTF8.self)
        guard result.terminationStatus == 0 else {
            let message = [stderr, stdout]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw AppleAssemblerError.assemblyFailed(message.isEmpty ? "\(failureLabel) failed." : message)
        }
        return (stdout, stderr)
    }
}
