# macOS release

The local `make package` target creates an unsigned tar archive for development and CI. The archive contains the MCP executable and a standalone `AppleDebugMenuBar.app` bundle with the MCP executable embedded in `Contents/Resources/`. The notarized release target builds and signs both `AppleDebugMCP.app` and `AppleDebugMenuBar.app` with a Developer ID Application identity, submits both in one zip to Apple Notary Service, staples the tickets, validates Gatekeeper acceptance, and writes a stapled zip under `dist/`.

Use the keychain profile already configured on the release Mac:

```sh
CODESIGN_IDENTITY='Developer ID Application: Burak Karahan (UPK4SC93AN)' \
NOTARY_PROFILE=general-notary \
make release-package
```

The resulting MCP executable is inside `AppleDebugMCP.app/Contents/MacOS/apple-debug-mcp`; the menu bar executable is inside `AppleDebugMenuBar.app/Contents/MacOS/AppleDebugMenuBar`, with its supervised daemon child at `Contents/Resources/apple-debug-mcp`. Install the signed menu bar app in `/Applications` before enabling `Launch at Login`; it uses `SMAppService.mainApp`, starts the child in `--daemon` mode, and publishes a user-private authenticated loopback endpoint. The separately signed `apple-debug-plugin-host` is colocated in the main app bundle. A production third-party plugin is an independently signed `.xpc` service implementing `AppleDebugPluginXPCProtocol`; embed one during release with `PLUGIN_XPC_BUNDLE=/absolute/path/Analyzer.xpc` and pass its bundle identifier as `serviceName` to `apple_plugin_host_execute`. The legacy `transport=profile` path remains only for explicit local diagnostics. An MCP client can use the MCP executable path after extracting the archive, or read `~/Library/Application Support/AppleDebugMCP/endpoint.json` when the menu bar daemon is running. The signing identity and notary credentials are read from the local keychain and are never stored in this repository.

## End-user MCP installation

The menu bar app is a self-contained supervisor bundle; it does not require a separately installed Swift compiler, Python runtime, Node.js, Homebrew package, or daemon binary. Extract the archive, move `AppleDebugMenuBar.app` to `/Applications`, and open it. The app can then start and stop its embedded `apple-debug-mcp --daemon` child and expose its local status popover.

For the simplest Codex CLI or Claude Code setup, register the embedded executable as a local stdio server:

```sh
MCP_SERVER=/Applications/AppleDebugMenuBar.app/Contents/Resources/apple-debug-mcp

codex mcp add apple-debug-mcp -- "$MCP_SERVER"
claude mcp add --scope user --transport stdio apple-debug-mcp -- "$MCP_SERVER"
```

Archives produced after the client-integration change include `install_mcp.sh` at their top level. After moving the app, run `./install_mcp.sh --client auto` from the extracted archive directory; it detects installed Codex/Claude CLIs, registers only the clients it finds, and leaves existing same-named entries unchanged. The published `v0.1.0` archive predates this helper, but the direct commands work with it.

The helper registers stdio and does not enable any mutation grant. The menu bar supervisor and stdio client registration are separate modes: use the supervisor for login/status/log/shutdown control, and use the stdio registration for a client-managed local MCP process. A client using the menu bar daemon directly must read the user-private endpoint metadata and bearer token; the endpoint is loopback-only and is not an internet or LAN service.

Codex CLI and Claude Code use their own `mcp add` commands rather than a shared `mcp install` command. See the [Codex MCP documentation](https://developers.openai.com/codex/mcp) and [Claude Code MCP documentation](https://code.claude.com/docs/en/mcp) for client-side configuration options.

## Codex and Claude Code plugin distribution

The repository includes an AWS Agent Toolkit-style repo marketplace at `.agents/plugins/marketplace.json` and the `Apple Debug` plugin under `plugins/apple-debug/`. The plugin carries both `.codex-plugin/plugin.json` and `.claude-plugin/plugin.json`, a shared skill, and `.mcp.json`; the packaging scripts add the release-built MCP executable as `plugins/apple-debug/bin/apple-debug-mcp-bin` so the plugin can start the local server without a separate MCP registration.

For a source checkout, add the repository as a Codex marketplace and install `Apple Debug` from `/plugins`:

```sh
codex plugin marketplace add /absolute/path/to/apple-debug-mcp
```

For an archive produced by the current repository, use the extracted `apple-debug-mcp` (unsigned) or `apple-debug-mcp-release` (signed) directory as the marketplace root. The published `v0.1.0` archive predates this plugin. Start a new Codex session after installation. The plugin launcher prefers its packaged executable and then falls back to an explicit `APPLE_DEBUG_MCP_EXECUTABLE`, a local SwiftPM build, or the signed application bundles. It only starts the stdio MCP process; the menu-bar daemon remains an optional supervisor.

For Claude Code, run these commands in a Claude Code session:

```text
/plugin marketplace add MarlonJD/apple-debug-mcp
/plugin install apple-debug@apple-debug-mcp
/reload-plugins
```

Claude Code starts plugin-provided MCP servers automatically when the plugin is enabled; use `/mcp` to confirm the Apple Debug tools.

`make package` includes the plugin with the unsigned release-build executable. `make release-package` signs the plugin executable and includes the plugin directory in the notarization submission and final archive. Public plugin publication is a separate product decision: this repository intentionally keeps Apple target access local and loopback-only.

Before release, run `make menubar-ui-smoke` in an accessible local GUI session and `make release-package`. The release script verifies the Developer ID signature before submission and runs `codesign --verify`, `stapler validate`, and `spctl --assess` after Apple accepts the submission. Release credentials, Apple account authorization, and external notarization are intentionally not part of ordinary `make check` or pull-request CI.

## Published release

GitHub Release `v0.1.0` was published from commit `59bda012683c99fdd7c95dbc2da25788492f23aa` with `apple-debug-mcp-macos-arm64-v0.1.0-notarized.zip`. Its SHA-256 digest is `f06f431abd24e93aa7594e1a71fa1a8d33c77929f00944d70944d4033b9c6bce`. A post-publication download verified both application bundles with strict nested-code signature checks, stapler validation, and Gatekeeper; both were accepted as notarized Developer ID applications for team `UPK4SC93AN`. The published archive predates the `install_mcp.sh` helper; direct `codex mcp add` and `claude mcp add` registration remain supported with its embedded executable.
