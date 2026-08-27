# Sol/Luna model comparison contract

The model comparison is separate from the Apple-tool timing comparison. The
repository does not call a paid model service from `make check`; an external
runner must execute the same prompt and attach its metadata to the casebook
evidence.

## Required lanes

| Label | Model | Reasoning |
| --- | --- | --- |
| Sol | `gpt-5.6-sol` | `xhigh` |
| Luna | `gpt-5.6-luna` | `max` |

The model name, actual provider model ID, reasoning setting, runner version,
prompt hash, repository commit, scenario, and lane are required fields. An
alias without the actual model ID is not sufficient for a comparison.

## Shared task prompt

Use one prompt for both operating points, changing only the runner metadata:

```text
Run the selected Apple Debug MCP casebook scenario. First reproduce the
buggy behavior with the allowed lane, collect the smallest evidence needed to
identify the root cause, propose and apply the source fix in the isolated run
workspace, rebuild, and run the regression oracle. Report elapsed time to the
first evidence-backed root cause, elapsed time to a passing fix, every tool or
command used, cleanup status, and any uncertainty. Do not use tools from the
other lane. Do not claim a pass without the objective oracle.
```

The current checked-in casebook uses pre-authored buggy/fixed compile variants
so its Apple-tool behavior is deterministic. Those variants are intentionally
not a hidden benchmark oracle: a genuine model repair benchmark must copy the
buggy fixture into an isolated workspace, hide the fixed variant and oracle,
and let the model edit source before rebuilding.

## Fair run

Use the same task prompt, starting commit, fixture, tool permissions, timeout,
Simulator model/runtime, and result oracle for both lanes. Use a warm-up before
scoring and randomize scenario order if multiple repetitions are run. The
suggested full matrix is four scenarios × two tool lanes × two models × five
repetitions; keep raw runs as well as aggregate statistics.

The model lane may reason and propose or apply a source fix inside its isolated
run workspace. It must not use the MCP lane's direct Apple CLI commands, and
the manual lane must not use MCP. The runner should record any tool-provenance
violation as a failed run instead of silently changing lanes.

## Scorecard

Score objective behavior first:

- root cause is correct and tied to evidence;
- the buggy oracle fails before the fix;
- the proposed fix passes the fixed oracle;
- no unrelated regression is introduced;
- the MCP session, process, and Simulator cleanup is complete;
- timing and tool/command counts are recorded.

Token count or raw response length is supporting telemetry, not a quality
score. Do not claim a Sol/Luna winner from one run or from different output
scopes.

The first local read-only comparison already showed a useful qualitative
difference: Sol `xhigh` emphasized a common scorer and a four-scenario matrix;
Luna `max` independently emphasized deterministic deadlock, safe-area UI,
performance, crash cases, and provenance checks. This is design feedback, not
a benchmark result; the actual model scorecard remains pending an external
runner with the required model metadata.
