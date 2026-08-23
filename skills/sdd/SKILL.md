---
description: SDD 전체 워크플로우 오케스트레이터 — 기능·버그 작업을 DESIGN→PLAN→IMPLEMENT→REVIEW→REFLECT로 자동 진행한다. 스펙→테스트→구현 순서를 강제하고, 위임 구간은 자동으로 넘어가되 사람 체크포인트에서만 멈춘다. Use when 새 기능·버그 작업을 시작할 때(단계별 수동 호출 대신 이 흐름으로).
disable-model-invocation: false
---

SDD 단계를 순서대로 이어 진행하는 오케스트레이터. 각 단계를 해당 스킬/에이전트에 위임하고, **위임 구간은 자동으로 진행하되 사람 체크포인트에서만 멈춘다.** (개별 단계는 `/harness` 등으로 직접 호출도 가능.)

> **한 줄 흐름**
> `why-logictree`(스펙) → `harness`(분해) → `grilling`(빈칸) → 🙋 → **`test-writer`(RED) → `feature-builder`(GREEN)** → `sdd-review` → `code-reviewer` → REFLECT

## 단계 진행 (🤖 자동 위임 / 🙋 사람 체크포인트)

1. **DESIGN** — `docs/{feature-YYYY-MM-DD}/`에 PRD·ARCHITECTURE·ADR을 확보한다.
   **PRD가 없거나 과제가 아직 막연하면 `why-logictree`로 먼저 만든다**(WHY→3질문→로직트리→So What/Why So). → 🙋 확인.
   ⚠️ PRD의 **수용 조건**이 `test-writer`의 입력이다. 여기가 비면 뒤가 전부 빈다.
2. **PLAN** — `harness`로 step 분해(각 step에 `tdd: true|false` 판정 포함).
   step 파일에 `⚠️`·`TBD`·미해결 가정이 **3개 이상**이거나 사람이 요청하면 `grilling`으로 빈칸을 캐묻는다. → 🙋 step 계획 승인.
3. **IMPLEMENT** 🤖 — `harness-run`이 step마다 2단으로 돈다. hands-off.
   - **RED**: `test-writer` → `verify.test`가 **실패해야** 통과 (전부 통과하면 잡는 게 없다는 뜻이라 step 실패)
   - **GREEN**: `feature-builder` → `verify` 전체 통과 **AND** diff에 테스트 파일 없음
   - (🙋 정지: blocked / 파괴적 변경 / 3회 실패.)
4. **REVIEW** — `sdd-review` 체크리스트 → escalate 판정에 따라 `code-reviewer` 심층 🤖 → 🙋 최종 판정.
5. **REFLECT** 🤖 — `changeset`(릴리스 도구가 있고 사용자 영향 시) → `commit` → `pr-write`.
   그 다음 **지식 환류**: 새 함정은 `.claude/rules/non-obvious-patterns.md`에 한 줄, `_brain/`이 있으면 `brain-intake` → **`brain-sync`로 통합 wiki 이관**(🙋 확인 후).

## 사람 체크포인트 (여기서만 승인 대기)

① DESIGN(PRD·수용 조건) 확인 ② PLAN step 승인 ③ 파괴적 변경 ④ REVIEW 최종 판정 ⑤ blocked step ⑥ brain-sync 이관

## 재개

중단 지점(`phases/{task}/index.json`의 status·현재 단계)을 읽고 이어서 진행한다. 디버깅이 필요하면 `root-cause-debugger`(`systematic-debugging` 규율). 원인이 확정되고 사람이 승인하면 **메인이** 해당 step을 `error → pending`으로 되돌리고 `error_message`에 근본 원인 한 줄을 남긴 뒤 루프를 재개한다.

> 디자인 트랙(`design-brief`·`design-plan`·`design-reconcile`)은 이 하네스에 **설치돼 있지 않다** — `incubator/ready/`에 있고, 꺼낼 때 이 문서에 트랙 분기를 다시 넣는다(`incubator/README.md`).
