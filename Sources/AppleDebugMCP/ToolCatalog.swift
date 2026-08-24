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

        default:
            return .init(
                content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)],
                isError: true
            )
        }
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
