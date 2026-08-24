# Agent Output Contract

## Required outcome

- Lead with the behavior or artifact delivered.
- Name material files and repository commits.
- Report exact verification commands and scoped outcomes.
- Separate remaining implementation gaps from approval-dependent work.
- State whether external writes, release, signing, deployment, or real-device work actually occurred.

## Evidence labels

| Label | Meaning |
| --- | --- |
| verified locally | The stated command or behavior was exercised in the local task environment |
| not run | The check was intentionally omitted with a reason |
| blocked | A named condition prevented required progress or verification |
| candidate-only | The implementation exists but lacks required behavior evidence |
| harness-ready | The current source/attestation harness contract passed with CERT000; it is not a production claim |
| release pending | Local work is complete but release evidence does not exist |
| production-ready | Use only with explicitly requested provider-authenticated production evidence |

## Handoff shape

- Outcome: behavior delivered
- Changed: paths and commits
- Verification: exact commands and observed signals
- Not verified: omitted or blocked surfaces
- Remaining work: active plan, debt, or approval boundary
