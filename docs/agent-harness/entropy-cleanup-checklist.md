# Entropy Cleanup Checklist

Run this sweep manually at each major milestone and before a release or harness attestation.

## Documentation and navigation

- [ ] Check Markdown links and indexes.
- [ ] Compare documented commands with Package.swift, Makefile, and scripts.
- [ ] Check architecture and product scope against the current code.
- [ ] Check active and completed plan state.

## Code and architecture

- [ ] Check for duplicated process wrappers or bypassed backend boundaries.
- [ ] Check capability restrictions against security documentation.
- [ ] Check growing files, ownerless TODOs, and stale compatibility paths.
- [ ] Promote repeated review findings into tests or explicit debt.

## Verification and runtime

- [ ] Run make check.
- [ ] Run make harness-check.
- [ ] Exercise the MCP smoke path and inspect stderr.
- [ ] Check that no stale debug process or listener remains.
- [ ] Refresh harness evidence when source or coverage changes.

## Triage

| Finding | Evidence | Impact | Action | Destination | Owner | Status |
| --- | --- | --- | --- | --- | --- | --- |
| No sweep finding recorded yet | Foundation checkout created 2026-08-24 | Future drift could remain undocumented | Run the first sweep after the foundation check | Active ExecPlan | Apple Debug MCP maintainers | candidate |

## Cadence and escalation

Run this sweep at each milestone and before a harness attestation. A maintainer decides whether a finding is a direct repair, a test, a runbook update, or an active-plan item. Do not enable automated writes or merges without explicit authorization.

## Automation decision

| Runner and cadence | Scan/repair scope | Read or write mode | Pull-request and merge authority | Rollback and escalation | Evidence and status |
| --- | --- | --- | --- | --- | --- |
| Manual maintainer/agent task completion | Repository docs, commands, capability boundaries, and tests | Read-only scan followed by explicitly authorized local repair | No automatic PR or merge | Escalate external writes, release, signing, and product judgment | Candidate until first dated sweep |
