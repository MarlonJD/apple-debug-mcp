# Agent Environment Contract

## Isolation model

| Concern | Contract | Evidence |
| --- | --- | --- |
| Workspace isolation | One local checkout at a time unless separate Git worktrees are explicitly used | Current task uses /Users/marlonjd/Developer/monorepos/apple-debug-mcp |
| Dependency/cache isolation | SwiftPM uses repository-local .build; parallel work should use separate worktrees | swift build creates .build without external project state |
| Port/process allocation | Foundation uses stdio and no listener or persistent process | MCP smoke closes stdin and observes process exit |
| Data/state isolation | No database, device data, or persistent fixture state in the foundation | Current tools are read-only discovery |
| Artifact and log location | Build artifacts under .build; smoke output is transient stdout/stderr | make check and scripts/smoke_mcp.sh |

## Lifecycle commands

| Stage | Exact command | Expected signal | Safe retry or cleanup | Status |
| --- | --- | --- | --- | --- |
| Setup | swift package resolve | Dependency graph resolves | Rerun; remove only .build with make clean if corrupted | candidate |
| Start | swift run apple-debug-mcp | MCP server accepts stdio input | Close stdin; retry after build | candidate |
| Seed or reproduce | scripts/smoke_mcp.sh | Initialize, tools/list, and capability call return JSON-RPC results | Rerun; inspect stderr | candidate |
| Reset | make clean | SwiftPM build artifacts removed | Rerun swift build | candidate |
| Stop and teardown | Close stdin and wait for the process | Process exits without leaving a listener | Use pgrep only for the task process if diagnosis is needed | candidate |

## Agent-readable surfaces

| Surface | Access path | Useful queries or actions | Expected evidence | Status |
| --- | --- | --- | --- | --- |
| UI/accessibility tree | N/A in the foundation | Simulator UI arrives with the iOS backend | N/A until Simulator adapter | N/A |
| API/CLI behavior | MCP stdio via scripts/smoke_mcp.sh | Initialize, list tools, call read-only tools | JSON-RPC response with tool content | candidate |
| Logs | Process stderr and smoke transcript | Capture launch/build failures | Non-empty actionable error | candidate |
| Metrics | N/A for the short-lived foundation CLI | Add only for a hosted service | N/A | N/A |
| Traces | N/A for the short-lived foundation CLI | Add only for long-running debugger sessions | N/A | N/A |

## Concurrency and cleanup

Do not run two agents against the same checkout or shared .build directory. Use separate worktrees for parallel work. The foundation opens no server port and stores no runtime state. Future LLDB/device sessions must record their process/device identity and provide deterministic teardown before a capability is marked verified.
