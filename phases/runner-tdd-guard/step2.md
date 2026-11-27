# Step 2: impl-base-pin

## 읽어야 할 파일

- docs/runner-tdd-guard-2026-11-27/{PRD,ARCHITECTURE,ADR}.md — ADR-024 T1~T5
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `TEST_FILE`(:80) · `check`(:606-671, tdd 판정 4는 :624-639) · `record`(:912-1006)
- `skills/sdd-run/scripts/test_sdd_runner.py` — `RunnerCase` 도우미(`phase` · `run_runner` · `session` · `act` · `red_turn` · `head`)
- `main`의 `prompt` 갈래(:1112-1148) · `pin_base`(:407-415) · `prompt` 메서드의 tdd:false 지시문(:569-572)
- 기존 테스트 `test_red_judge_tdd_false_is_impl_turn` · `test_session_base_pinned_across_retry`

## 의도

- 채우는 수용 조건: AC-1 · AC-2를 나눔 모드에서 성립시킨다 — 시작 커밋을 러너가 기록해야(ADR-024 T3) 판정 4'가 나눔 모드 tdd:false step에서 돈다. 지시문은 구현에게 규칙을 미리 알린다(T1)

## 작업

- `prompt --role impl`: 그 step에 `base`가 없고 `--base`도 없으면 그 순간 HEAD를 `pin_base`로 고정한다. `--base`를 주면 지금처럼 그 값(이미 고정돼 있으면 덮지 않음)
- tdd:false 지시문(측정 아님) 4번 줄에 붙인다: 「기존 테스트 파일은 고치지 않는다 — 고치면 러너가 되돌린다. 새 테스트 파일은 더해도 된다」. step에 `test_edits`가 있으면 「이 step에서 고쳐도 되는 기존 테스트 파일: <경로 — 이유> …」를 같이 보인다
- 1회 모드 `prompt`(`--role` 없음) · `--role test`의 BASE 처리는 바꾸지 않는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 `hooks/tests/sdd-runner-unit.sh`로 같이 돈다)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과(기존 테스트 포함)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_impl_prompt_pins_base_when_missing` · `test_tdd_false_prompt_states_test_rule`
  - 비정상 입력: `test_impl_prompt_keeps_given_base`
  - 실패 경로: `test_impl_tdd_false_judge_reverts_without_base_flag`
  - 상태 전이: `test_impl_base_repinned_after_blocked_fix`
  - 동시성: 해당 없음: 차례가 아니면 지금처럼 아무것도 안 바꾼다(`test_red_judge_refuses_out_of_turn`)

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
