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
            name: "apple_debug_session_create",
            description: "Create and initialize an authorized local LLDB-DAP debug session without launching a target.",
            inputSchema: emptyObjectSchema
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
            name: "apple_debug_set_breakpoint",
            description: "Set a source-line breakpoint in an active debug session.",
            inputSchema: breakpointObjectSchema
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
            description: "Launch an installed app on an iOS Simulator. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorLaunchObjectSchema
        ),
        Tool(
            name: "apple_simulator_terminate",
            description: "Terminate an app on an iOS Simulator. Disabled unless APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1.",
            inputSchema: simulatorLaunchObjectSchema
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
        case "apple_debug_session_create":
            do {
                return result(for: try await sessions.create())
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
        case "apple_debug_set_breakpoint":
            guard let sessionID = params.arguments?["sessionID"]?.stringValue,
                  let file = params.arguments?["file"]?.stringValue,
                  let line = intValue(from: params.arguments?["line"]) else {
                return errorResult("Missing required sessionID, file, or line argument.")
            }
            do {
                return result(for: try await sessions.setBreakpoint(sessionID: sessionID, file: file, line: line))
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
                let action = params.name == "apple_simulator_launch"
                    ? try SimulatorService.launch(udid: udid, bundleID: bundleID)
                    : try SimulatorService.terminate(udid: udid, bundleID: bundleID)
                return result(for: action)
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

    private static let breakpointObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "file": .object(["type": .string("string")]),
            "line": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("file"), .string("line")])
    ])

    private static let threadObjectSchema: Value = .object([
        "type": .string("object"),
        "properties": .object([
            "sessionID": .object(["type": .string("string")]),
            "threadID": .object(["type": .string("integer")])
        ]),
        "required": .array([.string("sessionID"), .string("threadID")])
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
            "bundleID": .object(["type": .string("string")])
        ]),
        "required": .array([.string("udid"), .string("bundleID")])
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
        guard let value,
              let data = try? JSONEncoder().encode(value),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return array
    }

    private static func boolValue(from value: Value?, default defaultValue: Bool) -> Bool {
        guard let value,
              let data = try? JSONEncoder().encode(value),
              let boolean = try? JSONSerialization.jsonObject(with: data) as? Bool else {
            return defaultValue
        }
        return boolean
    }

    private static func intValue(from value: Value?) -> Int? {
        guard let value,
              let data = try? JSONEncoder().encode(value),
              let number = try? JSONSerialization.jsonObject(with: data) as? NSNumber else {
            return nil
        }
        return number.intValue
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
