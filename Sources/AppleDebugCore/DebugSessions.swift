// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum DebugPolicyError: Error, Equatable, LocalizedError, Sendable {
    case launchDisabled
    case attachDisabled
    case memoryWriteDisabled
    case variableWriteDisabled
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
        case .variableWriteDisabled:
            return "Variable write is disabled. Set APPLE_DEBUG_ALLOW_VARIABLE_WRITE=1 only for an authorized target."
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

    public static func validateVariableWrite(name: String, value: String) throws {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_VARIABLE_WRITE"] == "1" else {
            throw DebugPolicyError.variableWriteDisabled
        }
        guard !name.isEmpty, name.utf8.count <= 4_096,
              !value.isEmpty, value.utf8.count <= 16_384 else {
            throw DebugPolicyError.invalidRequest("Variable name or value is invalid.")
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

public struct DebugLaunchConfiguration: Codable, Equatable, Sendable {
    public let program: String
    public let arguments: [String]
    public let stopOnEntry: Bool

    public init(program: String, arguments: [String], stopOnEntry: Bool) {
        self.program = program
        self.arguments = arguments
        self.stopOnEntry = stopOnEntry
    }
}

public struct DebugRelaunchResult: Codable, Equatable, Sendable {
    public let sessionID: String
    public let launchResponse: DAPMessage
    public let wait: DebugWaitForStopResult

    public init(sessionID: String, launchResponse: DAPMessage, wait: DebugWaitForStopResult) {
        self.sessionID = sessionID
        self.launchResponse = launchResponse
        self.wait = wait
    }
}

public struct RegisterSnapshot: Codable, Equatable, Sendable {
    public let scopes: DAPMessage
    public let variables: DAPMessage?

    public init(scopes: DAPMessage, variables: DAPMessage?) {
        self.scopes = scopes
        self.variables = variables
    }
}

public struct DebugStopSnapshot: Codable, Equatable, Sendable {
    public let sessionID: String
    public let stopReason: String?
    public let stoppedThreadID: Int?
    public let events: [DAPMessage]
    public let threads: DAPMessage
    public let stackTrace: DAPMessage?
    public let scopes: DAPMessage?
    public let registers: RegisterSnapshot?
    public let modules: DAPMessage?

    public init(
        sessionID: String,
        stopReason: String?,
        stoppedThreadID: Int?,
        events: [DAPMessage],
        threads: DAPMessage,
        stackTrace: DAPMessage?,
        scopes: DAPMessage?,
        registers: RegisterSnapshot?,
        modules: DAPMessage?
    ) {
        self.sessionID = sessionID
        self.stopReason = stopReason
        self.stoppedThreadID = stoppedThreadID
        self.events = events
        self.threads = threads
        self.stackTrace = stackTrace
        self.scopes = scopes
        self.registers = registers
        self.modules = modules
    }
}

public struct DebugWaitForStopResult: Codable, Equatable, Sendable {
    public let sessionID: String
    public let stopReason: String?
    public let stoppedThreadID: Int?
    public let stopped: Bool
    public let terminated: Bool
    public let timedOut: Bool
    public let events: [DAPMessage]

    public init(
        sessionID: String,
        stopReason: String?,
        stoppedThreadID: Int?,
        stopped: Bool,
        terminated: Bool,
        timedOut: Bool,
        events: [DAPMessage]
    ) {
        self.sessionID = sessionID
        self.stopReason = stopReason
        self.stoppedThreadID = stoppedThreadID
        self.stopped = stopped
        self.terminated = terminated
        self.timedOut = timedOut
        self.events = events
    }
}

public struct ForwardExecutionTraceResult: Codable, Equatable, Sendable {
    public let sessionID: String
    public let threadID: Int
    public let requestedSteps: Int
    public let completedSteps: Int
    public let reverseExecutionSupported: Bool
    public let points: [DebugWaitForStopResult]

    public init(
        sessionID: String,
        threadID: Int,
        requestedSteps: Int,
        completedSteps: Int,
        reverseExecutionSupported: Bool,
        points: [DebugWaitForStopResult]
    ) {
        self.sessionID = sessionID
        self.threadID = threadID
        self.requestedSteps = requestedSteps
        self.completedSteps = completedSteps
        self.reverseExecutionSupported = reverseExecutionSupported
        self.points = points
    }
}

public struct DebugMemoryMapResult: Codable, Equatable, Sendable {
    public let processID: Int
    public let output: String

    public init(processID: Int, output: String) {
        self.processID = processID
        self.output = output
    }
}

public struct MemorySearchResult: Codable, Equatable, Sendable {
    public let sessionID: String
    public let memoryReference: String
    public let offset: Int
    public let count: Int
    public let pattern: String
    public let matches: [Int]

    public init(
        sessionID: String,
        memoryReference: String,
        offset: Int,
        count: Int,
        pattern: String,
        matches: [Int]
    ) {
        self.sessionID = sessionID
        self.memoryReference = memoryReference
        self.offset = offset
        self.count = count
        self.pattern = pattern
        self.matches = matches
    }
}

public struct MemoryPatchResult: Codable, Equatable, Sendable {
    public let sessionID: String
    public let memoryReference: String
    public let offset: Int
    public let originalData: String
    public let requestedData: String
    public let verified: Bool
    public let rolledBack: Bool

    public init(
        sessionID: String,
        memoryReference: String,
        offset: Int,
        originalData: String,
        requestedData: String,
        verified: Bool,
        rolledBack: Bool
    ) {
        self.sessionID = sessionID
        self.memoryReference = memoryReference
        self.offset = offset
        self.originalData = originalData
        self.requestedData = requestedData
        self.verified = verified
        self.rolledBack = rolledBack
    }
}

public actor DebugSessionManager {
    private struct SessionRecord {
        let session: LLDBDAPSession
        let target: String
        let deviceIdentifier: String?
        let programPath: String?
        let legacyTransport: LegacyDeviceDebugTransport?
        let launchConfiguration: DebugLaunchConfiguration?
    }

    private struct LegacySessionSetup {
        let session: LLDBDAPSession
        let transport: LegacyDeviceDebugTransport
    }

    private var sessions: [String: SessionRecord] = [:]

    public init() {}

    public func create(
        deviceIdentifier: String? = nil,
        appPath: String? = nil
    ) async throws -> DebugSessionSummary {
        let sessionID = UUID().uuidString.lowercased()
        let session: LLDBDAPSession
        let target: String
        let programPath: String?
        let legacyTransport: LegacyDeviceDebugTransport?
        var sessionStarted = false
        if let deviceIdentifier {
            guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_DEVICE_DEBUG"] == "1" else {
                throw AppleDeviceError.debugDisabled
            }
            let device = try AppleDeviceService.device(identifier: deviceIdentifier)
            switch device.transport {
            case .coreDevice:
                session = try LLDBDAPSession(deviceIdentifier: deviceIdentifier)
                target = "ios-device:\(deviceIdentifier)"
                programPath = appPath
                legacyTransport = nil
            case .legacyXcode:
                guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_DEVICE_MUTATION"] == "1" else {
                    throw AppleDeviceError.mutationDisabled
                }
                guard let appPath else {
                    throw AppleDeviceError.legacyDebugRequiresAppPath
                }
                let setup = try await createLegacySession(
                    deviceIdentifier: deviceIdentifier,
                    appPath: appPath
                )
                session = setup.session
                target = "ios-device-legacy:\(deviceIdentifier)"
                programPath = appPath
                legacyTransport = setup.transport
                sessionStarted = true
            }
        } else {
            guard appPath == nil else {
                throw DebugPolicyError.invalidRequest("appPath is only valid when creating a physical-device debug session.")
            }
            session = try LLDBDAPSession()
            target = "macos"
            programPath = nil
            legacyTransport = nil
        }
        do {
            if !sessionStarted {
                _ = try await session.start()
            }
            sessions[sessionID] = SessionRecord(
                session: session,
                target: target,
                deviceIdentifier: deviceIdentifier,
                programPath: programPath,
                legacyTransport: legacyTransport,
                launchConfiguration: nil
            )
            return DebugSessionSummary(sessionID: sessionID, target: target)
        } catch {
            await session.stop()
            if let legacyTransport {
                await legacyTransport.stop()
            }
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
            throw DebugPolicyError.invalidRequest(
                record.legacyTransport == nil
                    ? "Launch is not available for a CoreDevice physical-device session; use apple_device_launch."
                    : "Legacy physical-device sessions launch their signed app during session creation."
            )
        }
        do {
            let response = try await record.session.launch(
                program: program,
                arguments: arguments,
                stopOnEntry: stopOnEntry
            )
            sessions[sessionID] = SessionRecord(
                session: record.session,
                target: record.target,
                deviceIdentifier: record.deviceIdentifier,
                programPath: record.programPath,
                legacyTransport: record.legacyTransport,
                launchConfiguration: DebugLaunchConfiguration(
                    program: program,
                    arguments: arguments,
                    stopOnEntry: stopOnEntry
                )
            )
            return response
        } catch {
            await record.session.stop()
            sessions.removeValue(forKey: sessionID)
            throw error
        }
    }

    public func relaunchLocal(
        sessionID: String,
        sourcePath: String,
        sourceLine: Int,
        timeoutMilliseconds: Int
    ) async throws -> DebugRelaunchResult {
        guard !sourcePath.isEmpty, sourcePath.utf8.count <= 4_096 else {
            throw DebugPolicyError.invalidRequest("Replay source path is invalid.")
        }
        try DebugPolicy.validatePositive(sourceLine, label: "Replay source line")
        try DebugPolicy.validatePositive(
            timeoutMilliseconds,
            label: "Replay stop timeout",
            maximum: 120_000
        )

        let record = try record(for: sessionID)
        guard record.deviceIdentifier == nil, record.target == "macos" else {
            throw DebugPolicyError.invalidRequest(
                "Checkpoint replay is currently limited to an authorized local macOS launch session."
            )
        }
        guard let launchConfiguration = record.launchConfiguration else {
            throw DebugPolicyError.invalidRequest(
                "Checkpoint replay requires a prior local launch configuration."
            )
        }
        try DebugPolicy.validateLaunchTarget(path: launchConfiguration.program)

        let replacement = try LLDBDAPSession()
        do {
            _ = try await replacement.start()
            _ = try await replacement.send(
                command: "setBreakpoints",
                arguments: .object([
                    "source": .object(["path": .string(sourcePath)]),
                    "breakpoints": .array([
                        .object(["line": .integer(sourceLine)])
                    ])
                ])
            )
            let launchResponse = try await replacement.launch(
                program: launchConfiguration.program,
                arguments: launchConfiguration.arguments,
                stopOnEntry: false
            )
            sessions[sessionID] = SessionRecord(
                session: replacement,
                target: record.target,
                deviceIdentifier: record.deviceIdentifier,
                programPath: record.programPath,
                legacyTransport: record.legacyTransport,
                launchConfiguration: launchConfiguration
            )
            await record.session.stop()

            let wait = try await waitForStop(
                sessionID: sessionID,
                timeoutMilliseconds: timeoutMilliseconds
            )
            return DebugRelaunchResult(
                sessionID: sessionID,
                launchResponse: launchResponse,
                wait: wait
            )
        } catch {
            await replacement.stop()
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
            if record.legacyTransport != nil {
                throw DebugPolicyError.invalidRequest(
                    "Legacy physical-device sessions are already attached during session creation."
                )
            }
            return try await record.session.attach(
                deviceProcessID: processID,
                program: record.programPath
            )
        } else {
            try DebugPolicy.validateAttach(processID: processID)
        }
        return try await record.session.attach(processID: processID)
    }

    public func setBreakpoint(
        sessionID: String,
        file: String,
        line: Int,
        condition: String? = nil,
        hitCondition: String? = nil,
        logMessage: String? = nil
    ) async throws -> DAPMessage {
        try DebugPolicy.validatePositive(line, label: "Breakpoint line")
        guard !file.isEmpty, file.utf8.count <= 4_096 else {
            throw DebugPolicyError.invalidRequest("Breakpoint source path is invalid.")
        }
        if let condition { try DebugPolicy.validateExpression(condition) }
        if let hitCondition { try DebugPolicy.validateExpression(hitCondition) }
        if let logMessage { try DebugPolicy.validateExpression(logMessage) }
        var breakpoint: [String: DAPValue] = ["line": .integer(line)]
        if let condition { breakpoint["condition"] = .string(condition) }
        if let hitCondition { breakpoint["hitCondition"] = .string(hitCondition) }
        if let logMessage { breakpoint["logMessage"] = .string(logMessage) }
        let session = try session(for: sessionID)
        return try await session.send(
            command: "setBreakpoints",
            arguments: .object([
                "source": .object(["path": .string(file)]),
                "breakpoints": .array([
                    .object(breakpoint)
                ])
            ])
        )
    }

    public func breakpointLocations(
        sessionID: String,
        file: String,
        line: Int,
        column: Int?,
        endLine: Int?,
        endColumn: Int?
    ) async throws -> DAPMessage {
        try DebugPolicy.validatePositive(line, label: "Breakpoint location line")
        guard !file.isEmpty, file.utf8.count <= 4_096 else {
            throw DebugPolicyError.invalidRequest("Breakpoint location source path is invalid.")
        }
        var arguments: [String: DAPValue] = [
            "source": .object(["path": .string(file)]),
            "line": .integer(line)
        ]
        if let column {
            try DebugPolicy.validatePositive(column, label: "Breakpoint location column")
            arguments["column"] = .integer(column)
        }
        if let endLine {
            try DebugPolicy.validatePositive(endLine, label: "Breakpoint location end line")
            arguments["endLine"] = .integer(endLine)
        }
        if let endColumn {
            try DebugPolicy.validatePositive(endColumn, label: "Breakpoint location end column")
            arguments["endColumn"] = .integer(endColumn)
        }
        return try await session(for: sessionID).send(
            command: "breakpointLocations",
            arguments: .object(arguments)
        )
    }

    public func setInstructionBreakpoint(
        sessionID: String,
        instructionReference: String,
        offset: Int?,
        condition: String?,
        hitCondition: String?,
        logMessage: String?
    ) async throws -> DAPMessage {
        guard !instructionReference.isEmpty, instructionReference.utf8.count <= 512 else {
            throw DebugPolicyError.invalidRequest("Instruction breakpoint reference is invalid.")
        }
        if let offset { try DebugPolicy.validateNonNegative(offset, label: "Instruction breakpoint offset") }
        if let condition { try DebugPolicy.validateExpression(condition) }
        if let hitCondition { try DebugPolicy.validateExpression(hitCondition) }
        if let logMessage { try DebugPolicy.validateExpression(logMessage) }
        var breakpoint: [String: DAPValue] = [
            "instructionReference": .string(instructionReference)
        ]
        if let offset { breakpoint["offset"] = .integer(offset) }
        if let condition { breakpoint["condition"] = .string(condition) }
        if let hitCondition { breakpoint["hitCondition"] = .string(hitCondition) }
        if let logMessage { breakpoint["logMessage"] = .string(logMessage) }
        return try await session(for: sessionID).send(
            command: "setInstructionBreakpoints",
            arguments: .object([
                "breakpoints": .array([.object(breakpoint)])
            ])
        )
    }

    public func setFunctionBreakpoints(
        sessionID: String,
        name: String,
        condition: String? = nil,
        hitCondition: String? = nil
    ) async throws -> DAPMessage {
        guard !name.isEmpty, name.utf8.count <= 4_096 else {
            throw DebugPolicyError.invalidRequest("Function breakpoint name is invalid.")
        }
        if let condition { try DebugPolicy.validateExpression(condition) }
        if let hitCondition { try DebugPolicy.validateExpression(hitCondition) }
        var breakpoint: [String: DAPValue] = ["name": .string(name)]
        if let condition { breakpoint["condition"] = .string(condition) }
        if let hitCondition { breakpoint["hitCondition"] = .string(hitCondition) }
        return try await session(for: sessionID).send(
            command: "setFunctionBreakpoints",
            arguments: .object([
                "breakpoints": .array([.object(breakpoint)])
            ])
        )
    }

    public func setExceptionBreakpoints(
        sessionID: String,
        filters: [String],
        filterOptions: [DAPValue] = []
    ) async throws -> DAPMessage {
        guard filters.count <= 32,
              filters.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 256 }) else {
            throw DebugPolicyError.invalidRequest("Exception breakpoint filters are invalid.")
        }
        guard filterOptions.count <= 32,
              filterOptions.allSatisfy(exceptionFilterOptionIsValid) else {
            throw DebugPolicyError.invalidRequest("Exception breakpoint filter options are invalid.")
        }
        var arguments: [String: DAPValue] = [
            "filters": .array(filters.map(DAPValue.string))
        ]
        if !filterOptions.isEmpty {
            arguments["filterOptions"] = .array(filterOptions)
        }
        return try await session(for: sessionID).send(
            command: "setExceptionBreakpoints",
            arguments: .object(arguments)
        )
    }

    public func threads(sessionID: String) async throws -> DAPMessage {
        try await session(for: sessionID).send(command: "threads")
    }

    public func stackTrace(
        sessionID: String,
        threadID: Int,
        levels: Int,
        startFrame: Int? = nil
    ) async throws -> DAPMessage {
        try DebugPolicy.validatePositive(threadID, label: "Thread ID")
        try DebugPolicy.validatePositive(levels, label: "Stack levels", maximum: 1_000)
        var arguments: [String: DAPValue] = [
            "threadId": .integer(threadID),
            "levels": .integer(levels)
        ]
        if let startFrame {
            try DebugPolicy.validateNonNegative(startFrame, label: "Stack start frame")
            arguments["startFrame"] = .integer(startFrame)
        }
        return try await session(for: sessionID).send(
            command: "stackTrace",
            arguments: .object(arguments)
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
        kind: DebugStepKind,
        granularity: DebugStepGranularity?
    ) async throws -> DAPMessage {
        try DebugPolicy.validatePositive(threadID, label: "Thread ID")
        var arguments: [String: DAPValue] = ["threadId": .integer(threadID)]
        if let granularity { arguments["granularity"] = .string(granularity.rawValue) }
        return try await session(for: sessionID).send(
            command: kind.command,
            arguments: .object(arguments)
        )
    }

    public func scopes(sessionID: String, frameID: Int) async throws -> DAPMessage {
        try await session(for: sessionID).send(
            command: "scopes",
            arguments: .object(["frameId": .integer(frameID)])
        )
    }

    public func variables(
        sessionID: String,
        variablesReference: Int,
        start: Int? = nil,
        count: Int? = nil,
        formatHex: Bool? = nil
    ) async throws -> DAPMessage {
        try DebugPolicy.validatePositive(variablesReference, label: "Variables reference")
        var arguments: [String: DAPValue] = [
            "variablesReference": .integer(variablesReference)
        ]
        if let start {
            try DebugPolicy.validateNonNegative(start, label: "Variables start")
            arguments["start"] = .integer(start)
        }
        if let count {
            try DebugPolicy.validatePositive(count, label: "Variables count", maximum: 10_000)
            arguments["count"] = .integer(count)
        }
        if let formatHex {
            arguments["format"] = .object(["hex": .boolean(formatHex)])
        }
        return try await session(for: sessionID).send(
            command: "variables",
            arguments: .object(arguments)
        )
    }

    public func completions(
        sessionID: String,
        frameID: Int?,
        text: String,
        column: Int,
        line: Int?
    ) async throws -> DAPMessage {
        guard !text.isEmpty, text.utf8.count <= 16_384 else {
            throw DebugPolicyError.invalidRequest("Completion text is invalid.")
        }
        try DebugPolicy.validatePositive(column, label: "Completion column")
        var arguments: [String: DAPValue] = [
            "text": .string(text),
            "column": .integer(column)
        ]
        if let frameID {
            try DebugPolicy.validatePositive(frameID, label: "Frame ID")
            arguments["frameId"] = .integer(frameID)
        }
        if let line {
            try DebugPolicy.validatePositive(line, label: "Completion line")
            arguments["line"] = .integer(line)
        }
        return try await session(for: sessionID).send(
            command: "completions",
            arguments: .object(arguments)
        )
    }

    public func setVariable(
        sessionID: String,
        variablesReference: Int,
        name: String,
        value: String,
        format: DAPValue?
    ) async throws -> DAPMessage {
        try DebugPolicy.validatePositive(variablesReference, label: "Variables reference")
        try DebugPolicy.validateVariableWrite(name: name, value: value)
        var arguments: [String: DAPValue] = [
            "variablesReference": .integer(variablesReference),
            "name": .string(name),
            "value": .string(value)
        ]
        if let format { arguments["format"] = format }
        return try await session(for: sessionID).send(
            command: "setVariable",
            arguments: .object(arguments)
        )
    }

    public func registers(sessionID: String, frameID: Int) async throws -> RegisterSnapshot {
        try DebugPolicy.validatePositive(frameID, label: "Frame ID")
        let session = try session(for: sessionID)
        let scopes = try await session.send(
            command: "scopes",
            arguments: .object(["frameId": .integer(frameID)])
        )
        guard case .object(let body) = scopes.body,
              case .array(let scopeValues) = body["scopes"] else {
            return RegisterSnapshot(scopes: scopes, variables: nil)
        }
        let registerReference = scopeValues.compactMap { value -> Int? in
            guard case .object(let scope) = value,
                  case .string(let name) = scope["name"],
                  name.lowercased().contains("register"),
                  case .integer(let reference) = scope["variablesReference"] else {
                return nil
            }
            return reference
        }.first
        guard let registerReference else {
            return RegisterSnapshot(scopes: scopes, variables: nil)
        }
        let variables = try await session.send(
            command: "variables",
            arguments: .object(["variablesReference": .integer(registerReference)])
        )
        return RegisterSnapshot(scopes: scopes, variables: variables)
    }

    public func stopSnapshot(
        sessionID: String,
        threadID requestedThreadID: Int?,
        levels: Int
    ) async throws -> DebugStopSnapshot {
        try DebugPolicy.validatePositive(levels, label: "Snapshot stack levels", maximum: 1_000)
        let session = try session(for: sessionID)
        let initialEvents = await session.drainEvents()
        let threads = try await session.send(command: "threads")
        let eventMetadata = stopMetadata(from: initialEvents)
        let threadID = requestedThreadID ?? eventMetadata.threadID ?? firstThreadID(from: threads)
        var stackTrace: DAPMessage?
        var scopes: DAPMessage?
        var registers: RegisterSnapshot?
        if let threadID {
            try DebugPolicy.validatePositive(threadID, label: "Thread ID")
            stackTrace = try await session.send(
                command: "stackTrace",
                arguments: .object([
                    "threadId": .integer(threadID),
                    "levels": .integer(levels)
                ])
            )
            if let frameID = firstFrameID(from: stackTrace) {
                scopes = try await session.send(
                    command: "scopes",
                    arguments: .object(["frameId": .integer(frameID)])
                )
                registers = try await registersForSession(session: session, scopes: scopes!)
            }
        }
        let modules = try await session.send(command: "modules")
        let finalEvents = await session.drainEvents()
        return DebugStopSnapshot(
            sessionID: sessionID,
            stopReason: eventMetadata.reason,
            stoppedThreadID: threadID,
            events: initialEvents + finalEvents,
            threads: threads,
            stackTrace: stackTrace,
            scopes: scopes,
            registers: registers,
            modules: modules
        )
    }

    public func waitForStop(
        sessionID: String,
        timeoutMilliseconds: Int
    ) async throws -> DebugWaitForStopResult {
        try DebugPolicy.validatePositive(
            timeoutMilliseconds,
            label: "Stop wait timeout",
            maximum: 120_000
        )
        let result = try await session(for: sessionID).waitForStop(
            timeoutMilliseconds: timeoutMilliseconds
        )
        var reason: String?
        var threadID: Int?
        var stopped = false
        var terminated = false
        for event in result.events.reversed() {
            if event.event == "stopped" {
                stopped = true
                if case .object(let body) = event.body {
                    if case .string(let value) = body["reason"] { reason = value }
                    if case .integer(let value) = body["threadId"] { threadID = value }
                }
                break
            }
            if event.event == "terminated" || event.event == "exited" {
                terminated = true
            }
        }
        return DebugWaitForStopResult(
            sessionID: sessionID,
            stopReason: reason,
            stoppedThreadID: threadID,
            stopped: stopped,
            terminated: terminated,
            timedOut: result.timedOut,
            events: result.events
        )
    }

    public func traceForward(
        sessionID: String,
        threadID: Int,
        steps: Int,
        kind: DebugStepKind,
        granularity: DebugStepGranularity?,
        timeoutMilliseconds: Int
    ) async throws -> ForwardExecutionTraceResult {
        try DebugPolicy.validatePositive(threadID, label: "Thread ID")
        try DebugPolicy.validatePositive(steps, label: "Forward trace steps", maximum: 100)
        try DebugPolicy.validatePositive(
            timeoutMilliseconds,
            label: "Forward trace stop timeout",
            maximum: 120_000
        )
        var points: [DebugWaitForStopResult] = []
        var activeThreadID = threadID
        for _ in 0..<steps {
            _ = try await step(
                sessionID: sessionID,
                threadID: activeThreadID,
                kind: kind,
                granularity: granularity
            )
            let point = try await waitForStop(
                sessionID: sessionID,
                timeoutMilliseconds: timeoutMilliseconds
            )
            points.append(point)
            if let stoppedThreadID = point.stoppedThreadID {
                activeThreadID = stoppedThreadID
            }
            if point.terminated || point.timedOut {
                break
            }
        }
        return ForwardExecutionTraceResult(
            sessionID: sessionID,
            threadID: threadID,
            requestedSteps: steps,
            completedSteps: points.count,
            reverseExecutionSupported: false,
            points: points
        )
    }

    public func memoryMap(processID: Int) throws -> DebugMemoryMapResult {
        try DebugPolicy.validateAttach(processID: processID)
        guard let vmmapPath = ToolchainProbe.path(for: "vmmap") else {
            throw DAPError.toolUnavailable
        }
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: vmmapPath,
                arguments: ["-wide", "-interleaved", String(processID)],
                maximumOutputSize: 8 * 1024 * 1024
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw DAPError.requestFailed("vmmap output exceeds the 8 MB analysis limit.")
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw DAPError.requestFailed(message)
        } catch {
            throw DAPError.requestFailed(error.localizedDescription)
        }
        guard result.terminationStatus == 0 else {
            let message = String(decoding: result.stderr, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw DAPError.requestFailed(message.isEmpty ? "vmmap failed." : message)
        }
        return DebugMemoryMapResult(
            processID: processID,
            output: String(decoding: result.stdout, as: UTF8.self)
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

    public func modules(
        sessionID: String,
        startModule: Int?,
        moduleCount: Int?
    ) async throws -> DAPMessage {
        var arguments: [String: DAPValue] = [:]
        if let startModule {
            try DebugPolicy.validateNonNegative(startModule, label: "Module start")
            arguments["startModule"] = .integer(startModule)
        }
        if let moduleCount {
            try DebugPolicy.validatePositive(moduleCount, label: "Module count", maximum: 10_000)
            arguments["moduleCount"] = .integer(moduleCount)
        }
        return try await session(for: sessionID).send(
            command: "modules",
            arguments: arguments.isEmpty ? nil : .object(arguments)
        )
    }

    public func exceptionInfo(sessionID: String, threadID: Int) async throws -> DAPMessage {
        try DebugPolicy.validatePositive(threadID, label: "Thread ID")
        return try await session(for: sessionID).send(
            command: "exceptionInfo",
            arguments: .object(["threadId": .integer(threadID)])
        )
    }

    public func terminate(sessionID: String, terminateDebuggee: Bool) async throws -> DAPMessage {
        try await session(for: sessionID).send(
            command: "terminate",
            arguments: .object(["terminateDebuggee": .boolean(terminateDebuggee)])
        )
    }

    public func disconnect(sessionID: String, terminateDebuggee: Bool) async throws -> DAPMessage {
        try await session(for: sessionID).send(
            command: "disconnect",
            arguments: .object(["terminateDebuggee": .boolean(terminateDebuggee)])
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
        try DebugPolicy.validateNonNegative(offset, label: "Memory offset")
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

    public func searchMemory(
        sessionID: String,
        memoryReference: String,
        offset: Int,
        count: Int,
        pattern: Data
    ) async throws -> MemorySearchResult {
        try DebugPolicy.validatePositive(count, label: "Search count", maximum: 1_048_576)
        try DebugPolicy.validateNonNegative(offset, label: "Search offset")
        guard !pattern.isEmpty, pattern.count <= 1_024 else {
            throw DebugPolicyError.invalidRequest("Search pattern must contain between 1 and 1024 bytes.")
        }
        let session = try session(for: sessionID)
        let response = try await session.send(
            command: "readMemory",
            arguments: .object([
                "memoryReference": .string(memoryReference),
                "offset": .integer(offset),
                "count": .integer(count)
            ])
        )
        let bytes = try memoryData(from: response)
        var matches: [Int] = []
        guard bytes.count >= pattern.count else {
            return MemorySearchResult(
                sessionID: sessionID,
                memoryReference: memoryReference,
                offset: offset,
                count: count,
                pattern: pattern.base64EncodedString(),
                matches: []
            )
        }
        for index in 0...(bytes.count - pattern.count) {
            if bytes[index..<(index + pattern.count)].elementsEqual(pattern) {
                matches.append(offset + index)
            }
            if matches.count == 10_000 { break }
        }
        return MemorySearchResult(
            sessionID: sessionID,
            memoryReference: memoryReference,
            offset: offset,
            count: count,
            pattern: pattern.base64EncodedString(),
            matches: matches
        )
    }

    public func patchMemory(
        sessionID: String,
        memoryReference: String,
        offset: Int,
        expectedData: Data?,
        data: Data
    ) async throws -> MemoryPatchResult {
        try DebugPolicy.validateMemoryWrite(data: data)
        try DebugPolicy.validateNonNegative(offset, label: "Patch offset")
        let session = try session(for: sessionID)
        let originalResponse = try await session.send(
            command: "readMemory",
            arguments: .object([
                "memoryReference": .string(memoryReference),
                "offset": .integer(offset),
                "count": .integer(data.count)
            ])
        )
        let original = try memoryData(from: originalResponse)
        guard original.count == data.count else {
            throw DebugPolicyError.invalidRequest("LLDB-DAP returned fewer bytes than the requested patch length.")
        }
        if let expectedData, original != expectedData {
            throw DebugPolicyError.invalidRequest("Patch expected bytes do not match the target.")
        }
        _ = try await sendWriteMemory(
            session: session,
            memoryReference: memoryReference,
            offset: offset,
            data: data
        )
        let verificationResponse = try await session.send(
            command: "readMemory",
            arguments: .object([
                "memoryReference": .string(memoryReference),
                "offset": .integer(offset),
                "count": .integer(data.count)
            ])
        )
        let verifiedData = try memoryData(from: verificationResponse)
        guard verifiedData == data else {
            var rolledBack = false
            do {
                _ = try await sendWriteMemory(
                    session: session,
                    memoryReference: memoryReference,
                    offset: offset,
                    data: original
                )
                rolledBack = true
            } catch {
                rolledBack = false
            }
            throw DebugPolicyError.invalidRequest(
                rolledBack
                    ? "Memory patch readback failed; original bytes were restored."
                    : "Memory patch readback failed and rollback could not be confirmed."
            )
        }
        return MemoryPatchResult(
            sessionID: sessionID,
            memoryReference: memoryReference,
            offset: offset,
            originalData: original.base64EncodedString(),
            requestedData: data.base64EncodedString(),
            verified: true,
            rolledBack: false
        )
    }

    public func close(sessionID: String) async -> Bool {
        guard let record = sessions.removeValue(forKey: sessionID) else {
            return false
        }
        await stop(record: record)
        return true
    }

    public func closeAll() async {
        let sessions = self.sessions
        self.sessions.removeAll()
        for record in sessions.values {
            await stop(record: record)
        }
    }

    private func stop(record: SessionRecord) async {
        if record.launchConfiguration != nil {
            try? await record.session.terminateDebuggee()
            try? await record.session.disconnectDebuggee()
        }
        await record.session.stop()
        if let legacyTransport = record.legacyTransport {
            await legacyTransport.stop()
        }
    }

    private func createLegacySession(
        deviceIdentifier: String,
        appPath: String
    ) async throws -> LegacySessionSetup {
        let transport = LegacyDeviceDebugTransport(
            deviceIdentifier: deviceIdentifier,
            appPath: appPath
        )
        do {
            let configuration = try await transport.start()
            let session = try LLDBDAPSession(
                preInitCommands: configuration.preInitCommands,
                pollThreadsForStop: true
            )
            _ = try await session.start()
            _ = try await session.attach(
                program: appPath,
                attachCommands: configuration.attachCommands
            )
            return LegacySessionSetup(session: session, transport: transport)
        } catch {
            await transport.stop()
            throw error
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

    private func registersForSession(
        session: LLDBDAPSession,
        scopes: DAPMessage
    ) async throws -> RegisterSnapshot {
        guard case .object(let body) = scopes.body,
              case .array(let scopeValues) = body["scopes"] else {
            return RegisterSnapshot(scopes: scopes, variables: nil)
        }
        let registerReference = scopeValues.compactMap { value -> Int? in
            guard case .object(let scope) = value,
                  case .string(let name) = scope["name"],
                  name.lowercased().contains("register"),
                  case .integer(let reference) = scope["variablesReference"] else {
                return nil
            }
            return reference
        }.first
        guard let registerReference else {
            return RegisterSnapshot(scopes: scopes, variables: nil)
        }
        let variables = try await session.send(
            command: "variables",
            arguments: .object(["variablesReference": .integer(registerReference)])
        )
        return RegisterSnapshot(scopes: scopes, variables: variables)
    }

    private func exceptionFilterOptionIsValid(_ value: DAPValue) -> Bool {
        guard case .object(let object) = value,
              case .string(let filter) = object["filter"],
              !filter.isEmpty, filter.utf8.count <= 256 else {
            return false
        }
        if case .string(let condition)? = object["condition"] {
            return (try? DebugPolicy.validateExpression(condition)) != nil
        }
        return object["condition"] == nil
    }

    private func sendWriteMemory(
        session: LLDBDAPSession,
        memoryReference: String,
        offset: Int,
        data: Data
    ) async throws -> DAPMessage {
        try await session.send(
            command: "writeMemory",
            arguments: .object([
                "memoryReference": .string(memoryReference),
                "offset": .integer(offset),
                "data": .string(data.base64EncodedString())
            ])
        )
    }

    private func memoryData(from message: DAPMessage) throws -> Data {
        guard case .object(let body) = message.body,
              case .string(let encoded) = body["data"],
              let data = Data(base64Encoded: encoded) else {
            throw DAPError.requestFailed("LLDB-DAP did not return readable memory data.")
        }
        return data
    }

    private func firstThreadID(from message: DAPMessage) -> Int? {
        guard case .object(let body) = message.body,
              case .array(let threads) = body["threads"],
              let first = threads.first,
              case .object(let thread) = first,
              case .integer(let threadID) = thread["id"] else {
            return nil
        }
        return threadID
    }

    private func firstFrameID(from message: DAPMessage?) -> Int? {
        guard case .object(let body) = message?.body,
              case .array(let frames) = body["stackFrames"],
              let first = frames.first,
              case .object(let frame) = first,
              case .integer(let frameID) = frame["id"] else {
            return nil
        }
        return frameID
    }

    private func stopMetadata(from events: [DAPMessage]) -> (reason: String?, threadID: Int?) {
        for event in events.reversed() where event.event == "stopped" {
            guard case .object(let body) = event.body else { continue }
            let reason: String?
            if case .string(let value) = body["reason"] {
                reason = value
            } else {
                reason = nil
            }
            let threadID: Int?
            if case .integer(let value) = body["threadId"] {
                threadID = value
            } else {
                threadID = nil
            }
            return (reason, threadID)
        }
        return (nil, nil)
    }
}

public enum DebugStepKind: String, Codable, CaseIterable, Sendable {
    case inInstruction = "stepIn"
    case over = "next"
    case out = "stepOut"

    fileprivate var command: String { rawValue }
}

public enum DebugStepGranularity: String, Codable, CaseIterable, Sendable {
    case statement
    case line
    case instruction
}
