# Entropy Cleanup Checklist

Run this sweep manually at each major milestone and before a release or harness attestation.

## Documentation and navigation

- [x] Check Markdown links and indexes.
- [x] Compare documented commands with Package.swift, Makefile, and scripts.
- [x] Check architecture and product scope against the current code.
- [x] Check active and completed plan state.

## Code and architecture

- [x] Check for duplicated process wrappers or bypassed backend boundaries.
- [x] Check capability restrictions against security documentation.
- [x] Check growing files, ownerless TODOs, and stale compatibility paths.
- [x] Promote repeated review findings into tests or explicit debt.

## Verification and runtime

- [x] Run make check.
- [x] Run make harness-check.
- [x] Exercise the MCP smoke path and inspect stderr.
- [x] Check that no stale debug process or listener remains.
- [ ] Refresh harness evidence when source or coverage changes.

## Triage

| Finding | Evidence | Impact | Action | Destination | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Modern CoreDevice fixture unavailable | iPhone 17 CoreDevice tunnel refresh, lifecycle, remote LLDB-DAP control, rollback, and cleanup pass through the modern smoke | Future devices may still be unavailable because pairing, Developer Mode, signing, or Xcode support are external authorities | Re-run the modern smoke when device/toolchain support changes; retain the legacy iOS 15 path | Active ExecPlan | Apple Debug MCP maintainers | resolved-for-current-scope |
| Accessibility-tree source not selected | XCUITest attachment bridge and bounded gesture actions are fixture-tested | Arbitrary installed-app UI trees still require a UI-test-enabled project/scheme | Keep the fixture bridge explicit and extend project adapters only with a stable authorization contract | Technical debt tracker | Apple Debug MCP maintainers | resolved-for-fixture |

## Cadence and escalation

Run this sweep at each milestone and before a harness attestation. A maintainer decides whether a finding is a direct repair, a test, a runbook update, or an active-plan item. Do not enable automated writes or merges without explicit authorization.

## Automation decision

| Runner and cadence | Scan/repair scope | Read or write mode | Pull-request and merge authority | Rollback and escalation | Evidence and status |
| --- | --- | --- | --- | --- | --- |
| Manual maintainer/agent task completion | Repository docs, commands, capability boundaries, and tests | Read-only scan followed by explicitly authorized local repair | No automatic PR or merge | Escalate external writes, release, signing, and product judgment | Dated sweep completed 2026-08-24 |
