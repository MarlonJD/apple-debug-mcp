# Reliability

Apple Debug MCP is currently a short-lived local CLI. It has no hosted availability target, persistent state, background worker, or production deployment.

## Reliability contract

| Risk or invariant | Detection | Recovery | Verification |
| --- | --- | --- | --- |
| Xcode tool is absent or unavailable | apple_toolchain_status returns a missing path | Install/select the required Xcode toolchain and rerun discovery | make check and MCP smoke output |
| MCP process exits before initialization | Smoke fixture receives no valid initialize response | Run swift build, inspect stderr, and retry the command | scripts/smoke_mcp.sh |
| Tool output becomes non-deterministic | Core tests or sorted JSON output changes unexpectedly | Reproduce with the same fixture and update the contract intentionally | swift test |
| Future debugger operation leaves a target running | Session lifecycle and process cleanup tests fail | Use the session teardown path; do not kill unrelated processes | Candidate until debugger backend exists |
| Hosted availability, failover, and production rollback | Not applicable to the current local CLI | N/A; define only when a hosted service is introduced | N/A |

## Failure policy

The server fails closed for unknown tools and reports missing allowlisted tool paths as data. It must not fall back to arbitrary shell execution or silently broaden target permissions.
