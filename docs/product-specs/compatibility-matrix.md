# Compatibility Matrix

This matrix separates the environments exercised by the repository from the minimum versions declared by the package. A passing current-host check does not certify the minimum baseline or every Apple device generation.

## Environment tiers

| Tier | Scope | Exact entry point | Environment and evidence | Status |
| --- | --- | --- | --- | --- |
| Deterministic PR | SwiftPM build, XCTest, stdio MCP, authenticated daemon, macOS fixture, replay, plugin XPC, and repository contracts | `make pr-check` | Hosted `macos-26` arm64 runner; local current host is macOS 26.5.2, Xcode 26.6, Swift 6.3.3 | verified locally; CI-configured |
| Host integration | Multi-client daemon isolation/cleanup, checkpoint replay, and signed XPC plugin transport | `make host-integration-check` | macOS host with the repository fixture and signing tools; no physical-device state required | verified locally; CI/manual-capable |
| Simulator integration | Simulator lifecycle, LLDB-DAP attach, MCP controls, XCUITest UI, Xcode build/test, environment controls, and repro bundle | `make simulator-check` | Requires an available iOS Simulator and Xcode; mutation is enabled only inside this explicit command; local verification and hosted run `33028167208` passed the split core/repro targets on commit `d6b78a3` | verified-with-boundary; manual/scheduled |
| Physical-device integration | Modern CoreDevice and legacy iOS transport lifecycle/debug-control | `make physical-device-check` | Requires explicit device IDs, signed app, Developer Mode, matching Xcode support, and mutation/debug grants | verified-with-boundary; manual only |
| Workbench and menu bar UI | Native debugger/evidence UI plus supervised daemon popover lifecycle | `make workbench-ui-smoke` / `make menubar-ui-smoke` | Requires an accessible local GUI session; both UI smokes passed on the current host and the menu bar app ships in the notarized release | verified locally; GUI-only |
| Release | Unsigned package in CI; signed/notarized archive on an authorized Mac | `make package` / `make release-package` | Developer ID identity, notary profile, and Gatekeeper authority are external to the repository; GitHub Release `v0.1.0` carries the notarized, stapled, Gatekeeper-accepted arm64 archive | verified locally; published |

## Declared versus exercised baseline

| Component | Declared baseline | Exercised baseline | Compatibility claim |
| --- | --- | --- | --- |
| macOS | macOS 13 deployment target | macOS 26.5.2 arm64e | Release Info.plists and Mach-O `LC_BUILD_VERSION` records declare macOS 13; runtime behavior is verified only on macOS 26.5.2, so macOS 13 remains candidate-only |
| Xcode/Swift | Swift tools 6.1 manifest floor; an Xcode toolchain containing Swift 6.1 or later | Xcode 26.6; Apple Swift 6.3.3 | The former blanket “Xcode 16 or later” claim is removed; current-host behavior is verified and older toolchains remain outside the verified boundary |
| MCP Swift SDK | Package requirement starts at 0.11.0 | `Package.resolved` pins 0.12.1 | The locked 0.12.1 graph is verified; 0.11.0 is a declared floor, not a separately certified build |
| Swift NIO | Package requirement starts at 2.101.3 | `Package.resolved` pins 2.101.3 | Locked version is verified through the daemon build/smoke on the current Swift 6.3/macOS-26 CI baseline |
| iOS Simulator | Xcode-provided available runtime | Local fixture and the selected available Simulator | Simulator behavior is conditional on the installed runtime and is not part of every PR run |
| Modern physical iOS | Paired CoreDevice, tunnel, signing, and Developer Mode | Recorded iPhone 17/CoreDevice fixture | One authorized device/toolchain combination is verified; broader device compatibility is manual evidence |
| Legacy physical iOS | Compatible `xcdevice`/`ios-deploy` transport and signed app | Recorded iOS 15 fixture | One legacy transport combination is verified; it is not interchangeable with CoreDevice evidence |

## Rules

- CI runs the deterministic PR tier only; it must not require a physical device or release credentials.
- Simulator integration is manual or scheduled because it depends on installed runtimes and mutable CoreSimulator state.
- Physical-device integration is never inferred from compilation or Simulator evidence and is run only after explicit authorization.
- A change to Xcode, Swift, the MCP SDK, NIO, CoreSimulator, CoreDevice, or `ios-deploy` support invalidates the affected compatibility claim until its tier is rerun.
- Workbench and menu bar UI evidence is local GUI-only and does not run in headless PR CI; the published release readback verifies signatures, notarization staples, and Gatekeeper acceptance separately from runtime UI behavior.
