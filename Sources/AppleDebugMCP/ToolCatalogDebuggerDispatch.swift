// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import Foundation
import MCP

extension ToolCatalog {
    static func dispatchDebugger(
        _ params: CallTool.Parameters,
        context: Context
    ) async -> CallTool.Result? {
        let sessions = context.sessions
        switch params.name {
        case "apple_debug_session_create":
            do {
                return result(
                    for: try await sessions.create(
                        deviceIdentifier: params.arguments?["deviceIdentifier"]?.stringValue,
                        appPath: params.arguments?["appPath"]?.stringValue
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
        default:
            return nil
        }
    }
}
