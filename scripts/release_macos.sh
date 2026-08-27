#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

identity=${CODESIGN_IDENTITY:-}
notary_profile=${NOTARY_PROFILE:-general-notary}
version=${RELEASE_VERSION:-0.1.0}
plugin_xpc_bundle=${PLUGIN_XPC_BUNDLE:-}
architecture=$(uname -m)
output_path=${1:-"$root/dist/apple-debug-mcp-macos-$architecture-notarized.zip"}

if [ -z "$identity" ]; then
    printf '%s\n' 'release: set CODESIGN_IDENTITY to a Developer ID Application identity' >&2
    exit 1
fi
case "$output_path" in
    *.zip) ;;
    *) printf '%s\n' 'release: output path must end with .zip' >&2; exit 1 ;;
esac
if [ -e "$output_path" ]; then
    printf 'release: output already exists: %s\n' "$output_path" >&2
    exit 1
fi

security find-identity -p codesigning -v | grep -Fq "\"$identity\"" || {
    printf 'release: signing identity is not available: %s\n' "$identity" >&2
    exit 1
}

swift build -c release >/dev/null

staging_directory=$(mktemp -d "${TMPDIR:-/tmp}/apple-debug-mcp-release.XXXXXX")
trap 'rm -rf "$staging_directory"' EXIT HUP INT TERM

app_path="$staging_directory/AppleDebugMCP.app"
contents_path="$app_path/Contents"
mkdir -p "$contents_path/MacOS" "$contents_path/Resources"
cp .build/release/apple-debug-mcp "$contents_path/MacOS/apple-debug-mcp"
cp .build/release/apple-debug-plugin-host "$contents_path/MacOS/apple-debug-plugin-host"
cp Resources/AppleDebugMCP-Info.plist "$contents_path/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$contents_path/Info.plist"
plutil -replace CFBundleVersion -string "$version" "$contents_path/Info.plist"
cp LICENSE README.md ARCHITECTURE.md "$contents_path/Resources/"

menu_bar_app_path="$staging_directory/AppleDebugMenuBar.app"
mkdir -p "$menu_bar_app_path/Contents/MacOS" "$menu_bar_app_path/Contents/Resources"
cp .build/release/apple-debug-menubar "$menu_bar_app_path/Contents/MacOS/AppleDebugMenuBar"
cp .build/release/apple-debug-mcp "$menu_bar_app_path/Contents/Resources/apple-debug-mcp"
cp Resources/AppleDebugMenuBar-Info.plist "$menu_bar_app_path/Contents/Info.plist"
cp LICENSE README.md "$menu_bar_app_path/Contents/Resources/"
chmod +x "$menu_bar_app_path/Contents/MacOS/AppleDebugMenuBar" "$menu_bar_app_path/Contents/Resources/apple-debug-mcp"

codesign --force --options runtime --timestamp --sign "$identity" "$contents_path/MacOS/apple-debug-mcp"
codesign --force --options runtime --timestamp --sign "$identity" "$contents_path/MacOS/apple-debug-plugin-host"
codesign --force --options runtime --timestamp --sign "$identity" "$menu_bar_app_path/Contents/Resources/apple-debug-mcp"

if [ -n "$plugin_xpc_bundle" ]; then
    case "$plugin_xpc_bundle" in
        *.xpc) ;;
        *) printf '%s\n' 'release: PLUGIN_XPC_BUNDLE must point to an .xpc bundle' >&2; exit 1 ;;
    esac
    if [ ! -d "$plugin_xpc_bundle" ]; then
        printf 'release: plugin XPC bundle does not exist: %s\n' "$plugin_xpc_bundle" >&2
        exit 1
    fi
    mkdir -p "$contents_path/XPCServices"
    cp -R "$plugin_xpc_bundle" "$contents_path/XPCServices/$(basename -- "$plugin_xpc_bundle")"
    codesign --force --options runtime --timestamp --sign "$identity" "$contents_path/XPCServices/$(basename -- "$plugin_xpc_bundle")"
fi

codesign --force --options runtime --timestamp --sign "$identity" "$app_path"
codesign --force --options runtime --timestamp --sign "$identity" "$menu_bar_app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"
codesign --verify --deep --strict --verbose=2 "$menu_bar_app_path"

notary_payload="$staging_directory/apple-debug-mcp-notary-payload"
mkdir -p "$notary_payload"
ditto "$app_path" "$notary_payload/AppleDebugMCP.app"
ditto "$menu_bar_app_path" "$notary_payload/AppleDebugMenuBar.app"
unsigned_submission="$staging_directory/apple-debug-mcp-notary-input.zip"
ditto -c -k --sequesterRsrc --keepParent "$notary_payload" "$unsigned_submission"
xcrun notarytool submit "$unsigned_submission" \
    --keychain-profile "$notary_profile" \
    --wait \
    --output-format json

xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
xcrun stapler staple "$menu_bar_app_path"
xcrun stapler validate "$menu_bar_app_path"
spctl --assess --type execute --verbose=4 "$app_path"
spctl --assess --type execute --verbose=4 "$menu_bar_app_path"

mkdir -p "$(dirname -- "$output_path")"
distribution_directory="$staging_directory/apple-debug-mcp-release"
mkdir -p "$distribution_directory"
ditto "$app_path" "$distribution_directory/AppleDebugMCP.app"
ditto "$menu_bar_app_path" "$distribution_directory/AppleDebugMenuBar.app"
cp scripts/install_mcp.sh "$distribution_directory/install_mcp.sh"
chmod +x "$distribution_directory/install_mcp.sh"
ditto -c -k --sequesterRsrc --keepParent "$distribution_directory" "$output_path"
printf 'release: created signed and notarized macOS app archive at %s\n' "$output_path"
