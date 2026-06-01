# claude-eng-shell

[English](README.md) | **한국어**

**[Claude Code](https://docs.claude.com/claude-code)를 위한, 강한 의견(opinionated)을 담은 워크플로 셸입니다.** 이 셸은 Claude Code 세션을, 숙련된 사람이 GitHub 저장소에서 적용할 엔지니어링 규율 — issue → branch → draft PR → reviewed commits → ready merge — 으로 감싸고, 그 규율을 hook, slash command, subagent, 그리고 audit trail로 구현합니다. 목적은 AI가 엔지니어링 작업을 처음부터 끝까지 주도하면서도, 신중한 사람이라면 건너뛰지 않을 점검들을 지나쳐 드리프트(drift)하지 않도록 하는 것입니다.

- **[MISSION.md](MISSION.md)** — 12개월 후의 성공이 어떤 모습인지, 누구를 위한 것인지, 그리고 명시적으로 목표가 *아닌* 것이 무엇인지.
- **[SPEC.md](SPEC.md)** — 단일하고 자기완결적인 명세서(약 2,000줄). 맨 위의 **Table of contents**에서 시작해, 파일 전체를 로드하지 말고 `Read --offset --limit`로 개별 섹션을 읽으세요.

## Install

```bash
git clone <this-repo-url> claude-eng-shell
cd claude-eng-shell
./scripts/bootstrap.sh                 # checks dependencies only — never edits ~/.zshrc
export PATH="$PWD/bin:$PATH"            # or: alias claude-eng="$PWD/bin/claude-eng"
```

`bootstrap.sh`는 의존성만 점검합니다 — `git`, `gh`, `jq`는 필수이고, `python3`는 권장됩니다(여러 helper가 사용하며, python이 없으면 덜 정밀한 동작으로 폴백). 이 스크립트는 `~/.zshrc`나 그 밖의 사용자 전역(user-global) 파일을 절대 수정하지 않습니다.

## Quick start

```bash
# Clone a target repo into the shell's workspace/ (or register an external path — see below).
./scripts/clone-into.sh https://github.com/<owner>/<repo>.git
cd workspace/<repo>
claude-eng

# Inside the session — the engineering loop:
> /onboard                      # one-time: check upstream, permissions, SSOT, CI
> /file-issue <description>     # files the Issue as status:proposed
> /activate <issue#>            # Proposed → Active (reviewer-gated; required before /work-on)
> /work-on <issue#>             # branch + draft PR + planner
                                #   …or  /work-on <issue#> --base experiment/foo  (topic-branch flow, SPEC §10.5)
> /ship                         # review, tick AC, mark ready (→ merge in unattended mode)
```

`workspace/`로 clone하는 대신 외부 경로를 등록할 수도 있습니다:

```bash
./scripts/register.sh ~/code/<repo>     # or: claude-eng ~/code/<repo> — an unregistered path prompts to register
```

## How the loop runs

두 개의 운영 계층(operating layer)이 있고, 둘 다 같은 **generate → review → gated approval → audit** 패턴을 따릅니다:

- **eng-mode** — 엔지니어링 실행. `/file-issue` → `/activate` → `/work-on` (branch + draft PR) → Doc → Test → Code commit들 → `/ship` (reviewer 실행, AC 체크, ready 전환) → merge.
- **dir-mode** — 유지보수 디렉팅. `/file-directive` → `/activate` → `/file-issue --parent <N>`로 Execution Issue 분기 → Directive의 success signal이 충족되면 `/complete-directive`. Directive 위에는 선택적 **Initiative** 계층이 있습니다 — 셸이 *작성하지 않고 소비하는* 계획 아티팩트입니다(`/consume-initiative`, `/initiative-feedback`). 전체 흐름과 substrate 설치(`/onboard-dir-mode`)는 **[docs/DIR_MODE_FLOW.md](docs/DIR_MODE_FLOW.md)**에 있으며, 다중-PR Directive를 위한 topic-branch 격리는 SPEC §10.5입니다.

**`attended`** 모드(기본)에서는 에이전트가 PR-ready에서 멈추고 사람이 리뷰 + merge 하기를 기다립니다. **`unattended`** 모드에서는 reviewer subagent가 사람 승인을 대체하며, `/ship`이 merge(clean PR)로 진행하거나 park(hard blocker)합니다. target별로 `echo unattended > .claude/state/mode`로 설정하거나, 호출별로 `/ship --mode=unattended`로 재정의합니다. 전체 해석 우선순위 + blocker 규칙은 SPEC §5.7.1을 참고하세요.

## Why this shape

작지만 핵심을 떠받치는 관찰 하나가 설계를 이끕니다: **AI 에이전트의 출력 품질은 작업 컨텍스트의 크기와 관련성(relevance)에 의해 제한된다.** 자유 형식 세션은 파일을 임기응변으로 읽고, 곁가지를 쌓으며, 작업 전체를 하나의 윈도우에 담아두기를 모델에 요구합니다 — 그 윈도우가 무관한 자료로 채워질수록, 드리프트하고, 불변식(invariant)을 환각하며, 전제조건을 잃습니다. 그래서 이 셸은 하나의 작업을 좁고 잘 정의된 단계(phase)로 쪼개고, 그 밖의 모든 것을 활성 컨텍스트 *밖으로* 밀어냅니다. 엔지니어링 규율이 지렛대이고, 컨텍스트 규율이 그 효과입니다:

- **Doc → Test → Code**는 작업을 짧은-컨텍스트 3단계로 나눕니다 — 각 단계는 자신에게 필요한 것만 읽고, 각 단계의 산출물(doc commit, 실패-test commit, 통과-test commit)이 다음 단계의 입력입니다.
- **Subagent는 격리된 윈도우에서 실행됩니다.** `planner`, `doc-writer`, `test-writer`, 그리고 `*-reviewer` 계열은 새 컨텍스트로 시작해 자기 일을 하고 transcript가 아니라 verdict를 반환합니다. 탐색·계획 소모가 메인 세션을 오염시키지 않습니다.
- **GitHub 아티팩트가 지속 메모리(durable memory)입니다.** branch 상태, PR 본문, AC 체크박스, commit 히스토리, audit log는 세션을 넘어 살아남습니다; 재개된 세션은 자기 위치를 저장소에서 읽고, SessionStart는 관련된 조각만 다시 주입합니다.
- **Hook이 규칙을 강제하므로** 에이전트가 스스로를 단속하는 데 컨텍스트를 쓰지 않습니다 — protected-branch commit, secret, 잘못된 형식의 메시지, AC 미체크 merge는 거부되며, 정당한 경우를 위한 audit-log된 escape hatch가 있습니다.
- **Reviewer는 대화가 아니라 아티팩트로 판단합니다** — 그것을 만든 토론이 아니라 diff + PR 본문 + MISSION을 봅니다. 새로운 독자는 선입견을 가진 독자가 잡지 못하는 것을 잡아냅니다.

모든 메커니즘은 같은 지렛대를 겨냥합니다: 어느 순간이든 모델이 추론하는 컨텍스트 조각을 가능한 한 작고 관련성 높게 유지하는 것. 이것이 이 셸이 긴 대화가 아니라 아티팩트 계층(`MISSION.md` → Directive → Execution Issue → PR → commits)을 중심으로 구조화된 이유입니다 — 각 계층은 자체 reviewer를 가진 컨텍스트 경계이고, 각 계층의 산출물은 다음 계층이 읽는 것입니다.

## Subagents

총 아홉: `explorer`, `planner`, `doc-writer`, `test-writer`, `code-reviewer`, `security-reviewer`, `issue-reviewer`, `plan-reviewer`, `activation-reviewer`. 다섯 reviewer(`code-`, `security-`, `issue-`, `plan-`, `activation-`)는 `unattended` 모드에서 human-confirm 체크포인트를 대체합니다. 각각을 언제 쓰는지는 [docs/SUBAGENTS.md](docs/SUBAGENTS.md)를 참고하세요.

## What the hooks enforce

환경은 신중한 엔지니어라면 하지 않을 일을 거부하고, 모든 block을 `.claude/audit/audit.jsonl`에 audit-log합니다. 그 표면에는 다음이 포함됩니다:

- **Git 안전** — protected branch로의 직접 commit/push, force-push, push 이후의 `--amend`, `--no-verify`.
- **Secret 및 민감 파일** — staged diff 속 secret 패턴(`.shellsecretignore`로 경로 allow-list 지정); `.env`, `*.pem`, `credentials*`에 대한 편집.
- **Scope** — 등록된 범위 밖의 경로에 대한 Edit/Write, 또는 파괴적 `rm -rf`/`mv -f`/`cp -f`.
- **워크플로 무결성** — 미체크 AC가 있는 `gh pr merge`(`ac-closeout`) 또는 default branch로의 비-`--merge` 전략(`merge-strategy`); `status:proposed` 또는 Directive Issue에 대한 branch 생성(`proposed-protect`); Issue의 parent-marker와 모순되는 label(`label-parent-consistency`); 그리고 trusted-filer Issue 변경.

모든 block은 escape 가능하며 audit-log됩니다. Claude Code Bash 도구 안에서는 후행 sentinel `<command>  # claude-eng:skip=<category> reason=<why>`를 사용하세요; 선행 `SKIP_HOOKS=<category> SKIP_REASON='<why>' <command>` env-prefix 형식은 명령 문자열에 그대로 도달하는 환경(실제 shell, smoke harness)에서만 동작합니다. 전체 강제(enforcement) 표면, fail-policy, 튜닝 메커니즘은 **SPEC §6.1 / §6.5 / §7**에 있습니다.

## Configuration toggles

모두 선택 사항입니다; target별 상태는 `.claude/state/` 아래에 있고(gitignored), 설정된 경우 env var가 우선합니다. 전체 toggle 카탈로그 — operating mode, Co-Authored-By trailer, cache TTL, timeout, unattended park log, dir-mode Project 이름 등 — 는 **[docs/CONFIG.md](docs/CONFIG.md)**에 있습니다.

## Versioning

셸 버전은 최상위 `VERSION` 파일의 [semver](https://semver.org) 0.x 한 줄입니다(v0 전반에 걸쳐 `MAJOR=0`); 태그는 `v` + semver입니다(예: `v0.2.0`). `claude-eng --version`이 이를 출력합니다 — registry/scope 해석 이전에 단락(short-circuit)되므로 어떤 cwd에서도 동작합니다. [SemVer 2.0 §4](https://semver.org/#spec-item-4)에 따라 0.x bump는 계약이 아니라 정보 신호입니다; 태그는 마일스톤이 merge된 후 maintainer가 수동으로 push합니다. PR별 changelog fragment는 `changelog_unreleased/<category>/<N>.md`([TEMPLATE](changelog_unreleased/TEMPLATE.md)) 아래에 두며, `/release <X.Y.Z>`가 이를 [CHANGELOG.md](CHANGELOG.md)로 통합합니다. 전체 계약: SPEC §18.

## Docs

- [MISSION.md](MISSION.md) — 장기 방향성과 성공 기준.
- [SPEC.md](SPEC.md) — 단일하고 자기완결적인 명세서(SSOT); 맨 위의 TOC에서 시작하세요.
- [docs/ENGINEERING_FLOW.md](docs/ENGINEERING_FLOW.md) — 단계별 엔지니어링 흐름.
- [docs/DIR_MODE_FLOW.md](docs/DIR_MODE_FLOW.md) — dir-mode 흐름(Directive, Initiative, substrate tier).
- [docs/SUBAGENTS.md](docs/SUBAGENTS.md) — subagent 사용 가이드.
- [docs/CONFIG.md](docs/CONFIG.md) — configuration toggle.
- [docs/ESCAPE_HATCH.md](docs/ESCAPE_HATCH.md) — hook을 안전하게 우회하기.
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — 흔한 block과 해결책.

## Verify

```bash
./scripts/test/smoke.sh           # 547 assertions across hooks, helpers, slash commands
./scripts/build_toc.sh --check    # SPEC.md TOC freshness
```
