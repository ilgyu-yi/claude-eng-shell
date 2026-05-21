#!/usr/bin/env bash
set -uo pipefail

SHELL_ROOT="${CLAUDE_ENG_SHELL_ROOT:-}"
[ -n "$SHELL_ROOT" ] && [ -d "$SHELL_ROOT/.claude/hooks/helpers" ] || exit 0

. "$SHELL_ROOT/.claude/hooks/helpers/cwd_guard.sh"

in_scope || exit 0
command -v git >/dev/null 2>&1 || exit 0

# Simple modulo throttle: suggest only when response_count is a multiple of N.
count_file="$SHELL_ROOT/.claude/state/stop_count"
count=$(cat "$count_file" 2>/dev/null || echo 0)
count=$((count + 1))
printf '%s\n' "$count" > "$count_file"

throttle_n=${CLAUDE_ENG_STOP_THROTTLE:-5}
[ $((count % throttle_n)) -ne 0 ] && exit 0

# Suggest /review when uncommitted changes are present.
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  printf '[claude-eng-shell] uncommitted changes present. consider /review.\n' >&2
fi

exit 0
