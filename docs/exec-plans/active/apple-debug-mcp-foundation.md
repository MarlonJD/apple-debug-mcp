<!-- harness-plan:v1
id: apple-debug-mcp-foundation
status: active
created: 2026-08-24
updated: 2026-08-24
completed:
owner: Apple Debug MCP maintainers
-->

# Establish the Apple Debug MCP foundation

Maintain this plan according to the [configured planning policy](../../PLANS.md). The plan covers the first independently verifiable repository checkpoint and remains active while debugger backends are added.

## Purpose / Big Picture

After this milestone, an MCP client can launch the SwiftPM server, complete MCP initialization, discover three safe read-only tools, inspect the macOS Xcode toolchain, initialize LLDB-DAP, and read explicit capability restrictions for macOS, iOS Simulator, and authorized physical iOS targets. Agents can resume work from this plan without relying on conversation history.

## Progress

- [x] (2026-08-24 01:00Z) Inspect the empty GitHub repository and repository-local instructions.
- [x] (2026-08-24 01:05Z) Run the adaptive harness audit and select the standard repository harness profile.
- [x] (2026-08-24 01:15Z) Record the product scope and physical iOS authorization boundary.
- [x] (2026-08-24 01:20Z) Add GPL-3.0-or-later licensing under Burak Karahan.
- [x] (2026-08-24 01:30Z) Add the SwiftPM package, official MCP SDK dependency, core capability model, and MCP tool registry.
- [x] (2026-08-24 01:42Z) Add and exercise the MCP smoke fixture.
- [x] (2026-08-24 01:44Z) Run build, test, whitespace, documentation, and project-native harness checks.
- [x] (2026-08-24 02:00Z) Add DAP framing, LLDB-DAP initialization, and adapter cleanup tests.
- [x] (2026-08-24 02:04Z) Commit the LLDB-DAP adapter foundation as 23dd183.
- [x] (2026-08-24 02:10Z) Add read-only Mach-O/universal-binary inspection and commit it as f4d9724.
- [x] (2026-08-24 02:22Z) Add owned LLDB-DAP session create/list/close lifecycle and commit it as d101ae7.
- [x] (2026-08-24 02:27Z) Add DAP breakpoint, continue, threads, stack, memory-read, and disassembly operations and commit them as 05dbc60.
- [x] (2026-08-24 01:53Z) Create the authorized source commit 48ce3c9 and direct-child harness attestation checkpoint f6d5348.
- [x] (2026-08-24 01:53Z) Push the verified commits to github.com/MarlonJD/apple-debug-mcp.

## Surprises & Discoveries

- Observation: The remote GitHub repository exists but is empty.
  Evidence: git clone reported an empty repository and the checkout has no commits.
- Observation: The current Mac has lldb and lldb-dap, but no lldb-mcp binary in the Xcode toolchain.
  Evidence: Local xcrun --find lldb-dap succeeds; xcrun --find lldb-mcp returns no path.
- Observation: The official Swift MCP SDK provides Server, StdioTransport, ListTools, and CallTool.
  Evidence: Checked-in docs/references/mcp-swift-sdk.md and the upstream SDK contract.
- Observation: The SDK starts request handlers as separate tasks, so a smoke producer must keep stdin open briefly after sending requests.
  Evidence: The smoke fixture adds a bounded 0.5 second drain window before EOF and observes all four responses.
- Observation: SwiftPM resolved the official SDK to 0.12.1 under the declared 0.11.0 lower bound.
  Evidence: Package.resolved and successful swift build output.
- Observation: LLDB-DAP initialization works, but target launch against a system binary was denied because macOS Developer Mode is disabled.
  Evidence: LLDB-DAP returned an attach-failed response; DevToolsSecurity -status reported Developer mode disabled. No system setting was changed.

## Decision Log

- Decision: Use SwiftPM and the official Swift MCP SDK for the foundation.
  Rationale: The product runs on macOS and must integrate with Xcode tooling; MCP framing should remain upstream-owned.
  Date/Author: 2026-08-24 / Apple Debug MCP maintainers
- Decision: Start with read-only capability and toolchain discovery.
  Rationale: Debugger launch, attach, memory mutation, and device operations carry a materially larger authorization and cleanup risk.
  Date/Author: 2026-08-24 / Apple Debug MCP maintainers
- Decision: Use GPL-3.0-or-later with Burak Karahan as copyright holder.
  Rationale: Explicit product-owner licensing request.
  Date/Author: 2026-08-24 / Apple Debug MCP maintainers
- Decision: Keep the project separate from AviaWorkspace.
  Rationale: AviaWorkspace owns platform composition; this tool owns Apple debugger source and should have its own lifecycle.
  Date/Author: 2026-08-24 / Apple Debug MCP maintainers

## Outcomes & Retrospective

The foundation checkpoint is complete: the MCP smoke, project-native checks, harness checks, source commit 48ce3c9, direct-child attestation f6d5348, and GitHub push were observed. The LLDB-DAP adapter foundation is committed as 23dd183 and proves framing, initialization, event draining, and cleanup without launching a debug target. The first Mach-O inspection layer is committed as f4d9724 and proves universal/thin header and segment parsing. Owned LLDB-DAP session lifecycle is committed as d101ae7 and proves create/initialize/close cleanup. Specialized debugger inspection operations are committed as 05dbc60 and map breakpoint, continue, threads, stack, memory-read, and disassembly requests. The result is a small working server with explicit future debt rather than a false claim of full debugger parity. The full target launch, symbol/static-analysis, Simulator, and device product remains active follow-up work.

## Context and Orientation

The repository contains a library target AppleDebugCore and an executable target AppleDebugMCP. The core owns AppleDebugPlatform, AppleDebugCapability, CapabilityReport, CapabilityMatrix, ToolchainStatus, ToolchainProbe, DAPValue, DAPMessage, DAPFraming, LLDBDAPSession, DebugSessionManager, MachOReport, and MachOInspector. The executable registers capability, toolchain, LLDB-DAP, Mach-O, and session lifecycle tools through the official MCP Swift SDK over stdio. docs/product-specs/platform-scope.md defines the full staged product boundary; docs/SECURITY.md defines the authorization boundary.

## Plan of Work

The first milestone establishes a transport-correct MCP process, a deterministic policy core, and a verified LLDB-DAP adapter handshake. The next milestone will add target launch/session inspection only after a signed fixture and cleanup proof are available. Mach-O and iOS adapters remain explicit follow-up work in the debt tracker.

## Concrete Steps

Work from /Users/marlonjd/Developer/monorepos/apple-debug-mcp.

1. Resolve dependencies with swift package resolve. Expected result: SwiftPM resolves the official MCP product.
2. Build with swift build. Expected result: executable apple-debug-mcp is produced.
3. Run swift test. Expected result: capability and allowlist tests pass.
4. Run scripts/smoke_mcp.sh. Expected result: initialize, tools/list, read-only tools/call, and LLDB-DAP initialization each return a JSON-RPC response.
5. Run make check. Expected result: build, tests, smoke, whitespace, and placeholder checks pass.
6. Run make harness-check. Expected result: project-native checks and harness structural checks pass after certification evidence is current.
7. Review git diff --check, git status --short --branch, and the staged diff before each authorized commit.
8. Create source commit S, then create a direct-child attestation commit A containing only harness evidence/manifest/coverage changes.
9. Push S and A to the existing main remote only after local verification succeeds.

## Validation and Acceptance

Acceptance requires:

- make check exits 0.
- The MCP smoke output contains successful initialize, tools/list, apple_capabilities, apple_toolchain_status, and apple_lldb_dap_initialize responses.
- Capability reports include all three Apple target classes and explicitly restrict physical-device attach and memory mutation.
- Toolchain probing uses only the five allowlisted tool names.
- No unresolved harness placeholders remain.
- Source and attestation commit boundaries are direct-child and clean before certification.

## Idempotence and Recovery

All build and test commands are safe to rerun. make clean removes only SwiftPM build artifacts. If dependency resolution fails, inspect the first SwiftPM error and rerun swift package resolve; do not delete the repository or reset unrelated Git state. If smoke hangs, close stdin, inspect stderr, and verify that the executable exits before retrying. If certification evidence is stale, leave the claim invalid, refresh records from the current source commit, and create a new direct-child attestation.

## Artifacts and Notes

- Source: Package.swift, Sources/, Tests/, Makefile, and scripts/.
- Product contract: docs/product-specs/platform-scope.md.
- Architecture/security: ARCHITECTURE.md, docs/SECURITY.md, and docs/RELIABILITY.md.
- Harness routes: docs/agent-harness/.
- Follow-up debt: docs/exec-plans/tech-debt-tracker.md.

## Interfaces and Dependencies

The MCP server uses MCP.Server, MCP.StdioTransport, MCP.ListTools, MCP.CallTool, MCP.Tool, and MCP.Value from the official Swift SDK. ToolCatalog.tools is the source for the current tool list, and ToolCatalog.call(_:) dispatches calls. CapabilityMatrix.reports() is the stable policy interface. ToolchainProbe.collect() returns a ToolchainStatus containing developer directory and allowlisted tool paths. LLDBDAPSession owns the adapter process; DAPFraming owns Content-Length framing; DAPValue and DAPMessage own the typed JSON boundary.

## Revision History

- (2026-08-24 00:00Z) Change: Created the foundation plan and recorded the initial repository, dependency, licensing, and harness decisions.
  Reason: Establish a restartable implementation record for the first source and attestation checkpoints.
- (2026-08-24 01:53Z) Change: Recorded the completed foundation, source commit, attestation commit, and GitHub push.
  Reason: Keep the living plan aligned with observed repository state while leaving the full product work active.
- (2026-08-24 02:04Z) Change: Recorded the LLDB-DAP adapter foundation commit 23dd183 and its verified local behavior.
  Reason: Preserve the first debugger backend checkpoint and its Developer Mode boundary for the next target-session milestone.
- (2026-08-24 02:10Z) Change: Recorded the initial Mach-O inspection commit f4d9724.
  Reason: Preserve a reusable static-analysis foundation for macOS and iOS binaries before adding symbols and metadata.
- (2026-08-24 02:22Z) Change: Recorded the owned LLDB-DAP session lifecycle commit d101ae7.
  Reason: Make adapter ownership and cleanup observable before enabling target launch and process-control tools.
- (2026-08-24 02:27Z) Change: Recorded the specialized debugger inspection commit 05dbc60.
  Reason: Add structured debugger operations without exposing arbitrary LLDB command execution.
