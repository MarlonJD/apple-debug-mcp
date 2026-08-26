#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

product=apple-debug-workbench
executable=apple-debug-workbench
bundle_identifier=com.burakkarahan.apple-debug-workbench
evidence_directory="$root/.build/evidence"
evidence_path="$evidence_directory/workbench-ui-smoke.json"

mkdir -p "$evidence_directory"
swift build --product "$product" >/dev/null

build_binary="$(swift build --show-bin-path)/$executable"
staging_directory=$(mktemp -d "${TMPDIR:-/tmp}/apple-debug-workbench-smoke.XXXXXX")
app_path="$staging_directory/AppleDebugWorkbench.app"
app_contents="$app_path/Contents"
app_macos="$app_contents/MacOS"
app_binary="$app_macos/$executable"

cleanup() {
    pkill -x "$executable" >/dev/null 2>&1 || true
    rm -rf "$staging_directory"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$app_macos"
cp "$build_binary" "$app_binary"
chmod +x "$app_binary"
cp Resources/AppleDebugMCP-Info.plist "$app_contents/Info.plist"
plutil -replace CFBundleDisplayName -string "Apple Debug Workbench" "$app_contents/Info.plist"
plutil -replace CFBundleExecutable -string "$executable" "$app_contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$bundle_identifier" "$app_contents/Info.plist"
plutil -replace CFBundleName -string "Apple Debug Workbench" "$app_contents/Info.plist"

/usr/bin/open -n "$app_path" >/dev/null

pid=""
attempt=0
while [ "$attempt" -lt 15 ]; do
    pid=$(pgrep -x "$executable" | head -n 1 || true)
    if [ -n "$pid" ]; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done

if [ -z "$pid" ]; then
    printf '%s\n' 'workbench-ui-smoke: Workbench process did not start' >&2
    exit 1
fi

ui_probe=""
attempt=0
while [ "$attempt" -lt 15 ]; do
    if ui_probe=$(/usr/bin/osascript - "$pid" 2>/dev/null <<APPLESCRIPT
on run argv
    set targetPID to (item 1 of argv) as integer
    set text item delimiters to linefeed
    tell application "System Events"
        set appProcess to first application process whose unix id is targetPID
        if (count of windows of appProcess) is less than 1 then
            error "Workbench has no visible window"
        end if

        set targetWindow to window 1 of appProcess
        set windowTitle to name of targetWindow
        set outputLines to {"window:" & windowTitle}

        set toolbarElement to first UI element of targetWindow whose role is "AXToolbar"
        repeat with elementRef in UI elements of toolbarElement
            try
                set elementDescription to description of elementRef
                if elementDescription is not missing value and elementDescription is not "" then
                    set end of outputLines to "toolbar:" & (elementDescription as text)
                end if
            end try
        end repeat

        set rootGroup to first UI element of targetWindow whose role is "AXGroup"
        set splitGroup to first UI element of rootGroup whose role is "AXSplitGroup"
        set leftGroup to first UI element of splitGroup whose role is "AXGroup"
        set scrollArea to first UI element of leftGroup whose role is "AXScrollArea"
        set sidebar to first UI element of scrollArea whose role is "AXOutline"
        repeat with rowRef in rows of sidebar
            set rowElement to contents of rowRef
            repeat with cellRef in UI elements of rowElement
                set cellElement to contents of cellRef
                repeat with labelRef in UI elements of cellElement
                    try
                        set labelValue to value of contents of labelRef
                        if labelValue is not missing value and labelValue is not "" then
                            set end of outputLines to "sidebar:" & (labelValue as text)
                        end if
                    end try
                end repeat
            end repeat
        end repeat

        return outputLines as text
    end tell
end run
APPLESCRIPT
    ); then
        if [ -n "$ui_probe" ]; then
            break
        fi
    fi
    attempt=$((attempt + 1))
    sleep 1
done

if [ -z "$ui_probe" ]; then
    printf '%s\n' 'workbench-ui-smoke: Workbench did not expose a visible window' >&2
    exit 1
fi

case "$ui_probe" in
    *"Apple Debug Workbench"*) ;;
    *)
        printf '%s\n' 'workbench-ui-smoke: expected Workbench window title was not exposed' >&2
        printf '%s\n' "$ui_probe" >&2
        exit 1
        ;;
esac

for required_label in "Open Target" "Open Evidence" "Evidence"; do
    case "$ui_probe" in
        *"$required_label"*) ;;
        *)
            printf 'workbench-ui-smoke: accessibility label missing: %s\n' "$required_label" >&2
            printf '%s\n' "$ui_probe" >&2
            exit 1
            ;;
    esac
done

python3 - "$evidence_path" "$app_path" "$pid" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps({
    "status": "passed",
    "workflow": "workbench-ui-v1",
    "bundlePath": sys.argv[2],
    "processID": int(sys.argv[3]),
    "checks": ["process-started", "visible-window", "toolbar-open-target", "toolbar-open-evidence", "sidebar-evidence"],
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

printf 'workbench-ui-smoke: visible Workbench window and required accessibility labels passed\n'
printf 'workbench-ui-smoke: evidence manifest written to %s\n' "$evidence_path"
