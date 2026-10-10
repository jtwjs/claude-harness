---
name: sdd
description: SDD 전체 워크플로우 오케스트레이터 — 기능·버그 작업을 DESIGN→PLAN→IMPLEMENT→REVIEW→REFLECT로 자동 진행한다. 스펙→테스트→구현 순서를 강제하고, 위임 구간은 자동으로 넘어가되 사람 체크포인트에서만 멈춘다. Use when 새 기능·버그 작업을 시작할 때(단계별 수동 호출 대신 이 흐름으로).
disable-model-invocation: false
---

SDD 단계를 순서대로 이어 진행하는 오케스트레이터. 각 단계를 해당 스킬/에이전트에 위임하고, **위임 구간은 자동으로 진행하되 사람 체크포인트에서만 멈춘다.** (개별 단계는 `/harness` 등으로 직접 호출도 가능.)

> **한 줄 흐름**
> **코어 트랙** — `why-plan`(왜부터 캐물어 → PRD · `_brain` 맥락) → `harness`(분해) → 🙋(빈칸이 많으면 `why-plan` 한 번 더) → **`test-writer`(RED) → `feature-builder`(GREEN)** → `sdd-review` → `code-reviewer` → REFLECT
> **디자인 트랙** — 위 흐름에 둘이 끼어든다: DESIGN에 `design-brief`(→ `/design`), REVIEW에 `design-reconcile`. PLAN은 `harness`가 핸드오프를 읽는다

## 0. 트랙 판단

**사용자에게 보이는 화면을 만들거나 고치는 작업인가?**

| 답 | 트랙 | 무엇이 달라지나 |
|---|---|---|
| 예 (UI·화면) | **디자인 트랙** | DESIGN에 `design-brief`, REVIEW에 `design-reconcile` **2스킬**. PLAN은 `harness` §3-b가 핸드오프를 읽는다 |
| 아니오 | **코어 트랙** | 아래 5단계 그대로 |

애매하면 묻는다. 서버 내부 로직이어도 **운영 화면·대시보드가 딸려 오면 디자인 트랙**이다.

병렬 트랙(worktree 세션 2개 이상)이면 지휘 세션 하나는 `conductor`로 돈다. 각 트랙 세션은 이 흐름 그대로다.

## 단계 진행 (🤖 자동 위임 / 🙋 사람 체크포인트)

1. **DESIGN** — `docs/{feature-YYYY-MM-DD}/`에 PRD·ARCHITECTURE·ADR을 확보한다.
   **PRD가 없거나 과제가 아직 막연하면 `why-plan`으로 먼저 만든다**(크기 판정 → 날것·참고 자료 → WHY·3질문(필요하면 로직트리) → 갈래별 한 질문씩 → So What/Why So → PRD · 기술 결정은 `ADR.md` · 제품·도메인 결정은 `_brain/wiki/decisions/<주제>.md` · `_learn` 카드). → 🙋 확인.
   ⚠️ PRD의 **수용 조건**이 `test-writer`의 입력이다. 여기가 비면 뒤가 전부 빈다.
   🎨 **디자인 트랙**: PRD 확정 후 `design-brief`로 **시안 전에** 권한·상태·데이터 결정을 끝내고 `.claude/design/`에 브리프를 만든다 →
   사람이 `/design`으로 시안 생성(상태 화면까지) → 프로젝트 URL 회수. → 🙋 확인.
2. **PLAN** — `harness`로 step 분해(각 step에 `tdd: true|false` 판정 포함).
   step 파일에 `⚠️`·`TBD`·미해결 가정이 **3개 이상**이거나 사람이 요청하면 `why-plan`으로 빈칸을 캐묻는다. → 🙋 step 계획 승인.
   🎨 **디자인 트랙**: `harness` §3-b가 시안(핸드오프)을 읽어 step마다 디자인 파일·화면·쓸 컴포넌트를 박고, DS에 없는 요소만 뽑아 신규 컴포넌트를 합의한다.
3. **IMPLEMENT** 🤖 — `harness-run`이 step마다 2단으로 돈다. hands-off.
   - **RED**: `test-writer` → `verify.test`가 **실패해야** 통과 (전부 통과하면 잡는 게 없다는 뜻이라 step 실패)
   - **GREEN**: `feature-builder` → `verify` 전체 통과 **AND** diff에 테스트 파일 없음
   - (🙋 정지: blocked / 파괴적 변경 / step `retries`가 3이 됨.)
4. **REVIEW** — `sdd-review` 체크리스트 → escalate 판정에 따라 `code-reviewer` 심층 🤖 → 🙋 최종 판정.
   위반이 나오면 **`feature-builder`로 수정하고 `sdd-review`를 다시 돈다** — REVIEW에서 IMPLEMENT로 돌아가는 유일한 경로.
   🎨 **디자인 트랙**: `design-reconcile`로 구현 화면을 스크린샷 대조하고 어긋남의 방향(동기화 후보 / 후속 step / 토큰)을 판정한다.
   **자동으로 덮어쓰지 않는다** — 코드→디자인 반영은 사람이 `/design-sync`로.
5. **REFLECT** 🤖 + 🙋×3(+리허설 제안 시 1) — 먼저 **세션 학습 회수**: `/revise-claude-md`(공식 플러그인 `claude-md-management`. Skill 도구로는 `claude-md-management:revise-claude-md`). 세션에서 말로 설명하고 흘려버린 것을 찾아 개념당 한 줄로 제안한다. **매 세션, 커밋 전.**
   🔴 **종착지는 하네스 3층으로 재지정한다** — 이 명령의 기본값은 CLAUDE.md라 그대로 두면 CLAUDE.md가 부푼다. 판정 한 줄(*"안 읽고 코드를 쓰면 규칙을 어기게 되나?"*)로 가른다: 함정·규칙은 `.claude/rules/non-obvious-patterns.md`, 길면 `.claude/references/`, CLAUDE.md에는 CRITICAL·링크만. **diff 승인보다 이 판정이 먼저다.**
   플러그인이 없으면 건너뛰고 **건너뛴 사실을 한 줄 보고**한다(하드 의존 아님).
   그 다음 `changeset`(릴리스 도구가 있고 사용자 영향 시) → `commit` → `pr-write`. **문서 한 줄은 고친 커밋과 같은 커밋에 태운다**(`rules/non-obvious-patterns.md` 자신의 규칙).
   그 다음 **지식 환류**: `_brain/`(팀 위키·인수인계용)이 있으면 **`brain-sync`로 통합 wiki 이관**(🙋 확인 후). 구조가 크게 바뀐 작업이면 `brain-walk` 갱신을 제안한다. **개인 학습**은 `_learn/inbox.md`(커밋 안 됨, `learn-setup` 훅이 만든다)에 작업 중 이미 쌓였다 — 여기서는 **「이번 세션 학습 카드 n건」 한 줄만 보고**한다. vault로 옮기는 것은 통합 wiki 쪽 주간 `/gauge week`다.
   마지막에 `task-observer` — 이번 작업에서 **반복된 것**(재지시·재교정·불발)을 `.claude/observations.md`에 세고, 3회에 닿은 것만 승격 제안한다. 🙋 판정은 사람이.
   ⚖️ 앞의 `revise-claude-md`(매 세션·자동 수집)와 뒤의 `task-observer`(3회부터·손으로 승격)는 **다른 층**이다 — 앞은 흘린 컨텍스트를 줍고, 뒤는 반복을 센다.
   🎤 **설명 리허설**(설계 결정이 있던 작업이면 제안, 거절하면 건너뛴다) — ADR의 `결정 주체: AI 추천 수용` 결정부터 골라, 회의 참석자(팀장·옆 파트 동료) 역할로 질문 5개를 **하나씩** 던진다. 사람은 문서를 안 보고 자기 말로 답한다. 막힌 질문은 **사람의 학습 목록**으로 돌려준다 — `_learn/inbox.md`에 `종류: 막힌 질문 · 출처: 리허설` 카드로 남긴다(git에서 빠진 개인 폴더라 레포에는 남지 않는다). 리허설은 이해를 만드는 일이라 에이전트가 대신 답하지 않는다.

## 사람 체크포인트 (여기서만 승인 대기)

① **DESIGN** — PRD·수용 조건 확인 · PRD·`_brain` 맥락 저장 경로(`why-plan`) · 🎨 시안 URL 회수
② **PLAN** — `harness` 범위 합의 → step 계획 승인(PLAN 안에서 두 번 멈춘다) · 🎨 DS 신규 컴포넌트 승인
③ **IMPLEMENT** — blocked step · 파괴적 변경 · step `retries`가 3
④ **REVIEW** — 최종 판정
⑤ **REFLECT** — `revise-claude-md` diff 승인(종착지 판정 포함) · brain-sync 이관 · task-observer 승격 판정 · 🎤 설명 리허설(제안 시)

> 이 목록 밖에서 멈췄다면 스킬 쪽이 틀린 것이다 — 목록에 넣거나 스킬을 고친다. (2026-10-08: 선언 7곳 vs 실제 13곳이던 것을 맞춤)

## 재개

중단 지점(`phases/{task}/index.json`의 status·현재 단계)을 읽고 이어서 진행한다. 디버깅이 필요하면 `root-cause-debugger`(`systematic-debugging` 규율). 원인이 확정되고 사람이 승인하면 **메인이** 해당 step을 `error → pending`으로 되돌리고 `error_message`에 근본 원인 한 줄을 남긴 뒤 루프를 재개한다.

> 디자인 트랙은 `design-brief`(DESIGN) · `design-reconcile`(REVIEW) **2스킬**이다 — 2026-09-01에 3스킬로 설치됐다가 `design-plan`이 **0.9.0에서 삭제**됐고, PLAN 자리는 `harness`가 디자인 핸드오프를 읽는다. 산출물 종착지는
> `.claude/design/` — `brief.md`(내용)·`DESIGN.md`(스타일)·`design-system-map.md`(레지스트리).
> 시안 생성은 `/design`(Claude Code 내장) 또는 claude.ai/design 웹 캔버스에서 **사람이 개시한다.**
