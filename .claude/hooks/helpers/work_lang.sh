# shellcheck shell=bash
# helpers/work_lang.sh — work-language resolution (#323, Directive #322).
# See SPEC §5.7.2.
#
# resolve_work_lang
# Stdout: the WORK language code for durable repository artifacts (commit
# messages, PR/issue/directive/execution bodies, acceptance criteria, changelog
# fragments, shell-authored code comments, audit `reason` text). The
# communication language (chat replies) is a separate channel the shell never
# configures or translates.
#
# Precedence (high → low), mirroring resolve_mode (helpers/ship_mode.sh):
#   1. $CLAUDE_ENG_WORK_LANG env var
#   2. .claude/state/work-lang per-target file (cwd-relative — read exactly as
#      resolve_mode reads .claude/state/mode; config tier, NOT eng-state)
#   3. default `en`
#
# Any non-empty code is returned VERBATIM (no closed enum — generalizes to any
# (communication, work) pair; never ko/en-hardcoded). An empty / whitespace-only
# value (env or file) resolves to `en`, naming the surface in a stderr note.
# set -u-safe; no external calls beyond head/tr.
resolve_work_lang() {
  local raw="" surface=""
  if [ -n "${CLAUDE_ENG_WORK_LANG:-}" ]; then
    raw="$CLAUDE_ENG_WORK_LANG"; surface="env"
  elif [ -f .claude/state/work-lang ]; then
    raw=$(head -c 64 .claude/state/work-lang 2>/dev/null); surface="file"
  fi
  # Trim any whitespace (language codes carry none); an all-blank
  # value collapses to empty → default. Matches resolve_mode's file sanitization,
  # applied to both surfaces so a whitespace-only env value also falls back.
  raw=$(printf '%s' "$raw" | tr -d '[:space:]')
  if [ -n "$raw" ]; then
    printf '%s\n' "$raw"
    return 0
  fi
  [ -n "$surface" ] && printf 'work_lang: empty work language from %s — using en\n' "$surface" >&2
  printf '%s\n' "en"
}
