# Step 1: rejudge-guards

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 R1 · R3와 「갱신」 줄
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- 이슈 #86 본문(`gh issue view 86`) — 이 step이 맡는 행
- `skills/sdd-run/scripts/sdd_runner.py` — `rejudge` · `red_passes`(돌아갈 곳을 `--abbrev-ref HEAD`로 잡는다 — detached면 문자 그대로 `HEAD`)
- `skills/sdd-run/scripts/test_sdd_runner.py` — `blocked_after_red` · `fix_tests` · rejudge 테스트들

## 의도

- 채우는 수용 조건: #86 F1 · F3 — `rejudge`가 구현 세션이 바꾼 테스트를 새 red로 씻어 주지 않게, detached HEAD에서 임시 커밋에 남지 않게

## 작업

- F1: 옛 red 뒤 ~ 끝의 「테스트만 담은 커밋」 묶음 앞 구간의 커밋이 테스트 파일(`TEST_FILE`, 지움 포함)을 건드렸으면 그 파일 목록을 보이고 종료 1. 아무것도 안 바꾼다
- F3: 결정 묶음 D3대로(지휘 답 전 추천: `red_passes`가 브랜치 위면 브랜치 이름, detached면 시작 sha로 돌아간다 — `judge --red`도 같은 함수를 쓴다)
- 기존 rejudge 테스트는 그대로 통과

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」):
  - 빈 값·경계: `test_rejudge_impl_test_edit_before_red_ok`
  - 비정상 입력: `test_rejudge_detached_head`
  - 실패 경로: `test_rejudge_impl_deleted_test_refused` · `test_rejudge_impl_edited_test_refused`
  - 상태 전이: 해당 없음: 성공 전이는 runner-gate step 3 테스트가 덮는다
  - 동시성: 해당 없음: 차례 장치는 `test_rejudge_out_of_turn_changes_nothing`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 「바뀌는 층」 재판정 행.
3. 결과를 `phases/runner-gate-fix/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. ADR-023에 바뀌는 행은 본문을 고치지 않고 「갱신」 줄로 단다.
