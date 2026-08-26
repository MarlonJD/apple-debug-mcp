// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Darwin

enum AppleProcessRunnerError: Error, Equatable, LocalizedError {
    case launchFailed(String)
    case outputTooLarge
    case timedOut
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            return "Apple tool failed to launch: \(message)"
        case .outputTooLarge:
            return "Apple tool output exceeded the configured limit."
        case .timedOut:
            return "Apple tool exceeded its execution deadline."
        case .invalidRequest:
            return "Apple tool execution limits are invalid."
        }
    }
}

struct AppleProcessResult {
    let stdout: Data
    let stderr: Data
    let terminationStatus: Int32
}

enum AppleProcessRunner {
    static let defaultTimeoutMilliseconds = 120_000

    static func run(
        executable: String,
        arguments: [String],
        maximumOutputSize: Int,
        timeoutMilliseconds: Int = defaultTimeoutMilliseconds,
        input: Data? = nil
    ) throws -> AppleProcessResult {
        guard maximumOutputSize > 0, timeoutMilliseconds > 0 else {
            throw AppleProcessRunnerError.invalidRequest
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-process-\(UUID().uuidString).stdout")
        let errorURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-process-\(UUID().uuidString).stderr")
        let inputURL = input.map { _ in
            FileManager.default.temporaryDirectory
                .appendingPathComponent("apple-debug-mcp-process-\(UUID().uuidString).stdin")
        }
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        if let input, let inputURL {
            try input.write(to: inputURL, options: .atomic)
        }
        defer {
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: errorURL)
            if let inputURL {
                try? FileManager.default.removeItem(at: inputURL)
            }
        }

        var outputHandle: FileHandle?
        var errorHandle: FileHandle?
        var inputHandle: FileHandle?
        defer {
            try? outputHandle?.close()
            try? errorHandle?.close()
            try? inputHandle?.close()
        }

        do {
            outputHandle = try FileHandle(forWritingTo: outputURL)
            errorHandle = try FileHandle(forWritingTo: errorURL)
            process.standardOutput = outputHandle
            process.standardError = errorHandle
            if let inputURL {
                inputHandle = try FileHandle(forReadingFrom: inputURL)
                process.standardInput = inputHandle
            } else {
                process.standardInput = FileHandle.nullDevice
            }
            try process.run()
        } catch {
            terminate(process)
            throw AppleProcessRunnerError.launchFailed(error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(Double(timeoutMilliseconds) / 1_000.0)
        while process.isRunning {
            if fileSize(at: outputURL) > maximumOutputSize || fileSize(at: errorURL) > maximumOutputSize {
                terminate(process)
                throw AppleProcessRunnerError.outputTooLarge
            }
            if Date() >= deadline {
                terminate(process)
                throw AppleProcessRunnerError.timedOut
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        process.waitUntilExit()

        if fileSize(at: outputURL) > maximumOutputSize || fileSize(at: errorURL) > maximumOutputSize {
            throw AppleProcessRunnerError.outputTooLarge
        }

        let stdout = try Data(contentsOf: outputURL)
        let stderr = try Data(contentsOf: errorURL)
        return AppleProcessResult(
            stdout: stdout,
            stderr: stderr,
            terminationStatus: process.terminationStatus
        )
    }

    private static func fileSize(at url: URL) -> Int {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    }

    private static func terminate(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(0.5)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            _ = Darwin.kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
    }
}
