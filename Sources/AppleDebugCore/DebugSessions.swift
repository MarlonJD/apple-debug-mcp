// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum DebugPolicyError: Error, Equatable, LocalizedError, Sendable {
    case launchDisabled
    case attachDisabled
    case memoryWriteDisabled
    case evaluateDisabled
    case invalidProcessID
    case invalidMemoryWrite
    case invalidRequest(String)
    case targetNotFound
    case targetNotRegularFile

    public var errorDescription: String? {
        switch self {
        case .launchDisabled:
            return "Target launch is disabled. Set APPLE_DEBUG_ALLOW_TARGET_LAUNCH=1 only for an authorized local target."
        case .attachDisabled:
            return "Target attach is disabled. Set APPLE_DEBUG_ALLOW_TARGET_ATTACH=1 only for an authorized local target."
        case .memoryWriteDisabled:
            return "Memory write is disabled. Set APPLE_DEBUG_ALLOW_MEMORY_WRITE=1 only for an authorized target."
        case .evaluateDisabled:
            return "Expression evaluation is disabled. Set APPLE_DEBUG_ALLOW_EVALUATE=1 only for an authorized target."
        case .invalidProcessID:
            return "Process ID must be a positive integer."
        case .invalidMemoryWrite:
            return "Memory write data is invalid or exceeds the 4096-byte safety limit."
        case .invalidRequest(let message):
            return message
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

    public static func validateAttach(processID: Int) throws {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_TARGET_ATTACH"] == "1" else {
            throw DebugPolicyError.attachDisabled
        }
        guard processID > 0 else {
            throw DebugPolicyError.invalidProcessID
        }
    }

    public static func validateMemoryWrite(data: Data) throws {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_MEMORY_WRITE"] == "1" else {
            throw DebugPolicyError.memoryWriteDisabled
        }
        guard !data.isEmpty, data.count <= 4096 else {
            throw DebugPolicyError.invalidMemoryWrite
        }
    }

    public static func validateEvaluate() throws {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_EVALUATE"] == "1" else {
            throw DebugPolicyError.evaluateDisabled
        }
    }

    public static func validatePositive(_ value: Int, label: String, maximum: Int? = nil) throws {
        guard value > 0 else {
            throw DebugPolicyError.invalidRequest("\(label) must be positive.")
        }
        if let maximum, value > maximum {
            throw DebugPolicyError.invalidRequest("\(label) exceeds the maximum of \(maximum).")
        }
    }

    public static func validateNonNegative(_ value: Int, label: String) throws {
        guard value >= 0 else {
            throw DebugPolicyError.invalidRequest("\(label) must not be negative.")
        }
    }

    public static func validateExpression(_ expression: String) throws {
        guard !expression.isEmpty, expression.count <= 16_384 else {
            throw DebugPolicyError.invalidRequest("Expression must be between 1 and 16384 characters.")
        }
    }
}

public struct DebugSessionSummary: Codable, Equatable, Sendable {
    public let sessionID: String
    public let target: String

    public init(sessionID: String, target: String = "macos") {
        self.sessionID = sessionID
        self.target = target
    }
}

public actor DebugSessionManager {
    private struct SessionRecord {
        let session: LLDBDAPSession
        let target: String
        let deviceIdentifier: String?
    }

    private var sessions: [String: SessionRecord] = [:]

    public init() {}

    public func create(deviceIdentifier: String? = nil) async throws -> DebugSessionSummary {
        let sessionID = UUID().uuidString.lowercased()
        let session: LLDBDAPSession
        let target: String
        if let deviceIdentifier {
            guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_DEVICE_DEBUG"] == "1" else {
                throw AppleDeviceError.debugDisabled
            }
            try AppleDeviceService.validateAuthorizedDevice(identifier: deviceIdentifier)
            session = try LLDBDAPSession(deviceIdentifier: deviceIdentifier)
            target = "ios-device:\(deviceIdentifier)"
        } else {
            session = try LLDBDAPSession()
            target = "macos"
        }
        do {
            _ = try await session.start()
            sessions[sessionID] = SessionRecord(
                session: session,
                target: target,
                deviceIdentifier: deviceIdentifier
            )
            return DebugSessionSummary(sessionID: sessionID, target: target)
        } catch {
            await session.stop()
            throw error
        }
    }

    public func list() -> [DebugSessionSummary] {
        sessions.keys.sorted().compactMap { sessionID in
            guard let record = sessions[sessionID] else { return nil }
            return DebugSessionSummary(sessionID: sessionID, target: record.target)
        }
    }

    public func launch(
        sessionID: String,
        program: String,
        arguments: [String],
        stopOnEntry: Bool
    ) async throws -> DAPMessage {
        try DebugPolicy.validateLaunchTarget(path: program)
        guard let record = sessions[sessionID] else {
            throw DAPError.requestFailed("Unknown debug session: \(sessionID)")
        }
        guard record.deviceIdentifier == nil else {
            throw DebugPolicyError.invalidRequest("Launch is not available for a physical-device session; use apple_device_launch.")
        }
        do {
            return try await record.session.launch(
                program: program,
                arguments: arguments,
                stopOnEntry: stopOnEntry
            )
        } catch {
            await record.session.stop()
            sessions.removeValue(forKey: sessionID)
            throw error
        }
    }

    public func attach(sessionID: String, processID: Int) async throws -> DAPMessage {
        try DebugPolicy.validatePositive(processID, label: "Process ID")
        let record = try record(for: sessionID)
        if let deviceIdentifier = record.deviceIdentifier {
            guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_DEVICE_DEBUG"] == "1" else {
                throw AppleDeviceError.debugDisabled
            }
            try AppleDeviceService.validateAuthorizedDevice(identifier: deviceIdentifier)
        } else {
            try DebugPolicy.validateAttach(processID: processID)
        }
        return try await record.session.attach(processID: processID)
    }

    public func setBreakpoint(sessionID: String, file: String, line: Int) async throws -> DAPMessage {
        try DebugPolicy.validatePositive(line, label: "Breakpoint line")
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
        try DebugPolicy.validatePositive(threadID, label: "Thread ID")
        try DebugPolicy.validatePositive(levels, label: "Stack levels", maximum: 1_000)
        return try await session(for: sessionID).send(
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
        try DebugPolicy.validatePositive(count, label: "Memory count", maximum: 1_048_576)
        try DebugPolicy.validateNonNegative(offset, label: "Memory offset")
        return try await session(for: sessionID).send(
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
        try DebugPolicy.validatePositive(instructionCount, label: "Instruction count", maximum: 1_000)
        try DebugPolicy.validateNonNegative(instructionOffset, label: "Instruction offset")
        return try await session(for: sessionID).send(
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
        try DebugPolicy.validatePositive(threadID, label: "Thread ID")
        return try await session(for: sessionID).send(
            command: "continue",
            arguments: .object(["threadId": .integer(threadID)])
        )
    }

    public func pause(sessionID: String) async throws -> DAPMessage {
        try await session(for: sessionID).send(command: "pause")
    }

    public func step(
        sessionID: String,
        threadID: Int,
        kind: DebugStepKind
    ) async throws -> DAPMessage {
        try DebugPolicy.validatePositive(threadID, label: "Thread ID")
        return try await session(for: sessionID).send(
            command: kind.command,
            arguments: .object(["threadId": .integer(threadID)])
        )
    }

    public func scopes(sessionID: String, frameID: Int) async throws -> DAPMessage {
        try await session(for: sessionID).send(
            command: "scopes",
            arguments: .object(["frameId": .integer(frameID)])
        )
    }

    public func variables(sessionID: String, variablesReference: Int) async throws -> DAPMessage {
        try await session(for: sessionID).send(
            command: "variables",
            arguments: .object(["variablesReference": .integer(variablesReference)])
        )
    }

    public func evaluate(
        sessionID: String,
        expression: String,
        frameID: Int?,
        context: String
    ) async throws -> DAPMessage {
        try DebugPolicy.validateExpression(expression)
        try DebugPolicy.validateEvaluate()
        var arguments: [String: DAPValue] = [
            "expression": .string(expression),
            "context": .string(context)
        ]
        if let frameID {
            arguments["frameId"] = .integer(frameID)
        }
        return try await session(for: sessionID).send(
            command: "evaluate",
            arguments: .object(arguments)
        )
    }

    public func dataBreakpointInfo(
        sessionID: String,
        variablesReference: Int,
        name: String
    ) async throws -> DAPMessage {
        try await session(for: sessionID).send(
            command: "dataBreakpointInfo",
            arguments: .object([
                "variablesReference": .integer(variablesReference),
                "name": .string(name)
            ])
        )
    }

    public func setDataBreakpoint(
        sessionID: String,
        dataID: String,
        accessType: String?
    ) async throws -> DAPMessage {
        var breakpoint: [String: DAPValue] = ["dataId": .string(dataID)]
        if let accessType {
            breakpoint["accessType"] = .string(accessType)
        }
        return try await session(for: sessionID).send(
            command: "setDataBreakpoints",
            arguments: .object([
                "breakpoints": .array([.object(breakpoint)])
            ])
        )
    }

    public func writeMemory(
        sessionID: String,
        memoryReference: String,
        offset: Int,
        data: Data
    ) async throws -> DAPMessage {
        try DebugPolicy.validateMemoryWrite(data: data)
        return try await session(for: sessionID).send(
            command: "writeMemory",
            arguments: .object([
                "memoryReference": .string(memoryReference),
                "offset": .integer(offset),
                "data": .string(data.base64EncodedString())
            ])
        )
    }

    public func close(sessionID: String) async -> Bool {
        guard let record = sessions.removeValue(forKey: sessionID) else {
            return false
        }
        await record.session.stop()
        return true
    }

    public func closeAll() async {
        let sessions = self.sessions
        self.sessions.removeAll()
        for record in sessions.values {
            await record.session.stop()
        }
    }

    private func session(for sessionID: String) throws -> LLDBDAPSession {
        try record(for: sessionID).session
    }

    private func record(for sessionID: String) throws -> SessionRecord {
        guard let record = sessions[sessionID] else {
            throw DAPError.requestFailed("Unknown debug session: \(sessionID)")
        }
        return record
    }
}

public enum DebugStepKind: String, Codable, CaseIterable, Sendable {
    case inInstruction = "stepIn"
    case over = "next"
    case out = "stepOut"

    fileprivate var command: String { rawValue }
}
