# Core Engineering Beliefs

| Belief | Why it matters here | Observable implication | Mechanical support |
| --- | --- | --- | --- |
| Start read-only, then add control | Debugger operations can terminate or mutate a target | Discovery tools work before process-control tools exist | Current tool catalog excludes process control |
| Advertise restrictions as data | macOS, Simulator, and physical iOS have different authority boundaries | Clients can inspect supported and restricted capabilities | CapabilityMatrix and tests |
| Prefer upstream protocol implementations | MCP framing and LLDB transport are complex and compatibility-sensitive | The project depends on the official Swift MCP SDK and will prefer DAP/libLLDB adapters | Package.swift and architecture review |
| Make every external process invocation explicit | Arbitrary shell execution would widen the attack surface | Toolchain discovery uses fixed paths and arguments | ToolchainProbe |
| Prove behavior with fixtures | A compiling debugger adapter can still fail at runtime | MCP smoke and platform fixtures are required for each backend | scripts/smoke_mcp.sh and roadmap |

## Revision rule

Change a belief only when architecture evidence, a security finding, a runtime failure, or repeated review friction demonstrates that the current rule is insufficient. Record the rationale in the active ExecPlan.
