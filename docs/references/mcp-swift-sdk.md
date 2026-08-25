# MCP Swift SDK Reference

The server uses the official modelcontextprotocol/swift-sdk package.

## Contract used by this repository

- Package product: MCP
- Minimum declared package requirement: 0.11.0; current resolved SDK: 0.12.1
- Transports: StdioTransport for client-spawned sessions and StatefulHTTPServerTransport for the supervised authenticated loopback daemon
- Server types: Server, ListTools, CallTool, Tool, and Value
- Current server protocol surface: apple_capabilities and apple_toolchain_status

The SDK owns JSON-RPC/MCP framing and Streamable HTTP/SSE session behavior. Apple Debug MCP owns the bounded NIO HTTP adapter, loopback/token policy, tool policy, platform capabilities, and backend behavior. Recheck the upstream server and transport API before changing the dependency range.
