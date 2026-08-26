// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import MCP
import XCTest
@testable import AppleDebugMCP

final class ToolCatalogTests: XCTestCase {
    func testToolNamesAreUniqueAndSchemasAreObjects() {
        let tools = ToolCatalog.tools
        let names = tools.map(\.name)

        XCTAssertFalse(tools.isEmpty)
        XCTAssertEqual(Set(names).count, names.count)

        for tool in tools {
            guard case .object(let schema) = tool.inputSchema else {
                XCTFail("Tool \(tool.name) does not expose an object input schema")
                continue
            }
            guard case .string("object") = schema["type"] else {
                XCTFail("Tool \(tool.name) does not declare schema type object")
                continue
            }

            guard case .array(let requiredValues)? = schema["required"] else { continue }
            let requiredNames = requiredValues.compactMap(\.stringValue)
            guard case .object(let properties)? = schema["properties"] else {
                XCTFail("Tool \(tool.name) declares required fields without properties")
                continue
            }
            for requiredName in requiredNames {
                XCTAssertNotNil(properties[requiredName], "Tool \(tool.name) requires an undeclared field \(requiredName)")
            }
        }
    }

    func testEveryRegisteredToolReachesAHandledDispatchBranch() async {
        let context = ToolCatalog.makeContext()

        for tool in ToolCatalog.tools {
            let result = await ToolCatalog.call(
                CallTool.Parameters(name: tool.name, arguments: [:]),
                context: context
            )
            let textResults = result.content.compactMap { content -> String? in
                guard case .text(let text, _, _) = content else { return nil }
                return text
            }
            XCTAssertFalse(
                textResults.contains("Unknown tool: \(tool.name)"),
                "Registered tool \(tool.name) is missing a dispatch branch"
            )
            XCTAssertTrue(
                !result.content.isEmpty || result.structuredContent != nil,
                "Registered tool \(tool.name) returned no MCP result content"
            )
        }

        await context.shutdown()
    }

    func testDomainContractsReturnStructuredSuccessAndErrors() async {
        let context = ToolCatalog.makeContext()

        let successCases: [(String, [String: Value])] = [
            ("apple_capabilities", [:]),
            ("apple_macho_inspect", ["path": .string("/bin/echo")])
        ]
        for (name, arguments) in successCases {
            let result = await ToolCatalog.call(
                CallTool.Parameters(name: name, arguments: arguments),
                context: context
            )
            XCTAssertEqual(result.isError, false, "Expected (name) to return a success result")
            XCTAssertFalse(result.content.isEmpty, "Expected (name) to return content")
        }

        let errorCases: [(String, [String: Value])] = [
            ("apple_plugin_list", ["directory": .string("/tmp/apple-debug-mcp-missing-plugin-directory")]),
            ("apple_debug_launch", ["sessionID": .string("missing"), "program": .string("/bin/echo")]),
            ("apple_performance_analyze", ["tracePath": .string("/tmp/apple-debug-mcp-missing.trace")]),
            ("apple_simulator_boot", ["udid": .string("not-a-simulator-udid")]),
            ("apple_device_terminate", ["identifier": .string("not-a-device")]),
            ("apple_xcode_discover", ["path": .string("/bin/echo")])
        ]
        for (name, arguments) in errorCases {
            let result = await ToolCatalog.call(
                CallTool.Parameters(name: name, arguments: arguments),
                context: context
            )
            XCTAssertEqual(result.isError, true, "Expected (name) to return a structured error")
            XCTAssertFalse(result.content.isEmpty, "Expected (name) to describe its error")
        }

        await context.shutdown()
    }

    func testUnknownToolFailsClosed() async {
        let context = ToolCatalog.makeContext()
        let result = await ToolCatalog.call(
            CallTool.Parameters(name: "apple_debug_unknown_test_tool"),
            context: context
        )

        XCTAssertEqual(result.isError, true)
    }

    func testPolicyBoundToolRejectsMissingArguments() async {
        let context = ToolCatalog.makeContext()
        let result = await ToolCatalog.call(
            CallTool.Parameters(name: "apple_debug_evaluate"),
            context: context
        )

        XCTAssertEqual(result.isError, true)
    }

    func testContextsOwnIndependentDebuggerManagers() {
        let first = ToolCatalog.makeContext()
        let second = ToolCatalog.makeContext()

        XCTAssertNotEqual(ObjectIdentifier(first.sessions), ObjectIdentifier(second.sessions))
    }

    func testContextShutdownClosesOwnedDebuggerSessions() async throws {
        let context = ToolCatalog.makeContext()
        let summary = try await context.sessions.create()

        let activeSessionIDs = (await context.sessions.list()).map(\.sessionID)
        XCTAssertEqual(activeSessionIDs, [summary.sessionID])
        await context.shutdown()
        let remainingSessions = await context.sessions.list()
        XCTAssertTrue(remainingSessions.isEmpty)
    }
}
