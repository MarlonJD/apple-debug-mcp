// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum RuntimeDiagnosticTool: String, Codable, CaseIterable, Sendable {
    case heap
    case leaks
    case mallocHistory = "malloc_history"
    case sample
}

public enum RuntimeDiagnosticError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case permissionDisabled
    case toolUnavailable(String)
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Runtime diagnostic request is invalid or exceeds its bounded limits."
        case .permissionDisabled:
            return "Runtime diagnostics require APPLE_DEBUG_ALLOW_TARGET_ATTACH=1 for an authorized local process."
        case .toolUnavailable(let tool):
            return "The Apple runtime diagnostic tool is unavailable: \(tool)."
        case .commandFailed(let message):
            return "Apple runtime diagnostic command failed: \(message)"
        case .outputTooLarge:
            return "Runtime diagnostic output exceeds the configured analysis limit."
        }
    }
}

public struct RuntimeDiagnosticResult: Codable, Equatable, Sendable {
    public let processID: Int
    public let tool: RuntimeDiagnosticTool
    public let mode: String
    public let command: [String]
    public let output: String

    public init(
        processID: Int,
        tool: RuntimeDiagnosticTool,
        mode: String,
        command: [String],
        output: String
    ) {
        self.processID = processID
        self.tool = tool
        self.mode = mode
        self.command = command
        self.output = output
    }
}

public enum RuntimeDiagnosticsService {
    private static let maximumOutputSize = 8 * 1024 * 1024
    private static let maximumPatternSize = 256

    public static func inspect(
        processID: Int,
        tool: RuntimeDiagnosticTool,
        mode: String = "summary",
        pattern: String? = nil,
        durationSeconds: Int = 5,
        sampleIntervalMilliseconds: Int = 10
    ) throws -> RuntimeDiagnosticResult {
        guard processID > 0,
              mode.utf8.count <= 64,
              !mode.contains("\0"),
              pattern.map({ !$0.isEmpty && $0.utf8.count <= maximumPatternSize && !$0.contains("\0") }) ?? true,
              (1...30).contains(durationSeconds),
              (1...1_000).contains(sampleIntervalMilliseconds) else {
            throw RuntimeDiagnosticError.invalidRequest
        }
        do {
            try DebugPolicy.validateAttach(processID: processID)
        } catch {
            if case DebugPolicyError.attachDisabled = error {
                throw RuntimeDiagnosticError.permissionDisabled
            }
            throw RuntimeDiagnosticError.invalidRequest
        }

        let arguments = try command(
            processID: processID,
            tool: tool,
            mode: mode,
            pattern: pattern,
            durationSeconds: durationSeconds,
            sampleIntervalMilliseconds: sampleIntervalMilliseconds
        )
        guard let executable = ToolchainProbe.path(for: tool.rawValue) else {
            throw RuntimeDiagnosticError.toolUnavailable(tool.rawValue)
        }
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: executable,
                arguments: Array(arguments.dropFirst()),
                maximumOutputSize: maximumOutputSize
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw RuntimeDiagnosticError.outputTooLarge
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw RuntimeDiagnosticError.commandFailed(message)
        } catch {
            throw RuntimeDiagnosticError.commandFailed(error.localizedDescription)
        }
        guard result.terminationStatus == 0 else {
            let stdout = String(decoding: result.stdout, as: UTF8.self)
            let stderr = String(decoding: result.stderr, as: UTF8.self)
            let message = [stderr, stdout]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw RuntimeDiagnosticError.commandFailed(message.isEmpty ? "\(tool.rawValue) failed." : message)
        }
        return RuntimeDiagnosticResult(
            processID: processID,
            tool: tool,
            mode: mode,
            command: arguments,
            output: String(decoding: result.stdout, as: UTF8.self)
        )
    }

    private static func command(
        processID: Int,
        tool: RuntimeDiagnosticTool,
        mode: String,
        pattern: String?,
        durationSeconds: Int,
        sampleIntervalMilliseconds: Int
    ) throws -> [String] {
        switch tool {
        case .heap:
            guard ["summary", "addresses", "layouts", "zones"].contains(mode) else {
                throw RuntimeDiagnosticError.invalidRequest
            }
            var arguments = ["heap", "-q", "-H"]
            switch mode {
            case "addresses":
                arguments += ["--addresses=\(pattern ?? "all")", "--noContent"]
            case "layouts":
                arguments.append("--layouts=\(pattern ?? "all")")
            case "zones":
                arguments.append("-z")
            default:
                break
            }
            arguments.append(String(processID))
            return arguments
        case .leaks:
            guard ["summary", "list", "fullStacks"].contains(mode), pattern == nil else {
                throw RuntimeDiagnosticError.invalidRequest
            }
            var arguments = ["leaks", "-q"]
            if mode == "list" { arguments.append("--list") }
            if mode == "fullStacks" { arguments.append("--fullStacks") }
            arguments.append(String(processID))
            return arguments
        case .mallocHistory:
            guard ["callTree", "allBySize", "allByCount", "allEvents"].contains(mode) else {
                throw RuntimeDiagnosticError.invalidRequest
            }
            var arguments = ["malloc_history", String(processID), "-q", "-\(mode)"]
            if let pattern { arguments.append(pattern) }
            return arguments
        case .sample:
            guard mode == "sample", pattern == nil else {
                throw RuntimeDiagnosticError.invalidRequest
            }
            return [
                "sample", String(processID), String(durationSeconds),
                String(sampleIntervalMilliseconds), "-mayDie", "-fullPaths"
            ]
        }
    }
}
