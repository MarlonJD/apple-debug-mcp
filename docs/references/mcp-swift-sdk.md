# MCP Swift SDK Reference

The server uses the official modelcontextprotocol/swift-sdk package.

## Contract used by this repository

- Package product: MCP
- `Package.swift` declares a minimum package requirement of 0.11.0; `Package.resolved` currently pins SDK 0.12.1. The repository verifies the locked 0.12.1 graph and does not claim an independently tested 0.11.0 build.
- Transports: StdioTransport for client-spawned sessions and StatefulHTTPServerTransport for the supervised authenticated loopback daemon
- Server types: Server, ListTools, CallTool, Tool, and Value
- Current server protocol surface: the registered MCP tool catalog, currently 111 tools; `ToolCatalogTests` checks that every registered tool reaches a handled dispatch branch and exposes a valid schema.

The SDK owns JSON-RPC/MCP framing and Streamable HTTP/SSE session behavior. Apple Debug MCP owns the bounded NIO HTTP adapter, loopback/token policy, tool policy, platform capabilities, and backend behavior. Recheck the upstream server and transport API before changing the dependency range.
