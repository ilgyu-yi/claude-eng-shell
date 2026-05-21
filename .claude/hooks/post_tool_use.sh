#!/usr/bin/env bash
set -uo pipefail

SHELL_ROOT="${CLAUDE_ENG_SHELL_ROOT:-}"
[ -n "$SHELL_ROOT" ] && [ -d "$SHELL_ROOT/.claude/hooks/helpers" ] || exit 0

. "$SHELL_ROOT/.claude/hooks/helpers/log.sh"
. "$SHELL_ROOT/.claude/hooks/helpers/cwd_guard.sh"
. "$SHELL_ROOT/.claude/hooks/helpers/detect_stack.sh"
. "$SHELL_ROOT/.claude/hooks/helpers/git_matcher.sh"

in_scope || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')

case "$tool" in
  Edit|Write|MultiEdit)
    target=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
    [ -z "$target" ] && exit 0
    fmt=$(detect_format_cmd "$target")
    [ -n "$fmt" ] && eval "$fmt" >/dev/null 2>&1 || true
    ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    # Match `git commit` / `git push` tolerantly so that option-prefix
    # forms (git -c <opt> commit, git -C <path> push, …) still fire the
    # reminders. Single source of truth lives in helpers/git_matcher.sh.
    if printf '%s' "$cmd" | grep -qE "${GIT_PREFIX}commit\b"; then
      printf '[claude-eng-shell] reminder: update the matching PR body checklist item.\n' >&2
    fi
    if printf '%s' "$cmd" | grep -qE "${GIT_PREFIX}push\b"; then
      if command -v gh >/dev/null 2>&1; then
        n=$(gh pr view --json number --jq .number 2>/dev/null)
        if [ -n "$n" ]; then
          state=$(gh pr checks "$n" --json state 2>/dev/null | jq -r '[.[].state] | unique | join(",")' 2>/dev/null)
          [ -n "$state" ] && printf '[claude-eng-shell] PR #%s checks: %s\n' "$n" "$state" >&2
        fi
      fi
    fi
    ;;
esac

exit 0
