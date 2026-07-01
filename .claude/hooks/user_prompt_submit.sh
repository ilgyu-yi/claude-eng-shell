#!/usr/bin/env bash
set -uo pipefail

SHELL_ROOT="${GHJIG_SHELL_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}"
[ -n "$SHELL_ROOT" ] && [ -d "$SHELL_ROOT/.claude/hooks/helpers" ] || exit 0
# Back-fill the env var from self-location (#312) so helpers that reference
# $GHJIG_SHELL_ROOT resolve even when launched with no global env.
export GHJIG_SHELL_ROOT="$SHELL_ROOT"

# Primitive bootstrap of hookrt.sh (audit_log + safe_source). SPEC §6.1.
hookrt="$SHELL_ROOT/.claude/hooks/hookrt.sh"
if [ ! -f "$hookrt" ]; then
  printf '[GHJig-Claude] WARN hookrt-missing: %s not loaded — hook exiting\n' "$hookrt" >&2
  exit 0
fi
# shellcheck source=/dev/null
. "$hookrt"

safe_source "$SHELL_ROOT/.claude/hooks/helpers/cwd_guard.sh" out-of-scope || true
in_scope 2>/dev/null || exit 0

# Delegate to the canonical work-state helper (SPEC §5.5). Same source as
# /status — so the per-turn injection and the on-demand command never drift.
if safe_source "$SHELL_ROOT/.claude/hooks/helpers/status.sh" status; then
  status_compact
fi
exit 0
