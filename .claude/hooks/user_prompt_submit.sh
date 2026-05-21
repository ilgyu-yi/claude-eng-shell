#!/usr/bin/env bash
set -uo pipefail

SHELL_ROOT="${CLAUDE_ENG_SHELL_ROOT:-}"
[ -n "$SHELL_ROOT" ] && [ -d "$SHELL_ROOT/.claude/hooks/helpers" ] || exit 0

. "$SHELL_ROOT/.claude/hooks/helpers/cwd_guard.sh"
in_scope || exit 0

# Delegate to the canonical work-state helper (SPEC §5.5). Same source as
# /status — so the per-turn injection and the on-demand command never drift.
# shellcheck disable=SC1090,SC1091
. "$SHELL_ROOT/.claude/hooks/helpers/status.sh"
status_compact
exit 0
