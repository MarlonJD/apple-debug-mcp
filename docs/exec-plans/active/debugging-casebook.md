<!-- harness-plan:v1
id: debugging-casebook
status: active
created: 2026-08-27
updated: 2026-08-27
completed:
owner: Apple Debug MCP maintainers
-->

# Build the Apple Debug MCP complex debugging casebook

The casebook is a repository-local set of runnable demonstrations that compare
manual Apple-tool workflows with the typed Apple Debug MCP surface. It must
show investigation quality, evidence, safety, and repair verification rather
than claiming that MCP is always faster.

## Purpose / Big Picture

Add complex, reproducible examples for deterministic macOS runtime and
concurrency bug fixes, an iOS Simulator visual regression/fix, and richer
crash/performance evidence.
Each case records the manual path, MCP path, elapsed timings, structured result
quality, cleanup, and the post-fix verification signal. Model evaluations use
the same casebook prompt with `gpt-5.6-sol` at `xhigh` and `gpt-5.6-luna` at
`max`; model quality is reported separately from Apple-tool timings.

## Progress

- [x] (2026-08-27) Add a deterministic runtime bug fixture with buggy/fixed build variants and a manual-vs-MCP evidence runner.
- [x] (2026-08-27) Add a deterministic lock-order deadlock fixture with bounded MCP runtime-diagnose evidence and fixed lock-order verification.
- [x] (2026-08-27) Add a visual regression fixture mode and a Simulator evidence runner that captures before/after screenshots and accessibility geometry.
- [x] (2026-08-27) Add crash/performance case documentation and a model-evaluation prompt/scorecard.
- [x] (2026-08-27) Route the new commands through the Makefile and agent harness registry.
- [x] (2026-08-27) Run focused demos, `make check`, `make harness-check`, and review the resulting evidence.

## Surprises & Discoveries

- The existing debugger and Simulator smokes already provide most of the MCP primitives needed for the casebook.
- A manual LLDB command batch can be faster for a narrow one-off inspection; the casebook must therefore compare equivalent evidence and not only wall time.
- Simulator UI inspection builds a temporary XCTest runner, so the visual case belongs in an explicit Simulator tier instead of the deterministic PR gate.
- The Simulator UI probe terminates the target app as part of its generated XCTest; the visual runner treats a subsequent "found nothing to terminate" response as an idempotent cleanup success.
- A barrier-based deadlock fixture gives the concurrency case deterministic evidence without relying on a scheduler race; the MCP lane can then inspect all worker stacks before bounded termination.
- Unfiltered Simulator logs exceeded the bounded repro-bundle response limit, so the visual case uses a screenshot/app-info repro bundle plus a separate predicate-bounded `apple_log_show` call.
- SwiftUI accessibility element frames expose the rendered title height more reliably than the outer card frame for this case; the oracle compares title expansion and preserves screenshots for human review.

## Decision Log

- Keep the demo fixtures under `Tests/Fixtures` and the runners under `scripts/` so they reuse the repository's existing build and cleanup conventions.
- Use compile-time buggy/fixed variants for the examples. This keeps the demonstrations repeatable without mutating checked-in source during a smoke run.
- Treat screenshots as artifacts and accessibility frames/labels as the deterministic visual contract. Do not infer a visual fix from a screenshot byte comparison alone.
- Keep model-runner metadata in the evidence JSON, but do not make the repository depend on an external model service.
- Do not add visual or model-dependent work to `make check`; expose explicit commands and document their authority requirements.

## Outcomes & Retrospective

The initial casebook tranche is implemented and verified locally. A maintainer
can run the host runtime and lock-order deadlock repair cases plus the
Simulator visual regression case, inspect
the manual and typed MCP evidence, and review before/after screenshots and a
repro bundle. The performance/crash extensions and full external Sol/Luna
agent-repair matrix remain documented follow-up work; no missing model,
physical-device, signing, or external service authority is represented as a
pass. Final local evidence includes the host casebook, the Simulator casebook,
`make check`, and `make harness-check`; the two read-only model reviews used
`gpt-5.6-sol`/`xhigh` and `gpt-5.6-luna`/`max` and correctly kept model scoring
candidate-only.

## Context and Orientation

`AppleDebugCore` owns debugger, artifact, performance, and Simulator behavior;
`AppleDebugMCP` exposes those capabilities through typed tools. Existing
fixture runners include `scripts/debug_fixture_smoke.py`,
`scripts/performance_analysis_smoke.py`, `scripts/repro_bundle_smoke.py`, and
the iOS UI runners. The product and security boundary remains in
`docs/product-specs/platform-scope.md` and `docs/SECURITY.md`.

## Plan of Work

1. Add and validate the host runtime case without changing the production MCP surface.
2. Add an opt-in visual regression mode to the existing iOS fixture and capture deterministic UI evidence.
3. Document crash/performance extensions and the exact Sol/Luna evaluation contract.
4. Register the commands and run the repository gates.

## Concrete Steps

Work from `/Users/marlonjd/Developer/monorepos/apple-debug-mcp`.

1. Build the Swift package and the existing macOS/iOS fixtures.
2. Run the new host casebook command and inspect its JSON evidence.
3. If an available iOS Simulator exists, run the visual casebook command with `APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1`.
4. Run `make check`, `make harness-check`, `git diff --check`, and review all changed fixture, script, documentation, and registry paths.
5. Run the same documented model-evaluation prompt with `gpt-5.6-sol`/`xhigh` and `gpt-5.6-luna`/`max`; keep their outputs as comparison notes, not repository authority.

## Validation and Acceptance

- The host case starts from a failing buggy binary, identifies the faulty loop through LLDB/MCP evidence, builds the fixed variant, and exits successfully after repair.
- The host evidence contains manual and MCP elapsed times, tool/command names, root-cause facts, a structured stop snapshot, cleanup status, and the fixed-run exit code.
- The visual case captures buggy and fixed screenshots, identifies the visual element through accessibility data, records its frame/label contract, captures a bounded fixture log separately, and verifies the fixed variant through the same Simulator path.
- Manual and MCP results are explicitly marked as equivalent or non-equivalent; no speedup is claimed when output scope differs.
- Missing Simulator/model authority is reported as `not-run` or `candidate-only` with a reason.
- `make check`, `make harness-check`, and `git diff --check` pass for the repository change.

## Idempotence and Recovery

The runners write only under `.build` and use temporary directories for generated
Xcode artifacts. They terminate owned processes and target only the selected
fixture Simulator/bundle. If a Simulator run is interrupted, terminate only
`com.burakkarahan.AppleDebugFixture` on the selected UDID before retrying; do
not erase unrelated Simulator data.

## Artifacts and Notes

- Host fixture: `Tests/Fixtures/complex_runtime_target.c`.
- Host runner: `scripts/complex_debug_casebook.py`.
- Deadlock fixture: `Tests/Fixtures/complex_deadlock_target.c`.
- Deadlock runner: `scripts/deadlock_casebook.py`.
- Visual runner: `scripts/visual_regression_casebook.py`.
- Durable case descriptions and scorecard: `docs/demos/complex-casebook.md`.
- Model prompt/metadata contract: `docs/demos/model-comparison.md`.
- MCP evidence is bounded JSON; screenshots and generated traces stay under `.build` and are not release artifacts.

## Interfaces and Dependencies

The runners use the existing stdio MCP JSON-RPC contract and named tools such
as `apple_debug_session_create`, `apple_debug_set_breakpoint`,
`apple_debug_attach`, `apple_debug_stack_trace`, `apple_debug_runtime_diagnose`,
`apple_debug_terminate`,
`apple_debug_stop_snapshot`, `apple_debug_scopes`, `apple_debug_variables`,
`apple_debug_evaluate`, `apple_debug_wait_for_stop`,
`apple_debug_session_close`, `apple_simulator_launch`,
`apple_simulator_screenshot`, `apple_simulator_ui_probe`, and
`apple_simulator_repro_bundle`. No new production MCP capability is required
for the initial casebook.

## Revision History

- 2026-08-27: Created the active plan for complex MCP-vs-manual debugging, visual regression, and model-evaluation examples.
- 2026-08-27: Added the deterministic runtime repair fixture/runner, accessibility-size visual regression runner, casebook docs, Makefile commands, and harness routes; verified the host and Simulator lanes plus `make check` and `make harness-check`. External model scoring and full performance/crash runners remain follow-up scope.
