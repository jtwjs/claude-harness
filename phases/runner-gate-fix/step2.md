# Step 2: rejudge-retry-window

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 R1 · R3와 「갱신」 줄
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- 이슈 #86 본문(`gh issue view 86`) — 이 step이 맡는 행
- `skills/sdd-run/scripts/sdd_runner.py` — 실패 판정의 `fails_now`(`resumed_at` 뒤 attempts만 셈) · `rejudge`의 `rejudged` 기록
- `skills/sdd-run/scripts/test_sdd_runner.py` — 재시도 한도 테스트 꼴

## 의도

- 채우는 수용 조건: #86 F2 — 재판정 뒤 구현 차례가 재시도 한도를 새로 받는다

## 작업

- 재시도 수는 `resumed_at`과 마지막 `rejudged[].at` 중 늦은 것 뒤의 attempts만 센다(결정 묶음 D2, 지휘 답 전 추천). `resumed_at`은 쓰지 않는다 — 쓰면 전체 verify가 켜진다
- attempts 기록 자체는 지우지 않는다(이력)
- step 1 F1 보강(검증 리뷰): ① 검증이 구현 구간에서 바뀐 테스트 파일을 옛 red 내용으로 되돌리는 테스트 커밋을 올리면 받는다(D1 「다시 받는다」 — HEAD 내용이 옛 red와 같으면 목록에서 뺀다) ② 구현 시도 커밋(blocked 판정이 만든 `wip:`)이 테스트 파일만 담았어도 「끝의 테스트만 담은 커밋 묶음」에 넣지 않는다 — 구현이 테스트만 지우고 막혀도 거부

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- 엣지 5축:
  - 빈 값·경계: `test_rejudge_resets_retry_window`
  - 비정상 입력: `test_rejudge_impl_only_deleted_test_refused`
  - 실패 경로: `test_rejudge_retry_window_still_limits`
  - 상태 전이: `test_rejudge_does_not_set_resumed_at` · `test_rejudge_after_restoring_impl_test_edit_accepted`
  - 동시성: 해당 없음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 「바뀌는 층」 재판정 행.
3. 결과를 `phases/runner-gate-fix/index.json`의 step 2에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. ADR-023에 바뀌는 행은 본문을 고치지 않고 「갱신」 줄로 단다.
