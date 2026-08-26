// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import AppleDebugCore
import MCP

extension ToolCatalog {
    static func call(
        _ params: CallTool.Parameters,
        context: Context
    ) async -> CallTool.Result {
        if let result = await dispatchFoundation(params, context: context) { return result }
        if let result = await dispatchArtifacts(params, context: context) { return result }
        if let result = await dispatchDebugger(params, context: context) { return result }
        if let result = await dispatchPerformance(params, context: context) { return result }
        if let result = await dispatchSimulator(params, context: context) { return result }
        if let result = await dispatchDevice(params, context: context) { return result }
        if let result = await dispatchXcode(params, context: context) { return result }
        return .init(
            content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)],
            isError: true
        )
    }
}
