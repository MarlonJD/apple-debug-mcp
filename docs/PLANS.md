# Execution Plans (ExecPlans)

Use an ExecPlan for cross-cutting, risky, multi-hour, or context-loss-sensitive work. This project uses the managed plan schema described in docs/agent-harness/index.md.

## How to use an ExecPlan

Read the active plan completely before resuming work. Keep the plan self-contained: record the purpose, current progress, decisions, exact commands, expected evidence, recovery path, and remaining gaps. Keep exec-plans/index.md synchronized with active and completed files.

## Repository rules

- Create active plans under docs/exec-plans/active/.
- Use lowercase-hyphenated filenames.
- Keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective current at each stopping point.
- Use milestones that produce independently verifiable behavior.
- Run make check for product changes and make harness-check for harness changes.
- Do not mark a plan complete while required behavior or evidence remains candidate-only or blocked.
- Keep unresolved follow-up work in the active plan or exec-plans/tech-debt-tracker.md.

## Completion

Before moving a plan to completed/, run the applicable acceptance commands, remove unresolved placeholders, record the final retrospective, perform the semantic review, and validate the plan with the configured harness tool. A completed plan does not grant release, deployment, production, merge, or external-write authority.
