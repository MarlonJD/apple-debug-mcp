#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

if [ "${APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION:-0}" != "1" ]; then
    printf '%s\n' 'ios-fixture-smoke: set APPLE_DEBUG_ALLOW_SIMULATOR_MUTATION=1 for this explicit local workflow' >&2
    exit 1
fi

app_path=$(./scripts/build_ios_fixture.sh | tail -1)
simulator_id=$(xcrun simctl list devices available --json | python3 -c 'import json,sys; data=json.load(sys.stdin); devices=data["devices"]; candidates=[d for runtime,items in devices.items() if "iOS" in runtime for d in items if d.get("isAvailable",True)]; print(candidates[0]["udid"] if candidates else "")')
if [ -z "$simulator_id" ]; then
    printf '%s\n' 'ios-fixture-smoke: no available iOS Simulator found' >&2
    exit 1
fi

state=$(xcrun simctl list devices --json | python3 -c 'import json,sys; data=json.load(sys.stdin); target=sys.argv[1]; print(next((d["state"] for items in data["devices"].values() for d in items if d.get("udid")==target), ""))' "$simulator_id")
started_here=0
if [ "$state" != "Booted" ]; then
    xcrun simctl boot "$simulator_id"
    xcrun simctl bootstatus "$simulator_id" -b
    started_here=1
fi

screenshot="$root/.build/ios-fixture/ios-fixture.png"
xcrun simctl install "$simulator_id" "$app_path"
xcrun simctl launch "$simulator_id" com.burakkarahan.AppleDebugFixture
xcrun simctl io "$simulator_id" screenshot "$screenshot" >/dev/null
xcrun simctl terminate "$simulator_id" com.burakkarahan.AppleDebugFixture

if [ "$started_here" = "1" ]; then
    xcrun simctl shutdown "$simulator_id"
fi

if [ ! -s "$screenshot" ]; then
    printf 'ios-fixture-smoke: screenshot missing or empty: %s\n' "$screenshot" >&2
    exit 1
fi

printf 'ios-fixture-smoke: install, launch, screenshot, terminate, and cleanup passed for %s\n' "$simulator_id"
