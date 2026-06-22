# shellcheck shell=bash
# helpers/replan_check.sh — surface the mechanical facts the /replan-check
# divergence judgment needs: the actually-touched files, the linked issue's
# acceptance criteria, and the PR-body Plan/Checklist/Key-context/Out-of-scope
# (a touched file the Plan declared Out-of-scope is a strong structural signal).
# The JUDGMENT
# (structural vs cosmetic, AC-reachability) stays in the skill (LLM), per the
# /recall -> recall.sh split. Fail-open: any git/gh error prints a single
# "...unavailable" line and never errors out — this is an advisory, never a gate.
# SPEC §5.26.
#
# Public:
#   replan_check_facts — print the fact bundle (base, touched files, PR-body
#     plan sections, linked-issue ACs) for the skill to read and judge.

replan_check_facts() {
  local base touched body issuenums n ib

  base=$(gh pr view --json baseRefName --jq .baseRefName 2>/dev/null) || base=""
  [ -n "$base" ] || base="main"
  printf '## base\n%s\n\n' "$base"

  printf '## touched files (git diff --name-only %s...HEAD)\n' "$base"
  if touched=$(git diff --name-only "$base"...HEAD 2>/dev/null) && [ -n "$touched" ]; then
    printf '%s\n' "$touched"
  elif touched=$(git diff --name-only "$base" 2>/dev/null) && [ -n "$touched" ]; then
    printf '%s\n' "$touched"
  else
    printf '(no diff, or git unavailable)\n'
  fi
  printf '\n'

  body=$(gh pr view --json body --jq .body 2>/dev/null) || body=""
  if [ -z "$body" ]; then
    printf '## plan / checklist / key context\nreplan-check: PR body unavailable\n\n'
  else
    printf '## plan / checklist / key context / out-of-scope (from PR body)\n'
    printf '%s\n' "$body" | awk '
      /^## (Plan|Checklist|Key context|Out of scope)/ { p=1; print; next }
      /^## / { p=0 }
      p { print }
    '
    printf '\n'
  fi

  printf '## linked-issue acceptance criteria\n'
  issuenums=$(printf '%s\n' "$body" | grep -oiE '(closes|refs) #[0-9]+' | grep -oE '[0-9]+' | sort -u)
  if [ -z "$issuenums" ]; then
    printf '(no linked issue found in PR body)\n'
  else
    for n in $issuenums; do
      if ib=$(gh issue view "$n" --json body --jq .body 2>/dev/null) && [ -n "$ib" ]; then
        printf '### issue #%s\n' "$n"
        printf '%s\n' "$ib" | grep -E '^[[:space:]]*- \[[ xX]\]' || printf '(no AC checkboxes)\n'
      else
        printf '### issue #%s\nreplan-check: issue body unavailable\n' "$n"
      fi
    done
  fi
}
