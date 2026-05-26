---
description: List Directive Issues filtered by Status label (default omits Completed). Read-only (dir-mode v3 / ADR-0003).
argument-hint: [--status <state>]
---

List Directive Issues filtered by Status label. Read-only; queries Issues directly (Issues-as-SSOT per ADR-0003 — no Project Item lookup).

## Procedure

0. **Step 0 — substrate preflight** (ADR-0004; #118): verify the target satisfies this command's tier requirement. Tier 2 minimum for all dir-mode commands (10-label v3 set must exist). If `gh label list | grep -qx directive` fails, exit with `"target lacks dir-mode substrate; run /onboard-dir-mode --tier 2 first"`. Fail-open on `gh` network errors per ADR-0004 reversibility framing.

1. **Parse arguments**:
   - `--status <state>` — one of `Proposed | Active | Blocked | Completed | All`. Default: omit `Completed` (show Proposed + Active + Blocked).

2. **Build the gh query**:

   | --status value  | gh issue list flags |
   |-----------------|---------------------|
   | (default)       | `--label directive --state open --json number,title,labels,createdAt` (then filter out closed; below) |
   | `Proposed`      | `--label directive --label status:proposed --state open` |
   | `Active`        | `--label directive --state open` then post-filter rows with no `status:*` label |
   | `Blocked`       | `--label directive --label status:blocked --state open` |
   | `Completed`     | `--label directive --state closed --search "reason:completed"` (or `--state closed` with post-filter on closer reason) |
   | `All`           | `--label directive --state all` |

   Run the query with `--limit 200 --json number,title,labels,createdAt,closedAt,closedByPullRequestsReferences,stateReason`.

3. **Output as a table** (markdown-style, sorted by `number` ascending unless `--status All` in which case sort by Status group then number):

   ```
   | #   | Status     | Title                                           |
   |-----|------------|-------------------------------------------------|
   | 92  | Active     | directive: dir-mode v3 reframe Issues-as-SSOT   |
   | ... |            |                                                 |
   ```

   - Status derivation per Issue:
     - has `status:proposed` label → Proposed
     - has `status:blocked` label → Blocked
     - state=CLOSED + stateReason=completed → Completed
     - state=OPEN + neither status label → Active
   - If the list is empty after filters: `No Directives match the filter (status=<state>).`

4. **No audit emission** — read-only query.

## Operating mode

Same output in `attended` and `unattended` modes.

## Examples

```
/list-directives                         # Proposed + Active + Blocked (default; omits Completed)
/list-directives --status Active         # Active only
/list-directives --status All            # Everything including Completed
/list-directives --status Completed      # Closed directives only
```

## Forbidden

- Mutating any field. This is read-only.
- Querying the Project — Issues are SSOT per ADR-0003; the Project is a derived view that may lag. Always read from `gh issue list`.
- Hiding `Type=Directive` items that match the filter.
