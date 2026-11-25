---
name: sdd
description: 새 기능을 만들거나 버그를 고쳐 달라는 말("~기능 추가해줘"·"~버그 고쳐줘"·"과제로 잡아 진행하자", PRD 없는 막연한 과제 포함)에 코드·git을 보기 전에 먼저 부른다 — 계획 → 구현 → 리뷰 → 회고 → 마무리를 잇고 사람 체크포인트에서만 멈춘다. 단순 수정·개념 질문은 아니다.
disable-model-invocation: false
---

SDD 단계를 순서대로 이어 진행하는 오케스트레이터. 각 단계를 해당 스킬/에이전트/참조 문서에 위임하고, **위임 구간은 자동으로 진행하되 사람 체크포인트에서만 멈춘다.** (개별 단계는 `/sdd-plan` 등으로 직접 호출도 가능.)

**원칙**: 판단 전에 `${CLAUDE_PLUGIN_ROOT}/docs/principles/INDEX.md`를 보고, 쓰는 원칙은 원문을 읽는다.

> **한 줄 흐름**
> **코어 트랙** — ① 계획: DESIGN(`references/design.md` — 왜부터 캐물어 → PRD·ARCHITECTURE·ADR → 🙋 Readiness) → PLAN(`sdd-plan` 분해 · 빈칸은 그 자리에서 → 🙋 step 승인) → ② **`sdd-run`(step당 1번: 테스트 먼저 → 구현, git 기록으로 판정)** → ③ `sdd-review` → `code-reviewer` → ④ REFLECT(회고 1장 → 하네스 되돌림 → 지식 정리) → ⑤ 마무리(세 줄 요약 → `changeset` → `commit` → `pr-write` → 학습 카드)
> **디자인 트랙** — 위 흐름에 셋이 끼어든다: DESIGN에 `design-brief`(→ 레포 캔버스에 시안) → `design-critique`(시안 평가 루프), REVIEW에 `design-reconcile`. PLAN은 `sdd-plan`이 레포 캔버스를 읽는다

## 0. 트랙 판단

**사용자에게 보이는 화면을 만들거나 고치는 작업인가?**

| 답 | 트랙 | 무엇이 달라지나 |
|---|---|---|
| 예 (UI·화면) | **디자인 트랙** | DESIGN에 `design-brief` → `design-critique`, REVIEW에 `design-reconcile` **3스킬**. PLAN은 `sdd-plan` §3-b가 레포 캔버스를 읽는다 |
| 아니오 | **코어 트랙** | 아래 5단계 그대로 |

애매하면 묻는다. 서버 내부 로직이어도 **운영 화면·대시보드가 딸려 오면 디자인 트랙**이다.

병렬 트랙(worktree 세션 2개 이상)이면 지휘 세션 하나는 `conductor`로 돈다. 각 트랙 세션은 이 흐름 그대로다.

## 단계 → 스킬 · 체크포인트 (🤖 자동 위임 / 🙋 여기서만 승인 대기)

단계 스킬은 `${CLAUDE_PLUGIN_ROOT}/skills/<이름>/SKILL.md`를 읽고 그대로 따른다 — 사람만 부르게 닫혀 있어(frontmatter `disable-model-invocation`) Skill 도구로 부르면 오류가 난다. 경로로 읽은 단계 스킬 본문의 `CLAUDE_PLUGIN_ROOT` 변수 자리는 치환되지 않고 셸에도 그 변수가 없다 — 그 자리를 `${CLAUDE_PLUGIN_ROOT}`로 바꿔 읽고 명령에도 이 값을 넣는다(루트를 따로 찾지 않는다). `commit` · `pr-write`는 Skill 도구로 부른다.

| 단계 | 맡는 것 | 🙋 체크포인트 |
|---|---|---|
| ① 계획 · DESIGN | `docs/{feature-YYYY-MM-DD}/`에 PRD·ARCHITECTURE·ADR이 없거나 과제가 막연하면 **`${CLAUDE_PLUGIN_ROOT}/skills/sdd/references/design.md`를 읽고 그 절차대로** 만든다. 세 장이 이미 있으면 Readiness만 돈다. 🎨 `${CLAUDE_PLUGIN_ROOT}/skills/design-brief/SKILL.md` → 레포 캔버스에 시안 → `${CLAUDE_PLUGIN_ROOT}/skills/design-critique/SKILL.md` | PRD·수용 조건 확인 · ARCHITECTURE 초안 · 세 장 저장 경로 · Readiness 착수 판단(AI 채점, 착수는 사람) · 🎨 브리프 승인 · 🎨 critique 결정 질문(회차당 ≤5) · 🎨 시안 `verdict` |
| ① 계획 · PLAN | `${CLAUDE_PLUGIN_ROOT}/skills/sdd-plan/SKILL.md` — step 분해와 step마다 `tdd` 판정. step의 `⚠️`·`TBD`는 §2가 그 자리에서 캐묻는다. 세 장이 이미 있어 PLAN만 필요하면 바로 부른다. 🎨 §3-b가 캔버스 작업 탭을 읽는다 | 범위 합의 → step 계획 승인(미해결 `⚠️` 0개) · 🎨 DS 신규 컴포넌트 승인 |
| ② IMPLEMENT 🤖 | `${CLAUDE_PLUGIN_ROOT}/skills/sdd-run/SKILL.md` — step마다 호출 1번(테스트 먼저 → 구현), `sdd_runner.py judge`가 git 기록으로 판정한다(RED · GREEN 규칙은 그 파일 §2). 사람이 없을 때는 같은 규칙의 `sdd_runner.py run`(헤드리스) | blocked step · 파괴적 변경 · 재시도 3번 뒤에도 실패(최대 4회) |
| ③ REVIEW | `${CLAUDE_PLUGIN_ROOT}/skills/sdd-review/SKILL.md` 체크리스트 → escalate 판정에 따라 `code-reviewer` 심층 🤖. 🎨 `${CLAUDE_PLUGIN_ROOT}/skills/design-reconcile/SKILL.md` | 최종 판정 · 3회차 뒤에도 위반이 남을 때 접근 재검토 · 🎨 reconcile 통과 판정(현행 반영) |
| ④ REFLECT | 커밋 전, 사람이 자리에 있을 때 `${CLAUDE_PLUGIN_ROOT}/skills/sdd/references/reflect.md`를 읽고 그 순서대로 돈다 | 적중 판정 정정 · 게이트 보정 확정 · `revise-claude-md` diff 승인(종착지 판정 포함) · harness-gaps 승격 판정 · 출구 조건 확인 |
| ⑤ 마무리(SHIP) | 세 줄 요약 → `${CLAUDE_PLUGIN_ROOT}/skills/changeset/SKILL.md`(릴리스 도구가 있고 사용자 영향 시) → `commit` → `pr-write` → 학습 카드 | `pr-write` 생성(commit은 REVIEW 승인이 겸한다) |

이 표 밖에서 멈췄다면 스킬 쪽이 틀린 것이다 — 표에 넣거나 스킬을 고친다.

### ① 계획

DESIGN과 PLAN은 한 단계지만 게이트가 둘이다 — 묻는 것이 다르다("무엇을 왜"가 굳었나 / "어떻게 쪼갰나").
🔴 **절차를 건너뛰고 세 장을 바로 쓰지 않는다** — 질문 규칙(`${CLAUDE_PLUGIN_ROOT}/docs/principles/ask-questions.md`)과 Readiness가 빠진다.
⚠️ PRD의 **수용 조건**이 각 step의 **먼저 쓰는 테스트**의 입력이다. 여기가 비면 뒤가 전부 빈다.

### ③ REVIEW

리뷰는 **같은 세션의 서브에이전트**가 한다 — 컨텍스트는 격리되고 세션은 그대로다("새 세션에서 리뷰"는 쓰지 않는다).
위반이 나오면 **수정 step을 하나 더 만들어 `${CLAUDE_PLUGIN_ROOT}/skills/sdd-run/SKILL.md`로 고치고(작은 수정은 `feature-builder`) `${CLAUDE_PLUGIN_ROOT}/skills/sdd-review/SKILL.md`를 다시 돈다** — REVIEW에서 IMPLEMENT로 돌아가는 유일한 경로.
선택: `/no-comments` — 사람이 부르면 `sdd-review` 전에 diff의 주석을 걷는다(`comment-hunter`가 찾고 메인이 판정). 사람만 부르는 스킬이라 흐름은 이것을 기다리지 않는다.
**루프는 수렴해야 한다** — 수렴 규칙 ①~③(회차 · 범위 · 지적 묶기)은 `${CLAUDE_PLUGIN_ROOT}/skills/sdd-review/SKILL.md` §2 · §4가 정본이다. ④ **3회차가 끝나도 위반이 남으면 수정 step을 더 만들지 않고 🙋 멈춘다** — "접근 방식 자체를 다시 볼까요?"(① 계획으로 / 이번 지적만 한 번 더 / 남은 지적은 후속 이슈로). 에이전트 작성자 × 에이전트 리뷰어는 서로를 끝없이 바쁘게 만든다.

### ④ REFLECT — 출구 조건

🔴 **출구 조건** — 셋 다 맞아야 ⑤로 간다. ① 회고 1장이 있다 ② 막힌 지점이 있으면 남긴 자산이 1개 이상이다(없으면 "안 남긴 이유" 한 줄이 있어야 통과) ③ 건너뛴 항목은 `REFLECT 건너뜀: <항목> — <이유>`로 적혀 있다. 건너뛰기는 허용, **말없이 넘어가는 것만 금지**다.

### ⑤ 마무리(SHIP)

작업이 **완전히 끝났을 때만** 돈다. 순서는 위 표 그대로다.

- **세 줄 요약** — PR 전에 터미널에 무엇 · 왜 · 위험/직접 확인할 것을 한 줄씩 낸다. 입력을 받지 않고 바로 다음으로 간다. 같은 세 줄을 PR 본문 첫머리 · 학습 카드 「작업 요약」 · 지휘 보고가 그대로 쓴다 — 곳마다 새로 쓰면 세 곳이 서로 다른 말을 한다.
- REFLECT 산출물(회고·규칙 한 줄·`observations.md`)을 구현과 **같은 PR**에 태운다 — 한 사이클 = 한 PR. **문서 한 줄은 고친 커밋과 같은 커밋에**(`rules/non-obvious-patterns.md` 자신의 규칙). PR 본문 끝에 회고 요약(막힌 지점 → 남긴 자산)과 `REFLECT 건너뜀` 줄을 그대로 둔다. `commit`은 REVIEW 최종 판정이 승인을 겸하므로 다시 묻지 않는다.
- **학습 카드** — 마무리 보고에 한 장 싣는다. 레포에 쓰지 않는다. 항목: 작업 요약 · 목적 · 개념/키워드(`${CLAUDE_PLUGIN_ROOT}/docs/learning-level.md`의 기술 카드 형식) · 새로 알게 된 것 · 선택: 내 한 줄. 카드 재료는 `explain`(`${CLAUDE_PLUGIN_ROOT}/skills/explain/SKILL.md`)을 읽어 얻는다.
- 마무리 보고 끝에 `쓴 원칙: <INDEX 이름|없음> · 바뀐 결정: <원칙을 읽고 달라진 판단 한 줄|없음>` 한 줄을 단다.

## 재개

중단 지점(`phases/{task}/index.json`의 status·현재 단계)을 읽고 이어서 진행한다. 디버깅이 필요하면 `root-cause-debugger`. 원인이 확정되고 사람이 승인하면 **메인이** 해당 step을 `error → pending`으로 되돌리고 `error_message`에 근본 원인 한 줄을 남긴 뒤 루프를 재개한다. 그 한 줄은 다음 지시문 머리에 들어가고, 재개한 실행은 재시도 한도를 새로 센다(`retries` 누계는 그대로). 그 원인은 ④ REFLECT 회고의 「막힌 지점」 첫 줄이 된다.

이어 가기 전에 현황을 **recall 출력 계약**으로 낸다: 요약 ≤5줄 · step마다 상태 태그(`index.json`의 status 그대로) · 반복 문제 ≤5(같은 error·재시도가 되풀이된 것) · 다음 수 1개.
