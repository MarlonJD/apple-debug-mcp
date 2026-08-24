// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum AppleProcessRunnerError: Error {
    case launchFailed(String)
    case outputTooLarge
}

struct AppleProcessResult {
    let stdout: Data
    let stderr: Data
    let terminationStatus: Int32
}

enum AppleProcessRunner {
    static func run(
        executable: String,
        arguments: [String],
        maximumOutputSize: Int
    ) throws -> AppleProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-process-\(UUID().uuidString).stdout")
        let errorURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-debug-mcp-process-\(UUID().uuidString).stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        defer {
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: errorURL)
        }

        do {
            let outputHandle = try FileHandle(forWritingTo: outputURL)
            let errorHandle = try FileHandle(forWritingTo: errorURL)
            process.standardOutput = outputHandle
            process.standardError = errorHandle
            try process.run()
            process.waitUntilExit()
            try outputHandle.close()
            try errorHandle.close()
        } catch {
            throw AppleProcessRunnerError.launchFailed(error.localizedDescription)
        }

        let stdout = try Data(contentsOf: outputURL)
        let stderr = try Data(contentsOf: errorURL)
        guard stdout.count <= maximumOutputSize, stderr.count <= maximumOutputSize else {
            throw AppleProcessRunnerError.outputTooLarge
        }
        return AppleProcessResult(
            stdout: stdout,
            stderr: stderr,
            terminationStatus: process.terminationStatus
        )
    }
}
