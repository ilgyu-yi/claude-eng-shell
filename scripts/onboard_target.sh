#!/usr/bin/env bash
# scripts/onboard_target.sh — install the v3 substrate into the current
# target repo (cwd). Tier-aware (--tier 1|2|3). Idempotent. PR-based file
# installs per ADR-0004 Decision 2. Audit-logged.
#
# Invoked from /onboard-dir-mode (.claude/commands/onboard-dir-mode.md).
#
# Tier semantics (per ADR-0004 Decision 4):
#   1 — no-op (eng-mode only; no substrate installed).
#   2 — labels: the 10-label v3 set via `gh label create --force`.
#   3 — tier 2 + ISSUE_TEMPLATE + workflows (via PR) + Project v2.

set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
: "${CLAUDE_ENG_SHELL_ROOT:=$SCRIPT_ROOT}"
export CLAUDE_ENG_SHELL_ROOT

if [ -f "$CLAUDE_ENG_SHELL_ROOT/.claude/hooks/hookrt.sh" ]; then
  # shellcheck source=/dev/null
  . "$CLAUDE_ENG_SHELL_ROOT/.claude/hooks/hookrt.sh"
else
  audit_log() { :; }
fi

TIER=3
DRY_RUN=
while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER="$2"; shift 2 ;;
    --tier=*) TIER="${1#--tier=}"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "onboard_target: unknown arg: $1" >&2; exit 2 ;;
  esac
done

case "$TIER" in
  1|2|3) ;;
  *) echo "onboard_target: --tier must be 1, 2, or 3 (got $TIER)" >&2; exit 2 ;;
esac

# Resolve target owner/repo (validates we're in a real gh repo context).
if ! command -v gh >/dev/null 2>&1; then
  echo "onboard_target: gh CLI not found" >&2
  exit 1
fi
TARGET_OWNER_REPO=$(gh repo view --json owner,name --jq '"\(.owner.login)/\(.name)"' 2>/dev/null || true)
if [ -z "$TARGET_OWNER_REPO" ]; then
  echo "onboard_target: cannot resolve gh repo (cwd not in a gh-recognized git repo or gh not authed)" >&2
  exit 1
fi
echo "onboard_target: target=$TARGET_OWNER_REPO tier=$TIER ${DRY_RUN:+(dry-run)}"

# ---------------------------------------------------------------
# Tier 1 — no-op
# ---------------------------------------------------------------
if [ "$TIER" = 1 ]; then
  echo "onboard_target: tier 1 — no substrate to install (eng-mode works without)"
  audit_log info onboard-dir-mode created "target=$TARGET_OWNER_REPO tier=1 noop"
  exit 0
fi

# ---------------------------------------------------------------
# Tier 2 — labels
# ---------------------------------------------------------------
echo "onboard_target: tier 2 — installing 10-label v3 set..."
LABELS_SPEC=(
  "directive:0E8A16:Directive Issue (dir-mode, SPEC §1.7)"
  "status:proposed:FBCA04:Directive proposed; awaiting maintainer triage (SPEC §2.1 v3)"
  "status:blocked:B60205:Directive cannot proceed without external input (SPEC §5.17)"
  "task:C5DEF5:Standalone task or small improvement (not parented under a Directive)"
  "needs-triage:D4C5F9:Issue filed without a template — awaiting maintainer triage classification"
  "discussion:FEF2C0:Observation or half-formed idea; close as promoted (#M) or no-action (SPEC §5.19)"
  "P0:B60205:Priority 0 — drop everything"
  "P1:D93F0B:Priority 1 — next"
  "P2:FBCA04:Priority 2 — soon"
  "P3:0E8A16:Priority 3 — eventually"
)
for spec in "${LABELS_SPEC[@]}"; do
  name="${spec%%:*}"; rest="${spec#*:}"
  color="${rest%%:*}"; desc="${rest#*:}"
  if [ -n "$DRY_RUN" ]; then
    echo "  [dry-run] would: gh label create '$name' --color '$color' --force"
  else
    gh label create "$name" --color "$color" --description "$desc" --force >/dev/null 2>&1 || \
      echo "  warn: label '$name' install failed (non-fatal; existing labels often differ in description-only)"
  fi
done
echo "onboard_target: tier 2 labels done."

if [ "$TIER" = 2 ]; then
  audit_log info onboard-dir-mode created "target=$TARGET_OWNER_REPO tier=2 labels=10"
  exit 0
fi

# ---------------------------------------------------------------
# Tier 3 — labels + ISSUE_TEMPLATE + workflows (via PR) + Project
# ---------------------------------------------------------------
echo "onboard_target: tier 3 — installing ISSUE_TEMPLATE + workflows via PR..."
SUBSTRATE_ROOT="$CLAUDE_ENG_SHELL_ROOT/.claude/templates/target-substrate"
if [ ! -d "$SUBSTRATE_ROOT" ]; then
  echo "onboard_target: canonical-source $SUBSTRATE_ROOT missing — re-run scripts/sync_target_substrate.sh" >&2
  exit 1
fi

# Copy canonical files into target's .github/.
TARGET_GITHUB="$(pwd)/.github"
mkdir -p "$TARGET_GITHUB/ISSUE_TEMPLATE" "$TARGET_GITHUB/workflows"
if [ -n "$DRY_RUN" ]; then
  echo "  [dry-run] would copy:"
  ls "$SUBSTRATE_ROOT/ISSUE_TEMPLATE/" "$SUBSTRATE_ROOT/workflows/" 2>/dev/null
else
  cp "$SUBSTRATE_ROOT/ISSUE_TEMPLATE/"*.yml "$TARGET_GITHUB/ISSUE_TEMPLATE/"
  cp "$SUBSTRATE_ROOT/workflows/"*.yml "$TARGET_GITHUB/workflows/"
  echo "  copied 6 ISSUE_TEMPLATE files + 3 workflow files into $TARGET_GITHUB/"
fi

# Open a PR if there are changes. Idempotent: skip if no diff.
if [ -z "$DRY_RUN" ]; then
  if git -C "$(pwd)" diff --quiet -- .github/; then
    echo "onboard_target: tier 3 files already match canonical-source (no PR needed; idempotent)"
  else
    BRANCH="onboard-dir-mode-substrate"
    git -C "$(pwd)" checkout -b "$BRANCH" 2>/dev/null || git -C "$(pwd)" checkout "$BRANCH"
    git -C "$(pwd)" add .github/
    git -C "$(pwd)" commit -m "chore: onboard claude-eng-shell dir-mode v3 substrate

Installs ISSUE_TEMPLATE files + dir-mode workflows per ADR-0004 Decision 1.
Reversibility: per ADR-0004 reversibility paths — git rm .github/ISSUE_TEMPLATE/<file>
or .github/workflows/<file> removes any installed file via a normal PR."
    git -C "$(pwd)" push -u origin "$BRANCH"
    gh pr create --title "chore: onboard claude-eng-shell dir-mode v3 substrate" \
      --body "Installs ISSUE_TEMPLATE files + dir-mode workflows per ADR-0004 Decision 1. Reversibility paths documented in the ADR."
  fi
fi

# Project v2 setup.
if [ -n "$DRY_RUN" ]; then
  echo "  [dry-run] would: bash scripts/setup_project.sh"
else
  echo "onboard_target: invoking setup_project.sh..."
  bash "$CLAUDE_ENG_SHELL_ROOT/scripts/setup_project.sh" || echo "  warn: setup_project.sh failed — Project may need manual creation"
fi

audit_log info onboard-dir-mode created "target=$TARGET_OWNER_REPO tier=3"
echo "onboard_target: tier 3 done."
