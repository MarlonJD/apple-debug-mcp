// Apple Debug MCP
// Copyright (C) 2026 Burak Karahan
// SPDX-License-Identifier: GPL-3.0-or-later

import MCP

@main
struct AppleDebugMCPMain {
    static func main() async throws {
        if CommandLine.arguments.contains("--daemon") {
            try await AppleDebugMCPDaemon.run()
            return
        }

        try await runStdio()
    }

    private static func runStdio() async throws {
        let server = await AppleDebugMCPServerFactory.makeServer()
        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
        await ToolCatalog.shutdown()
    }
}

enum AppleDebugMCPServerFactory {
    static func makeServer() async -> Server {
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
            await ToolCatalog.call(params)
        }

        return server
    }
}
