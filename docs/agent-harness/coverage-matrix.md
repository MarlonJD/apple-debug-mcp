# Harness Engineering Coverage Matrix

Status values are verified, candidate, blocked, or N/A. A future harness attestation must link every verified or justified N/A row to one fresh evidence record.

## Coverage

| Source principle or capability | Repository implementation | Required evidence | Status and reason |
| --- | --- | --- | --- |
| Humans set intent; agents execute within authority | operating-loop.md, product scope, and security docs | Explicit human approval boundaries | candidate — foundation workflow documented; first complete task trace pending |
| Break large goals into reusable design, code, review, test, and verification steps | ../PLANS.md and active ExecPlan | Restartable plan with milestones | candidate — active foundation plan is present |
| Agents can self-review and respond to feedback | operating-loop.md and output-contract.md | Review process and finding trace | candidate — first review trace pending |
| Application behavior is directly readable | environment-contract.md and MCP smoke | CLI/MCP transcript | candidate — smoke is implemented and awaits final evidence |
| Logs, metrics, and traces are queryable when relevant | environment-contract.md and registry.md | CLI stderr or justified N/A | N/A — metrics/traces are not applicable to the short-lived foundation CLI |
| Repository knowledge is the durable record | docs/index.md and linked authorities | Link and routing check | candidate — harness check pending |
| Repository tools and authorized work context are directly invocable | registry.md, Makefile, and scripts/ | Commands exercised | candidate — command evidence pending |
| Dependencies and abstractions remain agent-legible | ../../ARCHITECTURE.md, registry.md, and checked-in references or fixtures | Upstream contract plus local proof | candidate — SDK contract is recorded; build evidence pending |
| AGENTS.md is a concise map, not an encyclopedia | ../../AGENTS.md | Routes and command table | candidate — static check pending |
| Plans are versioned living artifacts | ../PLANS.md and ../exec-plans/index.md | Active plan with progress and decisions | candidate — plan is active |
| Architecture and critical taste boundaries are mechanical | ../../ARCHITECTURE.md and project-native checks | Invariant and passing check | candidate — foundation tests exist; gate evidence pending |
| Local autonomy exists inside enforced central boundaries | operating-loop.md and SECURITY.md | Allowed actions and escalation path | candidate — documented; mutation policy not implemented yet |
| Verification proves working behavior, not only code changes | verification-matrix.md, make check, and smoke | Exact commands and output | candidate — final command evidence pending |
| Failures and review judgment feed back into the harness | operating-loop.md and debt tracker | One promoted finding | candidate — first failure trace pending |
| Entropy and technical debt are continuously controlled | entropy-cleanup-checklist.md and ../exec-plans/tech-debt-tracker.md | Dated sweep | candidate — first sweep pending |
| Autonomy increases only after test, review, recovery, and escalation loops exist | operating-loop.md and output-contract.md | Evidence for granted level | candidate — foundation remains read-only |
| Merge throughput policy matches project risk | SECURITY.md, RELIABILITY.md, and operating loop | Project-specific review rationale | N/A — no hosted CI or merge policy is owned by this local CLI repository |
| Release, deployment, and production actions require repository-local authority | operating-loop.md, output-contract.md, and SECURITY.md | Gate or justified N/A | N/A — no release, deployment, or production action exists |
| Repository-specific OpenAI examples are treated as options, not universal mandates | Case-study ledger below | Independent decision for every choice | candidate — ledger decisions are recorded; final evidence pending |

## Case-study decision ledger

| OpenAI case-study choice | Local decision or implementation | Required evidence | Status and reason |
| --- | --- | --- | --- |
| Zero human-authored code as an operating constraint | Reject; human product and security judgment remains explicit | Responsibility model | N/A — not a project requirement |
| Reported repository size, pull-request throughput, elapsed-time speedup, and long agent-run duration as targets | Reject; use behavior and verification outcomes | Product/quality goals | N/A — vanity metrics are not project goals |
| Local and cloud agent review loops continue until reviewers are satisfied while human review is optional | Limit; maintainer review is required for security, device, signing, and release boundaries | Review policy and trace | candidate — policy documented; trace pending |
| Per-worktree application isolation | Adopt separate worktrees for parallel agents; current foundation has no app state | Isolation proof | candidate — single-worktree evidence only |
| Per-worktree observability stack | Reject; stdio transcript and stderr are sufficient for the short-lived CLI | Environment contract | N/A — no long-lived service |
| Chrome DevTools Protocol for UI control | Reject for the foundation; future iOS UI uses Simulator-native tooling | UI verification decision | N/A — no web UI |
| Victoria Logs, Metrics, and Traces with LogQL/PromQL/TraceQL | Reject for the foundation | Telemetry decision | N/A — no hosted runtime |
| OpenAI's fixed layered domain architecture | Limit; use core, MCP, and future backend boundaries | Architecture and dependency test | candidate — core boundary exists |
| Reimplementing upstream dependency behavior locally | Reject for MCP framing; use official Swift SDK | Dependency contract | candidate — dependency is declared; build evidence pending |
| Minimally blocking merge gates and short-lived pull requests | Limit; no hosted merge policy is owned here | Risk/review rationale | N/A — no CI/review service in repository |
| Scheduled Codex documentation gardening and quality-scoring agents open targeted repair pull requests | Reject automatic writes; manual sweep only | Entropy checklist | candidate — manual policy documented |
| Automated merge and agent-authored release tooling | Reject | Release policy | N/A — no release action exists |
