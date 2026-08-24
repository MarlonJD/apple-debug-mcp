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
            name: "apple_macho_inspect",
            description: "Inspect a Mach-O or universal Mach-O file and return architectures, header metadata, load-command count, and segments without executing it.",
            inputSchema: pathObjectSchema
        ),
        Tool(
            name: "apple_crash_inspect",
            description: "Parse an Apple .crash or .ips report into process, exception, thread, and image metadata without executing it.",
            inputSchema: crashObjectSchema
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
            name: "apple_debug_registers",
            description: "Read the register scope and register variables for a stopped stack frame.",
            inputSchema: frameObjectSchema
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
        case "apple_crash_inspect":
            guard let path = params.arguments?["path"]?.stringValue else {
                return errorResult("Missing required path argument.")
            }
            do {
                return result(for: try CrashReportAnalyzer.inspect(path: path))
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
            do {
                return result(
                    for: try await sessions.setExceptionBreakpoints(
                        sessionID: sessionID,
                        filters: stringArray(from: params.arguments?["filters"])
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
                return result(for: try await sessions.stackTrace(sessionID: sessionID, threadID: threadID, levels: levels))
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
                return result(for: try await sessions.step(sessionID: sessionID, threadID: threadID, kind: stepKind))
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
                return result(for: try await sessions.variables(sessionID: sessionID, variablesReference: variablesReference))
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
                            direction: params.arguments?["direction"]?.stringValue
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
                        destination: destination
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
            ])
        ]),
        "required": .array([.string("sessionID"), .string("threadID"), .string("kind")])
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
            "variablesReference": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("variablesReference")])
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
            "levels": .object(["type": .string("integer")])
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
                    .string("typeText"),
                    .string("swipe"),
                    .string("wait")
                ])
            ]),
            "identifier": .object(["type": .string("string")]),
            "text": .object(["type": .string("string")]),
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
            "destination": .object(["type": .string("string")])
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

    private static func boolValue(from value: Value?, default defaultValue: Bool) -> Bool {
        value?.boolValue ?? defaultValue
    }

    private static func intValue(from value: Value?) -> Int? {
        value?.intValue
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
