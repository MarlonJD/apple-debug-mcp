# Harness Engineering Coverage Matrix

Status values are verified, candidate, blocked, or N/A. Every verified or justified N/A row is linked to a fresh evidence record at attestation time.

Current attestation source commit: f7633872967b481e737cdd0017ba76fc71be7d1c.

## Coverage

| Source principle or capability | Repository implementation | Required evidence | Status and reason |
| --- | --- | --- | --- |
| Humans set intent; agents execute within authority | operating-loop.md, product scope, and security docs | Explicit human approval boundaries | [verified — make check and operating-loop review passed](evidence/coverage-01.json) |
| Break large goals into reusable design, code, review, test, and verification steps | ../PLANS.md and active ExecPlan | Restartable plan with milestones | [verified — active ExecPlan and plan registry are present](evidence/coverage-02.json) |
| Agents can self-review and respond to feedback | operating-loop.md and output-contract.md | Review process and finding trace | [verified — make check and diff review procedure are recorded](evidence/coverage-03.json) |
| Application behavior is directly readable | environment-contract.md and MCP smoke | CLI/MCP transcript | [verified — MCP smoke transcript passed](evidence/coverage-04.json) |
| Logs, metrics, and traces are queryable when relevant | environment-contract.md, registry.md, `apple_log_show`, and `apple_performance_record` | Bounded unified-log result and raw `.trace` artifact, or justified N/A for metrics | [verified — bounded host/Simulator logs and a short host Time Profiler trace are exercised; metrics remain N/A](evidence/coverage-05.json) |
| Repository knowledge is the durable record | docs/index.md and linked authorities | Link and routing check | [verified — documentation map and harness routes passed](evidence/coverage-06.json) |
| Repository tools and authorized work context are directly invocable | registry.md, Makefile, and scripts/ | Commands exercised | [verified — make check and registry commands passed](evidence/coverage-07.json) |
| Dependencies and abstractions remain agent-legible | ../../ARCHITECTURE.md, registry.md, and checked-in references or fixtures | Upstream contract plus local proof | [verified — Swift SDK reference and build passed](evidence/coverage-08.json) |
| AGENTS.md is a concise map, not an encyclopedia | ../../AGENTS.md | Routes and command table | [verified — AGENTS routes and command table passed](evidence/coverage-09.json) |
| Plans are versioned living artifacts | ../PLANS.md and ../exec-plans/index.md | Active plan with progress and decisions | [verified — active plan and lifecycle index passed](evidence/coverage-10.json) |
| Architecture and critical taste boundaries are mechanical | ../../ARCHITECTURE.md and project-native checks | Invariant and passing check | [verified — capability tests and native gate passed](evidence/coverage-11.json) |
| Local autonomy exists inside enforced central boundaries | operating-loop.md and SECURITY.md | Allowed actions and escalation path | [verified — security and operating-loop boundaries passed](evidence/coverage-12.json) |
| Verification proves working behavior, not only code changes | verification-matrix.md, make check, and smoke | Exact commands and output | [verified — build tests smoke and whitespace checks passed](evidence/coverage-13.json) |
| Failures and review judgment feed back into the harness | operating-loop.md and debt tracker | One promoted finding | [verified — operating loop and debt tracker are recorded](evidence/coverage-14.json) |
| Entropy and technical debt are continuously controlled | entropy-cleanup-checklist.md and ../exec-plans/tech-debt-tracker.md | Dated sweep | [verified — manual cleanup checklist and debt tracker are recorded](evidence/coverage-15.json) |
| Autonomy increases only after test, review, recovery, and escalation loops exist | operating-loop.md, output-contract.md, and policy gates | Evidence for granted level | [verified — mutation is opt-in, bounded, fixture-tested, and physical-device access remains escalated](evidence/coverage-16.json) |
| Merge throughput policy matches project risk | SECURITY.md, RELIABILITY.md, and operating loop | Project-specific review rationale | [N/A — no hosted CI or merge policy is owned by this repository](evidence/coverage-17.json) |
| Release, deployment, and production actions require repository-local authority | operating-loop.md, output-contract.md, SECURITY.md, and docs/RELEASE.md | Gate or justified N/A | [N/A — no production/deployment action exists; local signing/notarization is an explicit release-authority workflow](evidence/coverage-18.json) |
| Repository-specific OpenAI examples are treated as options, not universal mandates | Case-study ledger below | Independent decision for every choice | [verified — case-study decision ledger is complete](evidence/coverage-19.json) |

## Case-study decision ledger

| OpenAI case-study choice | Local decision or implementation | Required evidence | Status and reason |
| --- | --- | --- | --- |
| Zero human-authored code as an operating constraint | Reject; human product and security judgment remains explicit | Responsibility model | [N/A — not a project requirement](evidence/coverage-20.json) |
| Reported repository size, pull-request throughput, elapsed-time speedup, and long agent-run duration as targets | Reject; use behavior and verification outcomes | Product/quality goals | [N/A — vanity metrics are not project goals](evidence/coverage-21.json) |
| Local and cloud agent review loops continue until reviewers are satisfied while human review is optional | Limit; maintainer review is required for security, device, signing, and release boundaries | Review policy and trace | [verified — project review policy is explicitly limited](evidence/coverage-22.json) |
| Per-worktree application isolation | Adopt separate worktrees for parallel agents; this local CLI has no persistent app state | Isolation proof | [verified — single-checkout isolation and separate-worktree policy are recorded](evidence/coverage-23.json) |
| Per-worktree observability stack | Reject; stdio/HTTP transcripts, bounded stderr, and the menu-bar server log are sufficient for the local daemon | Environment contract | [N/A — no hosted service or production observability stack exists](evidence/coverage-24.json) |
| Chrome DevTools Protocol for UI control | Reject for the foundation; future iOS UI uses Simulator-native tooling | UI verification decision | [N/A — this repository has no web UI](evidence/coverage-25.json) |
| Victoria Logs, Metrics, and Traces with LogQL/PromQL/TraceQL | Reject for the foundation | Telemetry decision | [N/A — no hosted telemetry runtime exists](evidence/coverage-26.json) |
| OpenAI's fixed layered domain architecture | Limit; use the project-specific core, MCP, and Apple-tooling boundaries | Architecture and dependency test | [verified — project-specific core and backend boundaries are documented](evidence/coverage-27.json) |
| Reimplementing upstream dependency behavior locally | Reject for MCP framing; use official Swift SDK | Dependency contract | [verified — official Swift MCP SDK owns protocol framing](evidence/coverage-28.json) |
| Minimally blocking merge gates and short-lived pull requests | Limit; no hosted merge policy is owned here | Risk/review rationale | [N/A — no CI or review service is owned here](evidence/coverage-29.json) |
| Scheduled Codex documentation gardening and quality-scoring agents open targeted repair pull requests | Reject automatic writes; manual sweep only | Entropy checklist | [verified — manual maintenance policy is explicit](evidence/coverage-30.json) |
| Automated merge and agent-authored release tooling | Reject | Release policy | [N/A — no automated merge or agent-authored external release write exists; local release requires explicit human authority](evidence/coverage-31.json) |
