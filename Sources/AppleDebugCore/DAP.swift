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

public enum DAPError: Error, Equatable, LocalizedError, Sendable {
    case invalidHeader
    case missingContentLength
    case invalidMessage
    case processUnavailable
    case processExited(Int32)
    case requestFailed(String)
    case timeout
    case toolUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidHeader:
            return "LLDB-DAP returned an invalid message header."
        case .missingContentLength:
            return "LLDB-DAP message did not include Content-Length."
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
        }
    }
}

public enum DAPFraming {
    public static func frame(_ message: DAPMessage) throws -> Data {
        let body = try JSONEncoder().encode(message)
        var result = Data("Content-Length: \(body.count)\r\n\r\n".utf8)
        result.append(body)
        return result
    }

    public static func nextMessage(from buffer: inout Data) throws -> DAPMessage? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = buffer.range(of: separator) else {
            return nil
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
                contentLength = Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }

        guard let contentLength else {
            throw DAPError.missingContentLength
        }

        let bodyStart = headerRange.upperBound
        guard buffer.count >= bodyStart + contentLength else {
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
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var buffer = Data()
    private var nextSequence = 1
    private var events: [DAPMessage] = []

    public init(executablePath: String? = nil) throws {
        guard let executablePath = executablePath ?? ToolchainProbe.path(for: "lldb-dap") else {
            throw DAPError.toolUnavailable
        }
        self.executablePath = executablePath
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

    public func send(command: String, arguments: DAPValue? = nil) throws -> DAPMessage {
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

        while true {
            let data = try readChunk(from: output)
            if data.isEmpty {
                let status = process?.terminationStatus ?? -1
                throw DAPError.processExited(status)
            }
            buffer.append(data)

            while let message = try DAPFraming.nextMessage(from: &buffer) {
                if message.type == "event" {
                    events.append(message)
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

    public func drainEvents() -> [DAPMessage] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    public func stop() {
        if let process {
            try? input?.close()
            try? output?.close()
            if process.isRunning {
                process.terminate()
                if process.isRunning {
                    _ = Darwin.kill(process.processIdentifier, SIGKILL)
                }
                process.waitUntilExit()
            }
        }
        process = nil
        input = nil
        output = nil
        buffer.removeAll(keepingCapacity: false)
        events.removeAll(keepingCapacity: false)
    }

    private func startProcessIfNeeded() throws {
        guard process == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            throw DAPError.processUnavailable
        }

        self.process = process
        input = inputPipe.fileHandleForWriting
        output = outputPipe.fileHandleForReading
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

    private func readChunk(from output: FileHandle) throws -> Data {
        var descriptor = pollfd(
            fd: output.fileDescriptor,
            events: Int16(POLLIN),
            revents: 0
        )
        let ready = Darwin.poll(&descriptor, 1, 10_000)
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
            throw DAPError.processExited(process?.terminationStatus ?? -1)
        }
        return Data(bytes.prefix(count))
    }
}
