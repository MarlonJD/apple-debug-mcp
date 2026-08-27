# macOS release

The local `make package` target creates an unsigned tar archive for development and CI. The archive contains the MCP executable and a standalone `AppleDebugMenuBar.app` bundle with the MCP executable embedded in `Contents/Resources/`. The notarized release target builds and signs both `AppleDebugMCP.app` and `AppleDebugMenuBar.app` with a Developer ID Application identity, submits both in one zip to Apple Notary Service, staples the tickets, validates Gatekeeper acceptance, and writes a stapled zip under `dist/`.

Use the keychain profile already configured on the release Mac:

```sh
CODESIGN_IDENTITY='Developer ID Application: Burak Karahan (UPK4SC93AN)' \
NOTARY_PROFILE=general-notary \
make release-package
```

The resulting MCP executable is inside `AppleDebugMCP.app/Contents/MacOS/apple-debug-mcp`; the menu bar executable is inside `AppleDebugMenuBar.app/Contents/MacOS/AppleDebugMenuBar`, with its supervised daemon child at `Contents/Resources/apple-debug-mcp`. Install the signed menu bar app in `/Applications` before enabling `Launch at Login`; it uses `SMAppService.mainApp`, starts the child in `--daemon` mode, and publishes a user-private authenticated loopback endpoint. The separately signed `apple-debug-plugin-host` is colocated in the main app bundle. A production third-party plugin is an independently signed `.xpc` service implementing `AppleDebugPluginXPCProtocol`; embed one during release with `PLUGIN_XPC_BUNDLE=/absolute/path/Analyzer.xpc` and pass its bundle identifier as `serviceName` to `apple_plugin_host_execute`. The legacy `transport=profile` path remains only for explicit local diagnostics. An MCP client can use the MCP executable path after extracting the archive, or read `~/Library/Application Support/AppleDebugMCP/endpoint.json` when the menu bar daemon is running. The signing identity and notary credentials are read from the local keychain and are never stored in this repository.

Before release, run `make menubar-ui-smoke` in an accessible local GUI session and `make release-package`. The release script verifies the Developer ID signature before submission and runs `codesign --verify`, `stapler validate`, and `spctl --assess` after Apple accepts the submission. Release credentials, Apple account authorization, and external notarization are intentionally not part of ordinary `make check` or pull-request CI.

## Published release

GitHub Release `v0.1.0` was published from commit `59bda012683c99fdd7c95dbc2da25788492f23aa` with `apple-debug-mcp-macos-arm64-v0.1.0-notarized.zip`. Its SHA-256 digest is `f06f431abd24e93aa7594e1a71fa1a8d33c77929f00944d70944d4033b9c6bce`. A post-publication download verified both application bundles with strict nested-code signature checks, stapler validation, and Gatekeeper; both were accepted as notarized Developer ID applications for team `UPK4SC93AN`.
