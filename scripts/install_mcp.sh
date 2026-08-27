#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -d "$script_dir/AppleDebugMenuBar.app" ] || [ -x "$script_dir/apple-debug-mcp" ]; then
    package_root="$script_dir"
else
    package_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
fi

user_name=$(/usr/bin/id -un)
user_home=$(/usr/bin/dscl . -read "/Users/$user_name" NFSHomeDirectory 2>/dev/null | /usr/bin/awk '{print $2}' || true)
client=auto
scope=user
server_name=apple-debug-mcp
server_path=

usage() {
    status=${1:-0}
    cat <<'EOF'
Usage: install_mcp.sh [options]

Register the bundled Apple Debug MCP stdio server with an installed client.

Options:
  --client auto|codex|claude|both  Client(s) to configure (default: auto)
  --name NAME                     MCP server name (default: apple-debug-mcp)
  --scope user|project|local      Claude Code scope (default: user)
  --server-path PATH              Explicit absolute path to apple-debug-mcp
  -h, --help                      Show this help

The helper never enables debugger, evaluation, memory-write, device-mutation,
or other grants. Existing entries with the same name are left unchanged.
EOF
    exit "$status"
}

fail() {
    printf 'install-mcp: %s\n' "$1" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --client)
            [ "$#" -ge 2 ] || fail '--client requires a value'
            client=$2
            shift 2
            ;;
        --name)
            [ "$#" -ge 2 ] || fail '--name requires a value'
            server_name=$2
            shift 2
            ;;
        --scope)
            [ "$#" -ge 2 ] || fail '--scope requires a value'
            scope=$2
            shift 2
            ;;
        --server-path)
            [ "$#" -ge 2 ] || fail '--server-path requires a value'
            server_path=$2
            shift 2
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            fail "unknown option: $1"
            ;;
    esac
done

case "$client" in
    auto|codex|claude|both) ;;
    *) fail "unsupported client '$client' (use auto, codex, claude, or both)" ;;
esac
case "$scope" in
    user|project|local) ;;
    *) fail "unsupported Claude scope '$scope' (use user, project, or local)" ;;
esac

absolute_path() {
    candidate=$1
    case "$candidate" in
        /*) printf '%s\n' "$candidate" ;;
        *)
            candidate_directory=$(CDPATH= cd -- "$(dirname -- "$candidate")" && pwd) || fail "cannot resolve path: $candidate"
            printf '%s/%s\n' "$candidate_directory" "$(basename -- "$candidate")"
            ;;
    esac
}

select_candidate() {
    candidate=$1
    if [ -f "$candidate" ] && [ -x "$candidate" ]; then
        server_path=$candidate
        return 0
    fi
    return 1
}

if [ -n "$server_path" ]; then
    server_path=$(absolute_path "$server_path")
    [ -f "$server_path" ] && [ -x "$server_path" ] || fail "server executable is not executable: $server_path"
else
    select_candidate "/Applications/AppleDebugMenuBar.app/Contents/Resources/apple-debug-mcp" || \
    {
        if [ -n "$user_home" ]; then
            select_candidate "$user_home/Applications/AppleDebugMenuBar.app/Contents/Resources/apple-debug-mcp"
        else
            false
        fi
    } || \
    select_candidate "$package_root/AppleDebugMenuBar.app/Contents/Resources/apple-debug-mcp" || \
    select_candidate "$package_root/AppleDebugMCP.app/Contents/MacOS/apple-debug-mcp" || \
    select_candidate "$package_root/apple-debug-mcp" || \
    select_candidate "$package_root/.build/release/apple-debug-mcp" || \
    select_candidate "$package_root/.build/debug/apple-debug-mcp" || \
    fail 'bundled apple-debug-mcp was not found; pass --server-path PATH'
fi

register_codex() {
    command -v codex >/dev/null 2>&1 || fail 'Codex CLI was not found on PATH'
    if codex mcp get "$server_name" >/dev/null 2>&1; then
        printf 'Codex: %s already exists; leaving the existing configuration unchanged.\n' "$server_name"
        return 0
    fi
    codex mcp add "$server_name" -- "$server_path"
    printf 'Codex: registered %s -> %s\n' "$server_name" "$server_path"
}

register_claude() {
    command -v claude >/dev/null 2>&1 || fail 'Claude Code CLI was not found on PATH'
    if claude mcp get "$server_name" >/dev/null 2>&1; then
        printf 'Claude Code: %s already exists; leaving the existing configuration unchanged.\n' "$server_name"
        return 0
    fi
    claude mcp add --scope "$scope" --transport stdio "$server_name" -- "$server_path"
    printf 'Claude Code: registered %s -> %s (scope=%s)\n' "$server_name" "$server_path" "$scope"
}

configured=0
case "$client" in
    auto)
        if command -v codex >/dev/null 2>&1; then
            register_codex
            configured=1
        fi
        if command -v claude >/dev/null 2>&1; then
            register_claude
            configured=1
        fi
        [ "$configured" -eq 1 ] || fail 'neither Codex CLI nor Claude Code CLI was found on PATH'
        ;;
    codex)
        register_codex
        ;;
    claude)
        register_claude
        ;;
    both)
        register_codex
        register_claude
        ;;
esac

printf '%s\n' 'install-mcp: registration complete; restart the client or run its MCP status command.'
exit_code=0
