# Agent Environment Contract

## Isolation model

| Concern | Contract | Evidence |
| --- | --- | --- |
| Workspace isolation | One local checkout at a time unless separate Git worktrees are explicitly used | Current task uses /Users/marlonjd/Developer/monorepos/apple-debug-mcp |
| Dependency/cache isolation | SwiftPM uses repository-local .build; parallel work should use separate worktrees | swift build creates .build without external project state |
| Port/process allocation | Stdio mode has no listener; supervised daemon mode binds stable `127.0.0.1:49321` by default and publishes user-private endpoint metadata; isolated smoke uses port `0` | `make mcp-daemon-smoke` authenticates health/MCP and verifies endpoint cleanup |
| Data/state isolation | No database or persistent server state; fixture artifacts stay under .build and Apple target state is explicit | Mutation workflows require opt-in environment gates and deterministic cleanup |
| Artifact and log location | Build artifacts under .build; smoke output is transient stdout/stderr | make check and scripts/smoke_mcp.sh |

## Lifecycle commands

| Stage | Exact command | Expected signal | Safe retry or cleanup | Status |
| --- | --- | --- | --- | --- |
| Setup | swift package resolve | Dependency graph resolves | Rerun; remove only .build with make clean if corrupted | verified |
| Start | swift run apple-debug-mcp or `swift run apple-debug-mcp --daemon` | Stdio accepts MCP input; daemon publishes a bearer-authenticated endpoint | Close stdio or POST authenticated `/shutdown`; retry after build | verified |
| Seed or reproduce | scripts/smoke_mcp.sh | Initialize, tools/list, analysis calls, and capability call return JSON-RPC results | Rerun; inspect stderr | verified |
| Reset | make clean | SwiftPM build artifacts removed | Rerun swift build | verified |
| Stop and teardown | Close stdin for stdio; POST authenticated `/shutdown` for daemon and wait for the process | Process exits and daemon endpoint metadata is removed | Use the endpoint PID only for diagnosis; never kill an unrelated process | verified |

## Verification tiers

| Tier | Command | Intended trigger | State/authority boundary | Status |
| --- | --- | --- | --- | --- |
| Deterministic PR | `make pr-check` | Every push and pull request | No Simulator, physical device, release credential, or menu bar UI requirement | configured |
| Host integration | `make host-integration-check` | Manual or scheduled host integration validation | Uses only local fixtures, authenticated loopback, and signed repository XPC fixtures | configured-with-boundary |
| Simulator | `make simulator-check` | Manual or scheduled validation on a configured Mac | Requires an available runtime and `APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1`; cleans only selected fixture state | configured-with-boundary |
| Physical device | `make physical-device-check` | Explicit maintainer-authorized run | Requires device identifiers, signed app, Developer Mode, and explicit debug/mutation grants; never automatic | configured-with-boundary |
| Release | `make package` / `make release-package` | Release preparation | Signing/notarization is authority-gated and not part of the PR tier; the current arm64 archive has a local notarization/Gatekeeper result | verified locally |

## Agent-readable surfaces

| Surface | Access path | Useful queries or actions | Expected evidence | Status |
| --- | --- | --- | --- | --- |
| UI/accessibility tree | XCUITest attachment through apple_simulator_ui_snapshot | Structured accessibility tree with stable fixture identifiers | make ios-ui-tree-smoke | verified |
| API/CLI behavior | MCP stdio via scripts/smoke_mcp.sh and authenticated HTTP via scripts/mcp_daemon_smoke.py | Initialize, list tools, and call analysis/discovery tools over both transports | JSON-RPC response with tool content and endpoint health | verified |
| Logs | Process stderr and smoke transcript | Capture launch/build failures | Non-empty actionable error; smoke commands preserve stderr on failure | verified-with-boundary |
| Metrics | N/A for the short-lived foundation CLI | Add only for a hosted service | N/A | N/A |
| Traces | N/A for the short-lived foundation CLI | Add only for long-running debugger sessions | N/A | N/A |

## Concurrency and cleanup

Do not run two agents against the same checkout or shared .build directory. Use separate worktrees for parallel work. The server opens no port and stores no runtime state. LLDB sessions own only their adapter process; Simulator/device workflows record explicit identifiers and provide targeted teardown before the workflow is considered verified.
