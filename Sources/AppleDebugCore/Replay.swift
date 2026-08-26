// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct ReplayBackendCapabilities: Codable, Equatable, Sendable {
    public let checkpointReplaySupported: Bool
    public let nativeReverseExecutionSupported: Bool
    public let externalRecordReplaySupported: Bool
    public let scope: String
    public let notes: [String]

    public init(
        checkpointReplaySupported: Bool,
        nativeReverseExecutionSupported: Bool,
        externalRecordReplaySupported: Bool,
        scope: String,
        notes: [String]
    ) {
        self.checkpointReplaySupported = checkpointReplaySupported
        self.nativeReverseExecutionSupported = nativeReverseExecutionSupported
        self.externalRecordReplaySupported = externalRecordReplaySupported
        self.scope = scope
        self.notes = notes
    }
}

public enum ReplayBackendService {
    public static func capabilities() -> ReplayBackendCapabilities {
        ReplayBackendCapabilities(
            checkpointReplaySupported: true,
            nativeReverseExecutionSupported: false,
            externalRecordReplaySupported: false,
            scope: "authorized local macOS launch sessions",
            notes: [
                "Checkpoint replay relaunches an authorized debug build and stops at the recorded source location.",
                "Registers, memory, kernel state, external I/O, and scheduler state are not restored by checkpoint replay.",
                "A native external record/replay engine is not configured; the server does not claim reverse-step or reverse-continue support."
            ]
        )
    }
}

public struct ReplayMemoryCaptureRequest: Codable, Equatable, Sendable {
    public let memoryReference: String
    public let offset: Int
    public let count: Int

    public init(memoryReference: String, offset: Int = 0, count: Int) {
        self.memoryReference = memoryReference
        self.offset = offset
        self.count = count
    }
}

public struct ReplayMemoryCapture: Codable, Equatable, Sendable {
    public let request: ReplayMemoryCaptureRequest
    public let response: DAPMessage

    public init(request: ReplayMemoryCaptureRequest, response: DAPMessage) {
        self.request = request
        self.response = response
    }
}

public struct ReplayCheckpoint: Codable, Equatable, Sendable {
    public let version: Int
    public let checkpointID: String
    public let sessionID: String
    public let createdAt: String
    public let label: String
    public let sourcePath: String?
    public let sourceLine: Int?
    public let stoppedThreadID: Int?
    public let snapshot: DebugStopSnapshot
    public let memoryCaptures: [ReplayMemoryCapture]
    public let determinismManifest: [String: String]

    public init(
        version: Int = 1,
        checkpointID: String,
        sessionID: String,
        createdAt: String,
        label: String,
        sourcePath: String?,
        sourceLine: Int?,
        stoppedThreadID: Int?,
        snapshot: DebugStopSnapshot,
        memoryCaptures: [ReplayMemoryCapture],
        determinismManifest: [String: String]
    ) {
        self.version = version
        self.checkpointID = checkpointID
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.label = label
        self.sourcePath = sourcePath
        self.sourceLine = sourceLine
        self.stoppedThreadID = stoppedThreadID
        self.snapshot = snapshot
        self.memoryCaptures = memoryCaptures
        self.determinismManifest = determinismManifest
    }
}

public struct ReplayCheckpointResult: Codable, Equatable, Sendable {
    public let checkpoint: ReplayCheckpoint
    public let outputPath: String

    public init(checkpoint: ReplayCheckpoint, outputPath: String) {
        self.checkpoint = checkpoint
        self.outputPath = outputPath
    }
}

public struct ReplayResult: Codable, Equatable, Sendable {
    public let checkpointID: String
    public let sessionID: String
    public let replayed: Bool
    public let exactStateRestored: Bool
    public let sourcePath: String
    public let sourceLine: Int
    public let wait: DebugWaitForStopResult
    public let snapshot: DebugStopSnapshot?
    public let notes: [String]

    public init(
        checkpointID: String,
        sessionID: String,
        replayed: Bool,
        exactStateRestored: Bool,
        sourcePath: String,
        sourceLine: Int,
        wait: DebugWaitForStopResult,
        snapshot: DebugStopSnapshot?,
        notes: [String]
    ) {
        self.checkpointID = checkpointID
        self.sessionID = sessionID
        self.replayed = replayed
        self.exactStateRestored = exactStateRestored
        self.sourcePath = sourcePath
        self.sourceLine = sourceLine
        self.wait = wait
        self.snapshot = snapshot
        self.notes = notes
    }
}

public enum ReplayBackendError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest(String)
    case checkpointNotFound
    case checkpointTooLarge
    case outputAlreadyExists
    case outputPathInvalid
    case missingSourceLocation
    case sessionMismatch

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message):
            return message
        case .checkpointNotFound:
            return "Replay checkpoint file was not found."
        case .checkpointTooLarge:
            return "Replay checkpoint exceeds the 16 MB safety limit."
        case .outputAlreadyExists:
            return "Replay checkpoint output already exists; refusing to overwrite it."
        case .outputPathInvalid:
            return "Replay checkpoint output path must be absolute and have an existing parent directory."
        case .missingSourceLocation:
            return "Replay checkpoint does not contain a debuggable source location."
        case .sessionMismatch:
            return "Replay checkpoint belongs to a different debug session."
        }
    }
}

public actor CheckpointReplayManager {
    private let sessions: DebugSessionManager
    private let maximumCheckpointSize = 16 * 1024 * 1024
    private let maximumMemoryCaptureBytes = 1 * 1024 * 1024

    public init(sessions: DebugSessionManager) {
        self.sessions = sessions
    }

    public func capture(
        sessionID: String,
        label: String,
        outputPath: String?,
        memoryCaptures: [ReplayMemoryCaptureRequest],
        determinismManifest: [String: String]
    ) async throws -> ReplayCheckpointResult {
        try validateLabel(label)
        try validateMemoryCaptures(memoryCaptures)
        try validateDeterminismManifest(determinismManifest)

        let snapshot = try await sessions.stopSnapshot(
            sessionID: sessionID,
            threadID: nil,
            levels: 64
        )
        let captures = try await withThrowingTaskGroup(of: ReplayMemoryCapture.self) { group in
            for request in memoryCaptures {
                group.addTask {
                    let response = try await self.sessions.readMemory(
                        sessionID: sessionID,
                        memoryReference: request.memoryReference,
                        offset: request.offset,
                        count: request.count
                    )
                    return ReplayMemoryCapture(request: request, response: response)
                }
            }

            var values: [ReplayMemoryCapture] = []
            for try await capture in group {
                values.append(capture)
            }
            return values.sorted {
                if $0.request.memoryReference != $1.request.memoryReference {
                    return $0.request.memoryReference < $1.request.memoryReference
                }
                return $0.request.offset < $1.request.offset
            }
        }

        let location = sourceLocation(from: snapshot.stackTrace)
        let checkpoint = ReplayCheckpoint(
            checkpointID: UUID().uuidString.lowercased(),
            sessionID: sessionID,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            label: label,
            sourcePath: location.path,
            sourceLine: location.line,
            stoppedThreadID: snapshot.stoppedThreadID,
            snapshot: snapshot,
            memoryCaptures: captures,
            determinismManifest: determinismManifest
        )
        let path = try outputURL(outputPath, checkpointID: checkpoint.checkpointID)
        try write(checkpoint, to: path)
        return ReplayCheckpointResult(checkpoint: checkpoint, outputPath: path.path)
    }

    public func replay(
        sessionID: String,
        checkpointPath: String,
        timeoutMilliseconds: Int
    ) async throws -> ReplayResult {
        let checkpoint = try load(from: checkpointPath)
        guard checkpoint.sessionID == sessionID else {
            throw ReplayBackendError.sessionMismatch
        }
        guard let sourcePath = checkpoint.sourcePath,
              let sourceLine = checkpoint.sourceLine else {
            throw ReplayBackendError.missingSourceLocation
        }

        let relaunch = try await sessions.relaunchLocal(
            sessionID: sessionID,
            sourcePath: sourcePath,
            sourceLine: sourceLine,
            timeoutMilliseconds: timeoutMilliseconds
        )
        let snapshot: DebugStopSnapshot?
        if relaunch.wait.stopped {
            snapshot = try? await sessions.stopSnapshot(
                sessionID: sessionID,
                threadID: relaunch.wait.stoppedThreadID,
                levels: 64
            )
        } else {
            snapshot = nil
        }
        return ReplayResult(
            checkpointID: checkpoint.checkpointID,
            sessionID: sessionID,
            replayed: relaunch.wait.stopped && !relaunch.wait.terminated,
            exactStateRestored: false,
            sourcePath: sourcePath,
            sourceLine: sourceLine,
            wait: relaunch.wait,
            snapshot: snapshot,
            notes: [
                "Replay relaunched the recorded local program and stopped at its recorded source location.",
                "Register, memory, scheduler, kernel, and external-I/O state were not restored.",
                "Use the determinismManifest to document the inputs that the debug build must reproduce."
            ]
        )
    }

    private func validateLabel(_ label: String) throws {
        guard !label.isEmpty, label.utf8.count <= 256 else {
            throw ReplayBackendError.invalidRequest("Checkpoint label must contain between 1 and 256 UTF-8 bytes.")
        }
    }

    private func validateMemoryCaptures(_ captures: [ReplayMemoryCaptureRequest]) throws {
        guard captures.count <= 16 else {
            throw ReplayBackendError.invalidRequest("At most 16 memory captures are allowed per checkpoint.")
        }
        var total = 0
        for capture in captures {
            guard !capture.memoryReference.isEmpty, capture.memoryReference.utf8.count <= 512 else {
                throw ReplayBackendError.invalidRequest("Memory capture reference is invalid.")
            }
            try DebugPolicy.validateNonNegative(capture.offset, label: "Checkpoint memory offset")
            try DebugPolicy.validatePositive(capture.count, label: "Checkpoint memory count", maximum: 65_536)
            total += capture.count
        }
        guard total <= maximumMemoryCaptureBytes else {
            throw ReplayBackendError.invalidRequest("Checkpoint memory captures exceed the 1 MB safety limit.")
        }
    }

    private func validateDeterminismManifest(_ manifest: [String: String]) throws {
        guard manifest.count <= 32 else {
            throw ReplayBackendError.invalidRequest("A determinism manifest may contain at most 32 entries.")
        }
        for (key, value) in manifest {
            guard !key.isEmpty, key.utf8.count <= 256,
                  value.utf8.count <= 4_096 else {
                throw ReplayBackendError.invalidRequest("Determinism manifest keys or values are invalid.")
            }
        }
    }

    private func outputURL(_ outputPath: String?, checkpointID: String) throws -> URL {
        let url: URL
        if let outputPath {
            guard outputPath.hasPrefix("/"), outputPath.utf8.count <= 4_096 else {
                throw ReplayBackendError.outputPathInvalid
            }
            url = URL(fileURLWithPath: outputPath)
        } else {
            url = FileManager.default.temporaryDirectory
                .appendingPathComponent("apple-debug-mcp-checkpoint-\(checkpointID).json")
        }
        let parent = url.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              !FileManager.default.fileExists(atPath: url.path) else {
            if FileManager.default.fileExists(atPath: url.path) {
                throw ReplayBackendError.outputAlreadyExists
            }
            throw ReplayBackendError.outputPathInvalid
        }
        return url
    }

    private func write(_ checkpoint: ReplayCheckpoint, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(checkpoint)
        guard data.count <= maximumCheckpointSize else {
            throw ReplayBackendError.checkpointTooLarge
        }
        guard FileManager.default.createFile(atPath: url.path, contents: data) else {
            throw ReplayBackendError.outputAlreadyExists
        }
    }

    private func load(from path: String) throws -> ReplayCheckpoint {
        guard path.hasPrefix("/"), path.utf8.count <= 4_096 else {
            throw ReplayBackendError.outputPathInvalid
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ReplayBackendError.checkpointNotFound
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              size.intValue <= maximumCheckpointSize else {
            throw ReplayBackendError.checkpointTooLarge
        }
        do {
            return try JSONDecoder().decode(ReplayCheckpoint.self, from: Data(contentsOf: url))
        } catch {
            throw ReplayBackendError.invalidRequest("Replay checkpoint JSON is invalid: \(error.localizedDescription)")
        }
    }

    private func sourceLocation(from stackTrace: DAPMessage?) -> (path: String?, line: Int?) {
        guard case .object(let body) = stackTrace?.body,
              case .array(let frames) = body["stackFrames"],
              case .object(let frame) = frames.first else {
            return (nil, nil)
        }
        var path: String?
        var line: Int?
        if case .object(let source) = frame["source"],
           case .string(let value) = source["path"],
           !value.isEmpty {
            path = value
        }
        if case .integer(let value) = frame["line"], value > 0 {
            line = value
        }
        return (path, line)
    }
}
