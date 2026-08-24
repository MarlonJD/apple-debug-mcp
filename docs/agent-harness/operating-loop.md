# Human and Agent Operating Loop

## Responsibilities

| Role | Owns |
| --- | --- |
| Human product owner | Product scope, risk tolerance, authorization boundaries, release/signing approval, and final acceptance |
| Apple Debug MCP maintainers | Repository discovery, planning, implementation, local verification, self-review, evidence, and durable documentation |
| Mechanical harness | Deterministic build/test/smoke checks, documentation routing, and declared security boundaries |

## Task loop

1. Read the applicable instructions and canonical documentation.
2. Inspect the worktree and preserve unrelated changes.
3. Establish a baseline or reproduce the requested behavior.
4. Create or resume the active ExecPlan for cross-cutting work.
5. Implement the smallest independently verifiable increment.
6. Run focused checks, then make check.
7. Observe CLI/MCP behavior through scripts/smoke_mcp.sh or the relevant fixture.
8. Review the diff, tests, security boundary, docs, and recovery path.
9. Update the plan and canonical documents with observed evidence.
10. Run make harness-check when harness authorities or evidence change.
11. Hand off using the literal evidence labels in output-contract.md.

## Review policy decision

| Change surface | Local self-review | Independent review | Stop condition | Human review required? | Failure/escalation path |
| --- | --- | --- | --- | --- | --- |
| Core capability or policy | make check, diff review, and focused tests | Optional maintainer review | Tests and security docs agree | Yes for changing target authorization or mutation policy | Record finding in the active plan and security docs |
| MCP tool surface | MCP smoke and schema review | Optional maintainer review | Tool is discoverable and unknown tools fail closed | Yes for destructive tools | Do not expose the tool until policy and fixture evidence exist |
| LLDB/device backend | Fixture and lifecycle integration tests | Maintainer review required | Cleanup and target restrictions are verified | Yes before physical-device or release use | Keep capability candidate-only and record blocker |
| Harness authority | make harness-check and bundled cross-check | Maintainer review of evidence | No placeholders; records and commits are current | Yes for production or external-write claims | Keep harness-ready invalid and escalate |

## Review and recovery loop

| Signal | Immediate response | Durable feedback |
| --- | --- | --- |
| Focused test failure | Diagnose the first failure and fix or record the blocker | Add a fixture or update the relevant plan |
| MCP smoke failure | Capture stderr and protocol transcript; do not infer behavior | Update the transport contract or test |
| Security boundary failure | Disable the capability and preserve the reproducer | Update docs/SECURITY.md and add a policy test |
| Repeated review finding | Fix nearby occurrences before continuing | Promote the rule into a test or checklist |
| Harness gate failure | Repair only safe repository-local drift | Update coverage, evidence, and the active plan |

## Escalation boundaries

Stop and request direction for destructive deletion, signing/notarization, physical-device access not already authorized, external issue/PR writes, release publication, production operations, or a product decision that changes the supported target boundary.
