// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MCP
import AppleDebugCore

enum ToolCatalog {
    static let tools: [Tool] = [
        Tool(
            name: "apple_capabilities",
            description: "Describe debugger capabilities and platform restrictions for macOS, iOS Simulator, and authorized iOS devices.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_toolchain_status",
            description: "Discover the local Xcode, LLDB, Simulator, and device tooling without launching or attaching to a process.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_lldb_dap_initialize",
            description: "Start the local LLDB-DAP adapter, complete initialization, and return its advertised capabilities without launching a debug target.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_debug_reverse_capabilities",
            description: "Report whether the installed Apple LLDB supports process recording, reverse stepping, reverse continue, or time-travel replay; unsupported features fail closed.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_debug_replay_capabilities",
            description: "Report the bounded checkpoint/replay backend and distinguish it from native reverse execution or an external record/replay engine.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_debug_checkpoint",
            description: "Capture a bounded stop snapshot and optional memory evidence for an authorized local macOS launch session. Replay restores a source location, not live process state.",
            inputSchema: replayCheckpointObjectSchema
        ),
        Tool(
            name: "apple_debug_replay",
            description: "Relaunch an authorized local macOS debug program from a checkpoint artifact and stop at its recorded source location; exact register/memory state is not restored.",
            inputSchema: replayObjectSchema
        ),
        Tool(
            name: "apple_kernel_capabilities",
            description: "Report the fail-closed Apple kernel-debugging boundary and supported user-process alternatives such as vmmap, heap, leaks, and xctrace.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_kernel_lab_capabilities",
            description: "Report the separately gated read-only remote KDP kernel-lab provider without probing or changing a target.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_kernel_lab_connect",
            description: "Connect to an explicitly configured remote KDP kernel lab using a KDK/debug-kernel image. Disabled unless APPLE_DEBUG_ALLOW_KERNEL_LAB=1.",
            inputSchema: kernelLabConnectObjectSchema
        ),
        Tool(
            name: "apple_kernel_lab_inspect",
            description: "Inspect threads, stack, registers, and bounded kernel memory through a read-only remote KDP lab session. Arbitrary LLDB commands and writes are not exposed.",
            inputSchema: kernelLabInspectObjectSchema
        ),
        Tool(
            name: "apple_kernel_lab_close",
            description: "Close an owned remote KDP kernel-lab session.",
            inputSchema: sessionObjectSchema
        ),
        Tool(
            name: "apple_plugin_list",
            description: "Discover bounded JSON plugin manifests from an explicit directory without loading dylibs or executing plugin code.",
            inputSchema: pluginListObjectSchema
        ),
        Tool(
            name: "apple_plugin_host_plan",
            description: "Validate a signed plugin XPC service executable and return a non-executing plan for the App Sandbox service boundary.",
            inputSchema: pluginHostPlanObjectSchema
        ),
        Tool(
            name: "apple_plugin_host_execute",
            description: "Execute a signed plugin through the embedded App Sandbox XPC service after an explicit execution grant; use the legacy sandbox-exec profile only when transport=profile is explicitly selected.",
            inputSchema: pluginHostExecuteObjectSchema
        ),
        Tool(
            name: "apple_macho_inspect",
            description: "Inspect a Mach-O or universal Mach-O file and return architectures, header metadata, load-command count, and segments without executing it.",
            inputSchema: pathObjectSchema
        ),
        Tool(
            name: "apple_binary_inspect",
            description: "Inspect an authorized Apple binary for Mach-O metadata, code signature/entitlements, linked libraries, symbols, and dyld exports.",
            inputSchema: binaryInspectObjectSchema
        ),
        Tool(
            name: "apple_binary_diff",
            description: "Compare two authorized Mach-O files, .app bundles, or .dSYM bundles without executing them.",
            inputSchema: binaryDiffObjectSchema
        ),
        Tool(
            name: "apple_signing_audit",
            description: "Audit Apple code-signature verification, identity, entitlements, authorities, Gatekeeper assessment, and embedded provisioning metadata without modifying the artifact.",
            inputSchema: pathObjectSchema
        ),
        Tool(
            name: "apple_patch_preview",
            description: "Assemble code and preview byte-level changes at a file offset without modifying the Mach-O or bundle.",
            inputSchema: patchPreviewObjectSchema
        ),
        Tool(
            name: "apple_resign_plan",
            description: "Create a reviewable copy/sign/verify/Gatekeeper plan for an Apple artifact without executing release-authority operations.",
            inputSchema: resignPlanObjectSchema
        ),
        Tool(
            name: "apple_runtime_metadata",
            description: "Extract Objective-C classes/protocols/selectors and demangled Swift symbols from an authorized Apple binary.",
            inputSchema: binaryInspectObjectSchema
        ),
        Tool(
            name: "apple_swift_ast_inspect",
            description: "Emit a bounded typed source-backed Swift AST with declarations, types, functions, variables, imports, and compiler locations through public swiftc -dump-ast; accepts a file set or an Xcode project/scheme target context.",
            inputSchema: swiftASTObjectSchema
        ),
        Tool(
            name: "apple_assemble",
            description: "Assemble bounded arm64 or x86_64 Apple assembly into bytes and llvm-objdump disassembly without executing or patching it.",
            inputSchema: assembleObjectSchema
        ),
        Tool(
            name: "apple_control_flow",
            description: "Build a bounded Mach-O instruction model with function boundaries, basic blocks, direct branch edges, call graph edges, external call targets, and annotated decompiler-style pseudo-code.",
            inputSchema: controlFlowObjectSchema
        ),
        Tool(
            name: "apple_dyld_shared_cache_inspect",
            description: "Inspect a dyld shared-cache header, mappings, UUID, code-signature ranges, and bounded image paths without executing the cache.",
            inputSchema: dyldSharedCacheObjectSchema
        ),
        Tool(
            name: "apple_dyld_shared_cache_image_analyze",
            description: "Decode one selected shared-cache image's public Mach-O load commands, segments, export trie, UUID, nlist symbols, chained-fixup imports, and bounded ObjC/Swift runtime cross-references without executing the cache.",
            inputSchema: dyldSharedCacheImageObjectSchema
        ),
        Tool(
            name: "apple_dyld_shared_cache_discover",
            description: "Search bounded standard macOS/Xcode/CoreSimulator roots for mounted dyld shared-cache files and report whether the optional utility exists.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_dwarf_inspect",
            description: "Query bounded DWARF source paths, types, declarations, statistics, and address lookups from a Mach-O or dSYM.",
            inputSchema: dwarfInspectObjectSchema
        ),
        Tool(
            name: "apple_crash_inspect",
            description: "Parse an Apple .crash or .ips report into process, exception, thread, and image metadata without executing it.",
            inputSchema: crashObjectSchema
        ),
        Tool(
            name: "apple_crash_symbolicate",
            description: "Symbolicate bounded crash-report frames against supplied Mach-O, app, or dSYM artifacts without executing them.",
            inputSchema: crashSymbolicateObjectSchema
        ),
        Tool(
            name: "apple_log_show",
            description: "Read bounded host or Simulator unified logs without mutating the target.",
            inputSchema: logShowObjectSchema
        ),
        Tool(
            name: "apple_debug_session_create",
            description: "Create and initialize an authorized LLDB-DAP session. Pass a CoreDevice UUID with APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1, or a legacy physical-device UDID with both APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1 and APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1. Legacy devices also require the signed .app path and are attached through ios-deploy.",
            inputSchema: sessionCreateObjectSchema
        ),
        Tool(
            name: "apple_debug_session_list",
            description: "List active local LLDB-DAP debug sessions.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_debug_session_close",
            description: "Close a local LLDB-DAP debug session and terminate its adapter process.",
            inputSchema: sessionObjectSchema
        ),
        Tool(
            name: "apple_debug_launch",
            description: "Launch an authorized target in an existing LLDB-DAP session. Disabled unless APPLE_DEBUG_ALLOW_TARGET_LAUNCH=1.",
            inputSchema: launchObjectSchema
        ),
        Tool(
            name: "apple_debug_attach",
            description: "Attach an authorized local or CoreDevice physical-device LLDB-DAP session to a process ID. Legacy physical-device sessions are attached during apple_debug_session_create with appPath. Local attach requires APPLE_DEBUG_ALLOW_TARGET_ATTACH=1; device attach requires APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1.",
            inputSchema: attachObjectSchema
        ),
        Tool(
            name: "apple_debug_set_breakpoint",
            description: "Set a source-line breakpoint with optional condition, hit condition, or log message.",
            inputSchema: breakpointObjectSchema
        ),
        Tool(
            name: "apple_debug_breakpoint_locations",
            description: "Resolve executable breakpoint locations for a source line through LLDB-DAP.",
            inputSchema: breakpointLocationsObjectSchema
        ),
        Tool(
            name: "apple_debug_set_instruction_breakpoint",
            description: "Set a bounded instruction-address breakpoint with optional condition, hit condition, or log message.",
            inputSchema: instructionBreakpointObjectSchema
        ),
        Tool(
            name: "apple_debug_set_function_breakpoint",
            description: "Set a function breakpoint with optional condition or hit condition.",
            inputSchema: functionBreakpointObjectSchema
        ),
        Tool(
            name: "apple_debug_set_exception_breakpoints",
            description: "Configure exception breakpoint filters supported by LLDB-DAP.",
            inputSchema: exceptionBreakpointObjectSchema
        ),
        Tool(
            name: "apple_debug_threads",
            description: "List threads in an active debug session.",
            inputSchema: sessionObjectSchema
        ),
        Tool(
            name: "apple_debug_stack_trace",
            description: "Read a thread stack trace in an active debug session.",
            inputSchema: stackTraceObjectSchema
        ),
        Tool(
            name: "apple_debug_read_memory",
            description: "Read memory from a stopped target through LLDB-DAP.",
            inputSchema: memoryObjectSchema
        ),
        Tool(
            name: "apple_debug_memory_map",
            description: "Read a bounded macOS vmmap region report for an explicitly authorized local process. Requires APPLE_DEBUG_ALLOW_TARGET_ATTACH=1.",
            inputSchema: processObjectSchema
        ),
        Tool(
            name: "apple_debug_runtime_diagnose",
            description: "Run bounded Apple heap, leaks, malloc-history, or live-sample diagnostics for an explicitly authorized local process.",
            inputSchema: runtimeDiagnosticObjectSchema
        ),
        Tool(
            name: "apple_debug_memory_analyze",
            description: "Parse an authorized process vmmap report into typed regions, permissions, resident/dirty/swap sizes, and details.",
            inputSchema: processObjectSchema
        ),
        Tool(
            name: "apple_debug_memory_snapshot",
            description: "Capture a typed vmmap JSON snapshot for an authorized process for later memory-region diffing.",
            inputSchema: memorySnapshotObjectSchema
        ),
        Tool(
            name: "apple_debug_memory_diff",
            description: "Compare two typed vmmap snapshots and return added, removed, and changed regions.",
            inputSchema: memoryDiffObjectSchema
        ),
        Tool(
            name: "apple_performance_record",
            description: "Capture a bounded xctrace artifact for an authorized macOS PID, Simulator UDID, or paired CoreDevice UUID.",
            inputSchema: performanceRecordObjectSchema
        ),
        Tool(
            name: "apple_performance_analyze",
            description: "Parse an xctrace Time Profiler trace into bounded rows, symbol/frame hotspots, and folded flame-stack data.",
            inputSchema: performanceAnalyzeObjectSchema
        ),
        Tool(
            name: "apple_performance_semantic_report",
            description: "Return a template-specific semantic xctrace report for allocations, system trace, power/energy, animation, signposts, or Swift Concurrency public schemas.",
            inputSchema: performanceSemanticReportObjectSchema
        ),
        Tool(
            name: "apple_performance_timeline",
            description: "Return bounded timeline points from a public xctrace schema for workbench/timeline visualization.",
            inputSchema: performanceTimelineObjectSchema
        ),
        Tool(
            name: "apple_performance_diff",
            description: "Compare two bounded public xctrace exports by semantic counters, durations, and hotspot deltas.",
            inputSchema: performanceDiffObjectSchema
        ),
        Tool(
            name: "apple_swift_concurrency_graph",
            description: "Build a trace-backed Swift Concurrency task/actor/continuation graph from the public xctrace export; private runtime state is never accessed.",
            inputSchema: swiftConcurrencyGraphObjectSchema
        ),
        Tool(
            name: "apple_debug_disassemble",
            description: "Disassemble instructions from a stopped target through LLDB-DAP.",
            inputSchema: disassembleObjectSchema
        ),
        Tool(
            name: "apple_debug_continue",
            description: "Continue an active debug session for a selected thread.",
            inputSchema: threadObjectSchema
        ),
        Tool(
            name: "apple_debug_pause",
            description: "Pause a running target in an active debug session.",
            inputSchema: sessionObjectSchema
        ),
        Tool(
            name: "apple_debug_step",
            description: "Step into, over, or out of the selected thread in a stopped debug session.",
            inputSchema: stepObjectSchema
        ),
        Tool(
            name: "apple_debug_forward_trace",
            description: "Record a bounded sequence of forward LLDB-DAP stop events after stepping; this is not reverse execution and reports that boundary explicitly.",
            inputSchema: forwardTraceObjectSchema
        ),
        Tool(
            name: "apple_debug_scopes",
            description: "Read register, local, and argument scopes for a stack frame.",
            inputSchema: frameObjectSchema
        ),
        Tool(
            name: "apple_debug_variables",
            description: "Read variables for a DAP variables reference returned by a scope or evaluate request.",
            inputSchema: variablesObjectSchema
        ),
        Tool(
            name: "apple_debug_completions",
            description: "Request LLDB expression or source completions for a frame.",
            inputSchema: completionsObjectSchema
        ),
        Tool(
            name: "apple_debug_set_variable",
            description: "Set a debugger variable only when APPLE_DEBUG_ALLOW_VARIABLE_WRITE=1 is explicitly enabled.",
            inputSchema: setVariableObjectSchema
        ),
        Tool(
            name: "apple_debug_registers",
            description: "Read the register scope and register variables for a stopped stack frame.",
            inputSchema: frameObjectSchema
        ),
        Tool(
            name: "apple_debug_stop_snapshot",
            description: "Collect a structured stop snapshot with events, threads, stack, scopes, registers, and modules.",
            inputSchema: stopSnapshotObjectSchema
        ),
        Tool(
            name: "apple_debug_wait_for_stop",
            description: "Wait for the next stopped, exited, or terminated LLDB-DAP event after continue or step.",
            inputSchema: waitForStopObjectSchema
        ),
        Tool(
            name: "apple_debug_modules",
            description: "List loaded modules/images in an active debug session.",
            inputSchema: moduleObjectSchema
        ),
        Tool(
            name: "apple_debug_exception_info",
            description: "Read exception information for a stopped thread.",
            inputSchema: threadObjectSchema
        ),
        Tool(
            name: "apple_debug_evaluate",
            description: "Evaluate an expression in a stopped frame. Disabled unless APPLE_DEBUG_ALLOW_EVALUATE=1.",
            inputSchema: evaluateObjectSchema
        ),
        Tool(
            name: "apple_debug_data_breakpoint_info",
            description: "Resolve a DAP data breakpoint identifier for a variable.",
            inputSchema: dataBreakpointInfoObjectSchema
        ),
        Tool(
            name: "apple_debug_set_data_breakpoint",
            description: "Set a watchpoint using a DAP data breakpoint identifier.",
            inputSchema: dataBreakpointObjectSchema
        ),
        Tool(
            name: "apple_debug_write_memory",
            description: "Write up to 4096 bytes to a stopped target. Disabled unless APPLE_DEBUG_ALLOW_MEMORY_WRITE=1.",
            inputSchema: writeMemoryObjectSchema
        ),
        Tool(
            name: "apple_debug_search_memory",
            description: "Search a bounded readable memory range for a base64 byte pattern.",
            inputSchema: searchMemoryObjectSchema
        ),
        Tool(
            name: "apple_debug_patch_memory",
            description: "Transactionally patch stopped target memory after optional expected-byte validation. Disabled unless APPLE_DEBUG_ALLOW_MEMORY_WRITE=1.",
            inputSchema: patchMemoryObjectSchema
        ),
        Tool(
            name: "apple_debug_patch_assembly",
            description: "Assemble bounded arm64 or x86_64 code and transactionally patch it into a stopped authorized target. Requires memory-write authorization and expected-byte validation when supplied.",
            inputSchema: patchAssemblyObjectSchema
        ),
        Tool(
            name: "apple_debug_terminate",
            description: "Request target termination through LLDB-DAP.",
            inputSchema: terminateObjectSchema
        ),
        Tool(
            name: "apple_debug_disconnect",
            description: "Disconnect the LLDB-DAP session with an explicit terminate-debuggee choice.",
            inputSchema: terminateObjectSchema
        ),
        Tool(
            name: "apple_simulator_list",
            description: "List available iOS Simulator devices without changing simulator state.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_simulator_boot",
            description: "Boot an available iOS Simulator. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorObjectSchema
        ),
        Tool(
            name: "apple_simulator_shutdown",
            description: "Shut down an iOS Simulator. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorObjectSchema
        ),
        Tool(
            name: "apple_simulator_install",
            description: "Install an app bundle on an iOS Simulator. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorInstallObjectSchema
        ),
        Tool(
            name: "apple_simulator_launch",
            description: "Launch an installed app on an iOS Simulator with optional arguments, termination, or wait-for-debugger. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorLaunchObjectSchema
        ),
        Tool(
            name: "apple_simulator_terminate",
            description: "Terminate an app on an iOS Simulator. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorLaunchObjectSchema
        ),
        Tool(
            name: "apple_simulator_screenshot",
            description: "Capture a PNG screenshot from an iOS Simulator. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorScreenshotObjectSchema
        ),
        Tool(
            name: "apple_simulator_open_url",
            description: "Open a URL in an iOS Simulator. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorURLObjectSchema
        ),
        Tool(
            name: "apple_simulator_set_location",
            description: "Set a simulated latitude/longitude on an iOS Simulator. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorLocationObjectSchema
        ),
        Tool(
            name: "apple_simulator_clear_location",
            description: "Clear the simulated location on an iOS Simulator. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorObjectSchema
        ),
        Tool(
            name: "apple_simulator_record_video",
            description: "Record a bounded Simulator display video. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorRecordVideoObjectSchema
        ),
        Tool(
            name: "apple_simulator_app_info",
            description: "Read metadata for an installed Simulator application without changing target state.",
            inputSchema: simulatorAppInfoObjectSchema
        ),
        Tool(
            name: "apple_simulator_get_app_container",
            description: "Resolve an installed Simulator application's app, data, or app-group container path.",
            inputSchema: simulatorContainerObjectSchema
        ),
        Tool(
            name: "apple_simulator_environment",
            description: "Control or inspect bounded Simulator environment state: status bar, appearance/content size, privacy permissions, push payloads, pasteboard, keychain reset, environment variables, installed apps, and media import.",
            inputSchema: simulatorEnvironmentObjectSchema
        ),
        Tool(
            name: "apple_simulator_repro_bundle",
            description: "Capture a bounded reproducible Simulator evidence bundle containing screenshot, app metadata, logs, optional xctrace bundles, and an optional crash report.",
            inputSchema: simulatorReproBundleObjectSchema
        ),
        Tool(
            name: "apple_simulator_ui_snapshot",
            description: "Run the project's XCUITest UI probe and return a structured accessibility tree. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorUISnapshotObjectSchema
        ),
        Tool(
            name: "apple_simulator_ui_action",
            description: "Run a bounded XCUITest tap, text entry, swipe, or wait action and return the resulting accessibility tree. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorUIActionObjectSchema
        ),
        Tool(
            name: "apple_simulator_ui_probe",
            description: "Generate a temporary XCUITest runner for an arbitrary installed Simulator application and return its accessibility tree. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorUIProbeObjectSchema
        ),
        Tool(
            name: "apple_simulator_ui_probe_action",
            description: "Generate a temporary XCUITest runner, perform a bounded action against an arbitrary installed Simulator application, and return the resulting tree. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorUIProbeActionObjectSchema
        ),
        Tool(
            name: "apple_device_list",
            description: "List CoreDevice and legacy Xcode (xcdevice) physical-device inventory with transport-specific authorization state.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_device_install",
            description: "Install an authorized development app on a physical device. Uses CoreDevice when available and optional ios-deploy for legacy Xcode devices. Disabled unless APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1.",
            inputSchema: deviceInstallObjectSchema
        ),
        Tool(
            name: "apple_device_launch",
            description: "Launch an authorized development app on a physical device. CoreDevice launch terminates an existing instance, returns its PID when appPath identifies the executable, and supports start-stopped debugger attach; legacy devices use optional ios-deploy. Disabled unless APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1.",
            inputSchema: deviceLaunchObjectSchema
        ),
        Tool(
            name: "apple_device_processes",
            description: "List running processes on an authorized CoreDevice physical device. This is read-only and requires a paired, tunnel-ready CoreDevice UUID.",
            inputSchema: deviceIdentifierObjectSchema
        ),
        Tool(
            name: "apple_device_terminate",
            description: "Terminate a process on an authorized CoreDevice physical device. Disabled unless APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1; force termination is explicit.",
            inputSchema: deviceTerminateObjectSchema
        ),
        Tool(
            name: "apple_device_suspend",
            description: "Suspend a process on an authorized CoreDevice physical device. Disabled unless APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1.",
            inputSchema: deviceProcessObjectSchema
        ),
        Tool(
            name: "apple_device_resume",
            description: "Resume a process on an authorized CoreDevice physical device. Disabled unless APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1.",
            inputSchema: deviceProcessObjectSchema
        ),
        Tool(
            name: "apple_device_signal",
            description: "Send an allowlisted signal to a process on an authorized CoreDevice physical device. Disabled unless APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1.",
            inputSchema: deviceSignalObjectSchema
        ),
        Tool(
            name: "apple_device_sysdiagnose",
            description: "Collect a bounded CoreDevice sysdiagnose into an explicit destination directory. Disabled unless APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1.",
            inputSchema: deviceSysdiagnoseObjectSchema
        ),
        Tool(
            name: "apple_xcode_discover",
            description: "Discover schemes and targets from an Xcode project or workspace without building it.",
            inputSchema: xcodeDiscoverObjectSchema
        ),
        Tool(
            name: "apple_xcode_build",
            description: "Build an Xcode project or workspace for a destination. Disabled unless APPLE_DEBUG_ALLOW_XCODE_BUILD=1.",
            inputSchema: xcodeBuildObjectSchema
        ),
        Tool(
            name: "apple_xcode_test",
            description: "Run an Xcode scheme on an explicit destination and return its xcresult path and test summary. Disabled unless APPLE_DEBUG_ALLOW_XCODE_BUILD=1.",
            inputSchema: xcodeTestObjectSchema
        ),
        Tool(
            name: "apple_symbolicate",
            description: "Resolve a Mach-O address with atos using a binary or dSYM-backed binary.",
            inputSchema: symbolicateObjectSchema
        )
    ]

    struct Context: Sendable {
        let sessions: DebugSessionManager
        let replay: CheckpointReplayManager
        let kernelLab: KernelLabSessionManager

        init() {
            let sessions = DebugSessionManager()
            self.sessions = sessions
            self.replay = CheckpointReplayManager(sessions: sessions)
            self.kernelLab = KernelLabSessionManager()
        }

        func shutdown() async {
            await kernelLab.closeAll()
            await sessions.closeAll()
        }
    }

    static func makeContext() -> Context {
        Context()
    }

}
