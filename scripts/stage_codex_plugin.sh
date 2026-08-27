#!/bin/sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ "$#" -ne 2 ]; then
    printf '%s\n' 'Usage: stage_codex_plugin.sh DESTINATION_ROOT SERVER_EXECUTABLE' >&2
    exit 2
fi

destination=$1
server_binary=$2
source_plugin="$root/plugins/apple-debug"

[ -e "$destination" ] || mkdir -p "$destination"
[ -d "$destination" ] || {
    printf 'codex-plugin: destination does not exist: %s\n' "$destination" >&2
    exit 1
}
[ -d "$source_plugin/.codex-plugin" ] || {
    printf 'codex-plugin: source plugin is missing: %s\n' "$source_plugin" >&2
    exit 1
}
[ -f "$source_plugin/.mcp.json" ] || {
    printf 'codex-plugin: source MCP manifest is missing: %s\n' "$source_plugin/.mcp.json" >&2
    exit 1
}
[ -f "$server_binary" ] && [ -x "$server_binary" ] || {
    printf 'codex-plugin: MCP executable is not executable: %s\n' "$server_binary" >&2
    exit 1
}

plugin_destination="$destination/plugins/apple-debug"
[ ! -e "$plugin_destination" ] || {
    printf 'codex-plugin: refusing to overwrite staged plugin: %s\n' "$plugin_destination" >&2
    exit 1
}

mkdir -p \
    "$plugin_destination/bin" \
    "$plugin_destination/skills" \
    "$destination/.agents/plugins"

cp -R "$source_plugin/.codex-plugin" "$plugin_destination/"
cp "$source_plugin/.mcp.json" "$plugin_destination/.mcp.json"
cp -R "$source_plugin/skills/." "$plugin_destination/skills/"
cp "$source_plugin/bin/apple-debug-mcp-launcher" "$plugin_destination/bin/apple-debug-mcp-launcher"
cp "$server_binary" "$plugin_destination/bin/apple-debug-mcp-bin"
cp "$root/.agents/plugins/marketplace.json" "$destination/.agents/plugins/marketplace.json"

chmod +x \
    "$plugin_destination/bin/apple-debug-mcp-launcher" \
    "$plugin_destination/bin/apple-debug-mcp-bin"

printf 'codex-plugin: staged Apple Debug plugin at %s\n' "$plugin_destination"
