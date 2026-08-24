#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

fixture_dir="$root/.build/fixtures"
fixture_binary="$fixture_dir/apple-debug-mcp-debug-target"
mkdir -p "$fixture_dir"

clang -g -O0 Tests/Fixtures/debug_target.c -o "$fixture_binary"
codesign --force --sign - --entitlements Tests/Fixtures/debug_target.entitlements "$fixture_binary" >/dev/null

printf '%s\n' "$fixture_binary"
