# macOS release

The local `make package` target creates an unsigned tar archive for development and CI. The archive contains the MCP executable and a standalone `AppleDebugMenuBar.app` bundle with the MCP executable embedded in `Contents/Resources/`. The notarized release target builds and signs both `AppleDebugMCP.app` and `AppleDebugMenuBar.app` with a Developer ID Application identity, submits both in one zip to Apple Notary Service, staples the tickets, validates Gatekeeper acceptance, and writes a stapled zip under `dist/`.

Use the keychain profile already configured on the release Mac:

```sh
CODESIGN_IDENTITY='Developer ID Application: Burak Karahan (UPK4SC93AN)' \
NOTARY_PROFILE=general-notary \
make release-package
```

The resulting MCP executable is inside `AppleDebugMCP.app/Contents/MacOS/apple-debug-mcp`; the menu bar executable is inside `AppleDebugMenuBar.app/Contents/MacOS/AppleDebugMenuBar`, with its supervised MCP child at `Contents/Resources/apple-debug-mcp`. Install the signed menu bar app in `/Applications` before enabling `Launch at Login`; it uses `SMAppService.mainApp` and keeps the MCP transport stdio-only. The separately signed `apple-debug-plugin-host` is colocated in the main app bundle. A production third-party plugin is an independently signed `.xpc` service implementing `AppleDebugPluginXPCProtocol`; embed one during release with `PLUGIN_XPC_BUNDLE=/absolute/path/Analyzer.xpc` and pass its bundle identifier as `serviceName` to `apple_plugin_host_execute`. The legacy `transport=profile` path remains only for explicit local diagnostics. An MCP client can use the MCP executable path after extracting the archive. The signing identity and notary credentials are read from the local keychain and are never stored in this repository.

The release script verifies the Developer ID signature before submission and runs `codesign --verify`, `stapler validate`, and `spctl --assess` after Apple accepts the submission. Release credentials, Apple account authorization, and external notarization are intentionally not part of ordinary `make check` or pull-request CI.
