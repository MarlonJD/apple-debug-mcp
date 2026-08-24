#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

identity=${CODESIGN_IDENTITY:-}
notary_profile=${NOTARY_PROFILE:-general-notary}
version=${RELEASE_VERSION:-0.1.0}
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
cp Resources/AppleDebugMCP-Info.plist "$contents_path/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$contents_path/Info.plist"
plutil -replace CFBundleVersion -string "$version" "$contents_path/Info.plist"
cp LICENSE README.md ARCHITECTURE.md "$contents_path/Resources/"

codesign --force --options runtime --timestamp --sign "$identity" "$app_path"
codesign --verify --deep --strict --verbose=2 "$app_path"

unsigned_submission="$staging_directory/apple-debug-mcp-notary-input.zip"
ditto -c -k --keepParent "$app_path" "$unsigned_submission"
xcrun notarytool submit "$unsigned_submission" \
    --keychain-profile "$notary_profile" \
    --wait \
    --output-format json

xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=4 "$app_path"

mkdir -p "$(dirname -- "$output_path")"
ditto -c -k --keepParent "$app_path" "$output_path"
printf 'release: created signed and notarized macOS app archive at %s\n' "$output_path"
