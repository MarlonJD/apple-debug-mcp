# Apple Debug MCP examples and evidence

These examples show what changes when an Apple debugging task uses the MCP
server instead of a loose sequence of Apple CLI commands. The goal is not to
hide the cost of MCP or claim that it is always faster. The goal is to make a
complex investigation observable, bounded, repeatable, and safe to verify.

## What changes?

| Problem | Without Apple Debug MCP | With Apple Debug MCP | Why use MCP? |
| --- | --- | --- | --- |
| Runtime logic bug | Run LLDB commands, remember the current frame, and interpret text manually | Keep a named session, stop on a source condition, inspect typed scopes/variables, verify the failure, and close the session | The root cause and cleanup become machine-readable evidence |
| Lock-order deadlock | Run `sample` and manually correlate main/worker wait stacks | Run bounded `apple_debug_runtime_diagnose` with explicit process policy and output limits | A stuck process cannot silently turn into an unbounded command |
| Simulator visual regression | Use `simctl` to install/launch/screenshot and inspect PNGs by eye | Set a typed Simulator environment, capture screenshots, inspect accessibility frames/hittability, and write a repro bundle | Visual evidence gets a deterministic geometry contract and a replayable artifact set |
| Crash triage | Combine `plutil`, `atos`, `dwarfdump`, and manual image/UUID matching | Inspect and symbolicate through bounded crash tools with explicit artifact mappings | Frame, image, symbol, and missing-artifact results share one structured response |
| Performance regression | Record/export an Instruments trace and hand-parse XML | Record, analyze, summarize, timeline, and diff through typed xctrace tools | Hotspots, flame stacks, semantic totals, and before/after deltas are directly comparable |

The important unit is the complete investigation rather than one command:

```text
discover capability → reproduce → inspect → form hypothesis → take one bounded action
→ verify with a fresh observation → preserve evidence → clean up
```

## Runnable examples

The host runtime case is deterministic and needs no Simulator:

```sh
make complex-debug-casebook
```

It reproduces a length-boundary bug, stops exactly when `index == count`,
captures `count=4`, `index=4`, and sentinel `-1000` through both manual LLDB
and MCP paths, checks the no-grant policy rejection, then verifies the fixed
binary exits with the expected total.

The concurrency case is also host-only:

```sh
make complex-deadlock-casebook
```

It creates a deterministic two-thread lock-order deadlock. The manual lane
uses Apple `sample`; the MCP lane uses bounded runtime diagnostics with an
explicit target grant. Both must expose the main thread plus two workers, and
the fixed lock-order variant must print `fixed-ok`.

The visual case needs an available iOS Simulator and explicit local mutation
authority:

```sh
make visual-regression-casebook
```

It compares a direct `simctl` screenshot with MCP screenshots, a typed
accessibility probe, a bounded fixture log query, and a screenshot/app-info
repro bundle. The buggy card clips the second line at an accessibility content
size; the fixed card expands and keeps the title hittable.

Run all three casebook lanes sequentially with:

```sh
make complex-casebook
```

## Evidence

The runners write bounded JSON under `.build/evidence/` and retain visual
artifacts below `.build/demos/`:

- `complex-runtime-casebook.json`: manual versus typed debugger diagnosis,
  root-cause values, policy rejection, cleanup, and fixed exit.
- `deadlock-casebook.json`: manual versus MCP sample timing, thread/mutex-wait
  markers, bounded diagnostic envelope, cleanup, and fixed exit.
- `visual-regression-casebook.json`: source hash, variant builds, manual/MCP
  timings and scopes, accessibility frames, screenshots, logs, repro files,
  content-size restoration, and Simulator cleanup.

The detailed scenarios are in [the complex casebook](demos/complex-casebook.md).
The model evaluation contract is in [the Sol/Luna comparison](demos/model-comparison.md).

## Why use Apple Debug MCP?

Use it when the task crosses from ordinary source editing/building into
authorized runtime state or Apple artifacts:

- a debugger session must survive several observations;
- multiple Apple tools must be correlated before a conclusion is credible;
- a memory, Simulator, or device action needs explicit policy and bounds;
- an agent must return evidence another person or run can inspect;
- a failure must clean up owned processes and sessions predictably.

For ordinary project creation, source editing, SwiftUI design, or a simple
build/run/test loop, the normal Xcode/project workflow remains the better
starting point. Simulator output is not physical-device evidence, and model
labels are not benchmark results without an external runner and raw metadata.
