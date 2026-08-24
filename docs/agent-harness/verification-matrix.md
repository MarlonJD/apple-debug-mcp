# Verification Matrix

| Change surface | Fast check | Broader check | Behavioral evidence | Fallback or blocker | Owner/update trigger |
| --- | --- | --- | --- | --- | --- |
| Documentation only | git diff --check and link review | make harness-check | Canonical routes resolve | Fix the named link or route | Maintainers; docs change |
| Library or core logic | swift test --filter CapabilitiesTests | make check | Capability JSON, artifact analyzers, policy gates, and toolchain status remain deterministic | Record missing Xcode/device authority as a scoped result | Maintainers; core change |
| MCP/API surface | scripts/smoke_mcp.sh | make check | JSON-RPC initialize, tools/list, analysis calls, and LLDB-DAP probe transcript | Inspect stderr and SDK contract | Maintainers; tool change |
| macOS desktop backend | python3 scripts/debug_fixture_smoke.py | make check | LLDB launch, breakpoint, stack/scopes, memory, disassembly, step, continue, and cleanup | Keep target mutation opt-in | Maintainers; backend addition |
| iOS Simulator backend | make ios-fixture-smoke | make ios-debug-fixture-smoke | Build/install/launch/screenshot plus LLDB attach, stack, memory, disassembly, and cleanup | Requires an available Simulator and explicit mutation gate | Maintainers; backend addition |
| Physical iOS backend | apple_device_list and fail-closed policy tests | Authorized-device suite not yet available | Pairing/tunnel inventory and rejected mutation evidence | Requires authorized device, Developer Mode, signing, and user direction | Maintainers; device addition |
| Security-sensitive boundary | Capability restriction tests | Target-specific policy suite | Unauthorized operation fails closed | Keep operation disabled | Maintainers; policy change |
| Repository harness authority | make harness-check | Bundled harness validator | Current routes, coverage, records, and commit boundary | Fail closed on warning/error | Maintainers; harness change |
| Release or production | N/A | N/A | No hosted release action exists | Escalate if scope is added | Human product owner; scope change |

## Rules

Use a narrow deterministic check before a broader check. Do not mark a backend verified from compilation alone. A missing real device, release credential, or production verifier is a scoped blocker and must not be replaced with a local assertion.
