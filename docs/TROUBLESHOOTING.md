# Troubleshooting

Common blocks and how to resolve them.

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| `Not a valid Conventional Commit` | Missing `(#N)` on `feat`/`fix`/`docs`/`refactor`/`perf`, or a typo'd type | Use `<type>(#<N>)[!]: <≤72 chars>`. `chore` and other optional types may omit `(#N)`. |
| `Subject length out of codepoint range 1..72` | Subject is empty or longer than 72 codepoints | Shorten. Detail goes in the body. |
| `commit on protected branch blocked` | Direct commit on main/master/release/* | Create a feature branch via `/work-on <issue#>`. |
| `force push blocked` | Used `--force`/`-f`/`--force-with-lease` | Plain `git push` where possible. If truly needed: `SKIP_HOOKS=force-push SKIP_REASON='...'`. |
| `--amend of an already-pushed commit blocked` | Amending a commit that's already on upstream | Make a new commit (`git commit -m`). History rewriting is a separate procedure. |
| `<file>:<line>: <pattern-id>` followed by `Possible secret pattern detected` | API key / PAT / similar in staged diff. The marker line gives the exact location; pattern-id (`aws-akia`, `gh-pat-classic`, etc.) names the matched rule | If real secret: remove and audit history. Legitimate doc/test fixture: add the path to `.shellsecretignore` at the target-repo root (gitignore-narrow globs; read from `HEAD`, so a new entry needs its own commit before the work it covers). Last resort: `SKIP_HOOKS=secret SKIP_REASON='...'`. |
| `sensitive file edit blocked` | Editing `.env`/`*.pem`/`credentials*` | These usually shouldn't be git-tracked. If truly needed, escape. |
| `edit outside registry blocked` | Edit/Write target is outside a registered path | (1) Verify the target is what you intended. (2) The shell deliberately stays within registered paths. For genuine outside work, escape. |
| Hook seems inactive | Current cwd isn't registered (check `.claude/state/registry.txt`) | Register with `scripts/register.sh <path>`. If you're working on the shell repo itself, re-run `scripts/bootstrap.sh` — it self-registers (§3.6). |
| `[claude-eng-shell] WARN inject-consistency: ...` (stderr at session start) | Workspace has `.claude/settings.local.json` as a shell-injected symlink, but the session launched via plain `claude` so `CLAUDE_ENG_SHELL_ROOT` is unset → every hook silently no-ops | Exit and relaunch with `claude-eng`, or `export CLAUDE_ENG_SHELL_ROOT=<path-to-shell-repo>` and restart. SPEC §6.5(c). |
| `linked issue has unchecked AC and no '## AC closeout' marker comment` (on `gh pr merge`) | The PR's `closingIssuesReferences` includes an issue whose body has `- [ ]` items and no comment whose first line is `## AC closeout`. Without the comment, the issue auto-closes with its AC list reading as "nothing was done" — SPEC §1.4 violation. | Run `scripts/ac_closeout.sh <pr-num>` — idempotent; posts the canonical closeout comment on every linked issue that needs one. `/ship` step 7.6 invokes it automatically. For emergencies or no-AC issues: `SKIP_HOOKS=ac-closeout SKIP_REASON='<why>'` (audit-logged). |
| `claude-eng` not found | PATH not set | `export PATH="$SHELL_ROOT/bin:$PATH"` or alias. Editing `~/.zshrc` is your call. |

## Reading the audit log

```bash
cat .claude/audit/audit.jsonl | tail -50
# or from inside Claude: /audit force-push
```

Repeated escapes in the same category mean the hook needs tuning.
