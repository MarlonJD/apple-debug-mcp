// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum DebugPolicyError: Error, Equatable, LocalizedError, Sendable {
    case launchDisabled
    case targetNotFound
    case targetNotRegularFile

    public var errorDescription: String? {
        switch self {
        case .launchDisabled:
            return "Target launch is disabled. Set APPLE_DEBUG_ALLOW_TARGET_LAUNCH=1 only for an authorized local target."
        case .targetNotFound:
            return "Debug target does not exist."
        case .targetNotRegularFile:
            return "Debug target is not a regular file."
        }
    }
}

public enum DebugPolicy {
    public static func validateLaunchTarget(path: String) throws {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_TARGET_LAUNCH"] == "1" else {
            throw DebugPolicyError.launchDisabled
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DebugPolicyError.targetNotFound
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let type = attributes[.type] as? FileAttributeType, type == .typeRegular else {
            throw DebugPolicyError.targetNotRegularFile
        }
    }
}

public struct DebugSessionSummary: Codable, Equatable, Sendable {
    public let sessionID: String

    public init(sessionID: String) {
        self.sessionID = sessionID
    }
}

public actor DebugSessionManager {
    private var sessions: [String: LLDBDAPSession] = [:]

    public init() {}

    public func create() async throws -> DebugSessionSummary {
        let sessionID = UUID().uuidString.lowercased()
        let session = try LLDBDAPSession()
        do {
            _ = try await session.start()
            sessions[sessionID] = session
            return DebugSessionSummary(sessionID: sessionID)
        } catch {
            await session.stop()
            throw error
        }
    }

    public func list() -> [DebugSessionSummary] {
        sessions.keys.sorted().map(DebugSessionSummary.init(sessionID:))
    }

    public func launch(
        sessionID: String,
        program: String,
        arguments: [String],
        stopOnEntry: Bool
    ) async throws -> DAPMessage {
        try DebugPolicy.validateLaunchTarget(path: program)
        guard let session = sessions[sessionID] else {
            throw DAPError.requestFailed("Unknown debug session: (sessionID)")
        }
        do {
            return try await session.launch(
                program: program,
                arguments: arguments,
                stopOnEntry: stopOnEntry
            )
        } catch {
            await session.stop()
            sessions.removeValue(forKey: sessionID)
            throw error
        }
    }

    public func attach(sessionID: String, processID: Int) async throws -> DAPMessage {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_TARGET_ATTACH"] == "1" else {
            throw DebugPolicyError.launchDisabled
        }
        return try await session(for: sessionID).attach(processID: processID)
    }

    public func setBreakpoint(sessionID: String, file: String, line: Int) async throws -> DAPMessage {
        let session = try session(for: sessionID)
        return try await session.send(
            command: "setBreakpoints",
            arguments: .object([
                "source": .object(["path": .string(file)]),
                "breakpoints": .array([
                    .object(["line": .integer(line)])
                ])
            ])
        )
    }

    public func threads(sessionID: String) async throws -> DAPMessage {
        try await session(for: sessionID).send(command: "threads")
    }

    public func stackTrace(sessionID: String, threadID: Int, levels: Int) async throws -> DAPMessage {
        try await session(for: sessionID).send(
            command: "stackTrace",
            arguments: .object([
                "threadId": .integer(threadID),
                "levels": .integer(levels)
            ])
        )
    }

    public func readMemory(
        sessionID: String,
        memoryReference: String,
        offset: Int,
        count: Int
    ) async throws -> DAPMessage {
        try await session(for: sessionID).send(
            command: "readMemory",
            arguments: .object([
                "memoryReference": .string(memoryReference),
                "offset": .integer(offset),
                "count": .integer(count)
            ])
        )
    }

    public func disassemble(
        sessionID: String,
        memoryReference: String,
        instructionOffset: Int,
        instructionCount: Int
    ) async throws -> DAPMessage {
        try await session(for: sessionID).send(
            command: "disassemble",
            arguments: .object([
                "memoryReference": .string(memoryReference),
                "instructionOffset": .integer(instructionOffset),
                "instructionCount": .integer(instructionCount),
                "resolveSymbols": .boolean(true)
            ])
        )
    }

    public func continueExecution(sessionID: String, threadID: Int) async throws -> DAPMessage {
        try await session(for: sessionID).send(
            command: "continue",
            arguments: .object(["threadId": .integer(threadID)])
        )
    }

    public func close(sessionID: String) async -> Bool {
        guard let session = sessions.removeValue(forKey: sessionID) else {
            return false
        }
        await session.stop()
        return true
    }

    public func closeAll() async {
        let sessions = self.sessions
        self.sessions.removeAll()
        for session in sessions.values {
            await session.stop()
        }
    }

    private func session(for sessionID: String) throws -> LLDBDAPSession {
        guard let session = sessions[sessionID] else {
            throw DAPError.requestFailed("Unknown debug session: \(sessionID)")
        }
        return session
    }
}
