# ADR 0004: Symbol navigation for subagents — the shell does not own LSP; targets bring their own; grep is the universal fallback

- Date: 2026-06-22
- Status: Accepted
- Context PR: #433

## Context

The MISSION selective-injection half wants relevant material pulled in on demand; symbol-precise navigation (go-to-def, find-refs) and code diagnostics (find syntax/lint issues) are *low-noise* injection. The motivating "why now" (Issue #426) is the #416 review's completeness risk: grep can miss a call-site in a multi-site change. The central constraint is the shell boundary: *never touch user-global state* (MISSION isolation model: shared code, per-project ephemeral state only).

**The operative corpus is the bound *target* repo, not the shell's own bash.** The shell is a wrapper for developing *other* repos; its subagents (`explorer`/`planner`) navigate the target's code, which may be any language. Judging this question on the shell's own bash alone would be a category error — so it is split into two corpora:

**(a) The shell's own repo (bash) — minor case.** 53 `.sh` files, ~91 functions. A "symbol" is a bash function; go-to-def is `grep -rn '^<name>()' --include='*.sh'` and find-refs is `grep -rn '\b<name>\b' --include='*.sh'` — word-boundary grep is precise-enough, and this very session navigated the repo's intricate hook/helper graph (call-sites of `scan_staged_secrets`, consumers of `PROTECTED_BRANCH_PATTERN`, …) entirely via grep, adequately. Diagnostics for bash are `bash -n` + `shellcheck`, already run by the CI `syntax` job (§11). Both LSP faces are already covered here.

**(b) Bound target repos (arbitrary language) — the real case.** For typed/namespaced/overloaded languages (TS, Python, Go, Rust), grep find-refs over-matches badly (same method name across classes, imports vs locals) and go-to-def is genuinely ambiguous — an LSP/AST tool delivers precision grep cannot. So the navigation value is *real* on targets, unlike the bash self-case. **But the boundary bites hardest exactly here:** a shell that installed per-language LSP servers would violate the boundary (global install) and owe an *unbounded* per-language obligation across all bound targets — the load-bearing objection, not a hypothetical. The decisive fact: **targets typically already bring their own code intelligence** (a TS project has `tsserver`, a Python project `pyright`; the harness itself may provide target code navigation), so the need can be met by *consuming* existing tooling rather than the shell *providing* it.

Two further facts: in-boundary index storage exists (`.claude/ghjig-state/`, gitignored, per-project) — so storage is never the blocker, the binary/server install is; and a bespoke pure-shell symbol helper is possible but marginal even on the bash self-case.

## Decision

**The shell does not own or install LSP/MCP servers. On the shell's own bash, word-boundary grep + `shellcheck` already cover both navigation and diagnostics. On bound targets, the navigation need is real but is met by *consuming* the code intelligence the target or the harness already provides — which the shell neither installs nor forbids. grep is the universal fallback.**

- **NO-GO: a shell-owned / shell-installed LSP across languages.** Cost-asymmetry (§6.0) is lopsided and the wrong-cost is highest on targets: a global/per-language server install violates the boundary and creates an *unbounded* per-language obligation across all bound targets. This is the dominant objection — not the bash self-case.
- **GO (positive guidance, boundary-safe): consume existing target/harness code intelligence; don't provide it.** On a typed/namespaced target where grep find-refs degrades, subagents should *prefer the code intelligence already present* — the target's configured LSP (e.g. via the target's own `.mcp.json`) or the harness's native code navigation — over hand-rolled grep. The shell **neither installs nor blocks** a target bringing its own language server; that is per-project state the target owns, fully inside the isolation model. (Documenting this preference is a follow-up doc issue.)
- **GO (cheap, documentary): a word-boundary find-refs idiom for multi-site changes.** The #416 risk is *discipline*, not capability — enumerate call-sites before a rename/multi-site edit. On bash this is the grep one-liner; on a typed target it is the target's find-refs. Document it as a `planner`/`explorer` step. (Same follow-up doc issue.)
- **NO-GO / DEFER: a bespoke pure-shell symbol helper** (`symdef`/`symrefs`). Boundary-safe but marginal over the grep one-liner on the bash self-case, and it does nothing for typed targets (where the target's own LSP is the right tool). Not worth a new surface.

## Alternatives considered

- **`bash-language-server` over per-project MCP (`.mcp.json`)** — rejected: `.mcp.json` is in-boundary, but the *server install* (npm/node) is not, the process lifecycle is heavyweight for a non-node repo, and it generalizes badly to varied target languages. Precision gain over word-boundary grep doesn't justify it for bash.
- **universal-ctags index into `.claude/ghjig-state/`** — rejected: requires installing universal-ctags (the platform ships only BSD `ctags`, weak on bash); the binary install is the boundary cost. Storage would be clean; the dependency is not.
- **A pure-shell `symdef`/`symrefs` helper** — boundary-safe and considered seriously, but deferred: marginal gain over the grep one-liner at 91 functions; adds a surface for little benefit. Revisit if the corpus grows or precision pain recurs.
- **Shell *provides* a single all-language symbol-nav capability** — rejected: the boundary + unbounded-per-language objection. The shell's job is to *use* what a target brings, not to become a polyglot LSP host.
- **Do nothing, not even document the consume-existing-tooling preference** — rejected: on typed targets grep genuinely degrades, so leaving subagents to default to grep there is a real quality gap; the cheapest mitigation (documenting "prefer the target's/harness's code intelligence on typed targets") is worth taking.

## Consequences

- **Positive.** Keeps the boundary intact (no install, no global state, no per-language obligation) while still meeting the real target-repo navigation need — by consuming the target's/harness's existing code intelligence rather than the shell hosting it. Word-boundary grep stays the universal fallback, augmenting never replacing the grep/glob flow (issue AC3).
- **Negative / accepted residual.** On a typed target with *no* configured code intelligence and *no* harness-native navigation, subagents fall back to grep and inherit its over-match imprecision. Accepted: the boundary forbids the shell from filling that gap by installing a server; the target can close it by configuring its own.
- **Revisit triggers.** (a) A bound target repeatedly hits grep-imprecision pain *and* has no available code intelligence to consume — evidence the consume-don't-provide stance leaves a real gap; (b) a *zero-install, in-boundary* polyglot symbol-nav mechanism becomes available to the shell; (c) the harness ships first-class code navigation the shell should explicitly route subagents to. On any trigger, reopen — but still never as a shell-installed per-language server farm.
- **Follow-up (not built here — scoping spike).** A doc issue: instruct `planner`/`explorer` to (i) prefer the target's/harness's code intelligence over grep on typed targets, and (ii) run find-refs (the idiom — target LSP or word-boundary grep) before a multi-site change. No tooling build; the shell installs nothing.

## Notes

- Spike issue: #426. Gates: issue-reviewer (ship), activation-reviewer (pass).
- Surveyed: 53 `.sh` / ~91 functions; no `.mcp.json`; platform `ctags` is BSD (weak bash support); `.claude/ghjig-state/` (gitignored, in-boundary) as candidate index storage.
- Distinct from #422/`/recall` (decision record — issues/PRs/ADRs — not code symbols). Distinct from ADR-0002 (#424, generation-side fill) and ADR-0003 (#425, tracing/eval).
- Related: MISSION "The mechanism" (selective injection — low-noise); MISSION isolation model + CLAUDE.md Boundary (no user-global state); SPEC §6.0 (cost-asymmetry).
