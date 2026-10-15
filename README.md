# claude-harness

레포에서 AI와 일하는 방식을 까는 Claude Code 플러그인이다. 대상 레포에서 `/harness-init`을 한 번 돌리면 스펙 우선 개발(SDD) 흐름, 테스트 먼저(RED/GREEN — 러너가 git 기록으로 확인) 규칙, 컨텍스트 3층, 팀 위키(`_brain/`)가 갖춰진다.

## 세 레포의 관계

```
새 맥       claude-dotfiles  ./sync.sh  →  ~/.claude 설정 + 플러그인 자동 설치(claude-harness 포함)
새 프로젝트  /project-new  →  stack-kits 코드 뼈대(degit)  →  /harness-init
기존 레포    /harness-init
```

| 레포 | 맡는 것 | 어디에 남나 | |
|---|---|---|---|
| [claude-dotfiles](https://github.com/jtwjs/claude-dotfiles) | 내 맥의 Claude Code 환경: 전역 CLAUDE.md, 상태줄, 플러그인 목록, 개인 스킬 | `~/.claude/` | |
| [claude-harness](https://github.com/jtwjs/claude-harness) | 레포에서 AI와 일하는 방식: 스킬, 에이전트, 훅, 템플릿 | 플러그인 + 각 레포의 `.claude/`·`_brain/` | 📍 지금 여기 |
| [stack-kits](https://github.com/jtwjs/stack-kits) | 새 프로젝트의 코드 뼈대: kotlin-spring, nextjs, fullstack | 새 레포의 코드 | |

## 빠른 시작

```bash
/plugin marketplace add Egonex-AI/Understand-Anything   # 의존 플러그인. 없으면 harness가 비활성화된다
/plugin marketplace add jtwjs/claude-harness
/plugin install claude-harness@jtwjs-plugins
/plugin install claude-md-management@claude-plugins-official   # 선택. REFLECT의 세션 학습 회수
```

기존 레포는 `/harness-init`, 새 프로젝트는 `/project-new`로 시작한다. 이미 깔린 레포에서 `/harness-init`을 다시 부르면 업그레이드 모드로 템플릿 사본(라우팅·`_brain/CLAUDE.md`·버전)만 새 버전에 맞춘다. 계획 승인을 브라우저에서 하려면 [plannotator](https://github.com/backnotprop/plannotator)를 추가로 깐다.

## 무엇이 들었나

| 칸 | 내용 |
|---|---|
| 스킬 25개 | SDD: `sdd` `harness` `harness-run` `sdd-review` `design-brief` `design-critique` `design-reconcile` · 탐구: `why`<br/>하네스: `project-new` `harness-init` `harness-doctor` `task-observer`<br/>지식: `brain-walk` `brain-sync` · 병렬: `conductor`<br/>품질: `systematic-debugging` `ai-readiness-cartography`<br/>마무리: `commit` `changeset` `pr-write` · 글쓰기: `slack-writing` `notion-writing`<br/>코드 이해: `explain-diff-html` `explain-diff-notion` `plannotator-visual-explainer` |
| 에이전트 4개 | `test-writer`·`feature-builder`(TDD 2단계 도구 — 러너는 안 부르고 사람이 엄격하게 할 때) `code-reviewer` `root-cause-debugger`. 커밋·push는 하지 않는다 |
| SDD 러너 | `skills/harness-run/scripts/sdd_runner.py` — 세션 안(`harness-run`)·헤드리스(`run`) 같은 규칙. step당 1번 호출 + git 기록 판정. 설계 `docs/sdd-runner.md` |
| 훅 11개 | Bash 전: `block-dangerous-bash`(위험 명령 + `harness.json` `guard.prodDb`의 운영 DB 조회 밖 SQL·운영 프로필 실행 + `gh pr merge` 사람 확인) `todo-warn` · Write/Edit 전: `tdd-guard` · Write/Edit 후: `auto-format` · Bash 후(성공·실패 둘 다): `loop-lock`<br/>세션 시작: `cadence-reminder` `learn-setup` `weekly-readiness-check` `prod-db-check` `brain-sync-auto` · 세션 끝: `validate-session-end` |
| `templates/` | 대상 레포에 남는 것: `CLAUDE.md`, `.claude/`, `.github/`, `_brain/`, `stacks/` |
| `incubator/` | 로드 경로 밖 대기 스킬(지금 비어 있음 — 이력은 `incubator/README.md`) |

각 스킬·훅이 하는 일은 `skills/*/SKILL.md`와 `hooks/*.sh` 머리에 있다.

## 어떻게 도나

```mermaid
flowchart TD
  A([요청]) --> D["① 계획 · DESIGN<br/>sdd references/design.md: 왜 → PRD · ARCHITECTURE · ADR"]
  D --> RD{🙋 Readiness}
  RD --> H["① 계획 · PLAN<br/>harness: step 분해 · 빈칸은 그 자리에서"]
  H --> G{🙋 step 승인}
  G --> R["② IMPLEMENT · harness-run / sdd_runner run<br/>step당 1번: 테스트 먼저 → 구현 → git 기록 판정"]
  R --> V["③ REVIEW · sdd-review"]
  V -->|위반| R
  V --> F["④ REFLECT<br/>회고 1장 → 하네스 되돌림 → 지식 정리 → 이해 증명"]
  F --> X{🙋 출구 조건}
  X --> P["⑤ 마무리 · changeset → commit → pr-write<br/>REFLECT 산출물과 같은 PR"]
```

`sdd`가 이 흐름을 이어 돌리고, 🙋에서만 사람 승인을 받는다. 각 단계 스킬은 따로 불러도 된다.

하네스 엔지니어링 6축(구조→맥락→계획→실행→검증→개선)과는 이렇게 포개진다 — 앞 두 축은 레포당 한 번, 뒤 네 축이 ①~④이고 ⑤ 마무리는 축 밖 릴리스다(2026-10-16).

| 축 | 스킬 | 주기 |
|---|---|---|
| 구조 | `project-new` `harness-init` `harness-doctor` `ai-readiness-cartography` | 레포당 1회 · 점검 격주 |
| 맥락 | `brain-walk` `brain-sync` (CLAUDE.md·rules·references는 `harness-init`이 깐다) | 레포당 1회 · 주기 |
| 계획 | ① 계획 = DESIGN(`sdd` 내장 절차 + `why`) → PLAN(`harness`) · 🎨 `design-brief` `design-critique` | 기능마다 |
| 실행 | ② IMPLEMENT `harness-run` `conductor` (`test-writer`·`feature-builder`) | 기능마다 |
| 검증 | ③ REVIEW `sdd-review` `code-reviewer` `design-reconcile` `root-cause-debugger` `systematic-debugging` | 기능마다 |
| 개선 | ④ REFLECT 회고 1장 · `revise-claude-md` · `task-observer` · `brain-sync` · 리허설 | 기능마다 |
| (축 밖·마무리) | ⑤ 마무리 `changeset` `commit` `pr-write` — 작업이 끝났을 때만 | 기능마다 |
| 축 밖 | `slack-writing` `notion-writing` `explain-diff-*` `plannotator-visual-explainer` | 필요할 때 |

| 무엇 | 어디 |
|---|---|
| 기능 스펙·설계(PRD·ARCHITECTURE·ADR) | `docs/{feature-YYYY-MM-DD}/` |
| 계속 고치는 결정·규칙·용어, 코드 인계 문서 | `_brain/wiki/` |
| 내가 배울 기술·도메인 지식(커밋 안 함) | `_learn/inbox.md` |
| 분야별 학습 레벨(FE·BE·인프라·도메인 × beginner/intermediate/advanced) | `~/.claude/learning-level.json` — 없으면 전부 beginner. 형식은 `docs/learning-level.md`. 레포를 빼려면 `~/.claude/learn-skip.txt`에 본 레포 경로 한 줄 |
| GitHub 쓰기 계정(owner별) | `~/.claude/gh-accounts.txt`에 `owner 계정` 한 줄 — 그 owner 레포에 이슈·PR·릴리스를 쓰는 명령은 그 계정일 때만 통과(`block-dangerous-bash`) |

컨텍스트는 3층이다. `CLAUDE.md`(항상 로드, 짧게), `.claude/rules/`(`paths:` 매칭 시 로드), `.claude/references/`(필요할 때 수동).

## 원칙·안전장치

- 추측으로 채우지 않는다. `harness-init`은 실제로 통과한 명령만 `verify`에 적는다.
- 위험 명령과 짝 테스트 없는 구현은 훅이 막는다.
- 반복은 3회부터 승격하고, 기본 종착지는 `rules/` 한 줄이다.
- 설계 근거와 변경 이력은 [docs/design-notes.md](docs/design-notes.md)에 있다.

## 관리자용

```bash
bash hooks/test.sh             # 훅 검증
scripts/release.sh --dry-run   # 할 일만 보여 준다
scripts/release.sh             # push → 마켓플레이스·플러그인 갱신 → 설치본 확인
```

사전 확인(main, 깨끗한 트리, plugin.json·marketplace.json 버전 일치, `hooks/test.sh` 통과)이 하나라도 어긋나면 아무것도 바꾸지 않고 멈춘다.
