---
name: sdd-review
description: SDD REVIEW 단계 — 루트 CLAUDE.md + 기능의 ARCHITECTURE.md·ADR.md를 읽고 최근 변경 diff를 아키텍처·기술스택/ADR·테스트·CRITICAL 규칙·빌드/테스트 통과·실제 동작 관점으로 대조해 결과 표와 수정 제안을 낸다. Use when 구현(harness-run) 후 머지·커밋 전에 변경분을 검증할 때. 깊은 리뷰는 code-reviewer 에이전트에 위임.
disable-model-invocation: false
---

`harness-run` 산출 diff를 **설계문서 대비 체크리스트**로 빠르게 판정한다. 심층·다축 리뷰(성능·구조·보안 감사)는 **`code-reviewer` 에이전트**에 위임한다.

## 1. 기준 로드 (이 파일들만)

- 루트 `CLAUDE.md`
- 설계문서 폴더는 **`phases/{task}/index.json`의 `docs`** 에서 읽는다(`harness`가 채움). `task`를 모르면 묻고, `docs/` 아래를 뒤져 추측하지 않는다.
- `{docs}/ARCHITECTURE.md`(구조·레이어) · `ADR.md`(기술 결정)
- (필요 시 `PRD.md`로 요구사항 대조)

## 2. 변경 수집

- `git diff --name-only <base>...HEAD`(또는 `git diff HEAD`)로 변경 파일 파악 — `<base>`는 `harness.json`의 `git.baseBranch`(비었으면 `origin/HEAD`) → 필요한 파일 맥락 확인. diff가 비면 범위를 한 번 확인.
- **회차**(#10, 0.26.0) — `phases/{task}/index.json`의 `reviews`(없으면 빈 목록) 길이 + 1이 이번 회차다. 2회차부터는 **직전 회차의 `head` 이후 diff(`git diff <head>..HEAD`)만** 대조한다. 단 「빌드·테스트」 축의 `verify`는 늘 전체로 돌린다. 이전 회차의 `issues`에 있는 지적은 다시 내지 않는다.

## 3. 체크리스트 대조

| 축            | 확인                                                                                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 아키텍처 준수 | `{docs}/ARCHITECTURE.md`의 계층 배치·의존 방향과 일치. `.claude/rules/`가 금지한 경계 위반 없음                                                              |
| 기술스택·ADR  | `ADR.md` 결정과 일치. **미승인 새 의존성 없음**(추가됐다면 어느 ADR이 허락했는지 대라). ADR을 인용할 땐 번호 옆에 괄호로 한 줄 — `ADR-003(설정 스키마를 blocks 패키지에)` |
| 테스트 존재   | `harness.json.tdd.include` 범위의 변경 파일에 짝 테스트 존재. **동작 기준**으로 단언(구현 디테일 아님). 대상 판정은 `.claude/rules/testing.md` §0                         |
| CRITICAL 규칙 | `CLAUDE.md`의 🔴 CRITICAL 각 항목을 **그대로 대조**. hook 미우회(`--no-verify`), 자동 생성물 미수정                                                                       |
| 빌드·테스트   | `.claude/harness.json`의 `verify`를 **실제 실행**해 통과 확인. 앱별이면 root마다 그 폴더에서 돌리고 결과를 root 이름으로 적는다. 비어 있는 키는 그 사실을 보고한다          |
| 실제 동작     | **verify 통과는 동작 증거가 아니다** — 목·스텁·MSW로 바꾼 경계는 계약 위반을 못 잡는다. UI·API·외부 연동을 바꿨으면 앱을 띄워(`run` 스킬·브라우저·실 백엔드) 바뀐 경로를 **한 번 실제로** 지나가 본다. 못 했으면 `확인필요 — 미실행: 이유`로 보고하고 통과로 적지 않는다. 디자인 트랙이면 시각 대조는 `design-reconcile`이 하고 여기는 동작만 본다 |

## 4. 출력 형식

1. **리뷰 범위** — diff 범위·파일 수(1~2줄).
2. **결과 표** — 각 축: `통과 / 위반 / 확인필요` + 근거(파일:라인).
   - 🔴 크리티컬(빌드·타입 붕괴·CRITICAL 위반·명백 버그) / 🟡 경고(규칙·경계·테스트 누락) / 🟢 제안.
3. **수정 제안** — 항목별 `파일:라인 — 문제 — 수정 방향`. 실제 수정은 하지 않는다. 고치는 경로는 `sdd` REVIEW 절과 같다 — 수정 step을 하나 더 만들어 `harness-run`으로, 작은 수정만 `feature-builder`.
   - **종류로 묶는다** — 한 줄을 고치라고 하지 않고, 같은 종류(같은 패턴·같은 누락)의 위치를 grep으로 전부 찾아 한 항목에 모은다. 작성자가 한 번에 고치게.
   - **원래 있던 문제(pre-existing)는 따로** — 지적한 줄이 이번 diff(`<base>...HEAD`) 밖이거나 `git blame`상 이 작업 전 커밋이면 `원래 있던 문제` 절에 목록으로만 둔다. 수정 step을 만들지 않고, 후속 이슈로 할지는 사람이 정한다.
4. **회차 기록** — `index.json`의 `reviews`에 `{"at": <시각>, "head": <지금 HEAD>, "issues": [<이 작업 지적 종류 한 줄씩>]}`을 append한다. 위반이 남았고 이번이 **3회차**면 수정 제안 대신 "3회차가 끝났다 — 접근 방식 자체를 다시 볼까요?"를 사람에게 묻는다(`sdd` REVIEW 절 ④).
5. **다음 단계** — 통과 시 REFLECT로. 순서와 커밋 메시지 규칙은 여기 다시 적지 않는다 — **순서는 `sdd` SKILL.md의 ⑤ 마무리 절, 메시지 형식(`git.commitScope`)은 `commit` 스킬이 정본**이다. `--no-verify` 금지만 여기서도 한 번 더.

## 위임

- 성능/구조 건강성/보안까지 **깊게** 볼 필요가 있으면 Agent 도구로 **`code-reviewer`** 실행.
- 원인 불명 회귀 → `root-cause-debugger`.
- 이 스킬은 판정만 한다(코드 수정 없음).
