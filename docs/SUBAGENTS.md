# Subagents

Full specs in [SPEC.md §4](../SPEC.md).

| Agent | When | Input | Output |
|-------|------|-------|--------|
| `planner` | Before code edits. Required for 3+ file changes, migrations, API changes | User request, issue body, MISSION, target CLAUDE.md | Plan + Doc/Test/Code-ordered checklist (markdown for PR body) |
| `explorer` | Wide read-only exploration. Protects main context | Search question | Definition + up to 5 references, summarized |
| `doc-writer` | Phase A. When external surface changes | Intent of change | Identifies affected SSOT + patches. Stub proposal only if absent |
| `test-writer` | Phase B. Right after Phase A | doc/spec | Failing test (intentional failure confirmed) |
| `code-reviewer` | Before commit/PR. Auto-called by `/review` and `/ship` | diff + PR body + MISSION + issue body (no chat context) | ship / ship after fix / block + `path:line` |
| `security-reviewer` | Auth/input/deps/crypto changes | diff | High/Medium/Low/Info + risk + remediation |

## Call policy

You don't need to call all six on a single PR. Don't re-run something the main assistant already explored in `explorer`. No call-count limits or tracking.

## How to call (from within Claude Code)

```
> have planner take this change
> review the PR with code-reviewer
> run security-reviewer on the auth changes
```

Or use `/review`, `/ship` for automatic invocation.
