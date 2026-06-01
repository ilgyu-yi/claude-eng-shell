# shellcheck shell=bash
# helpers/ac_closeout_gate.sh — `gh pr merge` AC-closeout gate logic.
# Sourced by pre_tool_use.sh and (optionally) by scripts/ac_closeout.sh.
#
# Public:
#   extract_pr_from_merge_cmd <cmd> — print the first integer argv to
#     `gh pr merge` and return 0, or print nothing and return 1 if the
#     cmd has no explicit PR number. Tolerates flags between `merge`
#     and the number.
#   pr_needs_closeout <pr-num> — query gh for the PR's
#     `closingIssuesReferences`; for each linked issue, check whether
#     it has unchecked AC and lacks a `^## AC closeout` header comment.
#     Returns: 0 = needs closeout (block), 1 = allows, 2 = indeterminate.
#     gh calls are bounded by `timeout 5` (or `gtimeout 5` on macOS;
#     unbounded fallback if neither is present). Indeterminate maps to
#     allow in the caller (fail-open per SPEC §6.1).

extract_pr_from_merge_cmd() {
  local cmd="$1"
  local rest token
  # Strip up to and including `gh pr merge`; the remainder is the argv.
  # No `\b` — BSD sed (macOS) doesn't recognize it. The grep matcher in
  # pre_tool_use.sh already validated that `gh pr merge` is present as a
  # token (with end-anchor so `merge-queue` doesn't slip past), so plain
  # `.*gh[[:space:]]+pr[[:space:]]+merge` is sufficient.
  rest=$(printf '%s' "$cmd" | sed -nE 's/.*gh[[:space:]]+pr[[:space:]]+merge//p')
  # Collapse runs of whitespace so word-split picks tokens cleanly.
  rest=$(printf '%s' "$rest" | tr -s '[:space:]')
  # `set -f` disables pathname expansion so a literal `*` in cmd args
  # (extremely unlikely for `gh pr merge` but defensive — matches the
  # check_destructive_args style in pre_tool_use.sh).
  local _opts=$-
  set -f
  for token in $rest; do
    case "$token" in
      -*) continue ;;
      *[!0-9]*) continue ;;   # only pure-integer tokens count as PR number
      [0-9]*) case "$_opts" in *f*) ;; *) set +f ;; esac; printf '%s' "$token"; return 0 ;;
    esac
  done
  case "$_opts" in *f*) ;; *) set +f ;; esac
  return 1
}

# _ac_run_gh <args...> — wrap a gh call in `timeout 5`; emit to stdout.
# Returns gh's exit code (or 124 on timeout). Fallback to unbounded gh
# if no timeout binary is on PATH.
_ac_run_gh() {
  local timeout_bin=""
  if command -v timeout >/dev/null 2>&1; then
    timeout_bin=timeout
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_bin=gtimeout
  fi
  if [ -n "$timeout_bin" ]; then
    "$timeout_bin" 5 gh "$@"
  else
    gh "$@"
  fi
}

# parse_gh_merge_argv <cmd> — gh-flag-aware parse of a `gh pr merge` command for
# the merge-strategy matcher (#290). Echoes "<strategy>\t<pr>":
#   strategy ∈ merge|squash|rebase|bare — the explicit strategy FLAG token
#     (`--merge`/`-m`, `--squash`/`-s`, `--rebase`/`-r`), NOT a substring, so a
#     `--merge` inside a `--body`/`--subject` *value* is not read as the strategy
#     (#290 A) and the short `-m` is recognized as compliant (#290 C).
#   pr = the first POSITIONAL token (or a `.../pull/N` URL's N), skipping
#     value-taking flags' values (#290 B); empty if the command names none
#     (caller falls back to the current branch's PR).
# Shell-aware tokenization (python3 `shlex`, mirroring check_destructive_args)
# so a quoted multi-word flag value stays one token; `read -ra` fallback when
# python3 is absent (imperfect only for a multi-word quoted value containing a
# bare `--merge`/`-m` token — the degraded path). An unparseable command
# (unclosed quote — which would not execute in a real shell) yields strategy=bare
# so the caller takes the conservative base-resolution path.
parse_gh_merge_argv() {
  local cmd="$1" rest
  rest=$(printf '%s' "$cmd" | sed -nE 's/.*gh[[:space:]]+pr[[:space:]]+merge//p')
  local -a toks=()
  if command -v python3 >/dev/null 2>&1; then
    local _out
    if _out=$(printf '%s' "$rest" | python3 -c '
import shlex, sys
try:
    for t in shlex.split(sys.stdin.read()):
        print(t)
except ValueError:
    sys.exit(2)
' 2>/dev/null); then
      local _t
      while IFS= read -r _t; do [ -n "$_t" ] && toks+=("$_t"); done <<< "$_out"
    else
      printf 'bare\t'; return 0
    fi
  else
    local IFS=$' \t\n' _o=$-
    set -f
    read -ra toks <<< "$rest"
    case "$_o" in *f*) ;; *) set +f ;; esac
  fi
  local strategy=bare pr="" skip_next="" t i
  for ((i=0; i<${#toks[@]}; i++)); do
    t="${toks[$i]}"
    if [ -n "$skip_next" ]; then skip_next=""; continue; fi
    case "$t" in
      --merge|-m)   strategy=merge ;;
      --squash|-s)  strategy=squash ;;
      --rebase|-r)  strategy=rebase ;;
      # Value-taking flags consume their following token (so a value is never
      # mistaken for the PR or a strategy flag). `--flag=value` is one token.
      --body|-b|--body-file|--subject|-t|--match-head-commit|--author-email|--repo|-R) skip_next=1 ;;
      --*=*) : ;;
      -*) : ;;   # other boolean flags (--auto/--admin/--delete-branch/-d/--disable-auto): no value
      *)
        if [ -z "$pr" ]; then
          case "$t" in
            */pull/*) pr="${t##*/pull/}"; pr="${pr%%[!0-9]*}" ;;
            *[!0-9]*) ;;   # non-integer positional → ignore
            *) pr="$t" ;;
          esac
        fi
        ;;
    esac
  done
  printf '%s\t%s' "$strategy" "$pr"
}

pr_needs_closeout() {
  local pr="$1"
  [ -z "$pr" ] && return 2
  command -v gh >/dev/null 2>&1 || return 2

  local issues rc
  issues=$(_ac_run_gh pr view "$pr" --json closingIssuesReferences -q '.closingIssuesReferences[].number' 2>/dev/null)
  rc=$?
  [ "$rc" != 0 ] && return 2
  [ -z "$issues" ] && return 1  # no linked issues → allow

  local n body comments
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    body=$(_ac_run_gh issue view "$n" --json body -q .body 2>/dev/null)
    rc=$?
    [ "$rc" != 0 ] && return 2
    # No unchecked AC on this issue → it's fine.
    if ! printf '%s' "$body" | grep -q '^- \[ \]'; then
      continue
    fi
    comments=$(_ac_run_gh issue view "$n" --json comments -q '.comments[].body' 2>/dev/null)
    rc=$?
    [ "$rc" != 0 ] && return 2
    # Marker present → covered.
    if printf '%s' "$comments" | grep -q '^## AC closeout'; then
      continue
    fi
    # Any one issue missing the marker triggers the block.
    return 0
  done <<< "$issues"

  return 1
}
