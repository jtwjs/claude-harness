---
description: SDD 전체 워크플로우 오케스트레이터 — 기능·버그 작업을 DESIGN→PLAN→IMPLEMENT→REVIEW→REFLECT로 자동 진행한다. 스펙→테스트→구현 순서를 강제하고, 위임 구간은 자동으로 넘어가되 사람 체크포인트에서만 멈춘다. Use when 새 기능·버그 작업을 시작할 때(단계별 수동 호출 대신 이 흐름으로).
disable-model-invocation: false
---

SDD 단계를 순서대로 이어 진행하는 오케스트레이터. 각 단계를 해당 스킬/에이전트에 위임하고, **위임 구간은 자동으로 진행하되 사람 체크포인트에서만 멈춘다.** (개별 단계는 `/harness` 등으로 직접 호출도 가능.)

> **한 줄 흐름**
> **코어 트랙** — `why-logictree`(스펙) → `harness`(분해) → `grilling`(빈칸) → 🙋 → **`test-writer`(RED) → `feature-builder`(GREEN)** → `sdd-review` → `code-reviewer` → REFLECT
> **디자인 트랙** — 위 흐름에 3개가 끼어든다: DESIGN에 `design-brief`, PLAN에 `design-plan`, REVIEW에 `design-reconcile`

## 0. 트랙 판단

**사용자에게 보이는 화면을 만들거나 고치는 작업인가?**

| 답 | 트랙 | 무엇이 달라지나 |
|---|---|---|
| 예 (UI·화면) | **디자인 트랙** | DESIGN·PLAN·REVIEW에 디자인 3스킬이 각각 끼어든다 |
| 아니오 | **코어 트랙** | 아래 5단계 그대로 |

애매하면 묻는다. 서버 내부 로직이어도 **운영 화면·대시보드가 딸려 오면 디자인 트랙**이다.

## 단계 진행 (🤖 자동 위임 / 🙋 사람 체크포인트)

1. **DESIGN** — `docs/{feature-YYYY-MM-DD}/`에 PRD·ARCHITECTURE·ADR을 확보한다.
   **PRD가 없거나 과제가 아직 막연하면 `why-logictree`로 먼저 만든다**(WHY→3질문→로직트리→So What/Why So). → 🙋 확인.
   ⚠️ PRD의 **수용 조건**이 `test-writer`의 입력이다. 여기가 비면 뒤가 전부 빈다.
   🎨 **디자인 트랙**: PRD 확정 후 `design-brief`로 `.claude/design/`에 브리프를 만든다 →
   사람이 `/design`(Claude Code 내장) 또는 웹 캔버스로 시안 생성 → 프로젝트 URL 회수. → 🙋 확인.
2. **PLAN** — `harness`로 step 분해(각 step에 `tdd: true|false` 판정 포함).
   step 파일에 `⚠️`·`TBD`·미해결 가정이 **3개 이상**이거나 사람이 요청하면 `grilling`으로 빈칸을 캐묻는다. → 🙋 step 계획 승인.
   🎨 **디자인 트랙**: `harness` **앞에** `design-plan`을 돌린다 — 디자인 파일을 끝까지 읽고
   요소↔컴포넌트 매핑·역질문·신규 컴포넌트 합의를 끝낸 뒤 step을 쪼갠다.
   **디자인→코드가 이 워크플로에서 가장 오류가 잦은 지점**이라 여기를 건너뛰면 IMPLEMENT가 표류한다.
3. **IMPLEMENT** 🤖 — `harness-run`이 step마다 2단으로 돈다. hands-off.
   - **RED**: `test-writer` → `verify.test`가 **실패해야** 통과 (전부 통과하면 잡는 게 없다는 뜻이라 step 실패)
   - **GREEN**: `feature-builder` → `verify` 전체 통과 **AND** diff에 테스트 파일 없음
   - (🙋 정지: blocked / 파괴적 변경 / 3회 실패.)
4. **REVIEW** — `sdd-review` 체크리스트 → escalate 판정에 따라 `code-reviewer` 심층 🤖 → 🙋 최종 판정.
   🎨 **디자인 트랙**: `design-reconcile`로 구현 화면을 스크린샷 대조하고 드리프트를 양방향 플래그한다.
   **자동 clobber 금지** — 발산은 보고 후 사람 결정.
5. **REFLECT** 🤖 — 먼저 **세션 학습 회수**: `/revise-claude-md`(공식 플러그인 `claude-md-management`. Skill 도구로는 `claude-md-management:revise-claude-md`). 세션에서 말로 설명하고 흘려버린 것을 찾아 개념당 한 줄로 제안한다. **매 세션, 커밋 전.**
   🔴 **종착지는 하네스 3층으로 재지정한다** — 이 명령의 기본값은 CLAUDE.md라 그대로 두면 CLAUDE.md가 부푼다. 판정 한 줄(*"안 읽고 코드를 쓰면 규칙을 어기게 되나?"*)로 가른다: 함정·규칙은 `.claude/rules/non-obvious-patterns.md`, 길면 `.claude/references/`, CLAUDE.md에는 CRITICAL·링크만. **diff 승인보다 이 판정이 먼저다.**
   플러그인이 없으면 건너뛰고 **건너뛴 사실을 한 줄 보고**한다(하드 의존 아님).
   그 다음 `changeset`(릴리스 도구가 있고 사용자 영향 시) → `commit` → `pr-write`. **문서 한 줄은 고친 커밋과 같은 커밋에 태운다**(`rules/non-obvious-patterns.md` 자신의 규칙).
   그 다음 **지식 환류**: `_brain/`이 있으면 `brain-intake` → **`brain-sync`로 통합 wiki 이관**(🙋 확인 후).
   마지막에 `task-observer` — 이번 작업에서 **반복된 것**(재지시·재교정·불발)을 `.claude/observations.md`에 세고, 3회에 닿은 것만 승격 제안한다. 🙋 판정은 사람이.
   ⚖️ 앞의 `revise-claude-md`(매 세션·자동 수집)와 뒤의 `task-observer`(3회부터·손으로 승격)는 **다른 층**이다 — 앞은 흘린 컨텍스트를 줍고, 뒤는 반복을 센다.

## 사람 체크포인트 (여기서만 승인 대기)

① DESIGN(PRD·수용 조건) 확인 ② PLAN step 승인 ③ 파괴적 변경 ④ REVIEW 최종 판정 ⑤ blocked step ⑥ brain-sync 이관 ⑦ `revise-claude-md` diff 승인(종착지 판정 포함)

## 재개

중단 지점(`phases/{task}/index.json`의 status·현재 단계)을 읽고 이어서 진행한다. 디버깅이 필요하면 `root-cause-debugger`(`systematic-debugging` 규율). 원인이 확정되고 사람이 승인하면 **메인이** 해당 step을 `error → pending`으로 되돌리고 `error_message`에 근본 원인 한 줄을 남긴 뒤 루프를 재개한다.

> 디자인 트랙 3스킬은 **2026-09-01에 설치됐다**(`incubator/ready/` → `skills/`). 산출물 종착지는
> `.claude/design/` — `brief.md`(내용)·`DESIGN.md`(스타일)·`DESIGN-PLAN.md`(매핑)·`design-system-map.md`(레지스트리).
> 시안 생성은 `/design`(Claude Code 내장) 또는 claude.ai/design 웹 캔버스에서 **사람이 개시한다.**
