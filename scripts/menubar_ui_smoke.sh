#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

evidence_directory="$root/.build/evidence"
evidence_path="$evidence_directory/menubar-ui-smoke.json"
transcript=$(mktemp "${TMPDIR:-/tmp}/apple-debug-menubar-ui.XXXXXX")

cleanup() {
    pkill -x AppleDebugMenuBar >/dev/null 2>&1 || true
    pkill -f "dist/AppleDebugMenuBar.app/Contents/Resources/apple-debug-mcp --daemon" >/dev/null 2>&1 || true
    rm -f "$transcript"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$evidence_directory"
if ! ./script/build_and_run.sh --verify >"$transcript" 2>&1; then
    cat "$transcript" >&2
    exit 1
fi

open_status_item() {
    /usr/bin/osascript <<APPLESCRIPT
tell application "System Events"
    tell process "AppleDebugMenuBar"
        repeat 10 times
            try
                if (count of windows) > 0 then
                    return "already-open"
                end if
                if (count of menu bars) >= 2 then
                    click menu bar item 1 of menu bar 2
                    delay 0.5
                    if (count of windows) > 0 then
                        return "opened"
                    end if
                end if
            end try
            delay 0.5
        end repeat
        error "Apple Debug MCP status item did not open a popover"
    end tell
end tell
APPLESCRIPT
}

popover_probe() {
    /usr/bin/osascript <<APPLESCRIPT
set text item delimiters to linefeed
tell application "System Events"
    tell process "AppleDebugMenuBar"
        if (count of windows) < 1 then
            error "Apple Debug MCP popover is not visible"
        end if
        set targetWindow to window 1
        set rootGroup to first UI element of targetWindow whose role is "AXGroup"
        set outputLines to {"window:" & (name of targetWindow as text)}
        set buttonCount to 0
        set checkboxCount to 0
        repeat with elementRef in UI elements of rootGroup
            set elementElement to contents of elementRef
            try
                set elementRole to role of elementElement
                if elementRole is "AXButton" then
                    set buttonCount to buttonCount + 1
                else if elementRole is "AXCheckBox" then
                    set checkboxCount to checkboxCount + 1
                else if elementRole is "AXStaticText" then
                    set elementValue to value of elementElement
                    if elementValue is not missing value and elementValue is not "" then
                        set end of outputLines to "text:" & (elementValue as text)
                    end if
                end if
            end try
        end repeat
        set end of outputLines to "buttons:" & (buttonCount as text)
        set end of outputLines to "checkboxes:" & (checkboxCount as text)
        return outputLines as text
    end tell
end tell
APPLESCRIPT
}

press_button() {
    /usr/bin/osascript - "$1" <<APPLESCRIPT
on run argv
    set targetIndex to (item 1 of argv) as integer
    tell application "System Events"
        tell process "AppleDebugMenuBar"
            if (count of windows) < 1 then
                error "Apple Debug MCP popover is not visible"
            end if
            set targetWindow to window 1
            set rootGroup to first UI element of targetWindow whose role is "AXGroup"
            set buttonElements to {}
            repeat with elementRef in UI elements of rootGroup
                set elementElement to contents of elementRef
                try
                    if (role of elementElement) is "AXButton" then
                        set end of buttonElements to elementElement
                    end if
                end try
            end repeat
            if targetIndex is -1 then
                set targetIndex to count of buttonElements
            end if
            if targetIndex < 1 or targetIndex > (count of buttonElements) then
                error "Requested menu bar button index is unavailable"
            end if
            click item targetIndex of buttonElements
        end tell
end tell
        return ""
end run
APPLESCRIPT
}

probe_popover() {
    attempt=0
    while [ "$attempt" -lt 10 ]; do
        if probe=$(popover_probe 2>/dev/null); then
            printf '%s\n' "$probe"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.5
    done
    popover_probe
}

assert_contains() {
    value=$1
    expected=$2
    case "$value" in
        *"$expected"*) ;;
        *)
            printf 'menubar-ui-smoke: expected text was missing: %s\n%s\n' "$expected" "$value" >&2
            exit 1
            ;;
    esac
}

open_status_item >/dev/null
initial_probe=$(probe_popover)
assert_contains "$initial_probe" "text:Apple Debug MCP"
assert_contains "$initial_probe" "MCP running"
assert_contains "$initial_probe" "checkboxes:2"

press_button 1 >/dev/null
sleep 2
open_status_item >/dev/null
stopped_probe=$(probe_popover)
assert_contains "$stopped_probe" "MCP stopped"

press_button 1 >/dev/null
ready=0
attempt=0
while [ "$attempt" -lt 15 ]; do
    if python3 ./scripts/mcp_endpoint_health.py >/dev/null 2>&1; then
        ready=1
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done
if [ "$ready" -ne 1 ]; then
    printf '%s\n' 'menubar-ui-smoke: daemon did not become healthy after restart' >&2
    cat "$transcript" >&2
    exit 1
fi

open_status_item >/dev/null
restarted_probe=$(probe_popover)
assert_contains "$restarted_probe" "MCP running"
press_button 2 >/dev/null
open_status_item >/dev/null
copied_probe=$(probe_popover)
assert_contains "$copied_probe" "MCP endpoint URL copied."

press_button -1 >/dev/null
attempt=0
while [ "$attempt" -lt 10 ]; do
    if ! pgrep -x AppleDebugMenuBar >/dev/null 2>&1; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 1
done
if pgrep -x AppleDebugMenuBar >/dev/null 2>&1; then
    printf '%s\n' 'menubar-ui-smoke: Quit did not terminate AppleDebugMenuBar' >&2
    exit 1
fi

telemetry=$(/usr/bin/log show --last 3m --info --style compact --predicate 'subsystem == "com.burakkarahan.apple-debug-menubar"' 2>/dev/null || true)
assert_contains "$telemetry" "MCP server start requested"
assert_contains "$telemetry" "MCP server stop requested"
assert_contains "$telemetry" "Menu bar quit requested"

python3 - "$evidence_path" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps({
    "status": "passed",
    "workflow": "menubar-ui-v1",
    "checks": [
        "running-popover",
        "stop-restart",
        "endpoint-health-after-restart",
        "copy-endpoint-action",
        "quit-cleanup",
        "menu-bar-telemetry",
    ],
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

printf 'menubar-ui-smoke: popover, stop/restart, endpoint copy, Quit cleanup, and telemetry passed\n'
printf 'menubar-ui-smoke: evidence manifest written to %s\n' "$evidence_path"
