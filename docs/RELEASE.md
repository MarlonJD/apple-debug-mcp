# macOS release

The local `make package` target creates an unsigned tar archive for development and CI. The notarized release target builds an `AppleDebugMCP.app` bundle, signs it with a Developer ID Application identity, submits a zip to Apple Notary Service, staples the ticket, validates Gatekeeper acceptance, and writes a stapled zip under `dist/`.

Use the keychain profile already configured on the release Mac:

```sh
CODESIGN_IDENTITY='Developer ID Application: Burak Karahan (UPK4SC93AN)' \
NOTARY_PROFILE=general-notary \
make release-package
```

The resulting MCP executable is inside `AppleDebugMCP.app/Contents/MacOS/apple-debug-mcp`. An MCP client can use that executable path after extracting the archive. The signing identity and notary credentials are read from the local keychain and are never stored in this repository.

The release script verifies the Developer ID signature before submission and runs `codesign --verify`, `stapler validate`, and `spctl --assess` after Apple accepts the submission. Release credentials, Apple account authorization, and external notarization are intentionally not part of ordinary `make check` or pull-request CI.
