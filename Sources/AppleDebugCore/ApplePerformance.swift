// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum ApplePerformanceError: Error, Equatable, LocalizedError, Sendable {
    case invalidRequest
    case permissionDisabled
    case simulatorNotFound(String)
    case toolUnavailable
    case commandFailed(String)
    case outputTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Performance trace request is invalid or exceeds the bounded limits."
        case .permissionDisabled:
            return "Performance capture requires an explicit authorized target or Simulator policy grant."
        case .simulatorNotFound(let udid):
            return "Simulator is not in the available inventory: \(udid)"
        case .toolUnavailable:
            return "The local xctrace executable was not found."
        case .commandFailed(let message):
            return "xctrace command failed: \(message)"
        case .outputTooLarge:
            return "xctrace command output exceeds the configured limit."
        }
    }
}

public struct ApplePerformanceTraceResult: Codable, Equatable, Sendable {
    public let processID: Int?
    public let simulatorUDID: String?
    public let template: String
    public let durationSeconds: Int
    public let tracePath: String
    public let output: String

    public init(
        processID: Int?,
        simulatorUDID: String?,
        template: String,
        durationSeconds: Int,
        tracePath: String,
        output: String
    ) {
        self.processID = processID
        self.simulatorUDID = simulatorUDID
        self.template = template
        self.durationSeconds = durationSeconds
        self.tracePath = tracePath
        self.output = output
    }
}

public enum ApplePerformanceService {
    private static let templates = ["Time Profiler", "Allocations", "System Trace"]

    public static func record(
        processID: Int?,
        simulatorUDID: String?,
        template: String,
        durationSeconds: Int,
        outputPath: String
    ) throws -> ApplePerformanceTraceResult {
        guard (processID == nil) != (simulatorUDID == nil),
              templates.contains(template),
              (1...60).contains(durationSeconds),
              !outputPath.isEmpty, outputPath.utf8.count <= 4_096,
              !outputPath.contains("\0"),
              outputPath.hasSuffix(".trace"),
              URL(fileURLWithPath: outputPath).path.hasPrefix("/"),
              !FileManager.default.fileExists(atPath: outputPath) else {
            throw ApplePerformanceError.invalidRequest
        }

        var arguments = [
            "record",
            "--template", template,
            "--output", outputPath,
            "--time-limit", "\(durationSeconds)s",
            "--no-prompt"
        ]
        if let processID {
            try DebugPolicy.validateAttach(processID: processID)
            arguments += ["--attach", String(processID)]
        } else if let simulatorUDID {
            guard ProcessInfo.processInfo.environment["APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION"] == "1" else {
                throw ApplePerformanceError.permissionDisabled
            }
            guard try SimulatorService.list().contains(where: { $0.udid == simulatorUDID }) else {
                throw ApplePerformanceError.simulatorNotFound(simulatorUDID)
            }
            arguments += ["--device", simulatorUDID, "--all-processes"]
        }
        guard let xctracePath = ToolchainProbe.path(for: "xctrace") else {
            throw ApplePerformanceError.toolUnavailable
        }
        let result: AppleProcessResult
        do {
            result = try AppleProcessRunner.run(
                executable: xctracePath,
                arguments: arguments,
                maximumOutputSize: 8 * 1024 * 1024
            )
        } catch AppleProcessRunnerError.outputTooLarge {
            throw ApplePerformanceError.outputTooLarge
        } catch AppleProcessRunnerError.launchFailed(let message) {
            throw ApplePerformanceError.commandFailed(message)
        } catch {
            throw ApplePerformanceError.commandFailed(error.localizedDescription)
        }
        guard result.terminationStatus == 0 else {
            let message = String(decoding: result.stderr, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ApplePerformanceError.commandFailed(message.isEmpty ? "xctrace failed." : message)
        }
        guard FileManager.default.fileExists(atPath: outputPath) else {
            throw ApplePerformanceError.commandFailed("xctrace completed without producing a trace file.")
        }
        return ApplePerformanceTraceResult(
            processID: processID,
            simulatorUDID: simulatorUDID,
            template: template,
            durationSeconds: durationSeconds,
            tracePath: outputPath,
            output: String(decoding: result.stdout, as: UTF8.self)
        )
    }
}
