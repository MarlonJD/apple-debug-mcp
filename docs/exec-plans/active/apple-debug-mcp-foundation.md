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

After this milestone, an MCP client can launch the SwiftPM server, complete MCP initialization, discover two safe read-only tools, inspect the macOS Xcode toolchain, and read explicit capability restrictions for macOS, iOS Simulator, and authorized physical iOS targets. Agents can resume work from this plan without relying on conversation history.

## Progress

- [x] (2026-08-24 01:00Z) Inspect the empty GitHub repository and repository-local instructions.
- [x] (2026-08-24 01:05Z) Run the adaptive harness audit and select the standard repository harness profile.
- [x] (2026-08-24 01:15Z) Record the product scope and physical iOS authorization boundary.
- [x] (2026-08-24 01:20Z) Add GPL-3.0-or-later licensing under Burak Karahan.
- [x] (2026-08-24 01:30Z) Add the SwiftPM package, official MCP SDK dependency, core capability model, and MCP tool registry.
- [x] (2026-08-24 01:42Z) Add and exercise the MCP smoke fixture.
- [x] (2026-08-24 01:44Z) Run build, test, whitespace, documentation, and project-native harness checks.
- [ ] Create the authorized source commit and direct-child harness attestation checkpoint.
- [ ] Push the verified commits to github.com/MarlonJD/apple-debug-mcp.

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

The foundation is not complete until the MCP smoke, project-native checks, harness checks, source commit, and direct-child attestation are observed. The expected result is a small working server with explicit future debt rather than a false claim of full debugger parity.

## Context and Orientation

The repository contains a library target AppleDebugCore and an executable target AppleDebugMCP. The core owns AppleDebugPlatform, AppleDebugCapability, CapabilityReport, CapabilityMatrix, ToolchainStatus, and ToolchainProbe. The executable registers apple_capabilities and apple_toolchain_status through the official MCP Swift SDK over stdio. docs/product-specs/platform-scope.md defines the full staged product boundary; docs/SECURITY.md defines the authorization boundary.

## Plan of Work

The first milestone establishes a transport-correct MCP process and a deterministic policy core. The next milestone will add an LLDB/DAP backend only after a fixture can prove session creation, inspection, and cleanup. Mach-O and iOS adapters remain explicit follow-up work in the debt tracker.

## Concrete Steps

Work from /Users/marlonjd/Developer/monorepos/apple-debug-mcp.

1. Resolve dependencies with swift package resolve. Expected result: SwiftPM resolves the official MCP product.
2. Build with swift build. Expected result: executable apple-debug-mcp is produced.
3. Run swift test. Expected result: capability and allowlist tests pass.
4. Run scripts/smoke_mcp.sh. Expected result: initialize, tools/list, and read-only tools/call each return a JSON-RPC response.
5. Run make check. Expected result: build, tests, smoke, whitespace, and placeholder checks pass.
6. Run make harness-check. Expected result: project-native checks and harness structural checks pass after certification evidence is current.
7. Review git diff --check, git status --short --branch, and the staged diff before each authorized commit.
8. Create source commit S, then create a direct-child attestation commit A containing only harness evidence/manifest/coverage changes.
9. Push S and A to the existing main remote only after local verification succeeds.

## Validation and Acceptance

Acceptance requires:

- make check exits 0.
- The MCP smoke output contains successful initialize, tools/list, apple_capabilities, and apple_toolchain_status responses.
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

The MCP server uses MCP.Server, MCP.StdioTransport, MCP.ListTools, MCP.CallTool, MCP.Tool, and MCP.Value from the official Swift SDK. ToolCatalog.tools is the source for the current tool list, and ToolCatalog.call(_:) dispatches calls. CapabilityMatrix.reports() is the stable policy interface. ToolchainProbe.collect() returns a ToolchainStatus containing developer directory and allowlisted tool paths.

## Revision History

- (2026-08-24 00:00Z) Change: Created the foundation plan and recorded the initial repository, dependency, licensing, and harness decisions.
  Reason: Establish a restartable implementation record for the first source and attestation checkpoints.
