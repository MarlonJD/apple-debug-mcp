// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Darwin

public enum DAPValue: Codable, Equatable, Sendable {
    case object([String: DAPValue])
    case array([DAPValue])
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case null

    private struct CodingKey: Swift.CodingKey {
        let stringValue: String
        let intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKey.self) {
            var object: [String: DAPValue] = [:]
            for key in container.allKeys {
                object[key.stringValue] = try container.decode(DAPValue.self, forKey: key)
            }
            self = .object(object)
            return
        }

        if var container = try? decoder.unkeyedContainer() {
            var array: [DAPValue] = []
            while !container.isAtEnd {
                array.append(try container.decode(DAPValue.self))
            }
            self = .array(array)
            return
        }

        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DAPError.invalidMessage
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .object(let object):
            var container = encoder.container(keyedBy: CodingKey.self)
            for (key, value) in object {
                guard let codingKey = CodingKey(stringValue: key) else {
                    throw DAPError.invalidMessage
                }
                try container.encode(value, forKey: codingKey)
            }
        case .array(let array):
            var container = encoder.unkeyedContainer()
            for value in array {
                try container.encode(value)
            }
        case .string(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .integer(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .double(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .boolean(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

public struct DAPMessage: Codable, Equatable, Sendable {
    public let seq: Int?
    public let type: String
    public let requestSequence: Int?
    public let command: String?
    public let event: String?
    public let success: Bool?
    public let arguments: DAPValue?
    public let body: DAPValue?
    public let message: String?

    public init(
        seq: Int? = nil,
        type: String,
        requestSequence: Int? = nil,
        command: String? = nil,
        event: String? = nil,
        success: Bool? = nil,
        arguments: DAPValue? = nil,
        body: DAPValue? = nil,
        message: String? = nil
    ) {
        self.seq = seq
        self.type = type
        self.requestSequence = requestSequence
        self.command = command
        self.event = event
        self.success = success
        self.arguments = arguments
        self.body = body
        self.message = message
    }

    private enum CodingKeys: String, CodingKey {
        case seq
        case type
        case requestSequence = "request_seq"
        case command
        case event
        case success
        case arguments
        case body
        case message
    }
}

public struct DAPEventWaitResult: Codable, Equatable, Sendable {
    public let events: [DAPMessage]
    public let timedOut: Bool

    public init(events: [DAPMessage], timedOut: Bool) {
        self.events = events
        self.timedOut = timedOut
    }
}

public enum DAPError: Error, Equatable, LocalizedError, Sendable {
    case invalidHeader
    case missingContentLength
    case invalidContentLength
    case messageTooLarge
    case eventBufferOverflow
    case stderrTooLarge
    case invalidMessage
    case processUnavailable
    case processExited(Int32)
    case requestFailed(String)
    case timeout
    case toolUnavailable
    case invalidDeviceIdentifier

    public var errorDescription: String? {
        switch self {
        case .invalidHeader:
            return "LLDB-DAP returned an invalid message header."
        case .missingContentLength:
            return "LLDB-DAP message did not include Content-Length."
        case .invalidContentLength:
            return "LLDB-DAP returned an invalid Content-Length."
        case .messageTooLarge:
            return "LLDB-DAP returned a message larger than the configured limit."
        case .eventBufferOverflow:
            return "LLDB-DAP produced more buffered events than the configured limit."
        case .stderrTooLarge:
            return "LLDB-DAP stderr exceeded the configured limit."
        case .invalidMessage:
            return "LLDB-DAP returned an invalid JSON message."
        case .processUnavailable:
            return "LLDB-DAP process is not available."
        case .processExited(let status):
            return "LLDB-DAP exited before completing the request with status \(status)."
        case .requestFailed(let message):
            return "LLDB-DAP request failed: \(message)"
        case .timeout:
            return "Timed out waiting for an LLDB-DAP response."
        case .toolUnavailable:
            return "The local lldb-dap executable was not found."
        case .invalidDeviceIdentifier:
            return "The physical-device identifier is not a valid UUID."
        }
    }
}

public enum DAPFraming {
    public static let maximumHeaderSize = 64 * 1024
    public static let maximumBodySize = 16 * 1024 * 1024

    public static func frame(_ message: DAPMessage) throws -> Data {
        let body = try JSONEncoder().encode(message)
        guard body.count <= maximumBodySize else {
            throw DAPError.messageTooLarge
        }
        var result = Data("Content-Length: \(body.count)\r\n\r\n".utf8)
        result.append(body)
        return result
    }

    public static func nextMessage(from buffer: inout Data) throws -> DAPMessage? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = buffer.range(of: separator) else {
            guard buffer.count <= maximumHeaderSize else {
                throw DAPError.messageTooLarge
            }
            return nil
        }

        guard headerRange.lowerBound <= maximumHeaderSize else {
            throw DAPError.messageTooLarge
        }

        let headerData = buffer.subdata(in: buffer.startIndex..<headerRange.lowerBound)
        guard let header = String(data: headerData, encoding: .utf8) else {
            throw DAPError.invalidHeader
        }

        var contentLength: Int?
        for line in header.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else {
                throw DAPError.invalidHeader
            }
            if parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                guard let value = Int(parts[1].trimmingCharacters(in: .whitespaces)), value >= 0 else {
                    throw DAPError.invalidContentLength
                }
                contentLength = value
            }
        }

        guard let contentLength else {
            throw DAPError.missingContentLength
        }
        guard contentLength <= maximumBodySize else {
            throw DAPError.messageTooLarge
        }

        let bodyStart = headerRange.upperBound
        guard buffer.count - bodyStart >= contentLength else {
            return nil
        }

        let bodyEnd = bodyStart + contentLength
        let body = buffer.subdata(in: bodyStart..<bodyEnd)
        buffer.removeSubrange(buffer.startIndex..<bodyEnd)

        do {
            return try JSONDecoder().decode(DAPMessage.self, from: body)
        } catch {
            throw DAPError.invalidMessage
        }
    }
}

public actor LLDBDAPSession {
    private let executablePath: String
    private let preInitCommands: [String]
    private let replMode: String?
    private let pollThreadsForStop: Bool
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var stderrHandle: FileHandle?
    private var stderrURL: URL?
    private var buffer = Data()
    private var nextSequence = 1
    private var events: [DAPMessage] = []

    private static let maximumBufferedEvents = 4_096
    private static let maximumStderrSize = 1 * 1024 * 1024

    public init(
        executablePath: String? = nil,
        preInitCommands: [String] = [],
        replMode: String? = nil,
        pollThreadsForStop: Bool = false
    ) throws {
        guard let executablePath = executablePath ?? ToolchainProbe.path(for: "lldb-dap") else {
            throw DAPError.toolUnavailable
        }
        self.executablePath = executablePath
        self.preInitCommands = preInitCommands
        self.replMode = replMode
        self.pollThreadsForStop = pollThreadsForStop
    }

    public init(deviceIdentifier: String) throws {
        guard UUID(uuidString: deviceIdentifier) != nil else {
            throw DAPError.invalidDeviceIdentifier
        }
        try self.init(
            preInitCommands: ["device select \(deviceIdentifier)"]
        )
    }

    public func start() throws -> DAPMessage {
        try startProcessIfNeeded()
        return try initialize()
    }

    public func initialize() throws -> DAPMessage {
        try startProcessIfNeeded()
        let arguments: DAPValue = .object([
            "adapterID": .string("lldb-dap"),
            "clientID": .string("apple-debug-mcp"),
            "pathFormat": .string("path"),
            "linesStartAt1": .boolean(true),
            "columnsStartAt1": .boolean(true),
            "supportsRunInTerminalRequest": .boolean(false)
        ])
        return try send(command: "initialize", arguments: arguments)
    }

    public func send(
        command: String,
        arguments: DAPValue? = nil,
        readTimeoutMilliseconds: Int = 60_000
    ) throws -> DAPMessage {
        try startProcessIfNeeded()

        guard let input, let output else {
            throw DAPError.processUnavailable
        }

        let sequence = nextSequence
        nextSequence += 1
        let request = DAPMessage(
            seq: sequence,
            type: "request",
            command: command,
            arguments: arguments
        )

        try input.write(contentsOf: DAPFraming.frame(request))

        let deadline = Date().addingTimeInterval(Double(readTimeoutMilliseconds) / 1_000.0)
        while true {
            try validateStderrSize()
            let remaining = Int(deadline.timeIntervalSinceNow * 1_000)
            guard remaining > 0 else {
                throw DAPError.timeout
            }
            do {
                let data = try readChunk(
                    from: output,
                    timeoutMilliseconds: min(remaining, 250)
                )
                if data.isEmpty {
                    let status = processStatus()
                    throw DAPError.processExited(status)
                }
                buffer.append(data)

                while let message = try DAPFraming.nextMessage(from: &buffer) {
                    if message.type == "event" {
                        try appendEvent(message)
                        continue
                    }
                    guard message.type == "response", message.requestSequence == sequence else {
                        continue
                    }
                    guard message.success != false else {
                        throw DAPError.requestFailed(failureMessage(for: message))
                    }
                    return message
                }
            } catch DAPError.timeout {
                continue
            }
        }
    }

    public func launch(program: String, arguments: [String], stopOnEntry: Bool) throws -> DAPMessage {
        let launchArguments: DAPValue = .object([
            "program": .string(program),
            "args": .array(arguments.map(DAPValue.string)),
            "stopOnEntry": .boolean(stopOnEntry)
        ])
        let response = try send(command: "launch", arguments: launchArguments)
        _ = try send(command: "configurationDone")
        return response
    }

    public func attach(processID: Int) throws -> DAPMessage {
        try send(
            command: "attach",
            arguments: .object(["pid": .integer(processID)])
        )
    }

    public func attach(
        deviceProcessID: Int,
        program: String? = nil
    ) throws -> DAPMessage {
        var arguments: [String: DAPValue] = [
            "attachCommands": .array([
                .string("device process attach --pid \(deviceProcessID)")
            ])
        ]
        if let program {
            arguments["program"] = .string(program)
        }
        let response = try send(command: "attach", arguments: .object(arguments))
        // CoreDevice's attach command can return while the app is already
        // running, especially when a local program is supplied for symbols.
        // Normalize the session to a stopped debugger state for DAP clients.
        _ = try? send(command: "pause")
        _ = try? waitForStop(timeoutMilliseconds: 5_000)
        _ = drainEvents()
        return response
    }

    public func attach(
        program: String,
        attachCommands: [String]
    ) throws -> DAPMessage {
        guard !program.isEmpty, !attachCommands.isEmpty else {
            throw DAPError.requestFailed("Legacy LLDB-DAP attach requires a program and at least one attach command.")
        }
        return try send(
            command: "attach",
            arguments: .object([
                "program": .string(program),
                "attachCommands": .array(attachCommands.map(DAPValue.string))
            ])
        )
    }

    public func terminateDebuggee() throws {
        guard process != nil else { return }
        _ = try send(
            command: "terminate",
            arguments: .object(["terminateDebuggee": .boolean(true)]),
            readTimeoutMilliseconds: 2_000
        )
    }

    public func disconnectDebuggee() throws {
        guard process != nil else { return }
        _ = try send(
            command: "disconnect",
            arguments: .object(["terminateDebuggee": .boolean(true)]),
            readTimeoutMilliseconds: 2_000
        )
    }

    public func drainEvents() -> [DAPMessage] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    public func waitForStop(timeoutMilliseconds: Int) throws -> DAPEventWaitResult {
        try startProcessIfNeeded()
        guard let output else {
            throw DAPError.processUnavailable
        }
        let deadline = Date().addingTimeInterval(Double(timeoutMilliseconds) / 1_000.0)
        var nextThreadStateProbe = Date().addingTimeInterval(2)
        while true {
            try validateStderrSize()
            try appendBufferedEvents()
            if hasStopEvent(events) {
                return DAPEventWaitResult(events: drainEvents(), timedOut: false)
            }
            let remaining = Int(deadline.timeIntervalSinceNow * 1_000)
            if remaining <= 0 {
                return DAPEventWaitResult(events: drainEvents(), timedOut: true)
            }
            if pollThreadsForStop, Date() >= nextThreadStateProbe {
                nextThreadStateProbe = Date().addingTimeInterval(1)
                do {
                    let response = try send(
                        command: "threads",
                        readTimeoutMilliseconds: min(5_000, remaining)
                    )
                    if hasThreads(response) {
                        var observedEvents = drainEvents()
                        observedEvents.append(
                            DAPMessage(
                                type: "event",
                                event: "stopped",
                                body: .object(["reason": .string("adapter-state-poll")])
                            )
                        )
                        return DAPEventWaitResult(events: observedEvents, timedOut: false)
                    }
                } catch DAPError.timeout {
                    // The legacy adapter may not answer while it is transitioning state.
                } catch DAPError.requestFailed {
                    // LLDB-DAP reports a running or transitioning process as a request failure.
                }
            }
            do {
                let data = try readChunk(
                    from: output,
                    timeoutMilliseconds: min(remaining, 250)
                )
                if data.isEmpty {
                    let status = processStatus()
                    throw DAPError.processExited(status)
                }
                buffer.append(data)
                try appendBufferedEvents()
            } catch DAPError.timeout {
                continue
            }
        }
    }

    public func stop() {
        if let process {
            try? input?.close()
            try? output?.close()
            try? stderrHandle?.close()
            let terminated = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in
                terminated.signal()
            }
            if process.isRunning {
                process.terminate()
                if terminated.wait(timeout: .now() + 1) == .timedOut,
                   process.isRunning {
                    _ = Darwin.kill(process.processIdentifier, SIGKILL)
                    _ = terminated.wait(timeout: .now() + 2)
                }
            }
        }
        process = nil
        input = nil
        output = nil
        stderrHandle = nil
        if let stderrURL {
            try? FileManager.default.removeItem(at: stderrURL)
        }
        self.stderrURL = nil
        buffer.removeAll(keepingCapacity: false)
        events.removeAll(keepingCapacity: false)
    }

    private func startProcessIfNeeded() throws {
        guard process == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        var arguments: [String] = []
        if let replMode {
            arguments += ["--repl-mode", replMode]
        }
        for command in preInitCommands {
            arguments += ["--pre-init-command", command]
        }
        process.arguments = arguments
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let stderrURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-lldb-\(UUID().uuidString).stderr")
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stderrHandle: FileHandle
        do {
            stderrHandle = try FileHandle(forWritingTo: stderrURL)
        } catch {
            try? FileManager.default.removeItem(at: stderrURL)
            throw DAPError.processUnavailable
        }
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = stderrHandle

        do {
            try process.run()
        } catch {
            try? stderrHandle.close()
            try? FileManager.default.removeItem(at: stderrURL)
            throw DAPError.processUnavailable
        }

        self.process = process
        input = inputPipe.fileHandleForWriting
        output = outputPipe.fileHandleForReading
        self.stderrHandle = stderrHandle
        self.stderrURL = stderrURL
        Thread.sleep(forTimeInterval: 0.1)
    }

    private func failureMessage(for message: DAPMessage) -> String {
        if let message = message.message, !message.isEmpty {
            return message
        }
        if case .object(let body) = message.body,
           case .object(let error) = body["error"],
           case .string(let format) = error["format"] {
            return format
        }
        return "Unknown LLDB-DAP failure"
    }

    private func hasStopEvent(_ messages: [DAPMessage]) -> Bool {
        messages.contains { message in
            guard let event = message.event else { return false }
            return event == "stopped" || event == "terminated" || event == "exited"
        }
    }

    private func hasThreads(_ message: DAPMessage) -> Bool {
        guard case .object(let body) = message.body,
              case .array(let threads) = body["threads"] else {
            return false
        }
        return !threads.isEmpty
    }

    private func appendBufferedEvents() throws {
        while let message = try DAPFraming.nextMessage(from: &buffer) {
            if message.type == "event" {
                try appendEvent(message)
            }
        }
    }

    private func appendEvent(_ message: DAPMessage) throws {
        guard events.count < Self.maximumBufferedEvents else {
            stop()
            throw DAPError.eventBufferOverflow
        }
        events.append(message)
    }

    private func validateStderrSize() throws {
        guard let stderrURL,
              let size = try? FileManager.default.attributesOfItem(atPath: stderrURL.path)[.size] as? NSNumber,
              size.intValue > Self.maximumStderrSize else {
            return
        }
        stop()
        throw DAPError.stderrTooLarge
    }

    private func processStatus() -> Int32 {
        guard let process else { return -1 }
        return process.isRunning ? -1 : process.terminationStatus
    }

    private func readChunk(
        from output: FileHandle,
        timeoutMilliseconds: Int = 60_000
    ) throws -> Data {
        var descriptor = pollfd(
            fd: output.fileDescriptor,
            events: Int16(POLLIN),
            revents: 0
        )
        let ready = Darwin.poll(&descriptor, 1, Int32(max(1, timeoutMilliseconds)))
        guard ready > 0 else {
            if ready == 0 {
                throw DAPError.timeout
            }
            throw DAPError.processUnavailable
        }

        var bytes = [UInt8](repeating: 0, count: 4096)
        let count = bytes.withUnsafeMutableBytes { buffer in
            Darwin.read(output.fileDescriptor, buffer.baseAddress, buffer.count)
        }
        guard count > 0 else {
            throw DAPError.processExited(processStatus())
        }
        return Data(bytes.prefix(count))
    }
}
