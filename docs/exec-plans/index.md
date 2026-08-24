# ExecPlan Registry

The files under active/ and completed/ are authoritative. Keep this index synchronized with their lifecycle.

## Active

| Plan | Owner | State | Updated (UTC) | Current milestone or blocker |
| --- | --- | --- | --- | --- |
<!-- harness:plans:active:start -->
| [Establish the Apple Debug MCP foundation](active/apple-debug-mcp-foundation.md) | Apple Debug MCP maintainers | implementing | 2026-08-24 | Local macOS/iOS Simulator product; physical-device and release gates remain explicit |
<!-- harness:plans:active:end -->

## Completed

| Plan | Completed (UTC) | Outcome | Verification |
| --- | --- | --- | --- |
<!-- harness:plans:completed:start -->
_None._
<!-- harness:plans:completed:end -->

## Lifecycle rules

- Keep planning and implementation under active/.
- Move a plan to completed/ only after the gate in ../PLANS.md passes.
- Track confirmed deferred work in tech-debt-tracker.md.
