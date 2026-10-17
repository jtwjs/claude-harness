---
name: sdd
description: SDD 전체 워크플로우 오케스트레이터 — 기능·버그 작업을 ① 계획(DESIGN→PLAN) → ② IMPLEMENT → ③ REVIEW → ④ REFLECT → ⑤ 마무리(SHIP)로 자동 진행한다. 스펙→테스트→구현 순서를 강제하고, 위임 구간은 자동으로 넘어가되 사람 체크포인트에서만 멈춘다. Use when 새 기능·버그 작업을 시작할 때(단계별 수동 호출 대신 이 흐름으로). PRD가 없는 막연한 과제도 여기서 시작한다 — ① 계획 DESIGN이 인터뷰로 세 장을 만든다.
disable-model-invocation: false
---

SDD 단계를 순서대로 이어 진행하는 오케스트레이터. 각 단계를 해당 스킬/에이전트/참조 문서에 위임하고, **위임 구간은 자동으로 진행하되 사람 체크포인트에서만 멈춘다.** (개별 단계는 `/harness` 등으로 직접 호출도 가능.)

> **한 줄 흐름**
> **코어 트랙** — ① 계획: DESIGN(`references/design.md` — 왜부터 캐물어 → PRD·ARCHITECTURE·ADR → 🙋 Readiness) → PLAN(`harness` 분해 · 빈칸은 그 자리에서 → 🙋 step 승인) → ② **`harness-run`(step당 1번: 테스트 먼저 → 구현, git 기록으로 판정)** → 🙋빈틈 3곳 → ③ `sdd-review` → `code-reviewer` → ④ REFLECT(회고 1장 → 하네스 되돌림 → 지식 정리 → 이해 증명) → ⑤ 마무리(`changeset` → `commit` → `pr-write`)
> **디자인 트랙** — 위 흐름에 셋이 끼어든다: DESIGN에 `design-brief`(→ 레포 캔버스에 시안) → `design-critique`(시안 평가 루프), REVIEW에 `design-reconcile`. PLAN은 `harness`가 레포 캔버스를 읽는다
>
> 2026-10-16: DESIGN·PLAN을 **① 계획** 한 단계로 묶었다(하네스 엔지니어링 6축의 「계획」과 1:1). 밖에서 보면 하나, 안에서는 게이트 둘(Readiness → step 승인) — 묻는 것이 다르다("무엇을 왜"가 굳었나 / "어떻게 쪼갰나"). 릴리스는 REFLECT에서 떼어 **⑤ 마무리**로 — REFLECT가 pr-write 한 줄로 줄어 있었다(실측 30일: `_brain` 정리 0/8 세션, pr-write 125회).

## 0. 트랙 판단

**사용자에게 보이는 화면을 만들거나 고치는 작업인가?**

| 답 | 트랙 | 무엇이 달라지나 |
|---|---|---|
| 예 (UI·화면) | **디자인 트랙** | DESIGN에 `design-brief` → `design-critique`, REVIEW에 `design-reconcile` **3스킬**. PLAN은 `harness` §3-b가 레포 캔버스를 읽는다 |
| 아니오 | **코어 트랙** | 아래 5단계 그대로 |

애매하면 묻는다. 서버 내부 로직이어도 **운영 화면·대시보드가 딸려 오면 디자인 트랙**이다.

병렬 트랙(worktree 세션 2개 이상)이면 지휘 세션 하나는 `conductor`로 돈다. 각 트랙 세션은 이 흐름 그대로다.

## 단계 진행 (🤖 자동 위임 / 🙋 사람 체크포인트)

1. **계획** = DESIGN → PLAN. 한 단계, 게이트 둘.
   **DESIGN** — `docs/{feature-YYYY-MM-DD}/`에 PRD·ARCHITECTURE·ADR을 확보한다.
   세 장이 없거나 과제가 막연하면 **`${CLAUDE_PLUGIN_ROOT}/skills/sdd/references/design.md`를 읽고 그 절차대로** 만든다(크기 판정 → 날것·참고 자료 → WHY·3질문(`why` 탐구 모드) → 갈래별 한 질문씩 → 렌즈 점검(사용자 흐름 → 아키텍처 → 엣지·에러·보안+과설계) → So What/Why So → PRD → ARCHITECTURE → 기술 결정이 있으면 ADR · `_learn` 카드는 그 자리에서). 🔴 **절차를 건너뛰고 세 장을 바로 쓰지 않는다** — 질문 규칙(`why` 「질문 규칙」: 한 번에 한 질문 · "왜?"를 받을 결정은 사람 생각 먼저)과 Readiness가 빠진다. 세 장이 이미 있으면 Readiness만 돈다. `_brain`에는 아직 쓰지 않는다 — REFLECT에서 옮긴다. → 🙋 **Readiness 체크**(7항목 — AI 채점, 착수는 사람. "착수할까요?").
   ⚠️ PRD의 **수용 조건**이 각 step의 **먼저 쓰는 테스트**의 입력이다. 여기가 비면 뒤가 전부 빈다.
   🎨 **디자인 트랙**: PRD 확정 후 `design-brief`로 레퍼런스부터 정하고, **시안 전에** 권한·상태·데이터 결정(+ 닐슨 렌즈)을 끝내 `.claude/design/`에 브리프를 만든다 → 🙋 브리프 승인 →
   Claude가 **레포당 하나인 캔버스**의 `작업: <기능>` 탭에 시안을 그린다(제작 체크리스트 · `.claude/design/canvas/` 커밋) →
   `design-critique`로 시안 평가(페르소나 · 닐슨 휴리스틱 · 레퍼런스 실측 독립 병렬) → 체크포인트 `verdict: 변경`이면 반영 후 다시 → 🙋 `verdict: 승인`.
   **PLAN** — `harness`로 step 분해(각 step에 `tdd: true|false` 판정 포함). 세 장이 이미 있어 PLAN만 필요하면 `harness`를 바로 부른다.
   step 파일의 `⚠️`·`TBD`·미해결 가정은 `harness` §2가 **그 자리에서** 캐묻고(질문 규칙은 `why`) 결정을 PRD 「결정」/ADR에 적는다. 승인 시점 미해결 `⚠️` 0개. → 🙋 step 계획 승인.
   🎨 **디자인 트랙**: `harness` §3-b가 레포 캔버스의 작업 탭을 읽어 step마다 보드·뷰포트·쓸 컴포넌트를 박고, DS에 없는 요소만 뽑아 신규 컴포넌트를 합의한다.
2. **IMPLEMENT** 🤖 — `harness-run`이 step마다 호출 1번(테스트 먼저 → 구현)으로 돌리고 `sdd_runner.py judge`가 git 기록으로 판정한다. hands-off.
   - **RED**: 테스트만 담긴 커밋이 먼저 있고, 그 시점으로 돌려 `verify.test`가 **실패해야** 통과 (전부 통과하면 잡는 게 없다는 뜻이라 step 실패)
   - **GREEN**: `verify` 전체 통과 **AND** RED 커밋 뒤 테스트 파일 무변경 — 둘 다 `sdd_runner.py judge`가 본다. 사람이 없을 때는 같은 규칙의 `sdd_runner.py run`(헤드리스)
   - (🙋 정지: blocked / 파괴적 변경 / 재시도 3번 뒤에도 실패(최대 4회).)
   - 🙋 **빈틈 3곳** — 모든 step이 GREEN이 된 직후, REVIEW 전에 한 번. 이번 diff에서 사람이 **모를 수 있는 지점 3개**를 한 줄씩(`파일:줄` + 왜 헷갈릴 만한가) 낸다 → 사람이 고른 것만 12살 설명(+ React/TS 비유 하나) → **레벨 +@**: 그 지점 분야의 레벨(`~/.claude/learning-level.json`, 없으면 beginner · 형식 `${CLAUDE_PLUGIN_ROOT}/docs/learning-level.md`)이 beginner이면 그 지점이 기대는 기술을 정본의 「beginner 기술 카드」 한 장으로 풀고(이미 본 기술이면 여기선 왜 · 조심할 것만), 뒤에 도메인 한 줄(이게 사업·사용자에게 왜 필요한가)을 붙인다. intermediate·advanced은 지금 그대로 → 사람이 **자기 말 한 줄**. 답은 `_learn/inbox.md`에 `출처: 빈틈 3곳` 카드. "pass"면 건너뛰고 한 줄 보고. step마다 묻지 않는다 — IMPLEMENT는 hands-off다. 만든 직후에 묻는 이유: PR 때 처음 보면 이미 늦어 퀴즈만 남는다
3. **REVIEW** — `sdd-review` 체크리스트 → escalate 판정에 따라 `code-reviewer` 심층 🤖 → 🙋 최종 판정. 리뷰는 **같은 세션의 서브에이전트**가 한다 — 컨텍스트는 격리되고 세션은 그대로다(2026-10-16 확정. "새 세션에서 리뷰"는 쓰지 않는다).
   위반이 나오면 **수정 step을 하나 더 만들어 `harness-run`으로 고치고(작은 수정은 `feature-builder`) `sdd-review`를 다시 돈다** — REVIEW에서 IMPLEMENT로 돌아가는 유일한 경로.
   🎨 **디자인 트랙**: `design-reconcile`로 구현 화면을 스크린샷 대조하고 어긋남의 방향(동기화 후보 / 후속 step / 토큰)을 판정한다.
   **자동으로 덮어쓰지 않는다** — 🙋 통과 판정 뒤에만 작업 탭을 `현행` 탭에 반영하고 작업 탭을 지운다(캔버스 커밋).
4. **REFLECT** — **다음 바퀴를 덜 틀리게 만드는 단계.** 커밋 전, 사람이 자리에 있을 때 돈다(세션 끝 환기는 죽는다 — LEARNED.md 3곳 전부 사망 실측). 산출물 넷, 순서 고정. 작은 작업이라 절차를 줄여도 **회고 1장은 빼지 않는다.**
   1) **회고 1장 append** — `_brain/wiki/infra/retro.md`(레포당 1파일, 최신이 위. `_brain`이 없으면 `docs/retro.md`). 회고는 이력이라 고치지 않고 쌓는다.
      ```
      ## YYYY-MM-DD — <기능 slug>
      - 막힌 지점: step error·retries·재지시·리뷰 🔴·손으로 우회한 것 (없으면 "없음")
      - 원인 축: 맥락(CLAUDE.md·rules) / 검증(테스트·verify) / 도구(스킬·훅·MCP) / 코드(구조·패턴) / 공유(팀에 안 퍼짐)
      - 남긴 자산: <파일·훅·스킬·규칙 경로> — 막힌 지점이 있으면 비울 수 없다
      - 다음 후보: 아직 안 놓은 다리 (선택)
      ```
      막힌 지점은 `phases/{task}/index.json`의 error·retries·`attempts`, 세션의 재지시·재교정, `sdd-review` 🔴에서 **모은다** — 기억으로 쓰지 않는다. 막힌 지점이 0이면 "막힌 지점 없음" 한 줄로 끝.
   2) **하네스 되돌림 ≥1** — 회고의 「남긴 자산」을 실제로 놓는다. 종류별 종착지:
      - **흘린 것**(세션에서 말로 설명하고 지나간 규칙·패턴) → `/revise-claude-md`(공식 플러그인 `claude-md-management`. Skill 도구로는 `claude-md-management:revise-claude-md`). 🔴 **종착지는 하네스 3층으로 재지정** — 기본값 CLAUDE.md는 부푼다. 판정 한 줄(*"안 읽고 코드를 쓰면 규칙을 어기게 되나?"*): 함정·규칙은 `.claude/rules/non-obvious-patterns.md`, 길면 `.claude/references/`, CLAUDE.md에는 CRITICAL·링크만. **diff 승인보다 이 판정이 먼저다.** 플러그인이 없으면 건너뛰고 한 줄 보고.
      - **사고**(실제로 당한 함정) → `rules/non-obvious-patterns.md` 한 줄. 고친 커밋과 같은 PR.
      - **반복**(같은 지시·같은 교정·안 불린 스킬·못 맡긴 것·같은 수작업) → `task-observer`가 `.claude/observations.md`에 +1. 3회에 닿은 것만 승격 제안, 🙋 판정은 사람. 2회에 만들지 않는다.
      - **더하기만 금지** — 하나 넣었으면 안 쓰는 규칙·스킬·가드레일 하나를 지울 후보로 한 줄 낸다(없으면 "없음"). 개선은 다듬기다.
      ⚖️ `revise-claude-md`(매 세션·줍는다)와 `task-observer`(3회부터·센다)는 **다른 층**이다 — 한 줄로 끝나는 것은 앞이 줍고, 그 계열이 3회 재발하면 뒤가 승격을 건다.
   3) **지식 정리** — `_brain/`이 있을 때, 🙋 초안 승인. 이번 기능의 `docs/{feature-date}/` 세 장을 읽고 팀 위키로 옮긴다. 구현·리뷰 중 바뀐 결정까지 반영된 지금이 시점이다.

      | 세 장에서 | `_brain`으로 |
      |---|---|
      | PRD 「결정」 절(제품·도메인) | `_brain/wiki/decisions/<주제>.md` — 같은 주제가 있으면 고친다. PRD·ADR은 링크만 |
      | 기능과 무관하게 남는 규칙·용어 | `domain/` · `glossary/` |
      | ARCHITECTURE(구조가 바뀌었으면) | `brain-walk` 다섯 장 중 바뀐 장만 해당 부분 갱신 — 새 진입점 → 입출구 · 컬럼·테이블 → 테이블 표 · 흐름 → 생애 · 설정값 → 바뀔 수 있는 값 |
      | 순수 기술 ADR | 옮기지 않는다 — ADR이 정본 |

      다섯 장을 고쳤으면 `_brain/CLAUDE.md`의 lint를 한 번 돌리고, `log.md`에 `reflect` 항목·`index.md` 갱신. `_brain`이 없으면 PRD 「결정」 절이 그대로 정본이다. 원문·사람 이름·개인 vault 경로는 적지 않는다. 그 다음 **`brain-sync`로 통합 wiki 이관**(🙋 확인 후). **개인 학습**은 `_learn/inbox.md`에 작업 중 이미 쌓였다 — 「이번 세션 학습 카드 n건」 한 줄만 보고한다(vault로 옮기는 것은 통합 wiki 쪽 주간 `/gauge week`).
   4) **이해 증명** 🎤 — "왜?"를 받을 결정이 있던 작업이면 **설명 리허설**을 제안한다(거절하면 건너뛴다). ADR과 PRD 「결정」 절의 `결정 주체: AI 추천 수용` 결정부터 고르고, 없으면 PRD 「결정」 절 → ADR 순으로 골라, 회의 참석자(팀장·옆 파트 동료) 역할로 질문 5개를 **하나씩** 던진다. 질문 깊이는 그 결정 분야의 레벨을 따른다(`docs/learning-level.md` — beginner은 쓰인 기술의 큰 흐름부터 "이게 뭐고 보통 언제 써? 여기선 왜 썼어? 안 쓰면?", intermediate은 함정과 이 프로젝트 적용, advanced은 대안·트레이드오프). 끝나면 `history`에 `source: rehearsal` 한 줄. 사람은 문서를 안 보고 자기 말로 답한다. 막힌 질문은 `_learn/inbox.md`에 `종류: 막힌 질문 · 출처: 리허설` 카드로. 리허설은 이해를 만드는 일이라 에이전트가 대신 답하지 않는다 — 검증은 기계에 넘겨도 다음 루프는 사람의 이해에서 나온다.
   🔴 **출구 조건** — 셋 다 맞아야 ⑤로 간다. ① 회고 1장이 있다 ② 막힌 지점이 있으면 남긴 자산이 1개 이상이다(없으면 "안 남긴 이유" 한 줄이 있어야 통과) ③ 건너뛴 항목은 `REFLECT 건너뜀: <항목> — <이유>`로 적혀 있다. 건너뛰기는 허용, **말없이 넘어가는 것만 금지**다.
5. **마무리(SHIP)** — 작업이 **완전히 끝났을 때만**. `changeset`(릴리스 도구가 있고 사용자 영향 시) → `commit` → `pr-write`. REFLECT 산출물(회고·규칙 한 줄·`_brain`·`observations.md`)을 구현과 **같은 PR**에 태운다 — 한 사이클 = 한 PR. **문서 한 줄은 고친 커밋과 같은 커밋에**(`rules/non-obvious-patterns.md` 자신의 규칙). PR 본문 끝에 회고 요약(막힌 지점 → 남긴 자산)과 `REFLECT 건너뜀` 줄을 그대로 둔다. `commit`은 REVIEW 최종 판정이 승인을 겸하므로 다시 묻지 않는다.

## 사람 체크포인트 (여기서만 승인 대기)

① **계획** — DESIGN: PRD·수용 조건 확인 · ARCHITECTURE 초안 · 세 장 저장 경로 · Readiness 착수 판단 · 🎨 브리프 승인 · 🎨 critique 결정 질문(회차당 ≤5) · 🎨 시안 `verdict` / PLAN: `harness` 범위 합의 → step 계획 승인 · 🎨 DS 신규 컴포넌트 승인
② **IMPLEMENT** — blocked step · 파괴적 변경 · 재시도 3번 뒤에도 실패 · 빈틈 3곳(전 step GREEN 직후)
③ **REVIEW** — 최종 판정 · 🎨 reconcile 통과 판정(현행 반영)
④ **REFLECT** — `revise-claude-md` diff 승인(종착지 판정 포함) · `_brain` 정리 초안 · brain-sync 이관 · task-observer 승격 판정 · 🎤 설명 리허설(제안 시) · 출구 조건 확인
⑤ **마무리** — `pr-write` 생성(commit은 REVIEW 승인이 겸한다)

> 이 목록 밖에서 멈췄다면 스킬 쪽이 틀린 것이다 — 목록에 넣거나 스킬을 고친다. (2026-10-08: 선언 7곳 vs 실제 13곳이던 것을 맞춤)

## 재개

중단 지점(`phases/{task}/index.json`의 status·현재 단계)을 읽고 이어서 진행한다. 디버깅이 필요하면 `root-cause-debugger`(`systematic-debugging` 규율). 원인이 확정되고 사람이 승인하면 **메인이** 해당 step을 `error → pending`으로 되돌리고 `error_message`에 근본 원인 한 줄을 남긴 뒤 루프를 재개한다. 그 한 줄은 다음 지시문 머리에 들어가고, 재개한 실행은 재시도 한도를 새로 센다(`retries` 누계는 그대로). 그 원인은 ④ REFLECT 회고의 「막힌 지점」 첫 줄이 된다.

> 디자인 트랙은 `design-brief`·`design-critique`(DESIGN) · `design-reconcile`(REVIEW) **3스킬**이다 — 2026-09-01에 3스킬(`design-plan` 포함)로 설치됐다가 `design-plan`이 **0.9.0에서 삭제**됐고(PLAN 자리는 `harness`), 0.15.0에서 시안 평가용 `design-critique`가 들어왔다. 산출물 종착지는
> `.claude/design/` — `brief.md`(내용)·`DESIGN.md`(스타일)·`design-system-map.md`(레지스트리)·`canvas/`(레포당 캔버스 하나, 커밋)·`checkpoints/`·`references/`(로컬 전용, README만 커밋).
> 시안은 **브리프 승인 뒤 Claude가 그린다** — 0.14까지는 "사람이 개시한다"였지만 2026-10 두 레포에서 실제로는 매번 Claude가 그렸다.
