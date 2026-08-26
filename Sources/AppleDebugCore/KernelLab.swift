// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct KernelLabCapabilities: Codable, Equatable, Sendable {
    public let providerAvailable: Bool
    public let explicitGrantPresent: Bool
    public let readOnlyInspectionSupported: Bool
    public let memoryWriteSupported: Bool
    public let notes: [String]

    public init(
        providerAvailable: Bool,
        explicitGrantPresent: Bool,
        readOnlyInspectionSupported: Bool,
        memoryWriteSupported: Bool,
        notes: [String]
    ) {
        self.providerAvailable = providerAvailable
        self.explicitGrantPresent = explicitGrantPresent
        self.readOnlyInspectionSupported = readOnlyInspectionSupported
        self.memoryWriteSupported = memoryWriteSupported
        self.notes = notes
    }
}

public enum KernelLabService {
    public static func capabilities() -> KernelLabCapabilities {
        let providerAvailable = ToolchainProbe.path(for: "lldb-dap") != nil
        let explicitGrantPresent = ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_KERNEL_LAB"] == "1"
        return KernelLabCapabilities(
            providerAvailable: providerAvailable,
            explicitGrantPresent: explicitGrantPresent,
            readOnlyInspectionSupported: providerAvailable && explicitGrantPresent,
            memoryWriteSupported: false,
            notes: [
                "Kernel lab sessions use a fixed LLDB target-create plus kdp-remote pre-init sequence.",
                "A configured KDK/debug kernel and an authorized remote target are required; the MCP server does not change SIP or boot security.",
                "The initial provider exposes only read-only threads, stack, registers, and bounded memory inspection.",
                "Kernel memory write is intentionally unsupported."
            ]
        )
    }
}

public struct KernelLabConfiguration: Codable, Equatable, Sendable {
    public let host: String
    public let kernelImagePath: String
    public let symbolPath: String?

    public init(host: String, kernelImagePath: String, symbolPath: String? = nil) {
        self.host = host
        self.kernelImagePath = kernelImagePath
        self.symbolPath = symbolPath
    }
}

public struct KernelLabSessionSummary: Codable, Equatable, Sendable {
    public let sessionID: String
    public let host: String
    public let kernelImagePath: String
    public let readOnly: Bool

    public init(sessionID: String, host: String, kernelImagePath: String, readOnly: Bool = true) {
        self.sessionID = sessionID
        self.host = host
        self.kernelImagePath = kernelImagePath
        self.readOnly = readOnly
    }
}

public struct KernelLabInspectionResult: Codable, Equatable, Sendable {
    public let sessionID: String
    public let threads: DAPMessage
    public let selectedThreadID: Int?
    public let stackTrace: DAPMessage?
    public let registers: RegisterSnapshot?
    public let memory: DAPMessage?
    public let notes: [String]

    public init(
        sessionID: String,
        threads: DAPMessage,
        selectedThreadID: Int?,
        stackTrace: DAPMessage?,
        registers: RegisterSnapshot?,
        memory: DAPMessage?,
        notes: [String]
    ) {
        self.sessionID = sessionID
        self.threads = threads
        self.selectedThreadID = selectedThreadID
        self.stackTrace = stackTrace
        self.registers = registers
        self.memory = memory
        self.notes = notes
    }
}

public enum KernelLabError: Error, Equatable, LocalizedError, Sendable {
    case disabled
    case invalidHost
    case invalidPath(String)
    case invalidRequest(String)
    case unknownSession

    public var errorDescription: String? {
        switch self {
        case .disabled:
            return "Kernel lab is disabled. Set APPLE_DEBUG_ALLOW_KERNEL_LAB=1 only for an authorized two-machine lab."
        case .invalidHost:
            return "Kernel lab host must be a bounded hostname or IP address without LLDB command characters."
        case .invalidPath(let label):
            return "Kernel lab \(label) must be an absolute regular file."
        case .invalidRequest(let message):
            return message
        case .unknownSession:
            return "Unknown kernel lab session."
        }
    }
}

public actor KernelLabSessionManager {
    private struct SessionRecord {
        let session: LLDBDAPSession
        let configuration: KernelLabConfiguration
    }

    private var sessions: [String: SessionRecord] = [:]

    public init() {}

    public func connect(configuration: KernelLabConfiguration) async throws -> KernelLabSessionSummary {
        try validateGrant()
        try validate(configuration: configuration)

        var commands = [
            "target create \(lldbQuote(configuration.kernelImagePath))"
        ]
        if let symbolPath = configuration.symbolPath {
            commands.append("target symbols add \(lldbQuote(symbolPath))")
        }
        commands.append("kdp-remote \(configuration.host)")

        let session = try LLDBDAPSession(preInitCommands: commands)
        do {
            _ = try await session.start()
            let sessionID = UUID().uuidString.lowercased()
            sessions[sessionID] = SessionRecord(session: session, configuration: configuration)
            return KernelLabSessionSummary(
                sessionID: sessionID,
                host: configuration.host,
                kernelImagePath: configuration.kernelImagePath
            )
        } catch {
            await session.stop()
            throw error
        }
    }

    public func inspect(
        sessionID: String,
        threadID: Int?,
        frameID: Int?,
        levels: Int,
        memoryReference: String?,
        memoryCount: Int?
    ) async throws -> KernelLabInspectionResult {
        try validateGrant()
        try DebugPolicy.validatePositive(levels, label: "Kernel lab stack levels", maximum: 256)
        if let threadID {
            try DebugPolicy.validatePositive(threadID, label: "Kernel lab thread ID")
        }
        if let frameID {
            try DebugPolicy.validatePositive(frameID, label: "Kernel lab frame ID")
        }
        if let memoryReference {
            try validateMemoryReference(memoryReference)
        }
        if let memoryCount {
            try DebugPolicy.validatePositive(memoryCount, label: "Kernel lab memory count", maximum: 65_536)
        }
        guard let record = sessions[sessionID] else {
            throw KernelLabError.unknownSession
        }

        let threads = try await record.session.send(command: "threads")
        let selectedThreadID = threadID ?? firstThreadID(from: threads)
        var stackTrace: DAPMessage?
        var registers: RegisterSnapshot?
        if let selectedThreadID {
            stackTrace = try await record.session.send(
                command: "stackTrace",
                arguments: .object([
                    "threadId": .integer(selectedThreadID),
                    "levels": .integer(levels)
                ])
            )
            let selectedFrameID = frameID ?? firstFrameID(from: stackTrace)
            if let selectedFrameID {
                registers = try await registersForSession(
                    session: record.session,
                    frameID: selectedFrameID
                )
            }
        }

        var memory: DAPMessage?
        if let memoryReference, let memoryCount {
            memory = try await record.session.send(
                command: "readMemory",
                arguments: .object([
                    "memoryReference": .string(memoryReference),
                    "offset": .integer(0),
                    "count": .integer(memoryCount)
                ])
            )
        }

        return KernelLabInspectionResult(
            sessionID: sessionID,
            threads: threads,
            selectedThreadID: selectedThreadID,
            stackTrace: stackTrace,
            registers: registers,
            memory: memory,
            notes: [
                "Kernel lab inspection is read-only and uses the configured remote KDP target.",
                "The MCP server does not expose kernel memory write, arbitrary LLDB commands, or boot-security changes."
            ]
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
        let records = sessions
        sessions.removeAll()
        for record in records.values {
            await record.session.stop()
        }
    }

    private func validateGrant() throws {
        guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_KERNEL_LAB"] == "1" else {
            throw KernelLabError.disabled
        }
    }

    private func validate(configuration: KernelLabConfiguration) throws {
        guard !configuration.host.isEmpty,
              configuration.host.utf8.count <= 253,
              configuration.host.allSatisfy({ character in
                  character.isLetter || character.isNumber || ".-:%_".contains(character)
              }) else {
            throw KernelLabError.invalidHost
        }
        try validateRegularFile(configuration.kernelImagePath, label: "kernel image")
        if let symbolPath = configuration.symbolPath {
            try validateRegularFile(symbolPath, label: "symbol file")
        }
    }

    private func validateRegularFile(_ path: String, label: String) throws {
        guard path.hasPrefix("/"), path.utf8.count <= 4_096 else {
            throw KernelLabError.invalidPath(label)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw KernelLabError.invalidPath(label)
        }
    }

    private func validateMemoryReference(_ reference: String) throws {
        let value = reference.hasPrefix("0x") ? String(reference.dropFirst(2)) : reference
        guard !value.isEmpty,
              value.count <= 16,
              value.allSatisfy({ $0.isHexDigit }) else {
            throw KernelLabError.invalidRequest("Kernel lab memoryReference must be a bounded hexadecimal address.")
        }
    }

    private func registersForSession(
        session: LLDBDAPSession,
        frameID: Int
    ) async throws -> RegisterSnapshot {
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

    private func firstThreadID(from message: DAPMessage) -> Int? {
        guard case .object(let body) = message.body,
              case .array(let threads) = body["threads"] else {
            return nil
        }
        for thread in threads {
            guard case .object(let value) = thread,
                  case .integer(let id) = value["id"], id > 0 else {
                continue
            }
            return id
        }
        return nil
    }

    private func firstFrameID(from message: DAPMessage?) -> Int? {
        guard case .object(let body) = message?.body,
              case .array(let frames) = body["stackFrames"],
              case .object(let frame) = frames.first,
              case .integer(let id) = frame["id"], id > 0 else {
            return nil
        }
        return id
    }

    private func lldbQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\\\'"))'"
    }
}
