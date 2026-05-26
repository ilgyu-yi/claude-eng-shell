---
description: Close a Directive Issue as Completed — directive-reviewer evaluates evidence; closes Issue with --reason completed (dir-mode v3 / ADR-0003).
argument-hint: <issue-#>
---

Close a Directive Issue with `--reason completed`. Requires `directive-reviewer` evaluation of success-signal satisfaction by linked Execution Issues.

In dir-mode v3 (ADR-0003), Issue close-as-completed IS the Status=Completed signal. The Project Item's Status field follows via `.github/workflows/issues-to-project-mirror.yml`.

## Procedure

0. **Step 0 — substrate preflight** (ADR-0004; #118): verify the target satisfies this command's tier requirement. Tier 2 minimum for all dir-mode commands (10-label v3 set must exist). If `gh label list | grep -qx directive` fails, exit with `"target lacks dir-mode substrate; run /onboard-dir-mode --tier 2 first"`. Fail-open on `gh` network errors per ADR-0004 reversibility framing.

1. **Resolve the Issue** — `<issue-#>` is a GitHub Issue number. Fetch:
   ```bash
   gh issue view <issue-#> --json title,body,state,labels
   ```
   - If `state != OPEN`: error ("Directive is not open — current state `<X>`") and stop.
   - If `directive` label absent: error ("Issue #<N> is not a Directive (`directive` label missing)") and stop.
   - If `status:proposed` label is present: error ("Directive is in Proposed state — activate first via /activate-directive") and stop.

2. **Collect linked Execution Issues** — search for Issues whose body contains `^Parent Directive: #<issue-#>$`:
   ```bash
   gh issue list --search "in:body \"Parent Directive: #<issue-#>\"" --state all \
     --json number,title,state,body,closedAt --limit 100
   ```
   - For each linked Issue: parse its AC ticks (`^- \[(x|~| )\] ` lines from the body) and its open/closed state.

3. **Read the Directive's success signals** from its body (the `## Success signals` section authored at `/file-directive` time).

4. **Reviewer gate** — invoke `directive-reviewer` (SPEC §4.9) on the completion claim. Pass:
   - The Directive body (with success signals as written).
   - The list of linked Execution Issues + their states + AC ticks.

   Parse the verdict per `/file-directive` step 2 dispatch.

   On `block` (evidence insufficient): stop. Issue stays open. Audit `directive-complete blocked "<reason>"`. Surface the verdict reason to the user.

5. **Post the closing comment** with per-signal evidence:
   ```markdown
   ## Directive Completion (resolved by directive-reviewer ship verdict)

   - **Signal 1**: <signal text> — Evidence: PR #M (closed); AC #X ticked. Status: ✓
   - **Signal 2**: <signal text> — Evidence: PR #Y, #Z; smoke §N passes. Status: ✓
   - ...

   Closed via /complete-directive.
   ```

6. **Close the Issue** — `gh issue close <issue-#> --reason completed`.

   Note: the `trusted-filer-mutate` hook matcher (SPEC §6.1) allows `gh issue close --reason completed` on trusted-filer Issues without further confirmation. Closing as `not planned` or `duplicate` would require human confirm even after step 5 — `/complete-directive` only uses `--reason completed`.

7. **Audit log** — `audit_log info directive-complete completed "directive: #<issue-#> linked-execs=<N>"`.

8. **Mirror sync** — the mirror workflow fires on `issues.closed` and updates the Project Item's Status field to Completed.

9. **Output**:
   ```
   Completed Directive #<issue-#>: <Title>
   Status: Completed (Issue closed --reason completed)
   Evidence: <N> linked Execution Issues; all success signals satisfied.
   ```

## Operating mode

- **attended**: step 4's verdict surfaces to the user before closing.
- **unattended**: step 4's verdict gates directly; `block` leaves Issue open.

## Escape

`SKIP_HOOKS=directive-review SKIP_REASON='<why>' /complete-directive <issue-#>` bypasses the reviewer (SPEC §2.1, §7).

## Forbidden

- Closing without a `directive-reviewer` ship verdict (or audit-logged `SKIP_HOOKS=directive-review` escape).
- Closing with `--reason not planned` or `--reason duplicate` (use a separate `gh issue close` invocation with explicit reason + human confirm; the `trusted-filer-mutate` matcher blocks the not-planned case on trusted-filer Issues per SPEC §1.5).
- Closing without the closing comment (step 5) — the comment is the canonical evidence record.
- Writing to the Project Item directly — the mirror handles the Status field.
