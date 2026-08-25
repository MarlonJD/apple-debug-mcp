<!-- harness-plan:v1
id: harness-engineering-completion
status: completed
created: 2026-08-26
updated: 2026-08-26
completed: 2026-08-26
owner: Apple Debug MCP maintainers
-->

# Complete the Apple Debug MCP operational harness

Maintain this plan according to the [configured planning policy](../../PLANS.md). The default completion target is the repository-native operational gate; optional commit-bound certification is deliberately outside this plan.

## Purpose / Big Picture

Make the Apple Debug MCP repository end-to-end agent-legible and mechanically maintainable. A contributor should be able to discover the authoritative context, choose a restartable plan, run the documented build/test/smoke workflows, observe MCP and Apple-tool behavior, review coverage and evidence references, and receive an actionable failure when repository harness structure drifts. The result is verified through `make harness-check` and the bundled read-only cross-check, without creating or refreshing certification attestations.

## Progress

- [x] (2026-08-25 22:50Z) Read repository instructions, canonical harness documents, build/test entry points, and the existing active plan.
- [x] (2026-08-25 22:52Z) Ran the adaptive and standard bundled harness checks; confirmed the current native gate is permissive and optional certification records are stale relative to `HEAD`.
- [x] (2026-08-25 23:10Z) Ran the baseline `make harness-check`; build, 89 XCTest cases, MCP stdio/daemon smoke, debugger fixture, plugin XPC smoke, and documentation checks passed.
- [x] (2026-08-25 23:18Z) Added `scripts/harness_contract.py`, wired it into `scripts/harness_check.sh`, and added a Python cache ignore rule.
- [x] (2026-08-25 23:19Z) Updated harness documentation, coverage scope, maintenance statuses, and registry entries to match the implemented gate and the repository's no-certification default.
- [x] (2026-08-25 23:24Z) Ran `make check`, `make harness-check`, the native checker, and the bundled standard warnings-as-errors cross-check from a SwiftPM-reset workspace; all required local checks passed.

## Surprises & Discoveries

- Observation: The bundled audit traverses `.build/checkouts` when build artifacts exist, producing dependency-owned Markdown link findings that are unrelated to repository authorities.
  Evidence: `python3 /Users/marlonjd/.codex/skills/harness-engineering/scripts/harness.py audit --root .` reported 87 link errors under `.build/checkouts`; the standard check over configured authorities reported zero errors and warnings.
- Observation: The existing `scripts/harness_check.sh` runs the full product check but only validates a required-file list, a placeholder regex, and one plan-index string.
  Evidence: Baseline `make harness-check` passed despite missing registry entries for three Make targets and candidate statuses in `environment-contract.md`.
- Observation: The existing HMAC evidence and certification manifest are bound to earlier source commits.
  Evidence: `HEAD` is `66976e5d3771f3a50734f5628bd03dcc34250ce5`, while the evidence records reference `f7633872967b481e737cdd0017ba76fc71be7d1c`.

## Decision Log

- Decision: Implement a repository-local Python contract checker and invoke it from `scripts/harness_check.sh`.
  Rationale: The native gate must remain runnable after the external skill package is unavailable; Python is already used throughout `scripts/` and provides sufficient standard-library JSON, Markdown, and filesystem support.
  Date/Author: 2026-08-26 / Apple Debug MCP maintainers
- Decision: Treat certification and HMAC freshness as optional, not as the default readiness gate.
  Rationale: The user explicitly requested end-to-end harness engineering without certificate/attestation work. The repository still keeps the existing certification documents as an opt-in boundary, but routine readiness checks validate local structure and evidence references only.
  Date/Author: 2026-08-26 / Apple Debug MCP maintainers
- Decision: Enforce only stable, repository-specific invariants: authority files and routes, plan lifecycle/index integrity, complete 31-row coverage with evidence links, command registry consistency, and non-candidate runtime/maintenance status.
  Rationale: These rules are deterministic and directly prevent the observed drift without adding a broad or noisy policy framework.
  Date/Author: 2026-08-26 / Apple Debug MCP maintainers

## Outcomes & Retrospective

The repository now has an operational, repository-owned harness gate. `scripts/harness_contract.py` checks authority routing, local Markdown routes, managed ExecPlan metadata and lifecycle indexes, the complete 31-row coverage inventory and local evidence-record shape, Makefile/registry consistency, and candidate or unchecked maintenance drift. `scripts/harness_check.sh` composes that structural gate with the existing product build/test/MCP/debugger/plugin smoke gate. Documentation now distinguishes this verified local workflow from optional commit-bound certification, and the historical certificate snapshot is explicitly marked as not maintained. `make check`, `make harness-check`, the native checker, and the bundled standard warnings-as-errors check passed locally. No certification key, attestation commit, external write, release, signing, deployment, or physical-device operation was performed.

## Context and Orientation

The repository is a Swift Package Manager macOS/iOS debugging MCP server. `AGENTS.md` is the concise instruction map; `ARCHITECTURE.md`, `docs/SECURITY.md`, `docs/RELIABILITY.md`, and `docs/product-specs/` own product and boundary knowledge. `docs/agent-harness/` owns the agent registry, operating loop, environment and output contracts, verification matrix, coverage matrix, and entropy checklist. `docs/exec-plans/` owns the managed plan lifecycle. `scripts/check.sh` is the product build/test/smoke gate, while `scripts/harness_check.sh` is the repository harness gate.

The working directory is `/Users/marlonjd/Developer/monorepos/apple-debug-mcp`. Do not change branches, refresh HMAC records, create certification commits, push, release, sign, notarize, deploy, or operate a physical device for this task.

## Plan of Work

1. Add `scripts/harness_contract.py` with bounded checks for the configured authorities, Markdown routes, managed ExecPlan metadata/indexes, coverage/evidence shape, command registry/Makefile agreement, and candidate-status drift.
2. Make `scripts/harness_check.sh` run the native contract after the existing product gate and remove its narrow duplicated checks.
3. Fill the command-registry gaps, document the contract's scope, and make the no-certification default explicit without deleting the optional certification boundary.
4. Run focused script checks, `make harness-check`, `make check`, `harness.py check --profile standard --warnings-as-errors`, and the managed plan validator. Review the diff and repository status.
5. Complete this plan only after all required progress items are checked, the retrospective is factual, and the semantic-review digest is recorded.

## Concrete Steps

Work from `/Users/marlonjd/Developer/monorepos/apple-debug-mcp`.

1. Run `python3 scripts/harness_contract.py`; expect a zero exit and one summary line per contract group. A failure must name the affected path and a corrective action.
2. Run `python3 -m py_compile scripts/harness_contract.py` and `git diff --check`; expect zero exit.
3. Run `make harness-check`; expect the existing product checks plus `harness-contract: all repository contracts passed`.
4. Run `make check`; expect Swift build, all XCTest cases, MCP/debugger/plugin smoke, whitespace, and placeholder checks to pass.
5. Run `swift package reset`, then run `python3 /Users/marlonjd/.codex/skills/harness-engineering/scripts/harness.py check --root . --profile standard --warnings-as-errors`; expect zero errors and warnings. SwiftPM reset removes dependency checkouts under `.build/` so the bundled helper does not treat third-party Markdown as repository documentation. This is a read-only cross-check, not the repository's source of enforcement.
6. Run `python3 /Users/marlonjd/.codex/skills/harness-engineering/scripts/harness.py validate-plan --root . --slug harness-engineering-completion --state active`; expect zero errors before completion and rerun with `--completion --semantic-review` after the final review line is added.

## Validation and Acceptance

Acceptance requires all of the following:

- `scripts/harness_check.sh` remains independent of the installed harness skill and invokes the project-native checker.
- Every configured non-optional authority resolves to a regular repository file; critical Markdown routes and the configured ExecPlan index resolve.
- Every active or completed managed plan has the required metadata and thirteen-section schema, and every indexed plan appears exactly once in the correct lifecycle section.
- The 31-row coverage inventory has unique identities, only `verified` or justified `N/A` statuses, exactly one repository-local evidence link per row, and valid local evidence JSON shape.
- Every Makefile target is present in the agent capability registry, and every registry `make <target>` reference names a real target.
- The environment and entropy contracts have no unexplained candidate/unchecked maintenance state.
- `make harness-check`, `make check`, the bundled standard warnings-as-errors check, and the active plan validator exit 0.

The result is `verified locally`, not `harness-ready`: no source/attestation commit pair or HMAC refresh is produced.

## Idempotence and Recovery

The checker is read-only and safe to rerun. Documentation repairs are additive and can be reverted by editing the named authority. Product build and smoke commands use the repository's existing `.build` and fixture cleanup paths. If a contract check fails, fix the named document or command, rerun the checker, and do not bypass it by weakening the rule. If a check needs a certificate key, external write, release credential, device authorization, or product judgment, leave that surface outside this plan and record it as a scoped blocker instead.

## Artifacts and Notes

- Native checker: `scripts/harness_contract.py`.
- Native gate: `scripts/harness_check.sh` and `Makefile` target `harness-check`.
- Agent command catalog: `docs/agent-harness/registry.md`.
- Coverage and evidence references: `docs/agent-harness/coverage-matrix.md` and `docs/agent-harness/evidence/`.
- Optional certification boundary: `docs/agent-harness/certification.md`; not refreshed by this plan.

## Interfaces and Dependencies

The checker uses only Python 3.11-compatible standard-library modules (`datetime`, `json`, `pathlib`, `re`, `sys`, and `typing`). It reads the authority map in `docs/agent-harness/config.json`, the Makefile, Markdown authorities, managed plan directories, and JSON records under `docs/agent-harness/evidence/`. It does not invoke SwiftPM, Git, the external harness skill, Apple tools, network services, or shell commands. `scripts/harness_check.sh` remains the composition boundary between this structural contract and `scripts/check.sh`'s behavioral product gate.

## Revision History

- (2026-08-25 23:12Z) Change: Created the operational harness completion plan after the adaptive audit and baseline gate run.
  Reason: The repository had a broad documentation/evidence scaffold but lacked a durable project-native contract for its observed harness invariants.
- (2026-08-25 23:20Z) Change: Added and exercised the repository-local contract checker; documented the optional certification boundary and closed command/maintenance drift.
  Reason: The native gate needed deterministic checks for authority routing, managed plans, coverage/evidence references, and command registry completeness.
- (2026-08-25 23:24Z) Change: Completed the operational harness implementation and verification pass.
  Reason: The native product and structural gates passed, and the bundled cross-check passed after resetting SwiftPM's dependency cache so third-party Markdown was outside its scan.
- (2026-08-25 23:25Z) Change: Corrected the reproducible bundled-helper cleanup command and the native checker dependency list.
  Reason: `make clean` leaves SwiftPM dependency checkouts in `.build`; `swift package reset` is the command that produced the clean cross-check workspace, and the checker uses `typing` rather than `argparse`.
  Semantic-Review: reviewer=Apple Debug MCP maintainers; reviewed-at=2026-08-25 23:25Z; content-sha256=7df244ba6d95ed0d47d357b8f4583c1f56923eb198b906522a77f0e298120922; evidence=Reviewed all thirteen sections, lifecycle metadata, commands, recovery path, local gate output, and explicit no-certification boundary; no unresolved placeholders or unchecked progress remain.
