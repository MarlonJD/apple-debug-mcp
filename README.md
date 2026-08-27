# Apple Debug MCP

[![CI](https://github.com/MarlonJD/apple-debug-mcp/actions/workflows/ci.yml/badge.svg)](https://github.com/MarlonJD/apple-debug-mcp/actions/workflows/ci.yml)
[![License: GPL-3.0-or-later](https://img.shields.io/badge/License-GPL--3.0--or--later-blue.svg)](LICENSE)

Apple Debug MCP is a local, GPL-3.0-or-later [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server for AI-assisted debugging, analysis, and reproducible investigation of authorized macOS and iOS targets.

It turns Apple's debugger and developer-tool ecosystem—LLDB-DAP, Xcode, Simulator, CoreDevice, `xctrace`, `atos`, `dwarfdump`, Mach-O tools, signing tools, and unified logs—into one capability-aware surface that an MCP-compatible client can discover and call with typed inputs and structured results.

> This is a local developer tool for software and devices you are authorized to debug. It is not a signing bypass, a remote public debugger, or an arbitrary shell-execution service.

## Quick install

For the notarized macOS release, download the [latest arm64 archive](https://github.com/MarlonJD/apple-debug-mcp/releases/latest), extract it, move `AppleDebugMenuBar.app` to `/Applications`, and open it. The menu bar app already contains the MCP daemon; no separate Swift, Python, Node.js, or Homebrew installation is needed just to run it.

Register the local MCP server with the client you use:

```sh
MCP_SERVER=/Applications/AppleDebugMenuBar.app/Contents/Resources/apple-debug-mcp

# Codex CLI
codex mcp add apple-debug-mcp -- "$MCP_SERVER"

# Claude Code
claude mcp add --scope user --transport stdio apple-debug-mcp -- "$MCP_SERVER"
```

Archives produced from the current repository also include `install_mcp.sh`; after moving the app, run `./install_mcp.sh --client auto` from the extracted archive directory. Verify with `codex mcp list` or `claude mcp list`. The published `v0.1.0` archive predates this helper, but the direct commands above work with it. See [detailed release installation](docs/RELEASE.md#end-user-mcp-installation) for MenuBar supervisor and endpoint details.

## Codex plugin installation

The repository follows the AWS Agent Toolkit-style marketplace layout: `plugins/apple-debug` contains the plugin manifest, a focused `skills/` directory, and an `.mcp.json` that wires the plugin to Apple Debug MCP.

> **Installing the Apple Debug plugin also installs the Apple Debug MCP integration.** This is a combined plugin, not a skill-only package: the plugin includes the MCP server configuration and its launcher, and release archives include the MCP executable inside the plugin package. Users do not need to run `codex mcp add` separately.

From a GitHub checkout, add the repository marketplace once:

```sh
codex plugin marketplace add MarlonJD/apple-debug-mcp
```

Launch Codex, run `/plugins`, and install **Apple Debug**. Start a new session after installation so Codex loads the bundled skill and MCP definition. From an archive produced by the current repository, add the extracted `apple-debug-mcp` (unsigned) or `apple-debug-mcp-release` (signed) directory as the marketplace root instead:

```sh
codex plugin marketplace add /absolute/path/to/apple-debug-mcp
```

Archives produced by the current repository carry the MCP executable inside the plugin package; the published `v0.1.0` archive predates this plugin. A source checkout can use the same plugin after `swift build`, an installed `AppleDebugMCP.app`/`AppleDebugMenuBar.app`, or an explicit `APPLE_DEBUG_MCP_EXECUTABLE` path. The plugin starts stdio MCP on demand; it does not enable debugger, evaluation, memory-write, Simulator-mutation, device-mutation, or external-plugin grants. macOS, Xcode, signing, pairing, and Developer Mode requirements still apply to the selected workflow.

After installation, ask Codex to use **Apple Debug** or start a task that needs Apple runtime inspection. Codex starts the bundled/local MCP process on demand, then discovers the typed Apple Debug tools. If the plugin was installed from the GitHub source marketplace rather than a release archive, install or build the local Mac executable first; the plugin still supplies the MCP wiring and skill.

## Why does this project exist?

Apple debugging is powerful, but its useful evidence is spread across many tools and stateful workflows. An AI agent that only has a terminal often has to parse ad-hoc text, reconstruct debugger state from separate commands, guess which Apple capability is available, and clean up processes or Simulators itself.

Apple Debug MCP provides the missing execution layer:

- the MCP client supplies reasoning, orchestration, and the user experience;
- this server supplies named tools for observation and controlled action;
- AppleDebugCore owns policy, target lifecycle, adapters, parsers, bounds, and cleanup;
- capability reports make supported and restricted operations explicit before an agent attempts them.

The result is a reusable bridge between an AI agent and the real Apple target—not another prompt that tells an agent to “try LLDB.” The agent can inspect a stop snapshot, correlate a crash with a binary and dSYM, capture a trace, compare two artifacts, operate a Simulator UI, or execute a bounded debugger step while keeping the session and authorization boundary visible.

## How is this different from “Build for macOS” or “Build for iOS” skills?

Codex build workflows and Apple Debug MCP are complementary layers, not competing versions of the same feature.

| Concern | Codex build workflows, such as Build for macOS or Build for iOS | Apple Debug MCP |
| --- | --- | --- |
| Main question | How should an app project be created, built, run, tested, or fixed? | What is an authorized Apple target doing, and how can it be inspected or controlled? |
| Primary unit | Source repository, Xcode project/workspace, scheme, and build/run workflow | Process, LLDB-DAP session, binary, `.app`, `.dSYM`, `.crash`, `.trace`, Simulator, or development device |
| Interface | Guidance, project-local scripts, and Xcode-aware workflow tools | 111 typed MCP tools with stable schemas and structured results |
| State | Usually coordinates a build/run/debug task around a project | Owns persistent debugger sessions, stop observations, bounded actions, artifact analysis, and cleanup |
| Apple surface | Centered on app development and Xcode workflow completion | Spans runtime debugging, binary/DWARF/crash analysis, profiling, Simulator/device lifecycle, signing audits, and evidence capture |
| Safety model | Uses the permissions and boundaries of the selected development workflow | Reports capabilities per target and keeps launch, attach, evaluation, writes, Simulator mutation, device mutation, builds, and plugin execution explicitly gated |

In short: a skill is generally the workflow guidance; MCP is the callable capability surface. A Build for iOS workflow can build and launch an app, while this server can give an agent a structured LLDB session, inspect its dSYM, capture a trace, query its Simulator UI, and preserve evidence. Apple Debug MCP does not replace app scaffolding, SwiftUI design guidance, or Xcode project setup. It gives those workflows a deeper and reusable debugging/analysis backend when an MCP client is configured to use it.

### When should an agent use this MCP?

The server returns an MCP `instructions` field during initialization. That is the server-wide routing guidance: use Apple Debug MCP when an authorized Apple target is already built or running and the task needs runtime inspection or control, LLDB-DAP state, artifact/crash/DWARF analysis, profiling, Simulator/device lifecycle, or reproducible evidence. Individual tool descriptions in `Sources/AppleDebugMCP/ToolCatalog.swift` provide the narrower input and authorization guidance for each operation.

The MCP client/model still makes the final tool choice. Installing the server does not force it into every task. For project creation, source edits, ordinary build/run/test work, SwiftUI design, or general Simulator UI interaction, prefer the Build for iOS/macOS workflow first; use this server when the investigation crosses into structured debugger state, Apple artifact analysis, controlled runtime mutation, physical development-device evidence, or durable evidence capture.

## What does the MCP server provide?

The server exposes more than 100 named tools. The main domains are:

| Domain | Examples |
| --- | --- |
| Capability and toolchain discovery | `apple_capabilities`, `apple_toolchain_status`, `apple_lldb_dap_initialize` |
| macOS and Simulator debugging | Persistent LLDB-DAP sessions, launch/attach, source/function/instruction/exception breakpoints, watchpoints, threads, stack, scopes, variables, registers, stepping, pause/continue, stop snapshots, completions, disassembly, bounded memory reads, and controlled evaluation or mutation |
| Execution history and kernel lab | Bounded checkpoint capture/source-location replay for authorized local macOS launches, DriverKit/system-extension processes through normal LLDB, and a separately gated read-only remote KDP lab provider |
| Apple artifact intelligence | Mach-O headers/segments/symbols/strings, code signatures and entitlements, linked libraries, dyld exports, Objective-C/Swift metadata, Swift AST, DWARF/DIE/source/line data, CFG/basic blocks/call graph/xrefs/relocations, shared-cache data, binary diffs, symbolication, and crash-frame triage |
| Performance and runtime evidence | Bounded `xctrace` recording and analysis, hotspots, folded flame stacks, semantic reports, timeline points, trace diffs, Swift Concurrency graphs, `vmmap` snapshots/diffs, heap/leaks/malloc-history/sample diagnostics, and bounded unified logs |
| iOS Simulator workflows | Inventory, boot/shutdown, install/launch/terminate, screenshots, URLs, locations, video, app metadata, containers, environment controls, reproducible evidence bundles, project-backed XCUITest trees/actions, and generated UI probes for an installed bundle ID |
| Authorized physical iOS workflows | CoreDevice and legacy `xcdevice` inventory, development-app install/launch, process lifecycle, sysdiagnose, xctrace capture, and authorization-gated LLDB-DAP sessions |
| Xcode and release analysis | Project discovery, explicitly authorized builds/tests with `.app`/`.dSYM`/`.xcresult` metadata, signing audits, non-destructive patch previews, and re-sign plans |
| Extension boundary | Read-only plugin manifest discovery and independently signed App Sandbox XPC plugin validation/execution |

The important part is not only the number of tools. The server also provides:

- typed request schemas instead of free-form debugger commands;
- capability-aware results that distinguish macOS, iOS Simulator, and physical iOS support;
- stateful LLDB-DAP sessions with bounded stop snapshots and deterministic cleanup;
- transaction-style expected-byte memory patching and readback/rollback paths where mutation is authorized;
- bounded file and output handling so large Apple-tool responses do not silently become unbounded agent context;
- explicit failure for unavailable Apple features instead of pretending to provide Windows-style reverse debugging or unrestricted kernel access.

## Why use it?

Use Apple Debug MCP when you want an AI agent or automation client to work with real Apple runtime state and evidence, not only source code or build output.

Typical benefits include:

- **Faster diagnosis:** correlate a stopped process, stack, registers, modules, source, symbols, crash report, and dSYM through one tool surface.
- **Repeatable investigations:** turn a manual LLDB/Xcode sequence into named MCP calls with bounded arguments and explicit cleanup.
- **Better evidence:** return structured snapshots, trace summaries, symbolication results, UI trees, screenshots, and reproducibility bundles instead of a wall of terminal text.
- **Safer automation:** dangerous operations are disabled by default, scoped to known targets, bounded, and separately authorized.
- **Local privacy:** the server runs on the Mac and does not publish a hosted debugger or send target state to a remote Apple service.
- **Cross-tool correlation:** connect runtime behavior with Mach-O metadata, DWARF, signing state, performance traces, Simulator state, and crash artifacts.
- **A useful agent loop:** discover capabilities → inspect → form a hypothesis → take one bounded action → verify the result → save evidence.

## Practical use cases

### AI-assisted crash triage

Give the agent a `.crash` or `.ips`, the matching `.app`/Mach-O and dSYM artifacts, and let it inspect images, symbolicate frames, identify missing symbols, and produce a bounded explanation of the failing path.

### Runtime debugging of an authorized macOS process

Create a session, set a source or function breakpoint, wait for a stop, collect a correlated stop snapshot, inspect scopes/registers/modules, step forward, and evaluate an expression only when the explicit grant is enabled.

### Simulator UI and regression reproduction

Build and install a development app, launch it with known arguments, inspect its accessibility tree, perform bounded taps/text/gestures, capture screenshots or video, collect logs, and package the resulting evidence.

### Performance investigation

Record a bounded `xctrace` trace, inspect CPU/allocation/concurrency/hitch evidence, extract hotspots and flame stacks, compare two traces, and connect a regression to a concrete symbol or source location.

### Binary and reverse-engineering analysis

Inspect Mach-O layout, symbols, exports, code signatures, Objective-C/Swift metadata, DWARF, CFGs, relocations, shared-cache information, crash frames, and disassembly without turning the MCP surface into an unrestricted command console.

### Authorized physical-device debugging

Work with paired, development-authorized devices using CoreDevice or the legacy `ios-deploy` path for supported devices. Install or launch a signed development app, inspect processes, capture performance data, and attach LLDB-DAP when signing, Developer Mode, pairing, and grants are correct.

### Release and patch preparation

Audit signing and entitlements, compare binaries or bundles, preview patch payloads, and generate a re-sign plan for review. The server does not silently overwrite or sign release artifacts.

## What should you expect?

You should expect:

- a local macOS process with stdio MCP transport, plus an optional authenticated loopback daemon;
- a tool catalog that exposes exactly what the server knows how to do;
- capability reports that can say “restricted” or “unavailable” for the current host/target;
- read-only inspection as the default posture;
- opt-in permissions for launch, attach, expression evaluation, variable/memory writes, Simulator mutation, device mutation, Xcode builds, and plugin execution;
- bounded inputs, outputs, file paths, traces, memory reads, and diagnostic durations;
- cleanup of debugger adapters and child processes owned by the server;
- checkpoint artifacts and source-location replay for deterministic debug-build investigations;
- evidence that is tied to the selected target, build, device, and installed Apple toolchain.

## What should you not expect?

This project intentionally does not provide:

- arbitrary shell execution or arbitrary LLDB command injection;
- a way to bypass Apple code signing, entitlements, Developer Mode, SIP, sandboxing, or device security;
- debugging of stock App Store applications or devices you are not authorized to inspect;
- a hosted, LAN-accessible, or internet-facing debugger service—the daemon binds to `127.0.0.1` and requires its private bearer token;
- a replacement for Xcode, Instruments, Hopper, IDA, Ghidra, or every Apple development workflow;
- native Apple LLDB reverse-step, reverse-continue, or exact time-travel state restoration when the installed toolchain does not provide it;
- checkpoint replay does not restore registers, memory, scheduler, kernel, or external-I/O state;
- unrestricted local kernel debugging, kernel memory writes, or kext debugging;
- physical-device UI inspection or file-backed screenshots where the public Apple tooling does not expose a supported interface;
- a guarantee that a tool works on every Mac, Xcode version, Simulator runtime, device, entitlement set, or build configuration;
- an inference that an AI-generated explanation is proof. Treat the returned artifact, snapshot, trace, and command context as the evidence.

## Supported target boundary

| Target | Supported surface | Important restrictions |
| --- | --- | --- |
| macOS | LLDB-DAP launch/attach/control, artifact analysis, runtime diagnostics, xctrace, logs, memory maps, signing audits, patch workflows, checkpoint/source-location replay, DriverKit process debugging, and native workbench analyzers | Target permissions and entitlements apply; native reverse execution/time-travel and kernel debugging remain restricted |
| iOS Simulator | Build/discovery, install/launch/debug, screenshots, logs, UI trees/actions, environment controls, performance, crash/DWARF/symbol analysis, and reproducible evidence | Simulator behavior is not physical-device evidence; kernel and native reverse execution remain restricted |
| Physical iOS device | Paired development-device lifecycle, CoreDevice or supported legacy transport, xctrace, sysdiagnose, and signed development-app LLDB-DAP workflows | Requires signing, Developer Mode, pairing/tunnel state, explicit grants, and compatible tools; stock App Store apps and public physical UI capture are out of scope |

The native Workbench adds a target picker, policy-aware debugger session controls, typed stop evidence, and a read-only Evidence panel for the bounded workflow manifest produced by MCP. Run `make workbench-build-smoke` for the product build and `make mcp-mac-debug-workflow-smoke` for the end-to-end local debugger evidence.

## Architecture

```text
MCP client ── stdio ───────────────► apple-debug-mcp
     │                                  ├── typed MCP tool catalog
     └── authenticated loopback HTTP ──►├── capability and policy gates
       127.0.0.1                         ├── LLDB-DAP session manager
                                        ├── Apple tool adapters and analyzers
                                        └── evidence, cleanup, and daemon lifecycle
```

The executable depends on `AppleDebugCore` and the official Swift MCP SDK. `AppleDebugCore` does not depend on MCP transport details, so policy, parsing, and Apple adapters remain testable without a client connection.

The default transport is stdio. `--daemon` enables a local Streamable HTTP/SSE endpoint supervised by the optional SwiftUI menu bar app. The daemon validates loopback host/origin, requires a random bearer token, caps request bodies, and stores discovery metadata in a user-private endpoint file. It never binds a LAN or public interface.

## Requirements

- verified runtime environment: macOS 26.5.2; release binaries retain a macOS 13 deployment target, but macOS 13 runtime behavior is candidate-only until exercised on that OS;
- Swift 6.1 or later; the current verified toolchain is Swift 6.3.3 with Xcode 26.6, and older Xcode 16 releases are not covered by a blanket compatibility claim;
- Xcode and its command-line tools for Apple-specific build, Simulator, debugger, device, and profiling operations; the notarized menu bar bundle already contains the MCP daemon, so a separate Swift compiler, Python, Node, or Homebrew installation is not needed just to launch/register the server;
- an MCP-compatible client with local stdio support, or a client configured for the authenticated loopback endpoint;
- for physical-device workflows: a paired development device, Developer Mode, valid signing/entitlements, compatible Apple tools, and explicit authorization.

## Build and verify

```sh
swift package resolve
swift build
swift test
make check
make harness-check
make mcp-daemon-smoke
make pr-check
make host-integration-check
make simulator-check
# simulator-check includes the core tier and the separate repro-bundle tier
# physical-device-check is manual and requires explicit device inputs
make package
# Workbench UI/runtime smoke is local GUI-only and requires an accessible macOS session
make workbench-ui-smoke
# Menu bar popover/runtime smoke is local GUI-only and exercises daemon lifecycle
make menubar-ui-smoke
```

`make pr-check` is the deterministic push/pull-request gate. It covers the core tests, MCP protocol smoke, registered-tool dispatch coverage, capability/toolchain probes, Mach-O/crash fixtures, the signed macOS debugger fixture, daemon session isolation, replay, plugin XPC, and cleanup. `make host-integration-check` repeats the host-only integration tier, while `make simulator-check` is an explicit manual/scheduled Simulator tier. `make physical-device-check` never runs automatically and requires explicit device IDs, a signed app, Developer Mode, and grants. `make harness-check` validates repository-owned workflow and evidence contracts. `make package` creates an unsigned relocatable macOS archive; signing and notarization are separate release-authorized steps. See the [compatibility and verification matrix](docs/product-specs/compatibility-matrix.md) for declared versus exercised baselines.
The hosted Simulator workflow runs `simulator-check-core` and `simulator-repro-bundle-check` as separate jobs so a slow repro-bundle capture cannot consume the entire integration job budget. Locally, `make simulator-check` runs both targets sequentially.

The repository also includes focused smoke workflows:

```sh
make fixture
make mcp-mac-debug-workflow-smoke
make mcp-install-smoke
make codex-plugin-smoke
make replay-smoke
make ios-fixture
make ios-fixture-smoke
make ios-debug-fixture-smoke
make ios-mcp-tool-smoke
make ios-ui-tree-smoke
make ios-arbitrary-ui-smoke
make dwarf-smoke
make swift-ast-smoke
make performance-analysis-smoke
make swift-concurrency-graph-smoke
make runtime-diagnostics-smoke
make assembler-smoke
make control-flow-smoke
make memory-map-smoke
make simulator-environment-smoke
make repro-bundle-smoke
make simulator-repro-bundle-check
make signing-audit-smoke
make patch-workflow-smoke
make plugin-smoke
make plugin-xpc-smoke
make workbench-build-smoke
make workbench-ui-smoke
make reverse-capability-smoke
```

Physical-device smokes are intentionally explicit and require an authorized device:

```sh
APPLE_DEBUG_PHYSICAL_UDID=<legacy-device-udid> make ios-legacy-debug-smoke
APPLE_DEBUG_PHYSICAL_UDID=<legacy-device-udid> make ios-legacy-debug-control-smoke
APPLE_DEBUG_PHYSICAL_UDID=<iphone-udid> APPLE_DEBUG_COREDEVICE_ID=<coredevice-uuid> make ios-coredevice-lifecycle-smoke
APPLE_DEBUG_PHYSICAL_UDID=<iphone-udid> APPLE_DEBUG_COREDEVICE_ID=<coredevice-uuid> make ios-coredevice-debug-control-smoke
```

For a signed and notarized archive on a configured release Mac, see [docs/RELEASE.md](docs/RELEASE.md). Release signing, notarization, and distribution credentials are never assumed by the normal build or CI path.

## Run

Run the stdio server:

```sh
swift run apple-debug-mcp
```

Example MCP configuration after building:

```json
{
  "mcpServers": {
    "apple-debug-mcp": {
      "command": "/absolute/path/to/apple-debug-mcp/.build/debug/apple-debug-mcp"
    }
  }
}
```

Run the authenticated local daemon:

```sh
swift run apple-debug-mcp --daemon
```

The daemon uses `127.0.0.1:49321` by default and publishes its URL, bearer token, process ID, and schema version to:

```text
~/Library/Application Support/AppleDebugMCP/endpoint.json
```

Clients should read that file rather than guess a port. Set `APPLE_DEBUG_MCP_PORT=0` only for isolated test runs. The packaged menu bar app owns the bundled daemon, provides launch-at-login/server-at-login controls, opens Login Items settings when approval is needed, exposes endpoint/log/Quit actions, and writes its log to the user log directory. Its termination hook synchronously cleans up the owned daemon and endpoint metadata.

## Authorization and safe defaults

The server does not infer permission from a client request. State-changing operations require explicit environment grants and still validate target identifiers, paths, signing, and toolchain state.

```text
APPLE_DEBUG_ALLOW_TARGET_LAUNCH=1       launch a known local target
APPLE_DEBUG_ALLOW_TARGET_ATTACH=1       attach to an explicitly selected local process
APPLE_DEBUG_ALLOW_EVALUATE=1            evaluate an expression in a stopped target
APPLE_DEBUG_ALLOW_MEMORY_WRITE=1        enable bounded DAP memory writes and patches
APPLE_DEBUG_ALLOW_VARIABLE_WRITE=1      enable bounded debugger variable mutation
APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1  mutate a selected Simulator or run UI probes
APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1     mutate a paired development device
APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1        create an authorized physical-device LLDB session
APPLE_DEBUG_ALLOW_KERNEL_LAB=1          connect to an explicitly configured read-only remote KDP lab
APPLE_DEBUG_ALLOW_XCODE_BUILD=1         run an explicitly selected Xcode build/test
APPLE_DEBUG_ALLOW_PLUGIN_EXECUTION=1    execute an explicitly selected signed plugin path
```

Memory writes are bounded to 4096 bytes per operation, expression evaluation is bounded, and assembly patching goes through expected-byte validation plus the existing transactional memory path. Do not enable a grant for software or devices you are not authorized to debug.

## Current verification boundary

The local macOS debugger, checkpoint/source-location replay, menu bar app (`make menubar-ui-smoke`), iOS Simulator, legacy iOS transport, and modern CoreDevice workflows are verified against repository fixtures or explicitly authorized devices. The kernel-lab provider is verified fail-closed without a configured KDP target; an actual two-machine KDK/KDP session remains environment-dependent. CI builds and tests the unsigned macOS path; signing and notarization require a separate release workflow with Apple Developer credentials.

Apple tool availability and security policy vary by host. Physical-device support depends on the device transport, Xcode version, signing, Developer Mode, entitlements, and pairing state. The server reports those differences through `apple_capabilities` and fails closed when a required boundary is unavailable.

## Documentation

- [Architecture](ARCHITECTURE.md)
- [Platform scope](docs/product-specs/platform-scope.md)
- [Security model](docs/SECURITY.md)
- [Reliability and cleanup](docs/RELIABILITY.md)
- [Release and notarization](docs/RELEASE.md)
- [Documentation map](docs/index.md)

## License

Copyright (C) 2026 Burak Karahan.

This project is licensed under the GNU General Public License, version 3 or any later version. See [LICENSE](LICENSE).
