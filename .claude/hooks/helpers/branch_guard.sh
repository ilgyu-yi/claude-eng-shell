# helpers/branch_guard.sh — protected-branch checks. Source from hooks.

# Returns the current branch name, or the empty string if HEAD is detached.
# Callers that need a human-readable label (including detached-HEAD context)
# should use branch_label instead.
current_branch() {
  git symbolic-ref --short HEAD 2>/dev/null || echo ""
}

# Resolve the SHA of a protected ref, or empty if it doesn't exist.
_resolve_protected_ref() {
  git rev-parse --verify --quiet "refs/heads/$1" 2>/dev/null
}

# Human-readable branch label suitable for hook error messages.
# - Attached: the branch name.
# - Detached on a protected tip: `HEAD@<short> (detached, == <ref>)`.
# - Detached elsewhere: `HEAD@<short> (detached)`.
# - No HEAD (empty repo): empty string.
branch_label() {
  local b
  b=$(current_branch)
  if [ -n "$b" ]; then
    printf '%s' "$b"
    return
  fi
  local head_sha short tip
  head_sha=$(git rev-parse --verify --quiet HEAD 2>/dev/null) || { printf ''; return; }
  short=$(git rev-parse --short HEAD 2>/dev/null) || short="${head_sha:0:7}"
  local ref
  for ref in main master; do
    tip=$(_resolve_protected_ref "$ref") || continue
    if [ -n "$tip" ] && [ "$tip" = "$head_sha" ]; then
      printf 'HEAD@%s (detached, == %s)' "$short" "$ref"
      return
    fi
  done
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    tip="${line%% *}"
    ref="${line#* }"
    if [ "$tip" = "$head_sha" ]; then
      printf 'HEAD@%s (detached, == %s)' "$short" "$ref"
      return
    fi
  done < <(git for-each-ref --format='%(objectname) %(refname:short)' 'refs/heads/release/*' 2>/dev/null)
  printf 'HEAD@%s (detached)' "$short"
}

# Returns 0 (true) when:
# - the named branch is in the protected set, OR
# - HEAD is detached and its SHA equals the tip of any protected branch.
# The detached-tip check covers `git checkout <main-sha>` mistakes that
# the symbolic-ref-only matcher silently allowed.
is_protected_branch() {
  local b="${1:-$(current_branch)}"
  case "$b" in
    main|master|release/*) return 0 ;;
  esac
  # Detached HEAD (no symbolic ref): compare HEAD's SHA against the tip
  # SHA of each protected branch. main/master are constant names; release/*
  # is enumerated via for-each-ref so any branch under that prefix counts.
  if [ -z "$b" ]; then
    local head_sha tip
    head_sha=$(git rev-parse --verify --quiet HEAD 2>/dev/null) || return 1
    for ref in main master; do
      tip=$(_resolve_protected_ref "$ref") || continue
      [ -n "$tip" ] && [ "$tip" = "$head_sha" ] && return 0
    done
    # Enumerate release/* tips.
    while IFS= read -r tip; do
      [ -n "$tip" ] && [ "$tip" = "$head_sha" ] && return 0
    done < <(git for-each-ref --format='%(objectname)' 'refs/heads/release/*' 2>/dev/null)
  fi
  return 1
}
