#!/usr/bin/env bash
# resolve_parent_directive.sh — label-aware reflection-target resolver (#335).
#
# Sourced by .github/workflows/dir-mode-post-merge.yml (after actions/checkout)
# to decide which Directive a merged PR's reflection comment lands on. Extracted
# from inline workflow run-block bash so the logic is CI-shellchecked (SPEC §11)
# and smoke-executed (scripts/test/smoke.sh §48j) rather than untestable.
#
# THREE byte-identical copies exist, cmp-locked by smoke §48j-sync:
#   - scripts/lib/resolve_parent_directive.sh                              (canonical, CI-linted)
#   - .github/workflows/resolve_parent_directive.sh                       (this repo's runtime — what the workflow sources)
#   - .claude/templates/target-substrate/workflows/resolve_parent_directive.sh  (shipped into onboarded targets)
# Edit the canonical copy and mirror to the other two; the cmp assertion fails CI on drift.
#
# resolve_parent_directive <pr_num> <repo>
#   For each closing Issue of the merged PR, climb the `Parent Directive: #N`
#   body-marker chain to the FIRST `directive`-labelled ancestor (SPEC §5.15).
#   The marker target may be an *umbrella* Execution Issue rather than the
#   Directive itself; a first-marker pick would mis-target the umbrella (#335),
#   so each hop checks the target's labels and climbs one more level if it is
#   not `directive`-labelled. Depth-cap 2 hops, visited-set cycle guard.
#
#   On success prints two lines to stdout, suitable for appending to
#   $GITHUB_OUTPUT:
#       directive=<D>
#       exec_issue=<E>
#   On no resolution prints a visible no-op note to stderr and nothing to stdout
#   (the inline predecessor was silent). ALWAYS returns 0 — a gh failure resolves
#   to "no Directive" (fail-soft) rather than aborting the merge workflow. Every
#   gh call carries --repo so it works on a runner with no git context.
resolve_parent_directive() {
  local pr_num="$1" repo="$2"
  local closing n cur depth body parent labels seen
  closing=$(gh pr view "$pr_num" --repo "$repo" --json closingIssuesReferences \
    --jq '.closingIssuesReferences[].number' 2>/dev/null) || closing=""
  # shellcheck disable=SC2086  # $closing is a newline-separated list — split intended
  for n in $closing; do
    cur="$n"
    depth=0
    seen=" "
    while [ "$depth" -lt 2 ]; do
      body=$(gh issue view "$cur" --repo "$repo" --json body --jq .body 2>/dev/null) || break
      if [[ "$body" =~ ^Parent\ Directive:\ \#([0-9]+) ]]; then
        parent="${BASH_REMATCH[1]}"
        case "$seen" in *" $parent "*) break ;; esac   # cycle guard
        seen="$seen$parent "
        labels=$(gh issue view "$parent" --repo "$repo" --json labels \
          --jq '.labels[].name' 2>/dev/null) || break
        if printf '%s\n' "$labels" | grep -qx 'directive'; then
          printf 'directive=%s\n' "$parent"
          printf 'exec_issue=%s\n' "$n"
          return 0
        fi
        cur="$parent"               # not a Directive — climb through this umbrella
        depth=$((depth + 1))
      else
        break                       # no marker on this node — chain ends, no Directive
      fi
    done
  done
  printf 'resolve_parent_directive: no directive-labelled ancestor for PR #%s closing issues — no reflection posted\n' "$pr_num" >&2
  return 0
}
