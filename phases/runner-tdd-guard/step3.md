# Step 3: blocked-revert

## 읽어야 할 파일

- docs/runner-tdd-guard-2026-11-27/{PRD,ARCHITECTURE,ADR}.md — ADR-024 T1~T5
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `TEST_FILE`(:80) · `check`(:606-671, tdd 판정 4는 :624-639) · `record`(:912-1006)
- `skills/sdd-run/scripts/test_sdd_runner.py` — `RunnerCase` 도우미(`phase` · `run_runner` · `session` · `act` · `red_turn` · `head`)
- `check`의 blocked 갈래(:609-610) · `record`의 blocked 기록(:958-970, `wip:` 커밋 · red 없으면 BASE 지움)
- step 1이 만든 판정 4' 코드(같은 되돌림을 다시 쓴다)

## 의도

- 채우는 수용 조건: AC-1 · AC-2의 우회로를 닫는다 — 구현이 테스트를 고친 채 blocked로 보고해도 판정 4'와 같게 되돌린다(ADR-024 T5)

## 작업

- `tdd`가 아닌 step이 blocked로 보고되면, blocked를 기록하기 전에 남은 변경을 커밋하고 판정 4'와 같은 대상(BASE에 있던 테스트 파일 · `test_edits`에 없음)을 BASE 내용으로 되돌려 커밋한다. 그 뒤 `blocked_reason` 끝에 「(테스트 수정 되돌림: <경로 최대 5개>)」를 붙이고 지금 blocked 경로(종료 2 · `blocked_at` · BASE 지움 · index 커밋)를 그대로 탄다
- 고친 내용은 기록에 남아야 한다: 구현 커밋(또는 묶음 커밋) 뒤에 되돌림 커밋이 오는 순서
- 되돌릴 대상이 없으면 지금과 같다(사유 · 커밋 목록 그대로). `tdd: true` step의 blocked는 바꾸지 않는다(red 있는 재판정 경로는 rejudge D1 · D5가 맡는다)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 `hooks/tests/sdd-runner-unit.sh`로 같이 돈다)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과(기존 테스트 포함)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_tdd_false_blocked_without_test_edit_unchanged`
  - 비정상 입력: `test_tdd_false_blocked_listed_edit_kept`
  - 실패 경로: `test_tdd_false_blocked_test_edit_reverted`
  - 상태 전이: `test_tdd_true_blocked_keeps_test_edit`
  - 동시성: 해당 없음: 판정은 차례인 세션 하나만 돈다(ADR-019 E12)

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-tdd-guard-2026-11-27/ARCHITECTURE.md` 「바뀌는 층」 · 「지키는 것」.
3. 결과를 `phases/runner-tdd-guard/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 테스트 먼저 step(`tdd: true`)의 판정 4 동작은 바꾸지 않는다(설계서 결정 · ADR-024 「결과」).
