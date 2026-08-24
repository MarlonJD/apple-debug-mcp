// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct AssemblyPatchByteChange: Codable, Equatable, Sendable {
    public let offset: Int
    public let before: String
    public let after: String

    public init(offset: Int, before: String, after: String) {
        self.offset = offset
        self.before = before
        self.after = after
    }
}

public struct AssemblyPatchPreview: Codable, Equatable, Sendable {
    public let path: String
    public let architecture: String
    public let fileOffset: Int
    public let byteCount: Int
    public let bytesHex: String
    public let changes: [AssemblyPatchByteChange]
    public let disassembly: String
    public let applied: Bool

    public init(path: String, architecture: String, fileOffset: Int, byteCount: Int, bytesHex: String, changes: [AssemblyPatchByteChange], disassembly: String, applied: Bool) {
        self.path = path
        self.architecture = architecture
        self.fileOffset = fileOffset
        self.byteCount = byteCount
        self.bytesHex = bytesHex
        self.changes = changes
        self.disassembly = disassembly
        self.applied = applied
    }
}

public struct AppleResignPlan: Codable, Equatable, Sendable {
    public let inputPath: String
    public let outputPath: String
    public let identity: String
    public let entitlementsPath: String?
    public let commands: [[String]]
    public let executionSupported: Bool
    public let reason: String

    public init(inputPath: String, outputPath: String, identity: String, entitlementsPath: String?, commands: [[String]], executionSupported: Bool, reason: String) {
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.identity = identity
        self.entitlementsPath = entitlementsPath
        self.commands = commands
        self.executionSupported = executionSupported
        self.reason = reason
    }
}

public enum ApplePatchWorkflowError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case inputNotFound
    case expectedBytesMismatch
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest: return "Patch workflow request is invalid or exceeds its bounded limits."
        case .inputNotFound: return "The patch workflow input was not found."
        case .expectedBytesMismatch: return "Patch preview expected bytes do not match the input file."
        case .outputTooLarge: return "Patch preview bytes exceed the configured limit."
        }
    }
}

public enum ApplePatchWorkflowService {
    public static func preview(
        path: String,
        architecture: String,
        fileOffset: Int,
        source: String,
        expectedData: Data? = nil
    ) throws -> AssemblyPatchPreview {
        guard !path.isEmpty, path.utf8.count <= 4_096, !path.contains("\0"), URL(fileURLWithPath: path).path.hasPrefix("/"), fileOffset >= 0 else {
            throw ApplePatchWorkflowError.invalidRequest
        }
        guard FileManager.default.fileExists(atPath: path) else { throw ApplePatchWorkflowError.inputNotFound }
        let assembled = try AppleAssemblerService.assemble(source: source, architecture: architecture)
        guard let data = Data(base64Encoded: assembled.bytesBase64), data.count <= 4_096 else { throw ApplePatchWorkflowError.outputTooLarge }
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(fileOffset))
        let before = try handle.read(upToCount: data.count) ?? Data()
        guard before.count == data.count else { throw ApplePatchWorkflowError.invalidRequest }
        if let expectedData, before != expectedData { throw ApplePatchWorkflowError.expectedBytesMismatch }
        let changes = zip(before, data).enumerated().compactMap { index, pair -> AssemblyPatchByteChange? in
            guard pair.0 != pair.1 else { return nil }
            return AssemblyPatchByteChange(offset: fileOffset + index, before: String(format: "%02x", pair.0), after: String(format: "%02x", pair.1))
        }
        return AssemblyPatchPreview(path: path, architecture: architecture, fileOffset: fileOffset, byteCount: data.count, bytesHex: assembled.bytesHex, changes: changes, disassembly: assembled.disassembly, applied: false)
    }

    public static func resignPlan(
        inputPath: String,
        outputPath: String,
        identity: String,
        entitlementsPath: String? = nil
    ) throws -> AppleResignPlan {
        guard !inputPath.isEmpty, !outputPath.isEmpty, !identity.isEmpty,
              inputPath.utf8.count <= 4_096, outputPath.utf8.count <= 4_096, identity.utf8.count <= 512,
              !inputPath.contains("\0"), !outputPath.contains("\0"), !identity.contains("\0"),
              URL(fileURLWithPath: inputPath).path.hasPrefix("/"), URL(fileURLWithPath: outputPath).path.hasPrefix("/"),
              FileManager.default.fileExists(atPath: inputPath), !FileManager.default.fileExists(atPath: outputPath),
              entitlementsPath.map({ FileManager.default.fileExists(atPath: $0) && $0.utf8.count <= 4_096 && !$0.contains("\0") }) ?? true else {
            throw ApplePatchWorkflowError.invalidRequest
        }
        var signArguments = ["codesign", "--force", "--sign", identity]
        if let entitlementsPath { signArguments += ["--entitlements", entitlementsPath] }
        signArguments.append(outputPath)
        return AppleResignPlan(
            inputPath: inputPath,
            outputPath: outputPath,
            identity: identity,
            entitlementsPath: entitlementsPath,
            commands: [
                ["/bin/cp", "-R", inputPath, outputPath],
                signArguments,
                ["codesign", "--verify", "--deep", "--strict", outputPath],
                ["spctl", "--assess", "--type", "execute", "--verbose=4", outputPath]
            ],
            executionSupported: false,
            reason: "The MCP surface returns a reviewable plan only; copying, signing, and Gatekeeper assessment remain explicit release-authority operations."
        )
    }
}
