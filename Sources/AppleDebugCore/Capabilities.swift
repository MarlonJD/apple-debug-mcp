// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum AppleDebugPlatform: String, Codable, CaseIterable, Sendable {
    case macOS = "macos"
    case iOSSimulator = "ios-simulator"
    case iOSDevice = "ios-device"
}

public enum AppleDebugCapability: String, Codable, CaseIterable, Sendable {
    case sessionLifecycle = "session-lifecycle"
    case launch
    case attach
    case breakpoints
    case watchpoints
    case stepControl = "step-control"
    case registers
    case stack
    case memoryRead = "memory-read"
    case memoryWrite = "memory-write"
    case machOAnalysis = "macho-analysis"
    case controlFlowAnalysis = "control-flow-analysis"
    case dyldSharedCache = "dyld-shared-cache"
    case binaryIntelligence = "binary-intelligence"
    case runtimeMetadata = "runtime-metadata"
    case dwarfAnalysis = "dwarf-analysis"
    case performanceAnalysis = "performance-analysis"
    case runtimeDiagnostics = "runtime-diagnostics"
    case memoryMapAnalysis = "memory-map-analysis"
    case assembler
    case binaryDiff = "binary-diff"
    case symbolication
    case crashAnalysis = "crash-analysis"
    case simulatorControl = "simulator-control"
    case simulatorEnvironment = "simulator-environment"
    case reproducibleEvidence = "reproducible-evidence"
    case deviceControl = "device-control"
    case uiInspection = "ui-inspection"
    case forwardExecutionTrace = "forward-execution-trace"
    case reverseExecution = "reverse-execution"
    case kernelInspection = "kernel-inspection"
    case signingAudit = "signing-audit"
    case patchWorkflow = "patch-workflow"
    case nativeWorkbench = "native-workbench"
    case pluginExtensions = "plugin-extensions"
    case logs
}

public struct CapabilityReport: Codable, Equatable, Sendable {
    public let platform: AppleDebugPlatform
    public let supported: [AppleDebugCapability]
    public let restricted: [AppleDebugCapability]
    public let notes: [String]

    public init(
        platform: AppleDebugPlatform,
        supported: [AppleDebugCapability],
        restricted: [AppleDebugCapability],
        notes: [String]
    ) {
        self.platform = platform
        self.supported = supported
        self.restricted = restricted
        self.notes = notes
    }
}

public enum CapabilityMatrix {
    public static func reports() -> [CapabilityReport] {
        [
            CapabilityReport(
                platform: .macOS,
                supported: [
                    .sessionLifecycle, .launch, .attach, .breakpoints,
                    .watchpoints, .stepControl, .registers, .stack,
                    .memoryRead, .memoryWrite, .machOAnalysis, .symbolication,
                    .controlFlowAnalysis, .dyldSharedCache, .binaryIntelligence,
                    .runtimeMetadata, .dwarfAnalysis, .performanceAnalysis,
                    .runtimeDiagnostics, .memoryMapAnalysis, .assembler,
                    .binaryDiff, .crashAnalysis, .forwardExecutionTrace,
                    .signingAudit, .patchWorkflow, .nativeWorkbench,
                    .pluginExtensions, .logs
                ],
                restricted: [.reverseExecution, .kernelInspection],
                notes: [
                    "Attach and memory mutation depend on macOS debugger permissions and target entitlements.",
                    "Memory and variable mutation are disabled by default and require separate explicit policy grants.",
                    "Apple LLDB reverse execution/time-travel is not available in the installed toolchain; forward stop tracing is supported.",
                    "Kernel memory/debugging remains restricted by SIP, entitlements, and privileged Apple tooling; user-process vmmap and runtime diagnostics are the supported boundary.",
                    "The native workbench embeds read-only analyzers and safe patch planning; external plugin code is never loaded by the MCP server."
                ]
            ),
            CapabilityReport(
                platform: .iOSSimulator,
                supported: [
                    .sessionLifecycle, .launch, .attach, .breakpoints,
                    .watchpoints, .stepControl, .registers, .stack,
                    .memoryRead, .memoryWrite, .machOAnalysis, .symbolication,
                    .controlFlowAnalysis, .dyldSharedCache, .binaryIntelligence,
                    .runtimeMetadata, .dwarfAnalysis, .performanceAnalysis,
                    .assembler, .binaryDiff, .crashAnalysis, .simulatorControl,
                    .simulatorEnvironment, .reproducibleEvidence, .uiInspection,
                    .forwardExecutionTrace, .signingAudit, .patchWorkflow,
                    .pluginExtensions, .logs
                ],
                restricted: [.reverseExecution, .kernelInspection, .runtimeDiagnostics],
                notes: [
                    "Simulator behaviour is not a substitute for physical-device validation.",
                    "Memory and variable mutation are disabled by default and require separate explicit policy grants.",
                    "UI inspection and bounded actions run through project-backed or generated XCUITest probes; the generated path targets an installed bundle ID and requires Simulator mutation permission.",
                    "Apple LLDB reverse execution/time-travel is not available; use forward stop tracing, xctrace export, and crash/DWARF evidence instead.",
                    "Generated UI probes and repro bundles are local Simulator workflows and do not grant physical-device access."
                ]
            ),
            CapabilityReport(
                platform: .iOSDevice,
                supported: [
                    .launch, .machOAnalysis, .symbolication, .crashAnalysis,
                    .controlFlowAnalysis, .dyldSharedCache, .binaryIntelligence,
                    .runtimeMetadata, .dwarfAnalysis, .assembler, .binaryDiff,
                    .signingAudit, .patchWorkflow, .deviceControl
                ],
                restricted: [
                    .sessionLifecycle, .attach, .breakpoints, .watchpoints,
                    .stepControl, .registers, .stack, .memoryRead,
                    .memoryWrite, .uiInspection, .logs, .performanceAnalysis,
                    .runtimeDiagnostics, .forwardExecutionTrace,
                    .reverseExecution, .kernelInspection
                ],
                notes: [
                    "Physical-device debugging is limited to paired, authorized development targets.",
                    "Stock App Store applications are outside the supported debugging boundary.",
                    "Device access requires the appropriate signing, Developer Mode, and entitlements.",
                    "The current device adapter inventories, installs, and launches development apps; remote LLDB session attach remains gated until a paired-device fixture is available."
                ]
            )
        ]
    }
}

public struct ToolchainToolStatus: Codable, Equatable, Sendable {
    public let name: String
    public let path: String?

    public init(name: String, path: String?) {
        self.name = name
        self.path = path
    }
}

public struct ToolchainStatus: Codable, Equatable, Sendable {
    public let developerDirectory: String?
    public let tools: [ToolchainToolStatus]

    public init(developerDirectory: String?, tools: [ToolchainToolStatus]) {
        self.developerDirectory = developerDirectory
        self.tools = tools
    }
}

public enum ToolchainProbe {
    public static func collect() -> ToolchainStatus {
        let toolNames = [
            "lldb", "lldb-dap", "simctl", "devicectl", "xcodebuild",
            "codesign", "otool", "nm", "dyld_info", "swift-demangle", "dwarfdump", "vmmap", "xctrace",
            "heap", "leaks", "malloc_history", "sample", "clang", "llvm-objdump"
        ]
        let tools = toolNames.map { name in
            ToolchainToolStatus(name: name, path: path(for: name))
        }

        return ToolchainStatus(
            developerDirectory: run(
                executable: "/usr/bin/xcode-select",
                arguments: ["-p"]
            ),
            tools: tools
        )
    }

    public static func path(for name: String) -> String? {
        run(
            executable: "/usr/bin/xcrun",
            arguments: ["--find", name]
        )
    }

    private static func run(executable: String, arguments: [String]) -> String? {
        guard let result = try? AppleProcessRunner.run(
            executable: executable,
            arguments: arguments,
            maximumOutputSize: 256 * 1024
        ), result.terminationStatus == 0 else {
            return nil
        }
        guard let value = String(data: result.stdout, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty else {
            return nil
        }

        return value
    }
}
