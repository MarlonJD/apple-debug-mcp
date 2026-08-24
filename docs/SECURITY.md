# Security

Apple Debug MCP is a privileged local developer tool. It can start debuggers and, when explicitly enabled, alter an authorized target. The default process is read-only discovery and inspection; every state-changing boundary is opt-in and scoped.

## Trust boundaries

- The MCP client is the local caller and starts the server through stdio.
- The server inherits the caller’s macOS identity and developer-tool permissions.
- Xcode, LLDB, Simulator, CoreDevice, and unified logging are external authority-bearing tools.
- A physical iOS device and its development-signed application are separate trust targets.
- Stock App Store applications are outside the supported target boundary.

## Security invariants

| Boundary | Invariant | Enforcer | Verification |
| --- | --- | --- | --- |
| MCP tools | Unknown tools fail closed | `ToolCatalog.call` | `make check` |
| Toolchain | Only fixed executable paths and explicit argument arrays are used | `ToolchainProbe`, adapters | `CapabilitiesTests` and code review |
| Artifact files | Mach-O and crash inputs are bounded; binary diff additionally resolves only `.app` and `.dSYM` bundle layouts | `MachOInspector`, `CrashReportAnalyzer`, `AppleBinaryDiffService` | `MachOTests`, `CrashReportTests`, `AppleBinaryDiffTests` |
| Target launch | Requires `APPLE_DEBUG_ALLOW_TARGET_LAUNCH=1` and a regular target | `DebugPolicy.validateLaunchTarget` | `DebugSessionTests`, macOS fixture smoke |
| Target attach | Requires `APPLE_DEBUG_ALLOW_TARGET_ATTACH=1` and a positive process ID | `DebugPolicy.validateAttach` | `DebugSessionTests`, iOS Simulator smoke |
| Expression evaluation | Requires `APPLE_DEBUG_ALLOW_EVALUATE=1` and a 16 KiB expression limit | `DebugPolicy.validateEvaluate` | `DebugSessionTests` and fixture smoke |
| Memory write | Requires `APPLE_DEBUG_ALLOW_MEMORY_WRITE=1` and a 4096-byte limit | `DebugPolicy.validateMemoryWrite` | `DebugSessionTests` |
| Debugger commands | MCP exposes named DAP requests, not arbitrary shell execution | `ToolCatalog`, `DebugSessionManager` | Tool schema review and `make check` |
| Session cleanup | Failed launch, explicit close, and server shutdown terminate only owned adapters | `DebugSessionManager`, `LLDBDAPSession.stop` | Session tests and fixture smoke |
| Simulator mutation | Known UDID and `APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1` are required | `SimulatorService.mutate` | `AppleSimulatorTests`, iOS smoke |
| Physical devices | Install/launch require `APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1`, known identifier, paired state, and available tunnel | `AppleDeviceService.mutate` | `AppleDeviceTests`, live inventory |
| Physical-device LLDB | Session creation requires `APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1`, a UUID identifier, paired state, available tunnel, and LLDB `device select` pre-initialization | `DebugSessionManager.create`, `LLDBDAPSession(deviceIdentifier:)` | `DebugSessionTests`, `AppleDeviceTests`; live attach requires a paired fixture |
| Xcode builds | Require `APPLE_DEBUG_ALLOW_XCODE_BUILD=1` and explicit project/scheme/configuration/destination | `XcodeService.build` | `AppleXcodeTests` |
| Unified logs | Duration is bounded, predicates are single-line/limited, and output is capped at 2 MB | `AppleLogService` | `AppleLogsTests` |
| Network | No HTTP listener exists; future HTTP must be localhost/authenticated/TLS-scoped | Architecture boundary | Review before transport addition |
| Secrets | No credentials or tokens are stored in the repository | Repository contract | `make check` and review |

## Physical-device boundary

The CoreDevice adapter reports pairing and developer-tunnel state before any mutation. The current machine’s device inventory is not paired/tunnel-ready, so install, launch, and remote debug were not attempted. The server must not infer authorization from a device name, bundle identifier, or a successful inventory command.

## Abuse and reporting

Do not use the server to access software or devices without authorization. Security findings should be recorded in the active ExecPlan and fixed with a reproducing test or a documented blocker. Release, signing, notarization, and external issue reporting require explicit authorization.
