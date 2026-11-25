# PLAN — 하네스 재구성 phases 분해

> 승인됨(2026-11-24, #40 지휘 회신). step 파일 정본은 `phases/restructure-*/`이고, 이 문서는 PR 묶음과 바꿀 파일을 한눈에 보는 표다. 결정 값은 `ADR.md` ADR-016, 수용 조건은 `PRD.md`, 구조는 `ARCHITECTURE.md`.

## PR 묶음

phase 하나 = PR 하나. PR마다 앞 브랜치에서 딴 브랜치에서 돌리고 머지는 순서대로(ADR-016 Q5). 앞 phase가 끝나야 다음 phase를 시작한다(`after`).

| PR | phase | after | 묶음 | 담는 결정 | step |
|---|---|---|---|---|---|
| 1 | `restructure-rename` | 없음 | 이름 바꾸기 · 삭제 · 의존 | D1 이름 · D3 · D5 · D12 | 6 |
| 2 | `restructure-principles` | `restructure-rename` | 원칙 문서 · 기준 브랜치 스크립트 | D2 · D13 원칙 3장 · 글 스킬 출처 점검 | 6 |
| 2b | `restructure-principle-lever` | `restructure-principles` | build-the-lever 원칙 | D-lever | 1 |
| 3 | `restructure-gate-summary` | `restructure-principle-lever` | 이해 게이트 걷기 · 세 줄 요약 · 보고 형식 | D-gate · D-요약 · D13 recall 출력 계약 · 결함 pr-write:196 | 4 |
| 4 | `restructure-absorb` | `restructure-gate-summary` | 흡수 스킬 · 규칙 | D6 · D7 · D8 · D9 · D10 · D13 · Q2 | 11 |
| 5 | `restructure-trim` | `restructure-absorb` | 쪼개기 · 이력 걷기 · 입구 정리 | D0 · REVIEW §2-3 · 결함 2건 · Q1 · Q2 | 10 |
| 6 | `restructure-repo` | `restructure-trim` | 레포 구성 · CI · 훅 기록 | REVIEW §3(R1 · R5 · R6 · R7 · R9 · R11) · D11 | 8 |
| 7 | `restructure-readme` | `restructure-repo` | README · After 측정 | REVIEW R2 · D1 doctor 검사 · 결함 2건 | 3 |

- 순서 이유: 이름부터 바꿔야 뒤 PR이 새 이름으로 쓴다. 원칙 파일이 먼저 있어야 게이트 · 흡수 · 쪼개기가 그 경로를 가리킨다. 이력 걷기(5)는 내용 변경(2~4)이 끝난 뒤 한 번에 해야 같은 파일을 두 번 손대지 않는다. README는 이름 · 개수가 다 굳은 뒤(7).
- 모든 step AC: `bash hooks/test.sh`(`.claude/harness.json` `verify.test`). `sdd_runner.py`를 건드리는 step은 `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py`를 더한다.
- 이름 · 경로를 바꾸는 step의 「옛 이름 grep 0」은 쌓기만 하는 기록(`docs/<기능-날짜>/` · `docs/retro/` · `phases/*/` · design-notes 변경 이력 · `harness-init` 이름표)을 빼고 센다.
- `hooks/test.sh` 기존 줄 맞추기는 ADR-016 「대가」(Q3)의 예외 안에서만 한다(해당 step 금지사항에 적음).

## 실행 준비

- worktree에는 `.claude/harness.json`이 없다. main clone 사본을 복사하고 `git.branchPattern`을 PR 브랜치 규칙에 맞춰 넣는다. 복사본은 커밋하지 않는다(`.claude/rules/non-obvious-patterns.md`).
- 러너 판정은 설치본(0.40.0) `sdd_runner.py`가 한다. 레포에서 고친 러너(PR 6)는 릴리스 · 설치 뒤부터 판정에 쓰인다.

## 결정 뒤 반영

- Q7: ADR-016으로 지우기로 정한 동작(`learn-setup` 훅)을 검사하던 기존 케이스만 `hooks/test.sh`에서 지운다(ADR-016 「대가」). 지우는 곳은 `restructure-gate-summary` step 3에 이름 · 줄로 적었다.
- Q8: 지휘는 트랙 보고의 세 줄 요약 · 학습 카드를 사용자 보고에 그대로 싣는다(요약 · 재해석하지 않음). 카드는 사용자의 개인 기록 자리가 있으면 거기에도 붙이고, 「내 한 줄」은 사용자만 쓴다. `restructure-absorb` step 12(사용자 결정, 지휘 경유)
- Q9: step 기록(summary)에 계획에 없던 선택은 이유 한 구절(「…로 했다(계획은 X, 이유: Y)」), 계획대로 한 것은 안 적는다. 자리는 러너 지시문 한 곳. Before 10/57(PR 4 step 11 정규식 추정) → After는 PR 5~7 step에서 같은 정규식으로. `restructure-trim` step 11(사용자 · 지휘 추천 수용)

## step 목록

### PR 1 `restructure-rename` — 이름 바꾸기 · 삭제 · 의존

| # | step | tdd | 바꾸는 파일 |
|---|---|---|---|
| 1 | `rename-harness-to-sdd-plan` | false | `skills/harness/` → `skills/sdd-plan/` · `skills/sdd/SKILL.md` · `skills/sdd/references/design.md` · `skills/harness-run/SKILL.md` · `skills/conductor/SKILL.md` · `skills/why/SKILL.md` · `agents/feature-builder.md` · `agents/test-writer.md` · `templates/.claude/README.md` · `templates/.claude/references/track-brief.md` · `docs/sdd-runner.md` · `.claude/rules/non-obvious-patterns.md` · `README.md`(이름만) · `BACKLOG.md` · `hooks/test.sh` 케이스 10의 `skills/harness/SKILL.md` 경로 |
| 2 | `rename-harness-run-to-sdd-run` | false | `skills/harness-run/` → `skills/sdd-run/` · `hooks/loop-lock.sh` · `scripts/daily-hub/daily_hub.py` · `scripts/release.sh` · `skills/conductor/scripts/tracks_status.py` · `skills/sdd-run/scripts/sdd_runner.py` · `test_sdd_runner.py` · `agents/code-reviewer.md` · `agents/feature-builder.md` · `docs/sdd-runner.md` · `BACKLOG.md` · `README.md`(이름만) · `skills/{commit,conductor,design-reconcile,harness-gaps,harness-init,sdd-review,sdd,sdd-plan}/SKILL.md` · `skills/sdd/references/design.md` · `hooks/test.sh` 케이스 2-d의 `phases_status.py` 경로 |
| 3 | `rename-cartography-to-harness-score` | false | `skills/ai-readiness-cartography/` → `skills/harness-score/` · `hooks/weekly-readiness-check.sh` · `BACKLOG.md` · `README.md`(이름만) · `hooks/test.sh`의 가짜 플러그인 경로(`$FAKE/skills/ai-readiness-cartography/...` 두 줄) |
| 4 | `remove-visual-explainer` | false | `skills/plannotator-visual-explainer/` 삭제(LICENSE · references 포함) · `README.md`의 해당 행 |
| 5 | `drop-understand-anything` | false | `.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json` · `README.md` |
| 6 | `rename-table-and-guard` | false | `skills/harness-init/SKILL.md` 이름표 · 새 `hooks/tests/renames.sh` |

### PR 2 `restructure-principles` — 원칙 문서 · 기준 브랜치 스크립트

| # | step | tdd | 바꾸는 파일 |
|---|---|---|---|
| 1 | `base-branch-script` | true | 새 `scripts/base-branch.sh` · 새 `hooks/tests/base-branch.sh` |
| 2 | `skills-call-base-branch` | false | `skills/sdd-review/SKILL.md` · `skills/pr-write/SKILL.md` · `skills/changeset/SKILL.md` · `skills/harness-init/SKILL.md` |
| 3 | `principles-index-and-questions` | true | 새 `docs/principles/INDEX.md` · 새 `docs/principles/ask-questions.md` · 새 `hooks/tests/principles.sh` · `skills/why/SKILL.md` · `skills/sdd/SKILL.md` · `skills/sdd-plan/SKILL.md` · `skills/design-brief/SKILL.md` · `hooks/test.sh` 케이스 10의 질문 규칙 정본 경로 |
| 4 | `principles-write-for-readers` | false | 새 `docs/principles/write-for-readers.md` · `docs/principles/INDEX.md` 행 · `skills/slack-writing/SKILL.md` · `skills/notion-writing/SKILL.md` |
| 5 | `principles-three-docs` | false | 새 `docs/principles/attack-the-premise.md` · `subtract-before-you-add.md` · `explain-the-number.md` · `docs/principles/INDEX.md` 행 3개 |
| 6 | `entry-skills-point-to-index` | false | `skills/sdd/SKILL.md` · `skills/why/SKILL.md` · `skills/conductor/SKILL.md` · `skills/slack-writing/SKILL.md` · `skills/notion-writing/SKILL.md` · `skills/commit/SKILL.md` · `skills/pr-write/SKILL.md` |

### PR 2b `restructure-principle-lever` — build-the-lever 원칙

| # | step | tdd | 바꾸는 파일 |
|---|---|---|---|
| 1 | `principle-build-the-lever` | false | 새 `docs/principles/build-the-lever.md` · `docs/principles/INDEX.md` 행 · `skills/harness-gaps/SKILL.md` |

### PR 3 `restructure-gate-summary` — 이해 게이트 걷기 · 세 줄 요약 · 보고 형식

| # | step | tdd | 바꾸는 파일 |
|---|---|---|---|
| 1 | `sdd-drop-gap3-add-summary` | true | `skills/sdd/SKILL.md` · 새 `hooks/tests/no-gate-sdd.sh` |
| 2 | `pr-write-drop-quiz` | true | `skills/pr-write/SKILL.md` · 새 `hooks/tests/no-gate-pr.sh` |
| 3 | `learning-card-only` | false | `docs/learning-level.md` · `hooks/learn-setup.sh` 삭제 · `hooks/hooks.json` · `skills/explain-diff/SKILL.md` · `skills/sdd/references/design.md` · `skills/harness-init/SKILL.md` · `skills/pr-write/SKILL.md`의 `_learn` 언급 · `hooks/test.sh` 케이스 6-b · 훅 목록 · learn env 줄(PLAN 「확인 필요」 Q7) |
| 4 | `conductor-report-format` | false | `skills/conductor/SKILL.md` · `templates/.claude/references/track-brief.md` |

### PR 4 `restructure-absorb` — 흡수 스킬 · 규칙

| # | step | tdd | 바꾸는 파일 |
|---|---|---|---|
| 1 | `no-comments-skill-agent` | false | 새 `skills/no-comments/SKILL.md` · 새 `agents/comment-hunter.md` · `skills/sdd/SKILL.md` REVIEW 절 한 줄 |
| 2 | `review-proof-rules` | false | `skills/sdd-review/SKILL.md` · `agents/code-reviewer.md` |
| 3 | `statechart-import` | false | 새 `skills/statechart/`(SKILL.md · references · scripts 전부 · LICENSE 사본) |
| 4 | `gaps-correction-ladder` | false | `skills/harness-gaps/SKILL.md`(필요하면 `skills/harness-gaps/references/`) |
| 5 | `reflect-thresholds` | false | `skills/sdd/SKILL.md` |
| 6 | `why-code-decision` | false | `skills/why/SKILL.md` |
| 7 | `reframe-sharpen` | false | 새 `skills/reframe/SKILL.md` · 새 `skills/sharpen/SKILL.md` |
| 8 | `how-skill` | false | 새 `skills/how/SKILL.md` · `docs/harness-restructure-2026-11-24/trigger-eval/evals.json`(`how` 20문항) |
| 9 | `explain-diff-to-explain` | false | `skills/explain-diff/` → `skills/explain/` · `skills/sdd/SKILL.md`(학습 카드 재료 경로) · `skills/pr-write/SKILL.md` · `docs/learning-level.md` · `README.md`(이름만) · `skills/harness-init/SKILL.md` 이름표 행 · `hooks/tests/renames.sh` 옛 이름 목록 |
| 10 | `backlog-verification-row` | false | `BACKLOG.md` |
| 11 | `measure-show-me-your-work` | measure | 바꿀 파일 없음 |
| 12 | `conductor-relay-card` | false | `skills/conductor/SKILL.md` |

### PR 5 `restructure-trim` — 쪼개기 · 이력 걷기 · 입구 정리

| # | step | tdd | 바꾸는 파일 |
|---|---|---|---|
| 1 | `split-sdd` | false | `skills/sdd/SKILL.md` · 새 `skills/sdd/references/reflect.md` · `hooks/test.sh` 케이스 10의 sdd 문구 경로 |
| 2 | `conductor-issues-script` | true | 새 `skills/conductor/scripts/issues.py` · 새 `hooks/tests/conductor-issues.sh` |
| 3 | `split-conductor` | false | `skills/conductor/SKILL.md` · 새 `skills/conductor/references/*.md` |
| 4 | `split-pr-write` | false | `skills/pr-write/SKILL.md` · 새 `skills/pr-write/references/labels.md` |
| 5 | `renames-data-file` | true | 새 `skills/harness-init/references/renames.tsv` · `skills/harness-init/SKILL.md` · `hooks/tests/renames.sh` · 새 `hooks/tests/renames-data.sh` |
| 6 | `init-ci-fill-script` | true | 새 `skills/harness-init/scripts/fill_ci.py` · 새 `hooks/tests/fill-ci.sh` · `skills/harness-init/SKILL.md` |
| 7 | `trim-history-flow` | true | `skills/{sdd,sdd-plan,sdd-run,sdd-review,design-brief,design-critique,design-reconcile,why,how,conductor,commit,pr-write,changeset}/SKILL.md` · 새 `hooks/tests/no-history-flow.sh` |
| 8 | `trim-history-rest` | true | `skills/{harness-init,harness-doctor,harness-gaps,harness-score,project-new,slack-writing,notion-writing,explain,no-comments,reframe,sharpen,statechart}/SKILL.md` · 새 `hooks/tests/no-history-rest.sh` |
| 9 | `entry-and-stage-invocation` | false | ARCHITECTURE §2의 단계 · 슬래시 입구 스킬 `SKILL.md` frontmatter |
| 10 | `sharpen-entry-descriptions` | false | 자동 입구 8개 `SKILL.md`의 `description` |
| 11 | `summary-unplanned-reason` | false | `skills/sdd-run/scripts/preamble.md` |

### PR 6 `restructure-repo` — 레포 구성 · CI · 훅 기록

| # | step | tdd | 바꾸는 파일 |
|---|---|---|---|
| 1 | `test-sh-runs-runner-unit` | false | 새 `hooks/tests/sdd-runner-unit.sh` |
| 2 | `runner-recognizes-test-sh` | true | `skills/sdd-run/scripts/sdd_runner.py` · `test_sdd_runner.py` |
| 3 | `ci-workflow` | false | 새 `.github/workflows/ci.yml` |
| 4 | `hook-log-all-exits` | true | `hooks/validate-session-end.sh` · `hooks/loop-lock.sh` · `hooks/todo-warn.sh` · `hooks/lib/hook-log.sh` · 새 `hooks/tests/hook-log-exits.sh` |
| 5 | `release-always-on` | false | `scripts/release.sh` |
| 6 | `changelog-split` | false | `docs/design-notes.md` · 새 `docs/changes/<버전>.md` |
| 7 | `remove-incubator` | false | `incubator/` 삭제 · `docs/design-notes.md` 한 줄 |
| 8 | `nestjs-unmeasured-note` | false | `skills/harness-init/SKILL.md` |

### PR 7 `restructure-readme` — README · After 측정

| # | step | tdd | 바꾸는 파일 |
|---|---|---|---|
| 1 | `readme-rewrite` | true | `README.md` · 새 `hooks/tests/readme-index.sh` |
| 2 | `doctor-readme-check` | false | `skills/harness-doctor/SKILL.md` |
| 3 | `measure-after` | measure | 바꿀 파일 없음 |
