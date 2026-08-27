# Complex MCP-vs-manual casebook

This casebook demonstrates the difference between a narrow manual Apple-tool
sequence and a typed Apple Debug MCP investigation. The comparison is about
time-to-actionable-evidence, correctness, cleanup, safety, and repair
verification. It does not assume that MCP is faster for every one-off command.

## Run the cases

The host case is deterministic and does not need a Simulator:

```sh
make complex-debug-casebook
```

The visual case needs an available iOS Simulator and an explicit local
mutation grant:

```sh
make visual-regression-casebook
```

All three runnable cases can be run in sequence with `make complex-casebook`. The aggregate
command is intentionally outside `make check` because the visual lane builds a
temporary Xcode app, changes the selected Simulator content-size setting, and
depends on host Simulator availability.

Evidence is written below `.build/evidence/`; screenshots, generated app
bundles, and repro bundles are kept below `.build/demos/` for inspection.

## Case 1: runtime bug repair

`Tests/Fixtures/complex_runtime_target.c` models a real length-boundary bug in
a small production-like function. The buggy variant uses `index <= count` for
an input whose logical valid indexes are `0..<count`; an allocated sentinel
slot makes the failure deterministic without relying on undefined behavior. The fixed variant is compiled with
`APPLE_DEBUG_DEMO_FIXED=1`, which changes the loop to `index < count` without
mutating checked-in source during the run.

The manual lane uses a fixed LLDB batch:

```text
target create <buggy-binary>
breakpoint set --file complex_runtime_target.c --line 23 --condition "index == count"
process launch
thread backtrace --count 4
frame variable count index total
expression -- readings[index]
process continue
quit
```

The MCP lane uses the same target and authorization boundary through:

```text
apple_debug_session_create
apple_debug_set_breakpoint (line 23, condition index == count)
apple_debug_launch
apple_debug_wait_for_stop
apple_debug_threads
apple_debug_stop_snapshot
apple_debug_stack_trace
apple_debug_scopes
apple_debug_variables
apple_debug_evaluate (count, index, and readings[index])
apple_debug_continue
apple_debug_wait_for_stop
apple_debug_session_close
```

The repair oracle is objective:

- buggy run exits non-zero and reports `actual=-953 expected=47`;
- MCP observes `count=4`, the stopped `sum_readings` frame, the sentinel value
  `-1000`, and typed stop data;
- the no-grant launch probe is rejected with an explicit policy error;
- both MCP sessions close cleanly;
- the fixed variant exits zero and reports the expected total.

This shows the important distinction: manual LLDB may be quicker for a small
inspection, while MCP preserves the investigation state, correlates the
evidence, checks the mutation boundary, and proves the repaired binary.

## Case 2: concurrency deadlock repair

`Tests/Fixtures/complex_deadlock_target.c` starts two workers that acquire
`cache_lock` and `metrics_lock` in opposite orders. A barrier makes both
workers hold their first lock before they request the second, so the buggy
binary remains blocked instead of relying on a timing-sensitive race. The
fixed variant gives both workers the same lock order and prints `fixed-ok`.

The manual lane runs Apple `sample` against the blocked process and reads one
raw all-thread transcript. The MCP lane runs the same authorized PID through
`apple_debug_runtime_diagnose` with a fixed tool/mode, duration, and bounded
output envelope, then terminates the owned process. The sample text remains
Apple's evidence, while MCP makes the policy, limits, process identity, and
cleanup explicit instead of leaving those details to an ad-hoc command.

The repair oracle is objective:

- the buggy process stays alive after printing `workers-started` until the
  bounded cleanup kills it;
- both manual and MCP lanes expose at least the main thread plus two workers;
- MCP returns a typed all-thread stack set and closes its session;
- the fixed variant exits zero and prints `fixed-ok`.

## Case 3: visual regression repair

The existing iOS fixture has a compile-time visual case mode. In the buggy
variant, a two-line order title is forced into a fixed-height, one-line card.
With `accessibility-extra-extra-extra-large` content size, the second line is
clipped. The fixed variant uses two lines and an adaptive card height large
enough for the accessibility text.

The manual lane performs only the Apple lifecycle and screenshot sequence:

```text
xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large
xcrun simctl install <udid> <buggy-app>
xcrun simctl launch <udid> com.burakkarahan.AppleDebugFixture
xcrun simctl io <udid> screenshot manual-buggy.png
xcrun simctl terminate <udid> com.burakkarahan.AppleDebugFixture
```

The MCP lane installs and launches both variants, then adds evidence that is
not available in the screenshot alone:

```text
apple_simulator_environment (content_size)
apple_simulator_install
apple_simulator_launch
apple_simulator_screenshot
apple_simulator_ui_probe
apple_simulator_repro_bundle
apple_simulator_terminate
```

The visual oracle uses accessibility geometry rather than a brittle pixel
hash: the fixed card frame must be taller than the buggy card frame, the
bug/fix status markers must be present, both screenshots must be non-empty,
and the fixed repro bundle must contain a manifest, screenshot, and app
metadata; a separate bounded `apple_log_show` call captures only the fixture's
recent log lines. This avoids turning an unfiltered Simulator log into an
unbounded evidence payload. This is still a visual demonstration—the
screenshots are the human proof—but the geometry and hittability data make the
regression machine-checkable.

## Case 3: performance regression

The existing `make performance-analysis-smoke` is the performance building
block for a future before/after case. A complex version should introduce a
known hot function, capture equivalent Time Profiler traces before and after,
and compare `apple_performance_analyze`,
`apple_performance_semantic_report`, `apple_performance_timeline`, and
`apple_performance_diff` results. The success oracle is that the hot function
appears in the buggy trace, its weight falls in the fixed trace, and the
functional output remains unchanged.

Direct `xctrace record/export` is a valid manual baseline, but raw XML and MCP
hotspots/flame stacks are not equivalent outputs. The report must state that
scope difference next to every timing result.

## Case 4: crash triage

`Tests/Fixtures/example.crash` and the artifact tools provide a bounded crash
case. The manual lane can use `plutil`, `atos`, `dwarfdump`, and hand-written
image/UUID matching. The MCP lane uses `apple_crash_inspect`,
`apple_crash_symbolicate`, and the supplied artifact mapping, then returns
structured process, exception, thread, image, and frame evidence. A future
fixture should pair a generated crash with its matching binary/dSYM and make
`unmatchedFrameCount=0` the repair oracle.

## What to record

Every comparison should record:

- cold and warm elapsed time, with median and p95 after at least five runs;
- time to first actionable root cause and time to a passing fix;
- manual command count versus MCP tool-call count;
- output kind and evidence fields, not only output byte count;
- root-cause correctness, fixed-run result, cleanup, and policy behavior;
- target, build, Simulator runtime, Xcode version, Git commit, and model-runner metadata.

Physical devices are out of scope for this casebook. They remain a separate,
explicitly authorized verification tier.
