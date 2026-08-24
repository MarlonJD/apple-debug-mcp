# Security

Apple Debug MCP will eventually control debuggers that can read or mutate process state. The current foundation exposes only read-only capability and toolchain discovery, but the security boundary is established before adding those operations.

## Trust boundaries

- The MCP client is the local caller and starts the server through stdio.
- The server is a privileged local developer tool, not a network service.
- Xcode, LLDB, Simulator, and devicectl are external authority-bearing tools.
- A physical iOS device and its development-signed application are separate trust targets.
- Stock App Store applications are outside the supported target boundary.

## Security invariants

| Boundary | Invariant | Enforcer | Verification | Owner/update trigger |
| --- | --- | --- | --- | --- |
| MCP tools | Unknown tools fail closed | ToolCatalog.call | make check | Maintainers; every tool addition |
| Toolchain discovery | Only fixed executable paths and allowlisted arguments are used | ToolchainProbe | CapabilitiesTests and code review | Maintainers; every external process addition |
| Filesystem | Future targets must be inside an approved client root | Planned SecurityPolicy backend | Candidate until backend exists | Maintainers; before launch/attach |
| Process control | Launch, attach, terminate, and memory mutation require explicit capability and policy | Planned session policy | Candidate until backend exists | Maintainers; before debugger controls |
| Target launch | Launch is disabled unless APPLE_DEBUG_ALLOW_TARGET_LAUNCH=1 is explicitly set for an authorized local target | DebugPolicy.validateLaunchTarget | DebugSessionTests and launch tool error path | Maintainers; before enabling launch by default |
| Session cleanup | Failed launch and explicit close must terminate the LLDB-DAP adapter | DebugSessionManager and LLDBDAPSession.stop | DebugSessionTests and process inspection | Maintainers; every session lifecycle change |
| Debugger commands | MCP exposes specialized DAP operations, not arbitrary shell execution | ToolCatalog and DebugSessionManager | Tool schema review and make check | Maintainers; every new debugger command |
| Simulator mutation | Boot, shutdown, install, launch, and terminate require APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 and a known UDID | SimulatorService.mutate | AppleSimulatorTests and tool error path | Maintainers; every Simulator mutation change |
| Physical devices | Install/launch require APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1, a known identifier, paired state, and an available tunnel | AppleDeviceService.mutate | AppleDeviceTests and device inventory | Maintainers; every device operation change |
| iOS devices | Physical-device operations require pairing, Developer Mode, signing, and target authorization | Capability matrix and future device backend | Current restriction tests; device tests later | Maintainers; before device support |
| Secrets | No credentials or tokens are stored in the repository | Repository contract | make check and review | Maintainers; every configuration change |
| Network | No HTTP listener exists in the foundation; future HTTP must be localhost/authenticated/TLS-scoped | Architecture decision | Candidate until HTTP transport exists | Maintainers; before HTTP transport |

## Abuse and reporting

Do not use the server to access software or devices without authorization. Security findings should be recorded in the active ExecPlan and fixed with a reproducing test or a documented blocker. Release, signing, notarization, and external issue reporting require explicit authorization.
