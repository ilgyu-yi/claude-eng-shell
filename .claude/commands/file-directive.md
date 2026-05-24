---
description: File a new Directive in the dir-mode Project (SPEC §1.7, §2.1, §5.10). AI-assisted authoring with schema enforcement; reviewer-gated before commit.
argument-hint: [<short description>]
---

Create a new Directive Draft Item in the dir-mode GitHub Project v2.

## Procedure

1. **Resolve the Project** (deterministic gate, SPEC §1.7 Substrate guard, issue #71). Invoke `bash scripts/dir_mode_project.sh resolve` via the Bash tool. The script's exit code is the gate:
   - **exit 0**: project found. Stdout contains a single line `<project-num>\t<owner>\t<project-name>`. Parse and proceed to step 2.
   - **exit non-zero** (2 = no gh auth, 3 = no `project` scope, 4 = no `gh repo view`, 5 = no Project found, 6 = `jq` missing): **STOP**. Print the script's stderr verbatim. If exit code is 5, instruct the user to run `scripts/setup_project.sh`. Do not proceed to step 2.

   **Substitution prohibition.** Do NOT synthesize a Project from any other GitHub artifact — milestones, labels, plain Issues, etc. The script's exit-0 path is the **only** signal that a real Project exists for this target. If the script exits non-zero, `/file-directive` halts; this is by design (SPEC §1.7).

2. **Resolve the parent Goal.** Search the Project for an item with `Type=Goal` (via `gh project item-list <num> --owner <owner> --format json --limit 100`). If absent, ask the user whether to file a new Goal first, OR proceed with `Parent Goal: (no Goal item yet — bootstrap)` as the placeholder. If multiple Goals exist, ask which one this Directive serves.

3. **Author the body** from `.claude/templates/directive.md`:
   - **Objective** — bounded by concrete artifact-level boundary (issue counts, file paths, AC ticks, merge events). Refuse to proceed if the Objective doesn't name a concrete artifact-level boundary.
   - **Success signals** — 2 to 5 verifiable conditions. Each must be objectively testable by a reasonable engineer.
   - **Non-goals** — at least 2 explicit exclusions.
   - **Constraints** — at least 1 invariant to preserve.
   - **Parent Goal** — from step 2.
   - **Confidence** — 0–100; ask the user.

4. **Reviewer gate** — invoke the `directive-reviewer` subagent (SPEC §4.9) on the proposed body. Pass: proposed body, list of currently `Status=Active` Directives, parent Goal reference. Parse the verdict line (`^VERDICT: (ship|refine|block)`).

   Verdict dispatch (SPEC §2.1, §5.7.1 operating-mode coupling):
   - **`ship`** → proceed to step 5.
   - **`refine: <feedback>`** → revise the body per the one-line feedback. Re-invoke `directive-reviewer` on the revised body. After **two** consecutive `refine` verdicts on the latest body, escalate to the user (attended) or treat as `block` (unattended).
   - **`block: <reason>`** → do NOT create the Draft Item. In attended mode: report the reason and stop. In unattended mode: append one line to `$CLAUDE_ENG_SHELL_ROOT/.claude/state/directive-block.log` naming the rejected Objective + reason, then stop.

5. **Create the Draft Item** in the Project:
   ```bash
   gh project item-create <project-num> --owner <owner> --title "<Objective summary, ≤80 chars>" --body "<full body from step 3>" --format json
   ```
   The output contains the Item ID — keep it for the next steps.

6. **Set custom fields** on the new Draft Item:
   - `Type=Directive`
   - `Status=Planned`
   - `Priority=<asked from user, default P2>`
   - `Confidence=<from step 3>`
   - `Success Signals=<copy of the Success signals section>`
   - `Parent=<parent Goal reference or "(no Goal)">`

   Use `gh project item-edit --id <item-id> --field-id <field-id> --text <value>` (or `--single-select-option-id` for SINGLE_SELECT fields; resolve field IDs once via `gh project field-list`).

7. **Audit log** — `audit_log info directive-file created "directive: <Objective summary> item=<item-id> priority=P<N> confidence=<C>"`.

   The `item=<item-id>` token is **mandatory** — `<item-id>` is the Draft Item ID returned by step 5's `gh project item-create … --format json | jq -r '.id'`, always available by the time this step runs. Substituting `milestone=#N`, `issue=#N`, or any other identifier is a contract violation (issue #71). Smoke §50a scans `.claude/audit/audit.jsonl` after every CI run and fails on format drift.

8. **Output** — print:
   ```
   Filed Directive (Draft Item <id>): <Objective summary>
   Status: Planned
   Next: /activate-directive <id>  when ready to promote to a real Issue.
   ```

## Operating mode

- **attended** (default): step 4 surfaces the verdict to the user before applying it; the user may override a `block` with `SKIP_HOOKS=directive-review SKIP_REASON='<why>'` on a re-invocation.
- **unattended**: step 4's verdict gates directly; `block` parks the draft as described.

## Escape

`SKIP_HOOKS=directive-review SKIP_REASON='<why>' /file-directive <args>` bypasses the reviewer gate. Audit-logged per SPEC §7. Reserved for cases where a human accepts recorded responsibility for the override.

## Forbidden

- Creating a Draft Item with an empty or stub-only Objective.
- Skipping the reviewer gate without `SKIP_HOOKS=directive-review`.
- Setting `Type=Directive` on an Item that is not a Draft Item or a real Issue (the field is `Type`-awareness's primary key per SPEC §1.7).
