# Verification Matrix

| Change surface | Fast check | Broader check | Behavioral evidence | Fallback or blocker | Owner/update trigger |
| --- | --- | --- | --- | --- | --- |
| Documentation only | git diff --check and link review | make harness-check | Canonical routes resolve | Fix the named link or route | Maintainers; docs change |
| Library or core logic | swift test --filter CapabilitiesTests | make check | Capability JSON and toolchain status remain deterministic | Record missing Xcode tool as a scoped result | Maintainers; core change |
| MCP/API surface | scripts/smoke_mcp.sh | make check | JSON-RPC initialize, tools/list, and tools/call transcript | Inspect stderr and SDK contract | Maintainers; tool change |
| macOS desktop backend | N/A until LLDB backend exists | Planned fixture suite | LLDB session transcript and cleanup | Candidate-only until fixture exists | Maintainers; backend addition |
| iOS Simulator backend | N/A until Simulator backend exists | Planned Simulator fixture suite | Build/run/log/UI evidence | Candidate-only until Xcode fixture exists | Maintainers; backend addition |
| Physical iOS backend | N/A until device backend exists | Planned authorized-device suite | Pairing, launch, debug, and cleanup evidence | Requires authorized device and signing | Maintainers; device addition |
| Security-sensitive boundary | Capability restriction tests | Target-specific policy suite | Unauthorized operation fails closed | Keep operation disabled | Maintainers; policy change |
| Repository harness authority | make harness-check | Bundled harness validator | Current routes, coverage, records, and commit boundary | Fail closed on warning/error | Maintainers; harness change |
| Release or production | N/A | N/A | No hosted release action exists | Escalate if scope is added | Human product owner; scope change |

## Rules

Use a narrow deterministic check before a broader check. Do not mark a backend verified from compilation alone. A missing real device, release credential, or production verifier is a scoped blocker and must not be replaced with a local assertion.
