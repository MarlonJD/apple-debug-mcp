// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import MCP

@main
struct AppleDebugMCPMain {
    static func main() async throws {
        let server = Server(
            name: "apple-debug-mcp",
            version: "0.1.0",
            capabilities: .init(
                logging: .init(),
                tools: .init(listChanged: false)
            )
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: ToolCatalog.tools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            ToolCatalog.call(params)
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
