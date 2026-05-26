---
description: File a discussion-tier Issue (SPEC §5.19) — friction-free filing for "weird but not a bug" observations. Bypasses rationale triad + issue-reviewer gate.
argument-hint: <one-line title>
---

File a discussion-tier Issue per SPEC §5.19. Lower friction than `/file-issue`: no MISSION fit, no acceptance criteria, no rationale-triad check, no `issue-reviewer` gate. The discussion body IS the observation; clarification develops in comments.

## Procedure

1. **Parse `$ARGUMENTS`** — the user's one-line title or short framing. Empty → ask for title and stop.

2. **Optional body capture** — if the user typed more than a one-line title, treat the rest as the initial body. If only a one-line title, prompt the user for a one-paragraph body framing the observation. Body MAY include links to related Issues / PRs (the optional `notes` field on `.github/ISSUE_TEMPLATE/discussion.yml`).

3. **No rationale triad, no reviewer gate.** This is the whole point of the tier (SPEC §5.19). Friction is deferred to the maintainer's classification at close time.

4. **Create the Issue**:
   ```bash
   gh issue create \
     --title "discussion: <title from $1>" \
     --body "<body from step 2>" \
     --label "discussion"
   ```
   Capture the new Issue number `<N>`.

5. **Audit log** — `audit_log info discuss created "discussion: #<N> title=<short>"`. No rationale, no reviewer-verdict field — friction-free filing means a friction-free audit shape.

6. **Output**:
   ```
   Filed Discussion #<N>: <title>
   Develop in comments. Close with /resolve-discussion <N> --promoted-to <M>
   OR /resolve-discussion <N> --no-action "<reason>".
   ```

## Operating mode

Same in attended and unattended — no reviewer to skip, no human to confirm. The skill is intentionally light.

## Escape

None needed — there's nothing to skip. Maintainers may still file via `/file-issue` if they want the rationale-triad path.

## Forbidden

- Creating an Issue without the `discussion` label.
- Adding MISSION fit / acceptance criteria / rationale-triad prompts — those defeat the purpose of the tier.
- Routing to `issue-reviewer` — the gate is OFF for discussion-tier filings (SPEC §5.19).
