#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
device_identifier=${APPLE_DEBUG_PHYSICAL_UDID:-}
if [ -z "$device_identifier" ]; then
    printf '%s\n' 'build-ios-physical-fixture: set APPLE_DEBUG_PHYSICAL_UDID to an authorized device UDID' >&2
    exit 1
fi

derived_data_path="$root/.build/ios-physical-fixture"
xcodebuild \
    -project "$root/Tests/Fixtures/iOSDebugApp/DebugApp.xcodeproj" \
    -scheme DebugApp \
    -configuration Debug \
    -destination "id=$device_identifier" \
    -derivedDataPath "$derived_data_path" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration \
    build

app_path="$derived_data_path/Build/Products/Debug-iphoneos/DebugApp.app"
if [ ! -d "$app_path" ]; then
    printf 'build-ios-physical-fixture: missing output bundle: %s\n' "$app_path" >&2
    exit 1
fi
printf '%s\n' "$app_path"
