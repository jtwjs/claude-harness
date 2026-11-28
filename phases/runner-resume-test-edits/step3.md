# Step 3: align-commit-guard

## 읽어야 할 파일

- docs/runner-resume-test-edits-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음. PRD 결정 표 runner-resume-test-edits-commit-guard · runner-resume-test-edits-name-match
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `start`(`edits_problem` 루프 바로 뒤가 새 검사 자리, 부작용(exclude · 브랜치 · `resumed_at`) 전) · `align_test_edits`(step 1이 더한 메서드)
- `skills/sdd-run/scripts/test_sdd_runner.py` — `start_with`(start 앞뒤 브랜치 · index 바이트 대조 꼴) · 「기록 때 test_edits 를 BASE 계획 값으로 맞춤(#116)」 절

## 의도

- 채우는 수용 조건: AC-9 · AC-10 · AC-11 — 맞추기가 커밋 안 된 정당한 계획 칸을 지우거나 다른 step으로 옮기지 않게(REVIEW 1회차 🟡 2 · 🟢 1)

## 작업

- `start`: `edits_problem` 루프 뒤, 관문(`gate`) 전에 검사 하나를 더한다
  - `git show HEAD:phases/<task>/index.json`을 읽는다. 없거나 JSON이 아니면 모든 step의 커밋된 값 = 칸 없음
  - 작업 트리 index.json의 step마다 커밋된 값(같은 step 번호의 `test_edits`, dict가 아니면 칸 없음)과 지금 값(dict가 아니면 칸 없음 — `null`도 칸 없음)을 비교한다
  - 다른 step이 있으면 첫 step 하나로 `step {N} test_edits 가 커밋된 계획과 다르다 — index.json 을 커밋한 뒤 실행` 한 줄을 출력하고 종료 1. 브랜치 · index.json · exclude는 바꾸지 않는다
- `align_test_edits`: 계획 값은 계획 index에서 번호가 같고 `name`도 같은 step의 `test_edits`(dict일 때)만 쓴다. 번호만 같고 이름이 다르면 계획 값 = 칸 없음
- `align_test_edits`: 지금 값과 계획 값이 같으면(둘 다 칸 없음 — 키가 없거나 `null` — 포함) 아무것도 바꾸지 않고 줄도 내지 않는다
- 판정 4'(`planned_edits`) · 판정 1 ~ 6 · 실패 메시지는 바꾸지 않는다
- 문서: `docs/sdd-runner.md` `test_edits` 항목에 두 문장을 더한다 — ① `start`가 커밋 안 된 칸을 보면 「index.json 을 커밋한 뒤 실행」으로 종료 1(첫 실행 · 재개 모두) ② 맞추기는 step 번호와 name이 둘 다 같을 때만 계획 값을 넣는다. 「재개하며 칸을 더하려면 index.json을 커밋한 뒤 재개한다」 문장은 그대로 둔다. 테스트 개수 줄은 실제 `Ran N`과 이번 phase 몫 개수로 고친다
- 문서: `skills/sdd-run/SKILL.md` §4 재개 절차의 「`test_edits` 칸을 더하려면 index.json을 커밋한 뒤 재개한다.」를 「`test_edits` 칸을 더하려면 index.json을 커밋한 뒤 재개한다(커밋하지 않으면 `start`가 멈춘다).」로만 바꾼다. 그 문단의 다른 문장은 건드리지 않는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 같이 돈다)
- `grep -c '커밋하지 않으면 .start.가 멈춘다' skills/sdd-run/SKILL.md` → 1
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_start_refuses_uncommitted_plan_edits`
  - 비정상 입력: `test_align_null_edits_no_notice`
  - 실패 경로: `test_start_refuses_uncommitted_edit_on_resume`
  - 상태 전이: `test_align_renumbered_step_does_not_inherit_edits`
  - 동시성: 해당 없음: 다른 세션이 BASE 뒤 칸을 고친 경우는 step 1 `test_align_other_session_later_edit_reverted_with_notice`가 고정했다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-resume-test-edits-2026-11-28/ARCHITECTURE.md` 「불변 규칙」.
3. 결과를 `phases/runner-resume-test-edits/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- `docs/changes/**`(릴리스 몫)는 고치지 않는다.
