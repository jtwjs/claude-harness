---
description: SDD 전체 워크플로우 오케스트레이터 — 기능·화면·버그 작업을 DESIGN→PLAN→IMPLEMENT→REVIEW→DOCUMENT(사용자영향 시 가이드)→REFLECT로 자동 진행한다. 에이전트 위임 구간은 자동으로 넘어가고, 사람 체크포인트에서만 멈춘다. Use when 새 기능·화면·버그 작업을 시작할 때(단계별 수동 호출 대신 이 흐름으로).
disable-model-invocation: false
---

SDD 단계를 순서대로 이어 진행하는 오케스트레이터. 각 단계를 해당 스킬/에이전트에 위임하고, **위임 구간은 자동으로 진행하되 사람 체크포인트에서만 멈춘다.** (개별 단계는 `/harness` 등으로 직접 호출도 가능.)

## 0. 트랙 판단

- **UI/화면 작업(Claude Design 사용)** → **디자인 트랙**(design-brief·design-plan·design-reconcile 포함).
- **비UI(로직·API·버그)** → **코어 트랙**(harness·harness-run·sdd-review).

## 단계 진행 (🤖 자동 위임 / 🙋 사람 체크포인트)

1. **DESIGN** — (디자인) `design-brief`로 브리프 생성 → 🙋 확인 후 Claude Design 전달·import. `docs/{feature-YYYY-MM-DD}/`에 PRD·ARCHITECTURE·ADR 확보.
2. **PLAN** — (디자인) `design-plan`으로 매핑·갭 산출 → 🙋 신규 DS 컴포넌트 결정 승인. `harness`로 step 분해 → 🙋 step 계획 승인.
3. **IMPLEMENT** 🤖 — `harness-run`이 step마다 `feature-builder` 서브에이전트를 자동 구동·검증·커밋·3회 재시도. hands-off. (🙋 정지: blocked / 파괴적 변경 / 3회 실패.)
4. **REVIEW** — `sdd-review` 체크리스트 + 필요 시 `code-reviewer` 심층 🤖 자동 실행 → 🙋 최종 판정. (디자인) `design-reconcile`로 비주얼 대조·내부 DS 패키지→Claude Design push·drift 플래그.
5. **DOCUMENT** 🤖 — **사용자영향 기능일 때만**. `guide-author`가 완성된 기능을 사용자 가이드(docs-app) MDX·스크린샷(dev:mock+Playwright, 문서에 맞는 픽스처)·nav·변경이력으로 구성 → `guide-review`(+필요 시 `guide-reviewer` 에이전트)로 정확성 검토(코드 대조·라벨·픽스처 적합성). **AI가 게시 판정**: 🔴 없으면 자동 게시(커밋), 🔴 있으면 `guide-author`로 수정·재검토 루프(IMPLEMENT와 동일하게 3회 재시도 후 blocked 시 정지). 사람이 요청하면 판정 결과를 검토용으로 제시. 변경이력 문구는 `release-notice`. (내부 리팩터·비UI 변경은 건너뜀.)
6. **REFLECT** 🤖 — `changeset`(사용자 영향 시)→`commit`→`pr-write` 자동. 매핑 레지스트리·`non-obvious-patterns.md` 환류.

## 사람 체크포인트 (여기서만 승인 대기)

① 디자인/브리프 확인 ② PLAN(매핑·step) 승인 ③ 신규 DS 컴포넌트 ④ 파괴적 변경 ⑤ REVIEW 최종 판정 ⑥ blocked step (DOCUMENT 가이드 게시는 AI 판정이라 자동 — 사람은 필요 시 검토 요청)

## 재개

- 중단 지점(`phases/{task}/index.json` status·현재 단계)을 읽고 이어서 진행. 디버깅이 필요하면 `root-cause-debugger`(systematic-debugging 규율).
