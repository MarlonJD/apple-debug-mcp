# ExecPlan Registry

The files under active/ and completed/ are authoritative. Keep this index synchronized with their lifecycle.

## Active

| Plan | Owner | State | Updated (UTC) | Current milestone or blocker |
| --- | --- | --- | --- | --- |
<!-- harness:plans:active:start -->
| [Establish the Apple Debug MCP foundation](active/apple-debug-mcp-foundation.md) | Apple Debug MCP maintainers | implementing | 2026-08-27 | Foundation release published; iPhone 17 CoreDevice wrapper and Codex/Claude Code MCP registration helper are verified |
| [Build the Apple Debug MCP complex debugging casebook](active/debugging-casebook.md) | Apple Debug MCP maintainers | implementing | 2026-08-27 | Host runtime, lock-order deadlock, Simulator visual regression, and Sol/Luna operating-point review are recorded; external score matrix remains follow-up |
| [Harden post-fix verification and crash symbolication](active/post-fix-verification-symbolication.md) | Apple Debug MCP maintainers | implementing | 2026-08-27 | Core identity/layout/crash/symbolication and adaptive quick verification are implemented; focused/full checks and proportionate native smokes are locally verified, with final harness gate pending |
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
