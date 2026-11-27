# Step 4: impl-judge-after-rejudge

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 R3 「구현 쪽 판정 5」 줄
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `check`의 판정 4 · 5(`:513-540`) · `main`의 `prompt --role test` blocked 안내(`:893-895`) · step 3이 만든 `rejudge`
- `skills/sdd-run/scripts/test_sdd_runner.py` — step 3 테스트들 · `test_red_judge_impl_judge_skips_red_checks`

## 의도

- 채우는 수용 조건: AC-3 — rejudge 뒤 구현 차례가 끝까지 돌아 구현 커밋과 고친 테스트가 둘 다 남고 step이 끝난다. 테스트만 틀렸고 구현이 이미 맞는 경우가 「변경 없음」으로 헛돌지 않게 한다

## 작업

- 구현 쪽 `judge`(`check`) 판정 5: step에 `rejudged` 기록이 있으면 「`red` 뒤 커밋」 대신 「BASE 뒤 커밋 중 테스트 파일 · `phases/` 밖 파일을 담은 커밋이 있나」로 본다. 없으면 지금처럼 「completed 보고인데 변경 없음」
- 판정 4(새 `red` 뒤 테스트 파일 변경은 되돌림)와 판정 6(범위 · `{since}` = BASE)은 그대로
- `prompt --role test`가 blocked step에서 내는 재판정 안내(종료 2)에 다음 수 한 줄을 더한다: 테스트가 틀렸으면 테스트만 고쳐 커밋한 뒤 `rejudge {task} --step N`, 구현이 고칠 일이면 status를 pending으로 되돌린다
- `rejudged`가 없는 step(1회 모드 · 재판정 없는 나눔 모드)의 판정은 바뀌지 않는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_rejudged_impl_already_right_completes`
  - 비정상 입력: 해당 없음: 입력(index 상태)은 step 3 `rejudge`가 거른 뒤다
  - 실패 경로: `test_rejudged_impl_edit_test_reverted`
  - 상태 전이: `test_rejudge_round_trip_keeps_impl_and_fixed_test` · `test_blocked_test_prompt_mentions_rejudge`
  - 동시성: 해당 없음: 차례 장치는 step 3 `test_rejudge_out_of_turn_changes_nothing`이 덮는다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 「바뀌는 층」 재판정 행.
3. 결과를 `phases/runner-gate/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
