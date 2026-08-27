# ExecPlan Registry

The files under active/ and completed/ are authoritative. Keep this index synchronized with their lifecycle.

## Active

| Plan | Owner | State | Updated (UTC) | Current milestone or blocker |
| --- | --- | --- | --- | --- |
<!-- harness:plans:active:start -->
| [Establish the Apple Debug MCP foundation](active/apple-debug-mcp-foundation.md) | Apple Debug MCP maintainers | implementing | 2026-08-27 | Foundation release published; complete unlocked-device iPhone 17 CoreDevice wrapper passed, with the earlier locked-device retry retained as fail-closed evidence |
<!-- harness:plans:active:end -->

## Completed

| Plan | Completed (UTC) | Outcome | Verification |
| --- | --- | --- | --- |
<!-- harness:plans:completed:start -->
| [Complete the Apple Debug MCP operational harness](completed/harness-engineering-completion.md) | 2026-08-26 | Added a repository-owned operational harness contract without certificate/attestation maintenance | `make check`, `make harness-check`, native checker, and bundled standard warnings-as-errors check |
<!-- harness:plans:completed:end -->

## Lifecycle rules

- Keep planning and implementation under active/.
- Move a plan to completed/ only after the gate in ../PLANS.md passes.
- Track confirmed deferred work in tech-debt-tracker.md.
