#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

simulator_id=$(xcrun simctl list devices available --json | python3 -c 'import json,sys; data=json.load(sys.stdin); devices=data["devices"]; candidates=[d for runtime,items in devices.items() if "iOS" in runtime for d in items if d.get("isAvailable",True)]; print(candidates[0]["udid"] if candidates else "")')
if [ -z "$simulator_id" ]; then
    printf '%s\n' 'ios-fixture: no available iOS Simulator found' >&2
    exit 1
fi

derived_data="$root/.build/ios-fixture"
xcodebuild \
    -project Tests/Fixtures/iOSDebugApp/DebugApp.xcodeproj \
    -scheme DebugApp \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    build

app_path="$derived_data/Build/Products/Debug-iphonesimulator/DebugApp.app"
if [ ! -d "$app_path" ]; then
    printf 'ios-fixture: expected app bundle missing: %s\n' "$app_path" >&2
    exit 1
fi

printf '%s\n' "$app_path"
