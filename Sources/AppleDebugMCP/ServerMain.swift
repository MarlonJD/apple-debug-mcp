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
        let context = ToolCatalog.makeContext()
        let server = await AppleDebugMCPServerFactory.makeServer(context: context)
        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
        await context.shutdown()
    }
}

enum AppleDebugMCPServerFactory {
    static let serverInstructions = """
    Use this MCP for authorized Apple targets when you need LLDB-DAP runtime state/control, artifact analysis, profiling, Simulator/device lifecycle, or reproducible evidence. Prefer Build for iOS/macOS for project creation, build/run/test, UI work, and ordinary Simulator interaction. Start with apple_capabilities and apple_toolchain_status; inspect read-only first. Mutation and plugin actions require explicit grants. Never bypass Apple security or use unsupported reverse/kernel debugging.
    """

    static func makeServer(context: ToolCatalog.Context) async -> Server {
        let server = Server(
            name: "apple-debug-mcp",
            version: "0.1.0",
            instructions: serverInstructions,
            capabilities: .init(
                logging: .init(),
                tools: .init(listChanged: false)
            )
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: ToolCatalog.tools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            await ToolCatalog.call(params, context: context)
        }

        return server
    }
}
