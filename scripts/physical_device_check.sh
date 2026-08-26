#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

ran=0

if [ -n "${APPLE_DEBUG_PHYSICAL_UDID:-}" ]; then
    if [ -z "${APPLE_DEBUG_PHYSICAL_APP:-}" ]; then
        ./scripts/build_ios_physical_fixture.sh >/dev/null
    fi
    APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1 \
        APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1 \
        APPLE_DEBUG_ALLOW_EVALUATE=1 \
        APPLE_DEBUG_ALLOW_MEMORY_WRITE=1 \
        python3 ./scripts/ios_legacy_debug_control_smoke.py
    ran=1
fi

if [ -n "${APPLE_DEBUG_COREDEVICE_ID:-}" ]; then
    if [ -z "${APPLE_DEBUG_PHYSICAL_APP:-}" ] && [ -z "${APPLE_DEBUG_PHYSICAL_UDID:-}" ]; then
        printf '%s\n' 'physical-device-check: APPLE_DEBUG_PHYSICAL_APP is required for CoreDevice-only runs' >&2
        exit 2
    fi
    APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1 \
        python3 ./scripts/ios_coredevice_lifecycle_smoke.py
    APPLE_DEBUG_ALLOW_DEVICE_DEBUG=1 \
        APPLE_DEBUG_ALLOW_DEVICE_MUTATION=1 \
        APPLE_DEBUG_ALLOW_EVALUATE=1 \
        APPLE_DEBUG_ALLOW_MEMORY_WRITE=1 \
        python3 ./scripts/ios_coredevice_debug_control_smoke.py
    ran=1
fi

if [ "$ran" = "0" ]; then
    printf '%s\n' 'physical-device-check: set APPLE_DEBUG_PHYSICAL_UDID and/or APPLE_DEBUG_COREDEVICE_ID for an authorized manual run' >&2
    exit 2
fi

printf '%s\n' 'physical-device-check: authorized legacy/CoreDevice integration passed'
