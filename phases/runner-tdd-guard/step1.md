# Step 1: tdd-false-guard

## 읽어야 할 파일

- docs/runner-tdd-guard-2026-11-27/{PRD,ARCHITECTURE,ADR}.md — ADR-024 T1~T5
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `TEST_FILE`(:80) · `check`(:606-671, tdd 판정 4는 :624-639) · `record`(:912-1006)
- `skills/sdd-run/scripts/test_sdd_runner.py` — `RunnerCase` 도우미(`phase` · `run_runner` · `session` · `act` · `red_turn` · `head`)
- 판정 4의 되돌림 꼴(:630-639)을 그대로 본뜬다 — 되돌림 커밋 제목 · `Fail` 메시지 · 재시도 경로

## 의도

- 채우는 수용 조건: AC-1 · AC-2 · AC-3 + 범위 「변경 없음 → 통과 · 계획에 적은 파일 수정 → 통과」 — tdd가 아닌 step에서도 기존 테스트 파일 수정 · 삭제를 되돌리는 판정 4'(ADR-024 T1 · T2)

## 작업

- `check`에서 status 검사 · 남은 변경 묶음 커밋 뒤, `tdd`가 아닌 step(`kind: measure` 포함)이면 판정 4'를 판정 5 앞에 돈다
  - 대상: `git diff --name-only BASE HEAD`(순변화) 중 `TEST_FILE`에 걸리고 `phases/`로 시작하지 않고, BASE에 있었고(`cat-file -e BASE:<경로>`), step의 `test_edits`(객체, 키 = 경로 글자 그대로, glob 없음 — ADR-024 T4) 키에 없는 경로
  - 대상이 있으면 각 경로를 `git checkout BASE -- <경로>`로 되돌리고(지운 파일도 복원), 판정 4와 같은 꼴로 커밋(`test: step N — 테스트 수정 되돌림`)한 뒤 `Fail`을 낸다. 메시지는 「테스트 파일을 고쳤다(되돌림): <경로 최대 5개, 쉼표> — 기존 테스트 파일은 계획 칸(test_edits)에 적힌 것만 고친다. 고쳐야 하면 blocked + 이유」. 재시도 수 · `last_error` · `attempts`는 지금 `Fail` 경로 그대로
  - BASE에 없던 테스트 파일(추가)은 그대로 둔다. `test_edits`에 적힌 파일은 수정 · 삭제를 받는다
- `test_edits` 꼴 검사(이유 빈칸 등)는 step 4 몫이다. 여기서는 키만 읽는다(값은 보지 않는다)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 `hooks/tests/sdd-runner-unit.sh`로 같이 돈다)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과(기존 테스트 포함)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_tdd_false_no_test_change_passes` · `test_tdd_false_new_test_file_kept`
  - 비정상 입력: `test_tdd_false_listed_test_edit_passes`
  - 실패 경로: `test_tdd_false_test_edit_reverted` · `test_tdd_false_test_delete_restored` · `test_measure_step_test_edit_reverted`
  - 상태 전이: `test_tdd_false_revert_then_retry_passes`
  - 동시성: 해당 없음: 판정은 차례인 세션 하나만 돈다(나눔 모드 차례 장치, ADR-019 E12)

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
