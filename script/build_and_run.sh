#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AppleDebugMenuBar"
SERVER_NAME="apple-debug-mcp"
MENU_BAR_PRODUCT="apple-debug-menubar"
BUNDLE_ID="com.burakkarahan.apple-debug-menubar"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -f "^$APP_BUNDLE/Contents/Resources/$SERVER_NAME( --daemon)?$" >/dev/null 2>&1 || true

cd "$ROOT_DIR"
swift build --product "$MENU_BAR_PRODUCT"
swift build --product "$SERVER_NAME"

BUILD_BIN="$(swift build --show-bin-path)"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BIN/$MENU_BAR_PRODUCT" "$APP_BINARY"
cp "$BUILD_BIN/$SERVER_NAME" "$APP_RESOURCES/$SERVER_NAME"
cp Resources/AppleDebugMenuBar-Info.plist "$APP_CONTENTS/Info.plist"
cp LICENSE README.md "$APP_RESOURCES/"
chmod +x "$APP_BINARY" "$APP_RESOURCES/$SERVER_NAME"

SIGNING_IDENTITY="${CODESIGN_IDENTITY:--}"
codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_BUNDLE" >/dev/null

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
    run)
        open_app
        ;;
    --debug|debug)
        lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\" OR process == \"$APP_NAME\""
        ;;
    --verify|verify)
        open_app
        sleep 1
        pgrep -x "$APP_NAME" >/dev/null
        pgrep -f "^$APP_BUNDLE/Contents/Resources/$SERVER_NAME --daemon$" >/dev/null
        python3 "$ROOT_DIR/scripts/mcp_endpoint_health.py"
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
