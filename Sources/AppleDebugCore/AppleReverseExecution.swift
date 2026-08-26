// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct ReverseExecutionCapabilities: Codable, Equatable, Sendable {
    public let lldbVersion: String?
    public let processTraceCommandsAvailable: Bool
    public let processRecordSupported: Bool
    public let reverseStepSupported: Bool
    public let reverseContinueSupported: Bool
    public let timeTravelSupported: Bool
    public let forwardStopTraceAvailable: Bool
    public let notes: [String]

    public init(
        lldbVersion: String?,
        processTraceCommandsAvailable: Bool,
        processRecordSupported: Bool,
        reverseStepSupported: Bool,
        reverseContinueSupported: Bool,
        timeTravelSupported: Bool,
        forwardStopTraceAvailable: Bool,
        notes: [String]
    ) {
        self.lldbVersion = lldbVersion
        self.processTraceCommandsAvailable = processTraceCommandsAvailable
        self.processRecordSupported = processRecordSupported
        self.reverseStepSupported = reverseStepSupported
        self.reverseContinueSupported = reverseContinueSupported
        self.timeTravelSupported = timeTravelSupported
        self.forwardStopTraceAvailable = forwardStopTraceAvailable
        self.notes = notes
    }
}

public enum ReverseExecutionService {
    public static func capabilities() -> ReverseExecutionCapabilities {
        let lldbVersion = version()
        let lldbAvailable = ToolchainProbe.path(for: "lldb") != nil
        return ReverseExecutionCapabilities(
            lldbVersion: lldbVersion,
            processTraceCommandsAvailable: lldbAvailable,
            processRecordSupported: false,
            reverseStepSupported: false,
            reverseContinueSupported: false,
            timeTravelSupported: false,
            forwardStopTraceAvailable: true,
            notes: [
                "The installed Apple LLDB exposes process trace start/stop commands but no process record, reverse-step, reverse-continue, or replay command.",
                "The server therefore fails closed for reverse execution and exposes forward LLDB-DAP stop snapshots as the supported deterministic alternative.",
                "CheckpointReplayManager provides bounded local relaunch-to-source replay, but xctrace Time Profiler export, crash/DWARF analysis, and checkpoint artifacts cannot restore process state."
            ]
        )
    }

    private static func version() -> String? {
        guard let lldb = ToolchainProbe.path(for: "lldb") else { return nil }
        guard let result = try? AppleProcessRunner.run(
            executable: lldb,
            arguments: ["--version"],
            maximumOutputSize: 256 * 1024
        ), result.terminationStatus == 0 else {
            return nil
        }
        let value = String(decoding: result.stdout, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
