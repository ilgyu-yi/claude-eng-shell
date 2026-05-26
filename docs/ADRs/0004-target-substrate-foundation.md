# ADR 0004: Target-substrate foundation (cross-boundary install + reversibility)

- Date: 2026-05-26
- Status: Accepted
- Context PR: (foundation slice of Directive #107, Issue #114)
- Supersedes: none — extends ADR-0003 orthogonally

## Context

ADR-0003 (Issues-as-SSOT substrate) locked the dir-mode substrate **inside one repo** — labels, Issue body schema, mirror workflow, Project field set. It did not address how that substrate reaches **target repos** in `workspace/`. Today, a freshly-cloned target repo cannot run dir-mode end-to-end because the substrate isn't installed: no `directive` / `status:proposed` / `status:blocked` / `discussion` / `task` / `needs-triage` labels exist; no `.github/ISSUE_TEMPLATE/*.yml` files exist; no `issues-to-project-mirror.yml` or `auto-needs-triage.yml` workflows exist; no Project v2 named `<repo> roadmap` exists.

SPEC §0.2 ("not a general dotfiles framework") scoped the shell to `workspace/` and to `.claude/` symlinks within each target. Directive #107 explicitly broadens this boundary: the shell now also installs **a typed allow-list of `.github/` files + repo labels** into targets, and (out-of-band, via `gh project create`) creates a Project v2. This ADR locks the rationale for the broadening, the install mechanics, and the reversibility contract.

This decision is **orthogonal** to ADR-0003 — that ADR governs the substrate's internal shape (Issues-as-SSOT, label-encoded state, mirror workflow); this ADR governs how that internal shape is **propagated to target repos**. ADR-0003 stays canonical for everything it covers; ADR-0004 is additive.

## Decision

Five decisions, each independently revertable:

### 1. Boundary expansion: shell installs `.github/` files + labels in targets

The shell, via the future `/onboard-dir-mode` skill (deferred Execution Issue under Directive #107), installs:

- **Issue Form templates** — `.github/ISSUE_TEMPLATE/{directive-proposal,execution-under-directive,task,bug-report,discussion}.yml` + `config.yml`. Source-of-truth: `.claude/templates/target-substrate/ISSUE_TEMPLATE/` (deferred Execution Issue lands this directory).
- **Workflow files** — `.github/workflows/{auto-needs-triage,issues-to-project-mirror,dir-mode-post-merge}.yml`. Source-of-truth: same canonical directory.
- **Repo labels** — the 10-label v3 set (`directive`, `status:proposed`, `status:blocked`, `task`, `needs-triage`, `discussion`, `P0`, `P1`, `P2`, `P3`). Installed via `gh label create --force` invocations modeled on `scripts/ensure_v3_labels.sh`.
- **Project v2** — created via `gh project create --owner <owner> --title "<repo-name> roadmap"` if absent. Field schema populated via `scripts/setup_project.sh` (idempotent — exits clean if already correct).

SPEC §0.2's "scoped to `workspace/`" framing is broadened: scoped to `workspace/` + this typed allow-list of files/labels inside each target's `.github/` and label namespace. Anything outside this allow-list (CI configs, source code, READMEs, ARCHITECTURE docs) is **never** touched by the shell.

### 2. Installs go through PRs — shell never direct-pushes to target

File installations (Issue templates + workflows) install via a branch + PR in the target repo, NOT via direct push to `main`. The target maintainer reviews and merges. The shell creates the branch + PR via `gh pr create`; merge is the maintainer's decision.

This is enforced by the existing protected-branch hook (`pre_tool_use.sh`) which blocks `git push origin main` from inside any registered target. The hook fails-closed on this path; there is no escape for `/onboard-dir-mode` other than the PR route.

Labels + Project install directly (they're not git-tracked); the maintainer can revert them after the fact via `gh label delete` / `gh project delete`.

### 3. Reversibility contract — every install step is detectable + revertable

The shell's substrate footprint on a target is fully observable and fully revertable:

- **Detectability**: `git diff main..<onboard-branch> -- .github/` shows every file the shell adds. `gh label list --repo <target>` shows every label installed. `gh project list --owner <owner>` shows every Project.
- **File revertability**: `git rm .github/ISSUE_TEMPLATE/<file>` or `git rm .github/workflows/<file>` removes any installed file via a normal PR. The shell does not require any of these files to function (its `.claude/` symlinks are independent).
- **Label revertability**: `gh label delete <name>` removes any installed label. The 9-label set is described as a recommendation; the target maintainer may rename, recolor, or delete any subset.
- **Project revertability**: Project v2 is owner-state, not repo-file-state. Removal is out-of-band via `gh project delete <num> --owner <owner>` — **manually**, not scripted. The shell does not automate Project deletion because Projects often outlive the substrate that created them and may contain manual annotations.
- **Skill revertability**: removing `claude-eng-shell` from a target (deleting the `.claude/` symlinks via `scripts/unregister.sh`) leaves the `.github/` files + labels intact; the target keeps using them or removes them at its own pace.

The contract is: **the shell can be fully unwound from a target via a single PR (file removals) + a one-liner per label (`gh label delete`) + an out-of-band Project decision**. Nothing the shell installs is load-bearing for the target's own workflows.

### 4. Three-tier feature model

Targets adopt the shell at one of three tiers — each tier is a strict superset of the previous. Tier detection is **mechanical** (file/label observable):

| Tier | Required artifacts | Features available |
|---|---|---|
| **Tier 1: eng-mode** | None beyond a default git repo with `main` branch + protected-branch settings the maintainer configures themselves | `/file-issue`, `/work-on`, `/ship`, secret scan, AC closeout, conventional-commit enforcement — the full engineering loop |
| **Tier 2: dir-mode-with-labels** | Tier 1 + the 10-label v3 set installed via `scripts/ensure_v3_labels.sh` | Tier 1 + `/file-directive`, `/activate-directive`, `/complete-directive` writing to Issues directly. No Project mirror; no Issue templates; external contributors see no template chooser. |
| **Tier 3: full v3** | Tier 2 + `.github/ISSUE_TEMPLATE/*.yml` + `.github/workflows/{auto-needs-triage,issues-to-project-mirror,dir-mode-post-merge}.yml` + Project v2 with v3 field schema | Tier 2 + Issue template chooser for external contributors + `/triage` queue + Project-as-derived-view + mirror workflow. |

Tier transitions are mechanical: downgrade by deleting the tier-N artifacts; upgrade by running the next stage of `/onboard-dir-mode`. Each tier is independently shippable — a target can sit at tier 2 indefinitely without ever upgrading to tier 3.

### 5. Graceful-degradation principle — per-command judgment, not global

Dir-mode commands check substrate before acting. The rule (verbatim from Directive #107 body): **hard-refusal only when the SPECIFIC dependency for the command is missing AND the command's contract cannot be met without it**. Otherwise, run in degraded mode with a one-line warning.

Examples (the principle is per-command; these are the test anchors):

- `/file-issue` — works at **tier 1**. No substrate required.
- `/file-directive` — hard-refuses at **tier 1** (no `directive` label → no way to mark the Issue as a Directive). Works in **degraded mode at tier 2** (writes Issue with labels successfully + emits a one-line warning "no Project mirror to write to — Issue body + labels still satisfy SSOT"). Full functionality at **tier 3** (Issue body + labels + Project mirror all populated).
- `/triage` — hard-refuses below **tier 3**. The triage queue (`needs-triage` + `status:proposed`) requires both the labels (tier 2) AND the `auto-needs-triage.yml` workflow that applies `needs-triage` to template-less filings (tier 3). Without the workflow, the queue is empty by construction.
- `directive-reviewer` — at tier 2, the MISSION.md alignment check falls back to "no MISSION.md in target — treat as bootstrap allowance" (the existing v0 bootstrap allowance in `directive-reviewer.md`'s prompt).

Implementation of per-command preflight wiring is **deferred** to a separate Execution Issue under Directive #107. This ADR locks only the principle.

## Reversibility paths

Quick-reference summary of escape paths (concrete commands, in order of decreasing scope):

```
# 1. Remove a single installed file
git rm .github/ISSUE_TEMPLATE/discussion.yml   # for example
git commit -m "chore: remove claude-eng-shell template"
git push

# 2. Remove a single installed label
gh label delete discussion --yes

# 3. Remove all shell-installed labels at once
for L in directive status:proposed status:blocked task needs-triage discussion P0 P1 P2 P3; do
  gh label delete "$L" --yes 2>/dev/null
done

# 4. Remove the Project (out-of-band, owner-decision)
gh project list --owner <owner>
gh project delete <num> --owner <owner>

# 5. Full disengagement
bash $CLAUDE_ENG_SHELL_ROOT/scripts/unregister.sh "$PWD"
# Then `.github/` files + labels remain; target deletes them via #1-#4 at leisure.
```

The shell's footprint is enumerable and unwindable. Reversibility is the design property that makes the boundary expansion acceptable.

## Alternatives considered

- **Single-PR direct install (no separate branch in target)** — rejected. Forces the shell to push directly to the target's `main`; conflicts with the existing protected-branch hook + with any branch protection rules the target maintainer set up. The branch + PR path is mechanical respect for the maintainer's review role.
- **Amend ADR-0003 instead of new ADR-0004** — rejected. ADR-0003 governs the substrate's internal shape (one repo); ADR-0004 governs cross-boundary propagation. Different scope, different reversibility math, different supersession trajectory. Conflating them would break the supersession chain.
- **Skip the three-tier model; require full v3 always** — rejected. Forces every adopter to opt into Project v2 + workflows + templates from day one. Tier 1 / tier 2 are valid stopping points for teams that want eng-mode discipline without the directing layer. The tier model preserves opt-in granularity.
- **No reversibility contract — document the install path only** — rejected. Without the unwinding contract, the boundary expansion becomes irreversible by default. Targets adopting the shell must be able to leave it; the contract makes that mechanically possible.
- **Auto-revert on `unregister.sh`** — rejected. Auto-deleting `.github/` files on unregister would be a destructive surprise for targets that have integrated those files into their workflow. The shell's job is to install on opt-in and document the unwind path; deletion is the maintainer's call.

## Consequences

**Positive**:
- Multi-repo adoption (MISSION criterion #3) becomes mechanical — `/onboard-dir-mode` is the on-ramp.
- The boundary expansion is contractually visible (this ADR + SPEC §1.7 subsection); future PRs can't silently expand it further without amending the contract.
- The tier model gives adopters opt-in granularity; "eng-mode only" is a valid permanent state.
- Reversibility makes adoption low-risk for target maintainers.

**Negative**:
- SPEC §0.2 "not a general dotfiles framework" wording becomes partially aspirational. The shell IS a dotfiles framework for `.github/` files + labels; just a typed, allow-listed one. Future revision of §0.2 wording is a follow-up Issue.
- The shell now has install/uninstall surface to maintain. `/onboard-dir-mode` becomes a load-bearing skill; bugs in it propagate to every target.
- Per-command graceful-degradation logic adds branching to every dir-mode command's preflight. Maintenance cost grows linearly with the command count.

**Neutral**:
- ADR-0003 is unaffected. Its decisions about Issues-as-SSOT inside one repo remain canonical.
- The MISSION criterion "Multiple repos run on it" gains a mechanical path; whether two unrelated upstream repos actually adopt the shell is still a community-adoption question, not a tooling question.

## Notes

- **Lockstep with Directive #109**: the `discussion` label landed in this repo's `scripts/ensure_v3_labels.sh` via Issue #112 (PR #113). `/onboard-dir-mode`'s bootstrap-label set MUST include `discussion` per the v3 reframe substrate.
- **SPEC §1.7 amendment**: the operative "Substrate-in-target contract" subsection lives in SPEC §1.7 (added in the same PR as this ADR). The SPEC subsection is the developer-facing contract; this ADR is the long-form rationale.
- **Smoke §61**: regression guards on this ADR's existence + the SPEC subsection. Catches "ADR-0004 removed" or "SPEC §1.7 subsection deleted" in any future PR.
- **Deferred Execution Issues under Directive #107**: (a) `.claude/templates/target-substrate/` canonical-source directory + sync mechanism; (b) `/onboard-dir-mode` skill; (c) per-command graceful-degradation preflight wiring.
