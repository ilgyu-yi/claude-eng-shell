# Escape Hatch

Full spec in [SPEC.md §7](../SPEC.md).

How to temporarily bypass a hook block.

## Form

```bash
SKIP_HOOKS=<category>[,<category>...] SKIP_REASON='<reason>' <command>
```

## Categories

- `all` — emergencies only.
- `secret` — secret pattern detected in staged diff.
- `branch` — commit/push/edit on a protected branch.
- `commit-format` — Conventional Commit format violation.
- `format` — lint failure at commit time.
- `force-push` — force push.
- `amend` — `--amend` after push.
- `no-verify` — `git commit --no-verify`.
- `destructive` — `git reset --hard`, `git clean -f`, etc.
- `sensitive` — edit to `.env`/`*.pem`/`credentials*`.
- `out-of-scope` — Edit/Write outside registry, or `rm`/`mv`/`cp -f` args pointing outside registry.

## Examples

```bash
SKIP_HOOKS=force-push SKIP_REASON='cleaning up bad history from rebase' git push --force-with-lease

SKIP_HOOKS=format SKIP_REASON='formatter lockfile conflict; will fix in next commit' git commit -m "feat(#42): partial"

SKIP_HOOKS=out-of-scope SKIP_REASON='ad-hoc cache cleanup' rm -rf /tmp/some-cache
```

## Policy

- Skips should be temporary.
- A skip with no `SKIP_REASON` is logged as `unspecified` — easy review target.
- Use `all` only in emergencies.
- A category that gets skipped repeatedly is a sign the hook is misconfigured — open a PR to fix it.

Every skip is recorded as one line of JSON in `.claude/audit/audit.jsonl`.
