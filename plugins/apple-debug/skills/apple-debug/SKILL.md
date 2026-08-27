---
name: apple-debug
description: Use Apple Debug MCP for authorized macOS, iOS Simulator, and development-authorized physical iOS debugging, Apple artifact analysis, profiling, and reproducible evidence.
---

# Apple Debug

Use this plugin when the task needs structured Apple runtime state or evidence beyond an ordinary build/run/test workflow:

- inspect or control an authorized macOS process through LLDB-DAP;
- investigate a crash report with a matching app, Mach-O, or dSYM;
- inspect Mach-O, code-signing, entitlements, Objective-C/Swift, DWARF, CFG, or symbolication data;
- capture or analyze bounded `xctrace`, runtime-diagnostic, vmmap, or unified-log evidence;
- build, launch, debug, inspect, or act on an authorized iOS Simulator target;
- inspect a paired development-authorized physical iOS app;
- preserve a reproducible workflow manifest or evidence bundle.

Do not use this plugin as a replacement for ordinary source editing, project creation, SwiftUI design, or a normal build/run/test workflow. Prefer the relevant project and platform workflow until the task crosses into structured debugger state, Apple artifact analysis, controlled runtime mutation, physical-device evidence, or reproducible investigation.

## Required operating sequence

1. Confirm that the target and artifacts are authorized and identify the platform boundary.
2. Call `apple_capabilities` and `apple_toolchain_status` before selecting a debugger or device operation.
3. Start with read-only inspection: target metadata, stop state, stack, scopes, symbols, logs, traces, or artifacts.
4. Form a concrete hypothesis before taking one bounded action.
5. Verify the result with a fresh observation, readback, or artifact, then close sessions and clean up owned processes.

Use the named typed MCP tools. Never substitute arbitrary shell execution, arbitrary LLDB command injection, or guessed Apple security workarounds.

## Authorization boundaries

Launch, attach, expression evaluation, variable or memory writes, Simulator mutation, physical-device mutation, Xcode builds, and external plugin execution require the server's explicit policy grants. Never infer a grant from the user's debugging intent, enable an environment gate on your own, or broaden a path beyond the selected target. Memory patches must use expected-byte validation and readback/rollback when the server exposes those controls.

Treat Simulator results as Simulator evidence, not physical-device evidence. Stock App Store applications, unauthorized devices, signing bypasses, Developer Mode bypasses, SIP changes, kernel memory writes, and unsupported reverse execution/time travel are outside the supported boundary.

## Evidence standard

Keep the target identifier, artifact paths, build or dSYM identity, installed Apple toolchain, policy result, and cleanup result visible in the final explanation. Distinguish observed evidence from an AI hypothesis. Do not claim exact process-state restoration from checkpoint replay or native reverse execution when the installed Apple LLDB does not provide it.

The MCP server is local and normally runs over stdio from this plugin. A menu-bar-supervised authenticated loopback daemon is optional; it is not a remote or LAN debugger service.
