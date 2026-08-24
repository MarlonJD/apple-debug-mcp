#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

swift build -c release >/dev/null

architecture=$(uname -m)
output_path=${1:-"$root/dist/apple-debug-mcp-macos-$architecture.tar.gz"}
output_directory=$(dirname -- "$output_path")
mkdir -p "$output_directory"

if [ -e "$output_path" ]; then
    printf 'package: output already exists: %s\n' "$output_path" >&2
    exit 1
fi

staging_directory=$(mktemp -d "${TMPDIR:-/tmp}/apple-debug-mcp-package.XXXXXX")
trap 'rm -rf "$staging_directory"' EXIT HUP INT TERM

package_directory="$staging_directory/apple-debug-mcp"
mkdir -p "$package_directory"
cp .build/release/apple-debug-mcp "$package_directory/apple-debug-mcp"
cp .build/release/apple-debug-plugin-host "$package_directory/apple-debug-plugin-host"
cp LICENSE README.md ARCHITECTURE.md "$package_directory/"

tar -czf "$output_path" -C "$staging_directory" apple-debug-mcp
printf 'package: created unsigned macOS archive at %s\n' "$output_path"
