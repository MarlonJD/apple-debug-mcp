# Verification Matrix

| Change surface | Fast check | Broader check | Behavioral evidence | Fallback or blocker | Owner/update trigger |
| --- | --- | --- | --- | --- | --- |
| Documentation only | git diff --check and link review | make harness-check | Canonical routes resolve | Fix the named link or route | Maintainers; docs change |
| Library or core logic | swift test --filter CapabilitiesTests | make check | Capability JSON, artifact analyzers, policy gates, and toolchain status remain deterministic | Record missing Xcode/device authority as a scoped result | Maintainers; core change |
| MCP/API surface | scripts/smoke_mcp.sh | make check | JSON-RPC initialize, tools/list, analysis calls, and LLDB-DAP probe transcript | Inspect stderr and SDK contract | Maintainers; tool change |
| macOS desktop backend | python3 scripts/debug_fixture_smoke.py | make check | LLDB launch, source/instruction/function/exception breakpoints, breakpoint locations, stop snapshot, stop-event synchronization, modules, registers, stack/scopes, variables, completions, evaluate, memory, disassembly, instruction stepping, continue, and cleanup | Keep target mutation opt-in and respect adapter capability support | Maintainers; backend addition |
| iOS Simulator backend | make ios-fixture-smoke; make xcode-artifact-smoke | make ios-debug-fixture-smoke and make ios-ui-tree-smoke | Generic Xcode build returns app/dSYM artifacts; install/launch/screenshot, LLDB attach/inspection, accessibility tree, and UI-action evidence | Requires Xcode and, for target mutation, an available Simulator plus explicit mutation gate | Maintainers; backend addition |
| Physical iOS backend | apple_device_list and fail-closed policy tests | Authorized-device suite not yet available | Pairing/tunnel inventory and rejected mutation evidence | Requires authorized device, Developer Mode, signing, and user direction | Maintainers; device addition |
| Security-sensitive boundary | Capability restriction tests | Target-specific policy suite | Unauthorized operation fails closed | Keep operation disabled | Maintainers; policy change |
| Apple binary analysis | swift test --filter AppleBinaryDiffTests | make check | Code signature, entitlements, dependencies, symbols, dyld exports, Objective-C/Swift metadata, regular-Mach-O/.app/.dSYM diff reports, dSYM-aware symbolication, and crash-frame triage | Keep analyzers bounded and never execute artifact inputs | Maintainers; toolchain change |
| Repository harness authority | make harness-check | Bundled harness validator | Current routes, coverage, records, and commit boundary | Fail closed on warning/error | Maintainers; harness change |
| Release or production | make package; make release-package | `.github/workflows/ci.yml` plus configured release Mac | Unsigned package is CI-buildable; signed release target validates Developer ID, notarization staple, and Gatekeeper when authorized | Apple Developer credentials and explicit release authorization are required for the external submission | Human product owner; release scope |

## Rules

Use a narrow deterministic check before a broader check. Do not mark a backend verified from compilation alone. A missing real device, release credential, or production verifier is a scoped blocker and must not be replaced with a local assertion.
