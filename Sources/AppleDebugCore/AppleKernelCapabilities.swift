// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public struct AppleKernelCapabilityReport: Codable, Equatable, Sendable {
    public let kernelTaskAttachSupported: Bool
    public let kernelMemoryReadSupported: Bool
    public let kernelMemoryWriteSupported: Bool
    public let kextDebuggingSupported: Bool
    public let userProcessMemoryMapSupported: Bool
    public let supportedAlternatives: [String]
    public let notes: [String]

    public init(
        kernelTaskAttachSupported: Bool,
        kernelMemoryReadSupported: Bool,
        kernelMemoryWriteSupported: Bool,
        kextDebuggingSupported: Bool,
        userProcessMemoryMapSupported: Bool,
        supportedAlternatives: [String],
        notes: [String]
    ) {
        self.kernelTaskAttachSupported = kernelTaskAttachSupported
        self.kernelMemoryReadSupported = kernelMemoryReadSupported
        self.kernelMemoryWriteSupported = kernelMemoryWriteSupported
        self.kextDebuggingSupported = kextDebuggingSupported
        self.userProcessMemoryMapSupported = userProcessMemoryMapSupported
        self.supportedAlternatives = supportedAlternatives
        self.notes = notes
    }
}

public enum AppleKernelCapabilityService {
    public static func report() -> AppleKernelCapabilityReport {
        AppleKernelCapabilityReport(
            kernelTaskAttachSupported: false,
            kernelMemoryReadSupported: false,
            kernelMemoryWriteSupported: false,
            kextDebuggingSupported: false,
            userProcessMemoryMapSupported: ToolchainProbe.path(for: "vmmap") != nil,
            supportedAlternatives: [
                "apple_debug_memory_map",
                "apple_debug_runtime_diagnose",
                "apple_performance_record",
                "apple_performance_analyze",
                "apple_performance_semantic_report"
            ],
            notes: [
                "Stock macOS does not expose an authorized kernel-debugging boundary to this local MCP server.",
                "SIP, kernel code-signing, entitlements, and KDK/privileged debugger requirements prevent a truthful x64dbg-style kernel memory editor here.",
                "The server keeps kernel attach/read/write and kext debugging fail-closed while exposing user-process vmmap, heap, leaks, sampling, and xctrace alternatives."
            ]
        )
    }
}
