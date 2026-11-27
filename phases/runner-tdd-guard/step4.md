# Step 4: test-edits-check

## 읽어야 할 파일

- docs/runner-tdd-guard-2026-11-27/{PRD,ARCHITECTURE,ADR}.md — ADR-024 T1~T5
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `TEST_FILE`(:80) · `check`(:606-671, tdd 판정 4는 :624-639) · `record`(:912-1006)
- `skills/sdd-run/scripts/test_sdd_runner.py` — `RunnerCase` 도우미(`phase` · `run_runner` · `session` · `act` · `red_turn` · `head`)
- `start`의 계획 검사 자리(:456-463 — `kind: measure` + `tdd: true` 거절과 같은 꼴)
- 기존 테스트 `test_measure_step_with_tdd_refuses`

## 의도

- 채우는 수용 조건: 범위 「계획 칸에 이유와 함께 적힌 파일만 허용」을 장치로 세운다 — 칸 꼴이 틀린 계획을 첫 step 전에 거른다(ADR-024 T4)

## 작업

- `start`가 부작용(exclude · 브랜치 · `resumed_at`) 전에 step마다 `test_edits`를 본다. 다음이면 그 step 번호와 이유 한 줄을 보이고 종료 1, 아무것도 안 바꾼다
  - `test_edits`가 객체(경로 → 문자열)가 아니다
  - `tdd: true` step에 `test_edits`가 있다
  - 이유가 빈 문자열(공백만 포함)이다
  - 경로가 `TEST_FILE`에 걸리지 않거나 `phases/`로 시작한다
- 칸이 없거나 올바르면 지금처럼 진행한다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 `hooks/tests/sdd-runner-unit.sh`로 같이 돈다)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과(기존 테스트 포함)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_start_test_edits_empty_reason_refuses` · `test_start_test_edits_valid_passes`
  - 비정상 입력: `test_start_test_edits_not_object_refuses` · `test_start_test_edits_non_test_path_refuses`
  - 실패 경로: `test_start_test_edits_on_tdd_step_refuses`
  - 상태 전이: 해당 없음: start는 거절할 때 index · 브랜치를 바꾸지 않는다(같은 테스트들이 앞뒤 값을 대조한다)
  - 동시성: 해당 없음: start는 판정 전 한 번 돈다

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
