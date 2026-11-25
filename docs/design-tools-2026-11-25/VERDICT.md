# 판정표 — mattpocock/skills에서 설계 도구 고르기

> 이슈 #51 「이번 지시」 1. 원본은 `mattpocock/skills`(MIT) `d653911`(2026-11-24) 39개를 스크래치에 받아 읽었고, 하네스는 이 worktree(0.41.0, `9f37bef`)의 실물로 대조했다. 판정은 AI 추천이고, 흡수 여부는 사용자가 정한다(결정 주체는 `ADR.md`에 적는다).

## 읽는 법

- 판정: **흡수**(기존 단계에 녹인다) · **보류**(셀 수 있는 조건이 차면 다시 본다) · **안 함**
- 근거 세 칸은 이슈가 정한 순서다. ① 하네스에 이미 같은 일이 있나 ② 넣으면 어느 단계 · 어느 파일에 붙나 ③ 상시 로드량
- 상시 로드량: 모든 추천이 새 스킬 0 · description 변경 0이다. 그래서 늘 실리는 비용(컴포넌트 description, `design-notes.md` §3)은 0이고, 늘어나는 것은 그 단계를 돌 때만 읽는 본문뿐이다. 붙는 파일의 지금 크기는 확인함, 늘어날 줄 수는 추정
- 붙는 파일의 지금 크기(확인함): `sdd/references/design.md` 74줄 · 10,628B / `sdd-plan/SKILL.md` 120줄 · 11,899B / `agents/code-reviewer.md` 107줄 · 9,176B / `docs/principles/INDEX.md` 1,173B

## 후보 7 판정

| 후보 | 원본 | 판정(추천) | ① 이미 있나 (실물 대조) | ② 붙는 자리 | ③ 늘어나는 양 (추정) |
|---|---|---|---|---|---|
| 질문 라운드 | `productivity/grilling` · `grill-me` · `engineering/grill-with-docs` | **보류 — 질문 방식 비교 결과로 정한다** | 정면으로 반대다. 하네스 `docs/principles/ask-questions.md` 첫 줄이 「한 번에 한 질문」이고, 원본은 「선행 결정이 끝난 질문(frontier)을 한 라운드에 전부, 번호 + 추천 답」이다. 의존 순서로 내려가기는 `design.md` 3단계에 이미 있다. 사실은 찾고 결정은 묻는다 · 공유된 이해 전에 실행하지 않는다도 이미 있다. `grill-with-docs`(인터뷰 + 문서 동시 작성)는 `design.md`가 이미 그 모양이다 | 비교에서 라운드가 이기면 `ask-questions.md` 첫 줄 하나를 바꾼다(원칙 정본 한 곳이라 `why` · `design.md` · `sdd-plan` §2가 같이 따라온다) | 원칙 파일 ±3줄 |
| 수직 조각 | `engineering/to-tickets` | **흡수 — phase 단위만** | 반대가 있다. `sdd-plan` §3 「한 step = 한 레이어 · 모듈만, 아래 계층부터」는 가로 분할이고, §4 예시(`fe-cp-name`의 `after: ["be-cp-name"]`)는 phase도 층으로 나눈다. 막는 관계(blocking edge)는 phase `after`와 `conductor` 이슈 의존으로 이미 있다. 넓은 리팩터의 확장-수축(expand-contract)은 「이동 리팩터 세 step」이 일부만 덮는다 | `sdd-plan` §2 범위 합의(phase 목록을 끝까지 도는 조각으로 먼저 보이고 굵기를 묻는다) · §3 이동 리팩터 옆에 확장-수축 한 줄 · §4 `after` 예시 문구. step의 한 레이어 규칙은 둔다 | `sdd-plan` +5~8줄 |
| 용어집 | `engineering/domain-modeling` | **흡수(일부) · 나머지 보류** | 일부만 있다. ARCHITECTURE 맨 위 「키워드」 표(`design.md` 「설계문서 3장」)가 기능 하나의 용어를 적지만, 날짜 폴더 문서는 「뒤에 고치지 않는다」라서 기능을 넘어 살아 있는 용어집은 없다. 인터뷰 중 흐린 말을 짚기 · 사용자 말을 코드와 대조하기는 「사실은 찾고, 결정은 묻는다」가 일부 덮는다. ADR을 쓸지 거르는 3조건(되돌리기 비쌈 · 맥락 없이 보면 놀라움 · 진짜 대안이 있었음)은 없다. `design.md`는 「기술 결정이 나왔을 때만」이 전부다 | 흡수: `design.md` 3단계에 용어 겨루기 한 줄(흐린 말 → 정식 이름 제안, 앞 기능 「키워드」와 코드에 대조) · 「끝」 ADR 항목에 3조건. 보류: 대상 레포 루트의 살아 있는 용어집 파일(새 산출물이라 `harness-init` 템플릿까지 번진다). ⚠️ 비교 뒤 바뀜: 용어집 파일은 보류가 아니라 안 함(ADR-013과 같은 이유), 키워드 표는 PRD로 옮김 — `ADR.md` D2a | `design.md` +3~4줄 |
| 깊은 모듈 | `engineering/codebase-design` · `in-progress/setup-ts-deep-modules` | **흡수(판정 도구 3개만) · 나머지 안 함/보류** | 일부만 있다. `code-reviewer` 축 3이 책임 분리 · 성급한 추상화를 보지만, 판정 기준이 「두 번 보였다고 즉시 추상화」 한 구절뿐이다. 깊이(depth) · 이음매(seam) 어휘와 삭제 테스트는 없다 | 흡수: `code-reviewer` 축 3 · `design.md` 렌즈 2(아키텍처)에 판정 도구 3개 — 삭제 테스트(지우면 복잡도가 사라지나, 호출하는 N곳에 다시 나타나나) · 구현체가 하나뿐인 이음매는 가짜 · 인터페이스가 곧 테스트 면. 안 함: `setup-ts-deep-modules`(TS · dependency-cruiser 설치라 스택 무관 플러그인 범위 밖, 필요하면 스택 팩). 보류: 「두 번 설계」(서브에이전트 3개 이상 병렬, 비용 대비 근거 없음) | `code-reviewer` +3줄 · `design.md` +1줄 |
| 에이전트용 글쓰기 | `productivity/writing-for-agents` | **흡수 — 원칙 문서 1장** | 일부만 흩어져 있다. 로드 예산(`design-notes.md` §2~§3) · description을 날카롭게 · 지시문에서 이력 지우기(ADR-016 D0) · 반복은 구조로(`build-the-lever.md`) · 로드량 검사(`harness-doctor` 5)는 있다. 단계마다 끝났음을 판정할 기준을 둔다 · 금지 대신 할 일을 쓴다(부정문은 금지된 행동을 더 떠올리게 한다) · 기본으로 이미 하는 일을 시키는 문장(no-op) 지우기 · 환경이 정본인 것을 문서에 복사하지 않기는 없다. ⚠️ 정정(지휘 검토): 겹치는 지시 지우기는 `subtract-before-you-add.md` 「지시문도 같다」 줄이 이미 맡아서 새 원칙에선 그 문서를 가리킨다 — `ADR.md` D4 | `docs/principles/write-for-agents.md` + `INDEX.md` 한 줄(언제: 스킬 · 규칙 · CLAUDE.md · step 파일을 쓰거나 고칠 때). 부르는 쪽: `sdd-plan` §3(step 파일 작성) · `sdd` REFLECT 하네스 되돌림 · `harness-gaps` 승격 | 상시 0. INDEX +1행(입구 스킬이 판단 전에 읽음) |
| 설문지 | `productivity/to-questionnaire` | **흡수(작게)** | 없다. 그리고 지휘 1차 대응(「질문을 문서로 한꺼번에」)과 원본이 다르다: 원본은 **사용자가 모르는 것을 아는 다른 사람**에게 보낼 질문지다(받는 사람 · 돌려받을 것만 사용자에게 묻고, 질문은 그 차이를 겨눈다). 「지금 답할 수 있는 걸 한꺼번에」는 질문 라운드 쪽이다. 하네스는 그런 빈칸을 `⚠️ 미결정`으로 남기고 끝난다. `notion-writing`의 의사결정 요청은 결정을 청하는 글이지 사실을 캐는 질문지가 아니다 | `design.md` 3단계: 남만 아는 빈칸이면 질문지 초안(중요한 것부터 · 질문 하나에 한 생각 · 답 칸 · 「모르겠다도 답」)을 PRD 남은 `⚠️` 옆에 두고, 보내는 일은 `slack-writing` / `notion-writing`에 넘긴다(밖으로 나가는 것이라 사람 승인) | `design.md` +2줄 |
| 버릴 시제품 | `engineering/prototype` | **흡수 — 한 줄만, 상세 절차는 보류** | 갈래마다 이미 맡은 곳이 있다. 상태 모델이 맞나는 `statechart`(규칙 위반 경로를 모델 검사로 보인다), 화면 모양은 디자인 트랙 `design-brief` → 캔버스 시안. 「실험으로 가릴 수 있는 선택은 시제품으로 돌려 보고 관찰로 추천」은 `sharpen`이 다시 쓴 지시문에만 있고 DESIGN 절차에는 없다 | `design.md` 3단계 「버린 이유」 옆 한 줄: 실험으로 가릴 수 있는 선택이면 스크래치에서 버릴 시제품(맨 위에 답할 질문 한 줄, 저장 없음)으로 돌려 보고 결과로 추천. 원본의 LOGIC / UI 상세 절차(약 13KB)는 `statechart` 첫 사용 판정(ADR-016 D8) 뒤에 다시 본다 | `design.md` +1줄 |

## 「이미 있음 12」 다시 대조

지휘 1차 대조는 개수(이미 있음 12 · 후보 7)만 남아 있고 목록 원문은 없다. 그래서 후보 밖 29개를 전부 실물로 다시 대조했다. 집계: **이미 있음 14 · 일부 3 · 없음(설계 도구 아님) 12**. 12와 어긋나는 이유는 목록이 없어 가릴 수 없다.

| 원본 | 판정 | 하네스 실물 근거 |
|---|---|---|
| `engineering/code-review` | 이미 있음 | `sdd-review` 체크리스트 + `code-reviewer`(의도 되비추기 · 규칙 기준 · 증명 규칙) |
| `engineering/diagnosing-bugs` | 이미 있음 | `agents/root-cause-debugger.md`(재현 → 가설 하나씩) |
| `engineering/tdd` | 이미 있음 | `sdd-run` + `sdd_runner.py judge`(RED → GREEN을 git 기록으로) · `test-writer` · `feature-builder` · `tdd-guard` 훅 |
| `engineering/implement` | 이미 있음 | `sdd-run` |
| `engineering/implement-spec` | 이미 있음 | `sdd-run`(step 파일 = spec + ticket) |
| `engineering/to-spec` | 이미 있음 | `design.md` 산출물 PRD + `ask-questions.md` 「질문 말고 바로 써」 줄(인터뷰 없이 합성) |
| `engineering/pr` | 이미 있음 | `pr-write` |
| `engineering/retro` | 이미 있음 | `sdd/references/reflect.md` |
| `engineering/setup-matt-pocock-skills` | 이미 있음 | `harness-init` |
| `engineering/ask-matt`(라우터) | 이미 있음 | `sdd` 총괄 표 + README 목차(ADR-016 D1) |
| `engineering/wayfinder` | 이미 있음 | `conductor`(결정 이슈를 후속 이슈로 쪼개 의존을 건다) |
| `in-progress/claude-handoff` | 이미 있음 | `conductor/references/dispatch.md`(`claude --bg`로 새 세션에 지시문을 넘긴다) |
| `misc/git-guardrails-claude-code` | 이미 있음 | `hooks/block-dangerous-bash.sh` + `deny-patterns.yaml` |
| `productivity/wait-what` | 이미 있음 | `ask-questions.md` 「되물으면 질문이 실패한 것 — 더 쉽게 다시 쓴다」 |
| `in-progress/loop-me` | 일부 | 인터뷰 부분은 `why` · `design.md`. 「워크플로를 만든다」는 없음 |
| `in-progress/chief-of-staff` | 일부 | 위임은 `conductor`. 날짜별 위키 기억은 레포 밖 |
| `misc/setup-pre-commit` | 일부 | Husky 대신 Claude 훅(`auto-format` · `tdd-guard`) + `harness-init` CI 채우기(`fill_ci.py`) |
| `productivity/handoff` | 없음 ⚠️ | 이미 있음으로 치기 쉽지만 실물에 없다. `BACKLOG.md` 「세션 handoff 파일 규약」 행이 승격 조건을 기다리는 중이다 |
| `productivity/teach` | 없음 ⚠️ | 플러그인에 없다. `explain` 학습 카드는 작업 설명이지 가르치기가 아니다(전역 개인 스킬은 레포 밖) |
| `engineering/research` | 없음 ⚠️ | 1차 자료 조사 → 레포에 Markdown. `reframe`(용어 · 링크 확인)과 다르다. 설계 도구가 아니라 이번 범위 밖 |
| `engineering/improve-codebase-architecture` | 없음 | 깊은 모듈 후보에 딸린 것(깊게 만들 곳 찾기 → HTML 보고서). `harness-score`는 AI 준비도 지도라 다르다. 깊은 모듈 판정을 따른다 |
| `engineering/triage` | 없음 | 외부 이슈 · PR 분류 상태 기계. 설계 도구 아님 |
| `engineering/wizard` | 없음 | 사람만 할 수 있는 단계를 bash 마법사로. 설계 도구 아님 |
| `in-progress/software-factory` | 없음 | 설계 도구 아님 |
| `in-progress/writing-beats` · `writing-fragments` · `writing-shape` | 없음 | 긴 글 쓰기. 설계 도구 아님(남이 읽는 글은 `notion-writing` · `slack-writing`) |
| `misc/migrate-to-shoehorn` · `misc/scaffold-exercises` | 없음 | 특정 라이브러리 · 강의 자료. 해당 없음 |

⚠️ 세 줄(`handoff` · `teach` · `research`)은 이름만 보면 하네스에 있을 것 같지만 실물에 없다. 지휘 12개에 들어 있었다면 그 셋이 틀린 곳일 가능성이 크다(추정 — 목록 원문이 없어 확인 못 함).

## 대조 중 알게 된 것

- 하네스의 「한 번에 한 질문」은 원본 `grilling`의 옛 판에서 왔다(확인함). 하네스 커밋 `7fd7d85`(2026-08-23)가 들인 `skills/grilling/SKILL.md`에 「한 번에 하나씩, 한꺼번에 여러 개는 당황스럽다」가 있다. 원본은 커밋 `a4b2009`(2026-07-31, 「round-by-round frontier interview」)에서 라운드 방식으로 바꿨다. 하네스는 바뀌기 전 판을 들인 것으로 보이고(반입 시점의 원본 판은 추정), 그 뒤 원본만 움직였다.
- 원본 `grilling`은 2026-10-07에 「예라고 하면 추천을 받아들이는 문장으로 묻는다」를 더했다. 하네스 `ask-questions.md`는 설계 결정이면 「선택 + 이유를 받고 한 번 반박」이라 반대 방향이다. 비교 때 이 차이(추천 그대로 수용 수)도 같이 센다.
- 원본 39개 중 사람만 부르는 것 24 · 모델도 부르는 것 15(frontmatter `disable-model-invocation` 개수, 확인함). 하네스 0.41.0은 25개 중 자동 입구 8(확인함).
