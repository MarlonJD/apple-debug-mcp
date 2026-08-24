# Agent Harness

This directory is the progressive-disclosure entry point for reliable work on Apple Debug MCP.

Root [AGENTS.md](../../AGENTS.md) is the canonical instruction map. [config.json](config.json) declares the downstream authorities; it does not change Codex configuration or create external authority.

## Capability map

| Need | Source of truth |
| --- | --- |
| Available commands and tools | [registry.md](registry.md) |
| Adopted authority paths | [config.json](config.json) |
| Human/agent workflow | [operating-loop.md](operating-loop.md) |
| Local isolation and runtime observability | [environment-contract.md](environment-contract.md) |
| Completion evidence | [output-contract.md](output-contract.md) |
| Change-to-verification mapping | [verification-matrix.md](verification-matrix.md) |
| Recurring drift cleanup | [entropy-cleanup-checklist.md](entropy-cleanup-checklist.md) |
| Harness capability coverage | [coverage-matrix.md](coverage-matrix.md) |
| Harness-ready certification | [certification.md](certification.md) and [certification.json](certification.json) |
| Long-running work | [../exec-plans/index.md](../exec-plans/index.md) |
| Security and reliability | [../SECURITY.md](../SECURITY.md) and [../RELIABILITY.md](../RELIABILITY.md) |

## Route by task

| Task | Read first | Continue with |
| --- | --- | --- |
| Understand the repository | [../../AGENTS.md](../../AGENTS.md) | [../../ARCHITECTURE.md](../../ARCHITECTURE.md) and [../index.md](../index.md) |
| Start or resume complex work | [../PLANS.md](../PLANS.md) | [../exec-plans/index.md](../exec-plans/index.md) and the active plan |
| Implement and verify | [operating-loop.md](operating-loop.md) | [registry.md](registry.md), [verification-matrix.md](verification-matrix.md), and [output-contract.md](output-contract.md) |
| Reproduce runtime behavior | [environment-contract.md](environment-contract.md) | [registry.md](registry.md) and the relevant verification row |
| Change an architecture boundary | [../../ARCHITECTURE.md](../../ARCHITECTURE.md) | [../design-docs/index.md](../design-docs/index.md) and the active plan |
| Handle review feedback | [output-contract.md](output-contract.md) | Add a test, rule, runbook, or debt item based on evidence |
| Sweep drift and debt | [entropy-cleanup-checklist.md](entropy-cleanup-checklist.md) | [../exec-plans/tech-debt-tracker.md](../exec-plans/tech-debt-tracker.md) |
| Certify the harness | [certification.md](certification.md) | Complete coverage and run the project-native gate plus the bundled validator |

## Current maturity

| Dimension | State | Evidence | Next useful increment |
| --- | --- | --- | --- |
| Knowledge routing | repeatable | Root routes and documentation map | Keep links current as backends appear |
| Planning continuity | repeatable | Active foundation ExecPlan | Update progress at every checkpoint |
| Executable verification | repeatable | make check and MCP smoke | Add LLDB fixture checks |
| Agent-readable runtime | candidate | MCP stdio smoke is being established | Add debugger session transcripts |
| Mechanical boundaries | candidate | Capability tests and allowlisted probing | Add session and policy tests |
| Entropy control | candidate | Checklist and debt tracker exist | Run the first dated sweep |
| Safe autonomy | repeatable | Security and operating-loop boundaries | Add explicit approval flow for mutation |
