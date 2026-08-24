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
            name: "apple_kernel_capabilities",
            description: "Report the fail-closed Apple kernel-debugging boundary and supported user-process alternatives such as vmmap, heap, leaks, and xctrace.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_plugin_list",
            description: "Discover bounded JSON plugin manifests from an explicit directory without loading dylibs or executing plugin code.",
            inputSchema: pluginListObjectSchema
        ),
        Tool(
            name: "apple_plugin_host_plan",
            description: "Validate a signed plugin executable and return a sandboxed-host plan without executing it.",
            inputSchema: pluginHostPlanObjectSchema
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
            name: "apple_assemble",
            description: "Assemble bounded arm64 or x86_64 Apple assembly into bytes and llvm-objdump disassembly without executing or patching it.",
            inputSchema: assembleObjectSchema
        ),
        Tool(
            name: "apple_control_flow",
            description: "Build a bounded Mach-O instruction model with function boundaries, basic blocks, direct branch edges, call graph edges, and external call targets.",
            inputSchema: controlFlowObjectSchema
        ),
        Tool(
            name: "apple_dyld_shared_cache_inspect",
            description: "Inspect a dyld shared-cache header, mappings, UUID, code-signature ranges, and bounded image paths without executing the cache.",
            inputSchema: dyldSharedCacheObjectSchema
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
            description: "Create and initialize an authorized LLDB-DAP session. Pass a physical-device UUID only with APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1 and a paired development device.",
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
            description: "Attach an authorized local or paired physical-device LLDB-DAP session to a process ID. Local attach requires APPLE_DEBUG_ALLOW_TARGET_ATTACH=1; device attach requires APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1.",
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
            description: "Capture a bounded xctrace Time Profiler, Allocations, or System Trace artifact for an authorized macOS PID or Simulator.",
            inputSchema: performanceRecordObjectSchema
        ),
        Tool(
            name: "apple_performance_analyze",
            description: "Parse an xctrace Time Profiler trace into bounded rows, symbol/frame hotspots, and folded flame-stack data.",
            inputSchema: performanceAnalyzeObjectSchema
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
            description: "List CoreDevice physical-device inventory and explicit pairing/tunnel authorization state.",
            inputSchema: emptyObjectSchema
        ),
        Tool(
            name: "apple_device_install",
            description: "Install an authorized development app on a paired physical device. Disabled unless APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1.",
            inputSchema: deviceInstallObjectSchema
        ),
        Tool(
            name: "apple_device_launch",
            description: "Launch an authorized development app on a paired physical device. Disabled unless APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1.",
            inputSchema: deviceLaunchObjectSchema
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

    private static let sessions = DebugSessionManager()

    static func call(_ params: CallTool.Parameters) async -> CallTool.Result {
        switch params.name {
        case "apple_capabilities":
            return result(for: CapabilityMatrix.reports())
        case "apple_debug_reverse_capabilities":
            return result(for: ReverseExecutionService.capabilities())
        case "apple_kernel_capabilities":
            return result(for: AppleKernelCapabilityService.report())
        case "apple_plugin_list":
            guard let directory = params.arguments?["directory"]?.stringValue else {
                return errorResult("Missing required directory argument.")
            }
            do {
                return result(for: try AppleDebugPluginManifestService.discover(directory: directory))
            } catch {
                return errorResult(error)
            }
        case "apple_plugin_host_plan":
            guard let executablePath = params.arguments?["executablePath"]?.stringValue else {
                return errorResult("Missing required executablePath argument.")
            }
            do {
                return result(
                    for: try ApplePluginHostService.plan(
                        executablePath: executablePath,
                        manifestPath: params.arguments?["manifestPath"]?.stringValue,
                        requiredTeamIdentifier: params.arguments?["requiredTeamIdentifier"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_toolchain_status":
            return result(for: ToolchainProbe.collect())
        case "apple_lldb_dap_initialize":
            let session: LLDBDAPSession
            do {
                session = try LLDBDAPSession()
            } catch {
                return .init(
                    content: [.text(text: error.localizedDescription, annotations: nil, _meta: nil)],
                    isError: true
                )
            }

            do {
                let response = try await session.start()
                let events = await session.drainEvents()
                await session.stop()
                return result(for: DAPProbeResult(response: response, events: events))
            } catch {
                await session.stop()
                return .init(
                    content: [.text(text: error.localizedDescription, annotations: nil, _meta: nil)],
                    isError: true
                )
            }
        case "apple_macho_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return .init(
                    content: [.text(text: "Missing required path argument.", annotations: nil, _meta: nil)],
                    isError: true
                )
            }
            do {
                return result(for: try MachOInspector.inspect(path: path))
            } catch {
                return .init(
                    content: [.text(text: error.localizedDescription, annotations: nil, _meta: nil)],
                    isError: true
                )
            }
        case "apple_binary_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(
                    for: try AppleBinaryIntelligenceService.inspect(
                        path: path,
                        architecture: params.arguments?["architecture"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_binary_diff":
            guard let leftPath = params.arguments?["leftPath"]?.stringValue,
                  let rightPath = params.arguments?["rightPath"]?.stringValue else {
                return errorResult("Missing required leftPath or rightPath argument.")
            }
            do {
                return result(
                    for: try AppleBinaryDiffService.diff(
                        leftPath: leftPath,
                        rightPath: rightPath,
                        architecture: params.arguments?["architecture"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_signing_audit":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(for: try AppleSigningAuditService.inspect(path: path))
            } catch {
                return errorResult(error)
            }
        case "apple_patch_preview":
            guard let path = params.arguments?["path"]?.stringValue,
                  let architecture = params.arguments?["architecture"]?.stringValue,
                  let source = params.arguments?["source"]?.stringValue else {
                return errorResult("Missing required path, architecture, or source argument.")
            }
            let expectedData: Data?
            if let encoded = params.arguments?["expectedData"]?.stringValue {
                guard let decoded = Data(base64Encoded: encoded) else { return errorResult("expectedData must be valid base64.") }
                expectedData = decoded
            } else { expectedData = nil }
            do {
                return result(
                    for: try ApplePatchWorkflowService.preview(
                        path: path,
                        architecture: architecture,
                        fileOffset: intValue(from: params.arguments?["fileOffset"]) ?? 0,
                        source: source,
                        expectedData: expectedData
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_resign_plan":
            guard let inputPath = params.arguments?["inputPath"]?.stringValue,
                  let outputPath = params.arguments?["outputPath"]?.stringValue,
                  let identity = params.arguments?["identity"]?.stringValue else {
                return errorResult("Missing required inputPath, outputPath, or identity argument.")
            }
            do {
                return result(
                    for: try ApplePatchWorkflowService.resignPlan(
                        inputPath: inputPath,
                        outputPath: outputPath,
                        identity: identity,
                        entitlementsPath: params.arguments?["entitlementsPath"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_runtime_metadata":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(
                    for: try AppleRuntimeMetadataService.inspect(
                        path: path,
                        architecture: params.arguments?["architecture"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_assemble":
            guard let source = params.arguments?["source"]?.stringValue,
                  let architecture = params.arguments?["architecture"]?.stringValue else {
                return errorResult("Missing required source or architecture argument.")
            }
            do {
                return result(for: try AppleAssemblerService.assemble(source: source, architecture: architecture))
            } catch {
                return errorResult(error)
            }
        case "apple_control_flow":
            guard let path = params.arguments?["path"]?.stringValue,
                  let architecture = params.arguments?["architecture"]?.stringValue else {
                return errorResult("Missing required path or architecture argument.")
            }
            do {
                return result(for: try AppleControlFlowService.analyze(path: path, architecture: architecture))
            } catch {
                return errorResult(error)
            }
        case "apple_dyld_shared_cache_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(
                    for: try AppleDyldSharedCacheService.inspect(
                        path: path,
                        imageFilter: params.arguments?["imageFilter"]?.stringValue,
                        maximumImages: intValue(from: params.arguments?["maximumImages"]) ?? 10_000
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_dwarf_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(
                    for: try DWARFService.inspect(
                        path: path,
                        architecture: params.arguments?["architecture"]?.stringValue,
                        name: params.arguments?["name"]?.stringValue,
                        lookupAddress: params.arguments?["lookupAddress"]?.stringValue,
                        depth: intValue(from: params.arguments?["depth"]) ?? 3,
                        includeSources: boolValue(
                            from: params.arguments?["includeSources"],
                            default: true
                        ),
                        includeStatistics: boolValue(
                            from: params.arguments?["includeStatistics"],
                            default: true
                        ),
                        includeLineTable: boolValue(
                            from: params.arguments?["includeLineTable"],
                            default: true
                        ),
                        includeRaw: boolValue(
                            from: params.arguments?["includeRaw"],
                            default: false
                        )
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_crash_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(for: try CrashReportAnalyzer.inspect(path: path))
            } catch {
                return errorResult(error)
            }
        case "apple_crash_symbolicate":
            guard let crashPath = params.arguments?["crashPath"]?.stringValue,
                  let artifacts = crashArtifacts(from: params.arguments?["artifacts"]) else {
                return errorResult("Missing required crashPath or valid artifacts array argument.")
            }
            do {
                return result(
                    for: try CrashSymbolicationService.symbolize(
                        path: crashPath,
                        artifacts: artifacts
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_log_show":
            do {
                return result(
                    for: try AppleLogService.show(
                        target: params.arguments?["target"]?.stringValue ?? "host",
                        last: params.arguments?["last"]?.stringValue ?? "5m",
                        predicate: params.arguments?["predicate"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_session_create":
            do {
                return result(
                    for: try await sessions.create(
                        deviceIdentifier: params.arguments?["deviceIdentifier"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_session_list":
            return result(for: await sessions.list())
        case "apple_debug_session_close":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue else {
                return errorResult("Missing required sessionID argument.")
            }
            return result(
                for: SessionCloseResult(
                    sessionID: sessionID,
                    closed: await sessions.close(sessionID: sessionID)
                )
            )
        case "apple_debug_launch":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let program = params.arguments?["program"]?.stringValue else {
                return errorResult("Missing required sessionID or program argument.")
            }
            let arguments = stringArray(from: params.arguments?["args"])
            let stopOnEntry = boolValue(
                from: params.arguments?["stopOnEntry"],
                default: true
            )
            do {
                let response = try await sessions.launch(
                    sessionID: sessionID,
                    program: program,
                    arguments: arguments,
                    stopOnEntry: stopOnEntry
                )
                return result(for: DebugLaunchResult(sessionID: sessionID, response: response))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_attach":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let processID = intValue(from: params.arguments?["processID"]) else {
                return errorResult("Missing required sessionID or processID argument.")
            }
            do {
                return result(for: try await sessions.attach(sessionID: sessionID, processID: processID))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_set_breakpoint":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let file = params.arguments?["file"]?.stringValue,
                  let line = intValue(from: params.arguments?["line"]) else {
                return errorResult("Missing required sessionID, file, or line argument.")
            }
            do {
                return result(
                    for: try await sessions.setBreakpoint(
                        sessionID: sessionID,
                        file: file,
                        line: line,
                        condition: params.arguments?["condition"]?.stringValue,
                        hitCondition: params.arguments?["hitCondition"]?.stringValue,
                        logMessage: params.arguments?["logMessage"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_breakpoint_locations":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let file = params.arguments?["file"]?.stringValue,
                  let line = intValue(from: params.arguments?["line"]) else {
                return errorResult("Missing required sessionID, file, or line argument.")
            }
            do {
                return result(
                    for: try await sessions.breakpointLocations(
                        sessionID: sessionID,
                        file: file,
                        line: line,
                        column: intValue(from: params.arguments?["column"]),
                        endLine: intValue(from: params.arguments?["endLine"]),
                        endColumn: intValue(from: params.arguments?["endColumn"])
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_set_instruction_breakpoint":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let instructionReference = params.arguments?["instructionReference"]?.stringValue else {
                return errorResult("Missing required sessionID or instructionReference argument.")
            }
            do {
                return result(
                    for: try await sessions.setInstructionBreakpoint(
                        sessionID: sessionID,
                        instructionReference: instructionReference,
                        offset: intValue(from: params.arguments?["offset"]),
                        condition: params.arguments?["condition"]?.stringValue,
                        hitCondition: params.arguments?["hitCondition"]?.stringValue,
                        logMessage: params.arguments?["logMessage"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_set_function_breakpoint":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let name = params.arguments?["name"]?.stringValue else {
                return errorResult("Missing required sessionID or name argument.")
            }
            do {
                return result(
                    for: try await sessions.setFunctionBreakpoints(
                        sessionID: sessionID,
                        name: name,
                        condition: params.arguments?["condition"]?.stringValue,
                        hitCondition: params.arguments?["hitCondition"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_set_exception_breakpoints":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue else {
                return errorResult("Missing required sessionID argument.")
            }
            let filterOptions: [DAPValue]
            if let rawFilterOptions = params.arguments?["filterOptions"] {
                guard let converted = dapValueArray(from: rawFilterOptions) else {
                    return errorResult("filterOptions must be an array of valid objects.")
                }
                filterOptions = converted
            } else {
                filterOptions = []
            }
            do {
                return result(
                    for: try await sessions.setExceptionBreakpoints(
                        sessionID: sessionID,
                        filters: stringArray(from: params.arguments?["filters"]),
                        filterOptions: filterOptions
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_threads":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue else {
                return errorResult("Missing required sessionID argument.")
            }
            do {
                return result(for: try await sessions.threads(sessionID: sessionID))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_stack_trace":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let threadID = intValue(from: params.arguments?["threadID"]) else {
                return errorResult("Missing required sessionID or threadID argument.")
            }
            let levels = intValue(from: params.arguments?["levels"]) ?? 100
            do {
                return result(
                    for: try await sessions.stackTrace(
                        sessionID: sessionID,
                        threadID: threadID,
                        levels: levels,
                        startFrame: intValue(from: params.arguments?["startFrame"])
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_read_memory":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let memoryReference = params.arguments?["memoryReference"]?.stringValue,
                  let count = intValue(from: params.arguments?["count"]) else {
                return errorResult("Missing required sessionID, memoryReference, or count argument.")
            }
            let offset = intValue(from: params.arguments?["offset"]) ?? 0
            do {
                return result(for: try await sessions.readMemory(sessionID: sessionID, memoryReference: memoryReference, offset: offset, count: count))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_memory_map":
            guard let processID = intValue(from: params.arguments?["processID"]) else {
                return errorResult("Missing required processID argument.")
            }
            do {
                return result(for: try await sessions.memoryMap(processID: processID))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_runtime_diagnose":
            guard let processID = intValue(from: params.arguments?["processID"]),
                  let toolName = params.arguments?["tool"]?.stringValue,
                  let tool = RuntimeDiagnosticTool(rawValue: toolName) else {
                return errorResult("Missing or invalid processID/tool argument.")
            }
            do {
                return result(
                    for: try RuntimeDiagnosticsService.inspect(
                        processID: processID,
                        tool: tool,
                        mode: params.arguments?["mode"]?.stringValue ?? (tool == .sample ? "sample" : "summary"),
                        pattern: params.arguments?["pattern"]?.stringValue,
                        durationSeconds: intValue(from: params.arguments?["durationSeconds"]) ?? 5,
                        sampleIntervalMilliseconds: intValue(from: params.arguments?["sampleIntervalMilliseconds"]) ?? 10
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_memory_analyze":
            guard let processID = intValue(from: params.arguments?["processID"]) else {
                return errorResult("Missing required processID argument.")
            }
            do {
                return result(for: try AppleMemoryMapService.capture(processID: processID, includeRawOutput: false))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_memory_snapshot":
            guard let processID = intValue(from: params.arguments?["processID"]),
                  let outputPath = params.arguments?["outputPath"]?.stringValue else {
                return errorResult("Missing required processID or outputPath argument.")
            }
            do {
                return result(
                    for: try AppleMemoryMapService.saveSnapshot(
                        processID: processID,
                        outputPath: outputPath,
                        includeRawOutput: boolValue(from: params.arguments?["includeRawOutput"], default: false)
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_memory_diff":
            guard let leftPath = params.arguments?["leftPath"]?.stringValue,
                  let rightPath = params.arguments?["rightPath"]?.stringValue else {
                return errorResult("Missing required leftPath or rightPath argument.")
            }
            do {
                return result(for: try AppleMemoryMapService.diff(leftPath: leftPath, rightPath: rightPath))
            } catch {
                return errorResult(error)
            }
        case "apple_performance_record":
            do {
                return result(
                    for: try ApplePerformanceService.record(
                        processID: intValue(from: params.arguments?["processID"]),
                        simulatorUDID: params.arguments?["simulatorUDID"]?.stringValue,
                        template: params.arguments?["template"]?.stringValue ?? "Time Profiler",
                        durationSeconds: intValue(from: params.arguments?["durationSeconds"]) ?? 5,
                        outputPath: params.arguments?["outputPath"]?.stringValue ?? ""
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_performance_analyze":
            guard let tracePath = params.arguments?["tracePath"]?.stringValue else {
                return errorResult("Missing required tracePath argument.")
            }
            do {
                return result(
                    for: try ApplePerformanceService.analyze(
                        tracePath: tracePath,
                        schema: params.arguments?["schema"]?.stringValue ?? "time-profile",
                        maximumRows: intValue(from: params.arguments?["maximumRows"]) ?? 5_000,
                        includeRows: boolValue(
                            from: params.arguments?["includeRows"],
                            default: false
                        )
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_disassemble":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let memoryReference = params.arguments?["memoryReference"]?.stringValue,
                  let instructionCount = intValue(from: params.arguments?["instructionCount"]) else {
                return errorResult("Missing required sessionID, memoryReference, or instructionCount argument.")
            }
            let instructionOffset = intValue(from: params.arguments?["instructionOffset"]) ?? 0
            do {
                return result(for: try await sessions.disassemble(sessionID: sessionID, memoryReference: memoryReference, instructionOffset: instructionOffset, instructionCount: instructionCount))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_continue":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let threadID = intValue(from: params.arguments?["threadID"]) else {
                return errorResult("Missing required sessionID or threadID argument.")
            }
            do {
                return result(for: try await sessions.continueExecution(sessionID: sessionID, threadID: threadID))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_pause":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue else {
                return errorResult("Missing required sessionID argument.")
            }
            do {
                return result(for: try await sessions.pause(sessionID: sessionID))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_step":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let threadID = intValue(from: params.arguments?["threadID"]),
                  let kind = params.arguments?["kind"]?.stringValue,
                  let stepKind = DebugStepKind(rawValue: kind) else {
                return errorResult("Missing or invalid sessionID, threadID, or kind argument. kind must be stepIn, next, or stepOut.")
            }
            do {
                return result(
                    for: try await sessions.step(
                        sessionID: sessionID,
                        threadID: threadID,
                        kind: stepKind,
                        granularity: params.arguments?["granularity"]?.stringValue.flatMap(DebugStepGranularity.init(rawValue:))
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_forward_trace":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let threadID = intValue(from: params.arguments?["threadID"]),
                  let steps = intValue(from: params.arguments?["steps"]),
                  let kindValue = params.arguments?["kind"]?.stringValue,
                  let kind = DebugStepKind(rawValue: kindValue) else {
                return errorResult("Missing or invalid sessionID, threadID, steps, or kind argument.")
            }
            do {
                return result(
                    for: try await sessions.traceForward(
                        sessionID: sessionID,
                        threadID: threadID,
                        steps: steps,
                        kind: kind,
                        granularity: params.arguments?["granularity"]?.stringValue.flatMap(DebugStepGranularity.init(rawValue:)),
                        timeoutMilliseconds: intValue(from: params.arguments?["timeoutMilliseconds"]) ?? 10_000
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_scopes":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let frameID = intValue(from: params.arguments?["frameID"]) else {
                return errorResult("Missing required sessionID or frameID argument.")
            }
            do {
                return result(for: try await sessions.scopes(sessionID: sessionID, frameID: frameID))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_variables":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let variablesReference = intValue(from: params.arguments?["variablesReference"]) else {
                return errorResult("Missing required sessionID or variablesReference argument.")
            }
            do {
                return result(
                    for: try await sessions.variables(
                        sessionID: sessionID,
                        variablesReference: variablesReference,
                        start: intValue(from: params.arguments?["start"]),
                        count: intValue(from: params.arguments?["count"]),
                        formatHex: params.arguments?["formatHex"]?.boolValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_completions":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let text = params.arguments?["text"]?.stringValue,
                  let column = intValue(from: params.arguments?["column"]) else {
                return errorResult("Missing required sessionID, text, or column argument.")
            }
            do {
                return result(
                    for: try await sessions.completions(
                        sessionID: sessionID,
                        frameID: intValue(from: params.arguments?["frameID"]),
                        text: text,
                        column: column,
                        line: intValue(from: params.arguments?["line"])
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_set_variable":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let variablesReference = intValue(from: params.arguments?["variablesReference"]),
                  let name = params.arguments?["name"]?.stringValue,
                  let value = params.arguments?["value"]?.stringValue else {
                return errorResult("Missing required sessionID, variablesReference, name, or value argument.")
            }
            do {
                return result(
                    for: try await sessions.setVariable(
                        sessionID: sessionID,
                        variablesReference: variablesReference,
                        name: name,
                        value: value,
                        format: nil
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_registers":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let frameID = intValue(from: params.arguments?["frameID"]) else {
                return errorResult("Missing required sessionID or frameID argument.")
            }
            do {
                return result(for: try await sessions.registers(sessionID: sessionID, frameID: frameID))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_stop_snapshot":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue else {
                return errorResult("Missing required sessionID argument.")
            }
            do {
                return result(
                    for: try await sessions.stopSnapshot(
                        sessionID: sessionID,
                        threadID: intValue(from: params.arguments?["threadID"]),
                        levels: intValue(from: params.arguments?["levels"]) ?? 20
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_wait_for_stop":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue else {
                return errorResult("Missing required sessionID argument.")
            }
            do {
                return result(
                    for: try await sessions.waitForStop(
                        sessionID: sessionID,
                        timeoutMilliseconds: intValue(from: params.arguments?["timeoutMilliseconds"]) ?? 10_000
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_modules":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue else {
                return errorResult("Missing required sessionID argument.")
            }
            do {
                return result(
                    for: try await sessions.modules(
                        sessionID: sessionID,
                        startModule: intValue(from: params.arguments?["startModule"]),
                        moduleCount: intValue(from: params.arguments?["moduleCount"])
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_exception_info":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let threadID = intValue(from: params.arguments?["threadID"]) else {
                return errorResult("Missing required sessionID or threadID argument.")
            }
            do {
                return result(for: try await sessions.exceptionInfo(sessionID: sessionID, threadID: threadID))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_evaluate":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let expression = params.arguments?["expression"]?.stringValue else {
                return errorResult("Missing required sessionID or expression argument.")
            }
            do {
                return result(
                    for: try await sessions.evaluate(
                        sessionID: sessionID,
                        expression: expression,
                        frameID: intValue(from: params.arguments?["frameID"]),
                        context: params.arguments?["context"]?.stringValue ?? "repl"
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_data_breakpoint_info":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let variablesReference = intValue(from: params.arguments?["variablesReference"]),
                  let name = params.arguments?["name"]?.stringValue else {
                return errorResult("Missing required sessionID, variablesReference, or name argument.")
            }
            do {
                return result(
                    for: try await sessions.dataBreakpointInfo(
                        sessionID: sessionID,
                        variablesReference: variablesReference,
                        name: name
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_set_data_breakpoint":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let dataID = params.arguments?["dataID"]?.stringValue else {
                return errorResult("Missing required sessionID or dataID argument.")
            }
            do {
                return result(
                    for: try await sessions.setDataBreakpoint(
                        sessionID: sessionID,
                        dataID: dataID,
                        accessType: params.arguments?["accessType"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_write_memory":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let memoryReference = params.arguments?["memoryReference"]?.stringValue,
                  let encodedData = params.arguments?["data"]?.stringValue,
                  let data = Data(base64Encoded: encodedData) else {
                return errorResult("Missing required sessionID, memoryReference, or valid base64 data argument.")
            }
            do {
                return result(
                    for: try await sessions.writeMemory(
                        sessionID: sessionID,
                        memoryReference: memoryReference,
                        offset: intValue(from: params.arguments?["offset"]) ?? 0,
                        data: data
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_search_memory":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let memoryReference = params.arguments?["memoryReference"]?.stringValue,
                  let encodedPattern = params.arguments?["pattern"]?.stringValue,
                  let pattern = Data(base64Encoded: encodedPattern),
                  let count = intValue(from: params.arguments?["count"]) else {
                return errorResult("Missing required sessionID, memoryReference, count, or valid base64 pattern argument.")
            }
            do {
                return result(
                    for: try await sessions.searchMemory(
                        sessionID: sessionID,
                        memoryReference: memoryReference,
                        offset: intValue(from: params.arguments?["offset"]) ?? 0,
                        count: count,
                        pattern: pattern
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_patch_memory":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let memoryReference = params.arguments?["memoryReference"]?.stringValue,
                  let encodedData = params.arguments?["data"]?.stringValue,
                  let data = Data(base64Encoded: encodedData) else {
                return errorResult("Missing required sessionID, memoryReference, or valid base64 data argument.")
            }
            let expectedData: Data?
            if let encoded = params.arguments?["expectedData"]?.stringValue {
                guard let decoded = Data(base64Encoded: encoded) else {
                    return errorResult("expectedData must be valid base64.")
                }
                expectedData = decoded
            } else {
                expectedData = nil
            }
            do {
                return result(
                    for: try await sessions.patchMemory(
                        sessionID: sessionID,
                        memoryReference: memoryReference,
                        offset: intValue(from: params.arguments?["offset"]) ?? 0,
                        expectedData: expectedData,
                        data: data
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_debug_patch_assembly":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let memoryReference = params.arguments?["memoryReference"]?.stringValue,
                  let source = params.arguments?["source"]?.stringValue,
                  let architecture = params.arguments?["architecture"]?.stringValue else {
                return errorResult("Missing required sessionID, memoryReference, source, or architecture argument.")
            }
            let expectedData: Data?
            if let encoded = params.arguments?["expectedData"]?.stringValue {
                guard let decoded = Data(base64Encoded: encoded) else {
                    return errorResult("expectedData must be valid base64.")
                }
                expectedData = decoded
            } else {
                expectedData = nil
            }
            do {
                let assembled = try AppleAssemblerService.assemble(
                    source: source,
                    architecture: architecture
                )
                guard let data = Data(base64Encoded: assembled.bytesBase64) else {
                    return errorResult("Assembler returned invalid bytes.")
                }
                let patch = try await sessions.patchMemory(
                    sessionID: sessionID,
                    memoryReference: memoryReference,
                    offset: intValue(from: params.arguments?["offset"]) ?? 0,
                    expectedData: expectedData,
                    data: data
                )
                return result(for: AssemblerPatchResult(assembled: assembled, patch: patch))
            } catch {
                return errorResult(error)
            }
        case "apple_debug_terminate", "apple_debug_disconnect":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue else {
                return errorResult("Missing required sessionID argument.")
            }
            let terminateDebuggee = boolValue(
                from: params.arguments?["terminateDebuggee"],
                default: params.name == "apple_debug_terminate"
            )
            do {
                let response = params.name == "apple_debug_terminate"
                    ? try await sessions.terminate(
                        sessionID: sessionID,
                        terminateDebuggee: terminateDebuggee
                    )
                    : try await sessions.disconnect(
                        sessionID: sessionID,
                        terminateDebuggee: terminateDebuggee
                    )
                return result(for: response)
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_list":
            do {
                return result(for: try SimulatorService.list())
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_boot", "apple_simulator_shutdown":
            guard let udid = params.arguments?["udid"]?.stringValue else {
                return errorResult("Missing required udid argument.")
            }
            do {
                let action = params.name == "apple_simulator_boot"
                    ? try SimulatorService.boot(udid: udid)
                    : try SimulatorService.shutdown(udid: udid)
                return result(for: action)
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_install":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let appPath = params.arguments?["appPath"]?.stringValue else {
                return errorResult("Missing required udid or appPath argument.")
            }
            do {
                return result(for: try SimulatorService.install(udid: udid, appPath: appPath))
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_launch", "apple_simulator_terminate":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue else {
                return errorResult("Missing required udid or bundleID argument.")
            }
            do {
                let action: SimulatorActionResult
                if params.name == "apple_simulator_launch" {
                    action = try SimulatorService.launch(
                        udid: udid,
                        bundleID: bundleID,
                        arguments: stringArray(from: params.arguments?["arguments"]),
                        terminateRunning: boolValue(
                            from: params.arguments?["terminateRunning"],
                            default: false
                        ),
                        waitForDebugger: boolValue(
                            from: params.arguments?["waitForDebugger"],
                            default: false
                        )
                    )
                } else {
                    action = try SimulatorService.terminate(udid: udid, bundleID: bundleID)
                }
                return result(for: action)
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_screenshot":
            guard let udid = params.arguments?["udid"]?.stringValue else {
                return errorResult("Missing required udid argument.")
            }
            do {
                return result(
                    for: try SimulatorService.screenshot(
                        udid: udid,
                        path: params.arguments?["path"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_open_url":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let url = params.arguments?["url"]?.stringValue else {
                return errorResult("Missing required udid or url argument.")
            }
            do {
                return result(for: try SimulatorService.openURL(udid: udid, url: url))
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_set_location":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let latitude = doubleValue(from: params.arguments?["latitude"]),
                  let longitude = doubleValue(from: params.arguments?["longitude"]) else {
                return errorResult("Missing required udid, latitude, or longitude argument.")
            }
            do {
                return result(
                    for: try SimulatorService.setLocation(
                        udid: udid,
                        latitude: latitude,
                        longitude: longitude
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_clear_location":
            guard let udid = params.arguments?["udid"]?.stringValue else {
                return errorResult("Missing required udid argument.")
            }
            do {
                return result(for: try SimulatorService.clearLocation(udid: udid))
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_record_video":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required udid or path argument.")
            }
            do {
                return result(
                    for: try SimulatorService.recordVideo(
                        udid: udid,
                        path: path,
                        durationSeconds: intValue(from: params.arguments?["durationSeconds"]) ?? 1,
                        codec: params.arguments?["codec"]?.stringValue ?? "h264",
                        display: params.arguments?["display"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_app_info":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue else {
                return errorResult("Missing required udid or bundleID argument.")
            }
            do {
                return result(for: try SimulatorService.appInfo(udid: udid, bundleID: bundleID))
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_get_app_container":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue else {
                return errorResult("Missing required udid or bundleID argument.")
            }
            do {
                return result(
                    for: try SimulatorService.appContainer(
                        udid: udid,
                        bundleID: bundleID,
                        container: params.arguments?["container"]?.stringValue ?? "app"
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_environment":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let operation = params.arguments?["operation"]?.stringValue else {
                return errorResult("Missing required udid or operation argument.")
            }
            do {
                return result(
                    for: try AppleSimulatorEnvironmentService.perform(
                        udid: udid,
                        operation: operation,
                        bundleID: params.arguments?["bundleID"]?.stringValue,
                        service: params.arguments?["service"]?.stringValue,
                        value: params.arguments?["value"]?.stringValue,
                        payload: params.arguments?["payload"].flatMap(dapValue(from:)),
                        variable: params.arguments?["variable"]?.stringValue,
                        mediaPaths: stringArray(from: params.arguments?["mediaPaths"]),
                        statusOverrides: stringDictionary(from: params.arguments?["statusOverrides"])
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_repro_bundle":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue,
                  let outputDirectory = params.arguments?["outputDirectory"]?.stringValue else {
                return errorResult("Missing required udid, bundleID, or outputDirectory argument.")
            }
            do {
                return result(
                    for: try AppleReproBundleService.capture(
                        udid: udid,
                        bundleID: bundleID,
                        outputDirectory: outputDirectory,
                        includeScreenshot: boolValue(from: params.arguments?["includeScreenshot"], default: true),
                        includeAppInfo: boolValue(from: params.arguments?["includeAppInfo"], default: true),
                        includeLogs: boolValue(from: params.arguments?["includeLogs"], default: true),
                        tracePaths: stringArray(from: params.arguments?["tracePaths"]),
                        crashPath: params.arguments?["crashPath"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_ui_snapshot":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue,
                  let projectPath = params.arguments?["projectPath"]?.stringValue,
                  let scheme = params.arguments?["scheme"]?.stringValue else {
                return errorResult("Missing required udid, bundleID, projectPath, or scheme argument.")
            }
            do {
                return result(
                    for: try SimulatorUIService.snapshot(
                        udid: udid,
                        bundleID: bundleID,
                        projectPath: projectPath,
                        scheme: scheme,
                        configuration: params.arguments?["configuration"]?.stringValue ?? "Debug"
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_ui_action":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue,
                  let projectPath = params.arguments?["projectPath"]?.stringValue,
                  let scheme = params.arguments?["scheme"]?.stringValue,
                  let action = params.arguments?["action"]?.stringValue else {
                return errorResult("Missing required udid, bundleID, projectPath, scheme, or action argument.")
            }
            do {
                return result(
                    for: try SimulatorUIService.performAction(
                        udid: udid,
                        bundleID: bundleID,
                        projectPath: projectPath,
                        scheme: scheme,
                        configuration: params.arguments?["configuration"]?.stringValue ?? "Debug",
                        action: .init(
                            action: action,
                            identifier: params.arguments?["identifier"]?.stringValue,
                            text: params.arguments?["text"]?.stringValue,
                            direction: params.arguments?["direction"]?.stringValue,
                            durationSeconds: doubleValue(from: params.arguments?["durationSeconds"]),
                            scale: doubleValue(from: params.arguments?["scale"]),
                            velocity: doubleValue(from: params.arguments?["velocity"])
                        )
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_ui_probe":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue else {
                return errorResult("Missing required udid or bundleID argument.")
            }
            do {
                return result(
                    for: try SimulatorUIService.installedAppSnapshot(
                        udid: udid,
                        bundleID: bundleID,
                        configuration: params.arguments?["configuration"]?.stringValue ?? "Debug"
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_simulator_ui_probe_action":
            guard let udid = params.arguments?["udid"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue,
                  let action = params.arguments?["action"]?.stringValue else {
                return errorResult("Missing required udid, bundleID, or action argument.")
            }
            do {
                return result(
                    for: try SimulatorUIService.performInstalledAppAction(
                        udid: udid,
                        bundleID: bundleID,
                        configuration: params.arguments?["configuration"]?.stringValue ?? "Debug",
                        action: .init(
                            action: action,
                            identifier: params.arguments?["identifier"]?.stringValue,
                            text: params.arguments?["text"]?.stringValue,
                            direction: params.arguments?["direction"]?.stringValue,
                            durationSeconds: doubleValue(from: params.arguments?["durationSeconds"]),
                            scale: doubleValue(from: params.arguments?["scale"]),
                            velocity: doubleValue(from: params.arguments?["velocity"])
                        )
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_device_list":
            do {
                return result(for: try AppleDeviceService.list())
            } catch {
                return errorResult(error)
            }
        case "apple_device_install":
            guard let identifier = params.arguments?["identifier"]?.stringValue,
                  let appPath = params.arguments?["appPath"]?.stringValue else {
                return errorResult("Missing required identifier or appPath argument.")
            }
            do {
                return result(for: try AppleDeviceService.install(identifier: identifier, appPath: appPath))
            } catch {
                return errorResult(error)
            }
        case "apple_device_launch":
            guard let identifier = params.arguments?["identifier"]?.stringValue,
                  let bundleID = params.arguments?["bundleID"]?.stringValue else {
                return errorResult("Missing required identifier or bundleID argument.")
            }
            do {
                return result(
                    for: try AppleDeviceService.launch(
                        identifier: identifier,
                        bundleID: bundleID,
                        startStopped: boolValue(from: params.arguments?["startStopped"], default: false)
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_xcode_discover":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(for: try XcodeService.discover(path: path))
            } catch {
                return errorResult(error)
            }
        case "apple_xcode_build":
            guard let path = params.arguments?["path"]?.stringValue,
                  let scheme = params.arguments?["scheme"]?.stringValue,
                  let destination = params.arguments?["destination"]?.stringValue else {
                return errorResult("Missing required path, scheme, or destination argument.")
            }
            let configuration = params.arguments?["configuration"]?.stringValue ?? "Debug"
            do {
                return result(
                    for: try XcodeService.build(
                        path: path,
                        scheme: scheme,
                        configuration: configuration,
                        destination: destination,
                        derivedDataPath: params.arguments?["derivedDataPath"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_xcode_test":
            guard let path = params.arguments?["path"]?.stringValue,
                  let scheme = params.arguments?["scheme"]?.stringValue,
                  let destination = params.arguments?["destination"]?.stringValue else {
                return errorResult("Missing required path, scheme, or destination argument.")
            }
            do {
                return result(
                    for: try XcodeService.test(
                        path: path,
                        scheme: scheme,
                        configuration: params.arguments?["configuration"]?.stringValue ?? "Debug",
                        destination: destination,
                        derivedDataPath: params.arguments?["derivedDataPath"]?.stringValue,
                        resultBundlePath: params.arguments?["resultBundlePath"]?.stringValue,
                        codeSigningAllowed: boolValue(
                            from: params.arguments?["codeSigningAllowed"],
                            default: true
                        )
                    )
                )
            } catch {
                return errorResult(error)
            }
        case "apple_symbolicate":
            guard let binaryPath = params.arguments?["binaryPath"]?.stringValue,
                  let architecture = params.arguments?["architecture"]?.stringValue,
                  let address = params.arguments?["address"]?.stringValue else {
                return errorResult("Missing required binaryPath, architecture, or address argument.")
            }
            do {
                return result(
                    for: try SymbolicationService.symbolize(
                        binaryPath: binaryPath,
                        architecture: architecture,
                        address: address,
                        loadAddress: params.arguments?["loadAddress"]?.stringValue
                    )
                )
            } catch {
                return errorResult(error)
            }

        default:
            return .init(
                content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)],
                isError: true
            )
        }
    }

    static func shutdown() async {
        await sessions.closeAll()
    }

    private struct DAPProbeResult: Encodable {
        let response: DAPMessage
        let events: [DAPMessage]
    }

    private struct DebugLaunchResult: Encodable {
        let sessionID: String
        let response: DAPMessage
    }

    private struct SessionCloseResult: Encodable {
        let sessionID: String
        let closed: Bool
    }

    private static let emptyObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([:])
    ])

    private static let pluginListObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "directory": .object([
                "type": .string("string"),
                "description": .string("Absolute directory containing *.appledebugplugin.json manifests")
            ])
        ]),
        "required": .array([.string("directory")])
    ])

    private static let pluginHostPlanObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "executablePath": .object(["type": .string("string")]),
            "manifestPath": .object(["type": .string("string")]),
            "requiredTeamIdentifier": .object(["type": .string("string")])
        ]),
        "required": .array([.string("executablePath")])
    ])

    private static let pathObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute path to an authorized Mach-O file")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    private static let binaryInspectObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute path to an authorized Mach-O binary")
            ]),
            "architecture": .object([
                "type": .string("string"),
                "description": .string("Optional architecture such as arm64e or x86_64")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    private static let assembleObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "architecture": .object([
                "type": .string("string"),
                "enum": .array([.string("arm64"), .string("x86_64")])
            ]),
            "source": .object([
                "type": .string("string"),
                "description": .string("Bounded self-contained Apple assembly source; maximum 64 KiB")
            ])
        ]),
        "required": .array([.string("architecture"), .string("source")])
    ])

    private static let patchPreviewObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object(["type": .string("string")]),
            "architecture": .object([
                "type": .string("string"),
                "enum": .array([.string("arm64"), .string("x86_64")])
            ]),
            "fileOffset": .object(["type": .string("integer")]),
            "source": .object(["type": .string("string")]),
            "expectedData": .object(["type": .string("string"), "description": .string("Optional base64 expected bytes")])
        ]),
        "required": .array([.string("path"), .string("architecture"), .string("source")])
    ])

    private static let resignPlanObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "inputPath": .object(["type": .string("string")]),
            "outputPath": .object(["type": .string("string")]),
            "identity": .object(["type": .string("string")]),
            "entitlementsPath": .object(["type": .string("string")])
        ]),
        "required": .array([.string("inputPath"), .string("outputPath"), .string("identity")])
    ])

    private static let controlFlowObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute Mach-O or app executable path")
            ]),
            "architecture": .object([
                "type": .string("string"),
                "enum": .array([.string("arm64"), .string("arm64e"), .string("x86_64")])
            ])
        ]),
        "required": .array([.string("path"), .string("architecture")])
    ])

    private static let dyldSharedCacheObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute dyld_shared_cache file path")
            ]),
            "imageFilter": .object([
                "type": .string("string"),
                "description": .string("Optional bounded case-insensitive image path filter")
            ]),
            "maximumImages": .object([
                "type": .string("integer"),
                "description": .string("Maximum returned images from 1 to 10000")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    private static let binaryDiffObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "leftPath": .object([
                "type": .string("string"),
                "description": .string("Regular Mach-O path, .app bundle, or .dSYM bundle")
            ]),
            "rightPath": .object([
                "type": .string("string"),
                "description": .string("Regular Mach-O path, .app bundle, or .dSYM bundle")
            ]),
            "architecture": .object([
                "type": .string("string"),
                "description": .string("Optional Mach-O architecture such as arm64 or x86_64")
            ])
        ]),
        "required": .array([.string("leftPath"), .string("rightPath")])
    ])

    private static let dwarfInspectObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Mach-O binary or .dSYM bundle")
            ]),
            "architecture": .object(["type": .string("string")]),
            "name": .object([
                "type": .string("string"),
                "description": .string("Optional exact DW_AT_name query")
            ]),
            "lookupAddress": .object([
                "type": .string("string"),
                "description": .string("Optional hexadecimal address for dwarfdump source lookup")
            ]),
            "depth": .object([
                "type": .string("integer"),
                "description": .string("DWARF child recursion depth from 1 to 8; defaults to 3")
            ]),
            "includeSources": .object(["type": .string("boolean")]),
            "includeStatistics": .object(["type": .string("boolean")]),
            "includeLineTable": .object([
                "type": .string("boolean"),
                "description": .string("Include bounded DWARF line-table address/source rows")
            ]),
            "includeRaw": .object([
                "type": .string("boolean"),
                "description": .string("Include bounded raw debug-info output")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    private static let sessionCreateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "deviceIdentifier": .object([
                "type": .string("string"),
                "description": .string("Optional paired physical-device UUID; requires APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1")
            ])
        ])
    ])

    private static let crashObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Absolute path to an authorized .crash or .ips report")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    private static let crashSymbolicateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "crashPath": .object([
                "type": .string("string"),
                "description": .string("Absolute path to an authorized .crash or .ips report")
            ]),
            "artifacts": .object([
                "type": .string("array"),
                "description": .string("Up to 32 image-to-binary/dSYM mappings"),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "imageName": .object(["type": .string("string")]),
                        "binaryPath": .object(["type": .string("string")]),
                        "architecture": .object(["type": .string("string")]),
                        "loadAddress": .object(["type": .string("string")])
                    ]),
                    "required": .array([
                        .string("binaryPath"),
                        .string("architecture")
                    ])
                ])
            ])
        ]),
        "required": .array([.string("crashPath"), .string("artifacts")])
    ])

    private static let logShowObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "target": .object([
                "type": .string("string"),
                "description": .string("host or an available iOS Simulator UDID")
            ]),
            "last": .object([
                "type": .string("string"),
                "description": .string("Bounded duration such as 30s, 5m, 1h, or 1d")
            ]),
            "predicate": .object(["type": .string("string")])
        ])
    ])

    private static let sessionObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object([
                "type": .string("string"),
                "description": .string("Active Apple Debug MCP session identifier")
            ])
        ]),
        "required": .array([.string("sessionID")])
    ])

    private static let launchObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "program": .object(["type": .string("string")]),
            "args": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ]),
            "stopOnEntry": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("sessionID"), .string("program")])
    ])

    private static let attachObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "processID": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("processID")])
    ])

    private static let processObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "processID": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("processID")])
    ])

    private static let runtimeDiagnosticObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "processID": .object(["type": .string("integer")]),
            "tool": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("heap"), .string("leaks"), .string("malloc_history"), .string("sample")
                ])
            ]),
            "mode": .object([
                "type": .string("string"),
                "description": .string("heap: summary/addresses/layouts/zones; leaks: summary/list/fullStacks; malloc_history: callTree/allBySize/allByCount/allEvents; sample: sample")
            ]),
            "pattern": .object([
                "type": .string("string"),
                "description": .string("Optional bounded class/symbol pattern for heap or malloc_history")
            ]),
            "durationSeconds": .object([
                "type": .string("integer"),
                "description": .string("sample duration from 1 to 30 seconds; defaults to 5")
            ]),
            "sampleIntervalMilliseconds": .object([
                "type": .string("integer"),
                "description": .string("sample interval from 1 to 1000 milliseconds; defaults to 10")
            ])
        ]),
        "required": .array([.string("processID"), .string("tool")])
    ])

    private static let memorySnapshotObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "processID": .object(["type": .string("integer")]),
            "outputPath": .object([
                "type": .string("string"),
                "description": .string("Absolute non-existing .json snapshot path")
            ]),
            "includeRawOutput": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("processID"), .string("outputPath")])
    ])

    private static let memoryDiffObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "leftPath": .object(["type": .string("string")]),
            "rightPath": .object(["type": .string("string")])
        ]),
        "required": .array([.string("leftPath"), .string("rightPath")])
    ])

    private static let performanceRecordObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "processID": .object(["type": .string("integer")]),
            "simulatorUDID": .object(["type": .string("string")]),
            "template": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("Time Profiler"),
                    .string("Allocations"),
                    .string("System Trace"),
                    .string("Power Profiler"),
                    .string("Animation Hitches"),
                    .string("Swift Concurrency"),
                    .string("Processor Trace"),
                    .string("CPU Profiler"),
                    .string("Leaks"),
                    .string("Network"),
                    .string("File Activity"),
                    .string("Game Performance")
                ])
            ]),
            "durationSeconds": .object([
                "type": .string("integer"),
                "description": .string("Recording duration from 1 to 60 seconds; defaults to 5")
            ]),
            "outputPath": .object([
                "type": .string("string"),
                "description": .string("Absolute non-existing .trace output path")
            ])
        ]),
        "required": .array([.string("outputPath")])
    ])

    private static let performanceAnalyzeObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "tracePath": .object([
                "type": .string("string"),
                "description": .string("Absolute existing .trace bundle produced by apple_performance_record")
            ]),
            "schema": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("time-profile"), .string("time-sample"), .string("allocations"),
                    .string("allocation"), .string("os-signpost"), .string("os-log"),
                    .string("animation-hitch"), .string("animation-hitches"), .string("power"),
                    .string("energy"), .string("core-animation"), .string("swift-concurrency"),
                    .string("thread-info"), .string("process-info"), .string("signpost")
                ])
            ]),
            "maximumRows": .object([
                "type": .string("integer"),
                "description": .string("Maximum exported rows from 1 to 5000; defaults to 5000")
            ]),
            "includeRows": .object([
                "type": .string("boolean"),
                "description": .string("Include parsed rows in addition to hotspots and folded flame stacks")
            ])
        ]),
        "required": .array([.string("tracePath")])
    ])

    private static let breakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "file": .object(["type": .string("string")]),
            "line": .object(["type": .string("integer")]),
            "condition": .object(["type": .string("string")]),
            "hitCondition": .object(["type": .string("string")]),
            "logMessage": .object(["type": .string("string")])
        ]),
        "required": .array([.string("sessionID"), .string("file"), .string("line")])
    ])

    private static let breakpointLocationsObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "file": .object(["type": .string("string")]),
            "line": .object(["type": .string("integer")]),
            "column": .object(["type": .string("integer")]),
            "endLine": .object(["type": .string("integer")]),
            "endColumn": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("file"), .string("line")])
    ])

    private static let instructionBreakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "instructionReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "condition": .object(["type": .string("string")]),
            "hitCondition": .object(["type": .string("string")]),
            "logMessage": .object(["type": .string("string")])
        ]),
        "required": .array([.string("sessionID"), .string("instructionReference")])
    ])

    private static let functionBreakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "name": .object(["type": .string("string")]),
            "condition": .object(["type": .string("string")]),
            "hitCondition": .object(["type": .string("string")])
        ]),
        "required": .array([.string("sessionID"), .string("name")])
    ])

    private static let exceptionBreakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "filters": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ]),
            "filterOptions": .object([
                "type": .string("array"),
                "items": .object([
                    "type": .string("object"),
                    "properties": .object([
                        "filter": .object(["type": .string("string")]),
                        "condition": .object(["type": .string("string")])
                    ]),
                    "required": .array([.string("filter")])
                ])
            ])
        ]),
        "required": .array([.string("sessionID"), .string("filters")])
    ])

    private static let threadObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("threadID")])
    ])

    private static let stepObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")]),
            "kind": .object([
                "type": .string("string"),
                "enum": .array([.string("stepIn"), .string("next"), .string("stepOut")])
            ]),
            "granularity": .object([
                "type": .string("string"),
                "enum": .array([.string("statement"), .string("line"), .string("instruction")])
            ])
        ]),
        "required": .array([.string("sessionID"), .string("threadID"), .string("kind")])
    ])

    private static let forwardTraceObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")]),
            "steps": .object([
                "type": .string("integer"),
                "description": .string("Number of forward steps from 1 to 100")
            ]),
            "kind": .object([
                "type": .string("string"),
                "enum": .array([.string("stepIn"), .string("next"), .string("stepOut")])
            ]),
            "granularity": .object([
                "type": .string("string"),
                "enum": .array([.string("statement"), .string("line"), .string("instruction")])
            ]),
            "timeoutMilliseconds": .object([
                "type": .string("integer"),
                "description": .string("Per-step stop timeout up to 120000 milliseconds")
            ])
        ]),
        "required": .array([
            .string("sessionID"), .string("threadID"), .string("steps"), .string("kind")
        ])
    ])

    private static let frameObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "frameID": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("frameID")])
    ])

    private static let variablesObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "variablesReference": .object(["type": .string("integer")]),
            "start": .object(["type": .string("integer")]),
            "count": .object(["type": .string("integer")]),
            "formatHex": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("sessionID"), .string("variablesReference")])
    ])

    private static let completionsObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "frameID": .object(["type": .string("integer")]),
            "text": .object(["type": .string("string")]),
            "column": .object(["type": .string("integer")]),
            "line": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("text"), .string("column")])
    ])

    private static let setVariableObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "variablesReference": .object(["type": .string("integer")]),
            "name": .object(["type": .string("string")]),
            "value": .object(["type": .string("string")])
        ]),
        "required": .array([
            .string("sessionID"),
            .string("variablesReference"),
            .string("name"),
            .string("value")
        ])
    ])

    private static let moduleObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "startModule": .object(["type": .string("integer")]),
            "moduleCount": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID")])
    ])

    private static let stopSnapshotObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")]),
            "levels": .object([
                "type": .string("integer"),
                "description": .string("Maximum stack depth; defaults to 20")
            ])
        ]),
        "required": .array([.string("sessionID")])
    ])

    private static let waitForStopObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "timeoutMilliseconds": .object([
                "type": .string("integer"),
                "description": .string("Positive timeout in milliseconds; maximum 120000; defaults to 10000")
            ])
        ]),
        "required": .array([.string("sessionID")])
    ])

    private static let evaluateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "expression": .object(["type": .string("string")]),
            "frameID": .object(["type": .string("integer")]),
            "context": .object(["type": .string("string")])
        ]),
        "required": .array([.string("sessionID"), .string("expression")])
    ])

    private static let dataBreakpointInfoObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "variablesReference": .object(["type": .string("integer")]),
            "name": .object(["type": .string("string")])
        ]),
        "required": .array([.string("sessionID"), .string("variablesReference"), .string("name")])
    ])

    private static let dataBreakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "dataID": .object(["type": .string("string")]),
            "accessType": .object([
                "type": .string("string"),
                "enum": .array([.string("read"), .string("write"), .string("readWrite")])
            ])
        ]),
        "required": .array([.string("sessionID"), .string("dataID")])
    ])

    private static let writeMemoryObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "data": .object([
                "type": .string("string"),
                "description": .string("Base64-encoded bytes; maximum 4096 bytes")
            ])
        ]),
        "required": .array([.string("sessionID"), .string("memoryReference"), .string("data")])
    ])

    private static let searchMemoryObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "count": .object(["type": .string("integer")]),
            "pattern": .object([
                "type": .string("string"),
                "description": .string("Base64-encoded byte pattern")
            ])
        ]),
        "required": .array([
            .string("sessionID"),
            .string("memoryReference"),
            .string("count"),
            .string("pattern")
        ])
    ])

    private static let patchMemoryObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "expectedData": .object([
                "type": .string("string"),
                "description": .string("Optional base64 bytes that must match before writing")
            ]),
            "data": .object([
                "type": .string("string"),
                "description": .string("Base64 bytes to write; maximum 4096 bytes")
            ])
        ]),
        "required": .array([
            .string("sessionID"),
            .string("memoryReference"),
            .string("data")
        ])
    ])

    private static let patchAssemblyObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "architecture": .object([
                "type": .string("string"),
                "enum": .array([.string("arm64"), .string("x86_64")])
            ]),
            "source": .object([
                "type": .string("string"),
                "description": .string("Bounded self-contained Apple assembly source; emitted code is limited to 4096 bytes")
            ]),
            "expectedData": .object([
                "type": .string("string"),
                "description": .string("Optional base64 bytes required at the target before patching")
            ])
        ]),
        "required": .array([
            .string("sessionID"), .string("memoryReference"),
            .string("architecture"), .string("source")
        ])
    ])

    private static let terminateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "terminateDebuggee": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("sessionID")])
    ])

    private static let stackTraceObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")]),
            "levels": .object(["type": .string("integer")]),
            "startFrame": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("threadID")])
    ])

    private static let memoryObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "offset": .object(["type": .string("integer")]),
            "count": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("memoryReference"), .string("count")])
    ])

    private static let disassembleObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "memoryReference": .object(["type": .string("string")]),
            "instructionOffset": .object(["type": .string("integer")]),
            "instructionCount": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("memoryReference"), .string("instructionCount")])
    ])

    private static let simulatorObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid")])
    ])

    private static let simulatorInstallObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "appPath": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("appPath")])
    ])

    private static let simulatorLaunchObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "arguments": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")])
            ]),
            "terminateRunning": .object(["type": .string("boolean")]),
            "waitForDebugger": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("udid"), .string("bundleID")])
    ])

    private static let simulatorScreenshotObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "path": .object([
                "type": .string("string"),
                "description": .string("Optional absolute PNG output path; defaults to a temporary file")
            ])
        ]),
        "required": .array([.string("udid")])
    ])

    private static let simulatorURLObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "url": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("url")])
    ])

    private static let simulatorLocationObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "latitude": .object(["type": .string("number")]),
            "longitude": .object(["type": .string("number")])
        ]),
        "required": .array([.string("udid"), .string("latitude"), .string("longitude")])
    ])

    private static let simulatorRecordVideoObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "path": .object(["type": .string("string")]),
            "durationSeconds": .object([
                "type": .string("integer"),
                "description": .string("Recording duration from 1 to 60 seconds; defaults to 1")
            ]),
            "codec": .object([
                "type": .string("string"),
                "enum": .array([.string("h264"), .string("hevc")])
            ]),
            "display": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("path")])
    ])

    private static let simulatorAppInfoObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("bundleID")])
    ])

    private static let simulatorContainerObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "container": .object([
                "type": .string("string"),
                "description": .string("app, data, groups, or a specific app-group identifier")
            ])
        ]),
        "required": .array([.string("udid"), .string("bundleID")])
    ])

    private static let simulatorEnvironmentObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "operation": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("status_bar_list"), .string("status_bar_override"), .string("status_bar_clear"),
                    .string("ui_get"), .string("ui_set"), .string("privacy"), .string("push"),
                    .string("pasteboard_get"), .string("pasteboard_set"), .string("keychain_reset"),
                    .string("getenv"), .string("list_apps"), .string("add_media")
                ])
            ]),
            "bundleID": .object(["type": .string("string")]),
            "service": .object(["type": .string("string")]),
            "value": .object(["type": .string("string")]),
            "variable": .object(["type": .string("string")]),
            "payload": .object(["type": .string("object")]),
            "mediaPaths": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
            "statusOverrides": .object([
                "type": .string("object"),
                "description": .string("Fixed status-bar override keys: time, dataNetwork, wifiMode, wifiBars, cellularMode, cellularBars, operatorName, batteryState, batteryLevel")
            ])
        ]),
        "required": .array([.string("udid"), .string("operation")])
    ])

    private static let simulatorReproBundleObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "outputDirectory": .object([
                "type": .string("string"),
                "description": .string("Absolute non-existing output directory")
            ]),
            "includeScreenshot": .object(["type": .string("boolean")]),
            "includeAppInfo": .object(["type": .string("boolean")]),
            "includeLogs": .object(["type": .string("boolean")]),
            "tracePaths": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
            "crashPath": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("bundleID"), .string("outputDirectory")])
    ])

    private static let simulatorUISnapshotObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "projectPath": .object([
                "type": .string("string"),
                "description": .string("Path to an Xcode project or workspace with a UI-test-enabled scheme")
            ]),
            "scheme": .object(["type": .string("string")]),
            "configuration": .object(["type": .string("string")])
        ]),
        "required": .array([
            .string("udid"),
            .string("bundleID"),
            .string("projectPath"),
            .string("scheme")
        ])
    ])

    private static let simulatorUIActionObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "projectPath": .object(["type": .string("string")]),
            "scheme": .object(["type": .string("string")]),
            "configuration": .object(["type": .string("string")]),
            "action": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("tap"),
                    .string("doubleTap"),
                    .string("longPress"),
                    .string("typeText"),
                    .string("swipe"),
                    .string("pinch"),
                    .string("wait")
                ])
            ]),
            "identifier": .object(["type": .string("string")]),
            "text": .object(["type": .string("string")]),
            "durationSeconds": .object(["type": .string("number")]),
            "scale": .object(["type": .string("number")]),
            "velocity": .object(["type": .string("number")]),
            "direction": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("up"),
                    .string("down"),
                    .string("left"),
                    .string("right")
                ])
            ])
        ]),
        "required": .array([
            .string("udid"),
            .string("bundleID"),
            .string("projectPath"),
            .string("scheme"),
            .string("action")
        ])
    ])

    private static let simulatorUIProbeObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object([
                "type": .string("string"),
                "description": .string("Bundle identifier of an application already installed in the selected Simulator")
            ]),
            "configuration": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("bundleID")])
    ])

    private static let simulatorUIProbeActionObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "udid": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "configuration": .object(["type": .string("string")]),
            "action": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("tap"), .string("doubleTap"), .string("longPress"),
                    .string("typeText"), .string("swipe"), .string("pinch"), .string("wait")
                ])
            ]),
            "identifier": .object(["type": .string("string")]),
            "text": .object(["type": .string("string")]),
            "durationSeconds": .object(["type": .string("number")]),
            "scale": .object(["type": .string("number")]),
            "velocity": .object(["type": .string("number")]),
            "direction": .object([
                "type": .string("string"),
                "enum": .array([.string("up"), .string("down"), .string("left"), .string("right")])
            ])
        ]),
        "required": .array([.string("udid"), .string("bundleID"), .string("action")])
    ])

    private static let deviceInstallObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "identifier": .object(["type": .string("string")]),
            "appPath": .object(["type": .string("string")])
        ]),
        "required": .array([.string("identifier"), .string("appPath")])
    ])

    private static let deviceLaunchObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "identifier": .object(["type": .string("string")]),
            "bundleID": .object(["type": .string("string")]),
            "startStopped": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("identifier"), .string("bundleID")])
    ])

    private static let xcodeDiscoverObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object([
                "type": .string("string"),
                "description": .string("Path to an .xcodeproj or .xcworkspace")
            ])
        ]),
        "required": .array([.string("path")])
    ])

    private static let xcodeBuildObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object(["type": .string("string")]),
            "scheme": .object(["type": .string("string")]),
            "configuration": .object(["type": .string("string")]),
            "destination": .object(["type": .string("string")]),
            "derivedDataPath": .object([
                "type": .string("string"),
                "description": .string("Optional absolute derived-data directory; build results include discovered app and dSYM artifacts")
            ])
        ]),
        "required": .array([.string("path"), .string("scheme"), .string("destination")])
    ])

    private static let xcodeTestObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "path": .object(["type": .string("string")]),
            "scheme": .object(["type": .string("string")]),
            "configuration": .object(["type": .string("string")]),
            "destination": .object(["type": .string("string")]),
            "derivedDataPath": .object(["type": .string("string")]),
            "resultBundlePath": .object([
                "type": .string("string"),
                "description": .string("Optional absolute xcresult output path")
            ]),
            "codeSigningAllowed": .object(["type": .string("boolean")])
        ]),
        "required": .array([.string("path"), .string("scheme"), .string("destination")])
    ])

    private static let symbolicateObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "binaryPath": .object(["type": .string("string")]),
            "architecture": .object(["type": .string("string")]),
            "address": .object(["type": .string("string")]),
            "loadAddress": .object(["type": .string("string")])
        ]),
        "required": .array([.string("binaryPath"), .string("architecture"), .string("address")])
    ])

    private static func errorResult(_ error: Error) -> CallTool.Result {
        errorResult(error.localizedDescription)
    }

    private static func errorResult(_ message: String) -> CallTool.Result {
        .init(
            content: [.text(text: message, annotations: nil, _meta: nil)],
            isError: true
        )
    }

    private static func stringArray(from value: Value?) -> [String] {
        value?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    private static func stringDictionary(from value: Value?) -> [String: String] {
        guard let object = value?.objectValue else { return [:] }
        return object.compactMapValues(\.stringValue)
    }

    private static func crashArtifacts(from value: Value?) -> [CrashSymbolicationArtifact]? {
        guard let values = value?.arrayValue, !values.isEmpty, values.count <= 32 else {
            return nil
        }
        var artifacts: [CrashSymbolicationArtifact] = []
        for value in values {
            guard let object = value.objectValue,
                  let binaryPath = object["binaryPath"]?.stringValue,
                  let architecture = object["architecture"]?.stringValue,
                  !binaryPath.isEmpty,
                  !architecture.isEmpty else {
                return nil
            }
            artifacts.append(
                CrashSymbolicationArtifact(
                    imageName: object["imageName"]?.stringValue,
                    binaryPath: binaryPath,
                    architecture: architecture,
                    loadAddress: object["loadAddress"]?.stringValue
                )
            )
        }
        return artifacts
    }

    private static func dapValueArray(from value: Value) -> [DAPValue]? {
        guard let values = value.arrayValue else { return nil }
        let converted = values.compactMap(dapValue(from:))
        return converted.count == values.count ? converted : nil
    }

    private static func dapValue(from value: Value) -> DAPValue? {
        switch value {
        case .null:
            return .null
        case .bool(let value):
            return .boolean(value)
        case .int(let value):
            return .integer(value)
        case .double(let value):
            return .double(value)
        case .string(let value):
            return .string(value)
        case .data(_, let data):
            return .string(data.base64EncodedString())
        case .array(let values):
            return .array(values.compactMap(dapValue(from:)))
        case .object(let object):
            return .object(object.compactMapValues(dapValue(from:)))
        }
    }

    private static func boolValue(from value: Value?, default defaultValue: Bool) -> Bool {
        value?.boolValue ?? defaultValue
    }

    private static func intValue(from value: Value?) -> Int? {
        value?.intValue
    }

    private static func doubleValue(from value: Value?) -> Double? {
        value?.doubleValue ?? value?.intValue.map(Double.init)
    }

    private static func result<T: Encodable>(for value: T) -> CallTool.Result {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        do {
            let data = try encoder.encode(value)
            let text = String(decoding: data, as: UTF8.self)
            return .init(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
        } catch {
            return .init(
                content: [.text(text: "Failed to encode result: \(error.localizedDescription)", annotations: nil, _meta: nil)],
                isError: true
            )
        }
    }
}
