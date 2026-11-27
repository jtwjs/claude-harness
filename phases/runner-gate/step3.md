# Step 3: rejudge-entry

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 「R3 재판정 진입점」이 규칙의 정본이다. ADR-019 E3 · E12(`docs/verify-flow-2026-11-25/ADR.md:71,77`)
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `current` · `turn` · `refuse_turn`(`:216-242`) · `red_check` · `red_passes`(`:561-588`, `:655-681`, 커밋을 잠깐 옮겨 verify.test를 돌리고 진행 중 index.json을 지킨다) · `record`의 blocked 처리(`:739-747`, `red`가 있으면 BASE를 남긴다) · `main`의 `judge --red` 차례 검사(`:919-942`)
- `skills/sdd-run/scripts/test_sdd_runner.py` — `red_turn()` · `act()` · `test_red_judge_impl_red_blame_blocks_without_discard`(구현 쪽이 blocked가 되는 꼴)

## 의도

- 채우는 수용 조건: AC-3 — 재판정 「테스트가 틀렸다」 뒤 검증 세션이 고친 테스트를 진입점 하나로 구현 차례에 넘긴다. 구현 커밋을 지우지 않는다(#77)

## 작업

- `sdd_runner.py rejudge TASK --step N` 하위 명령. 순서대로 본다 — 앞에서 걸리면 **아무것도 바꾸지 않는다**:
  1. 차례: 끝나지 않은 첫 step(`current()`)이 N이 아니거나, N이 blocked가 아니거나, `red`가 없으면 한 줄(왜 아닌지 · 지금 누구 차례인지) + 종료 3(`NOT_TURN`)
  2. 두 번째 막힘: N에 `rejudged` 기록이 이미 있으면 「한 번 다시 판정했다 — 사용자에게(ADR-019 E3)」 + 종료 2
  3. 트리: `phases/{task}` · 훅 기록 파일 밖에 커밋 안 된 변경이 있으면 종료 1
  4. 고친 테스트: HEAD부터 거꾸로 이어지는 커밋 중 파일이 모두 테스트 파일(`TEST_FILE`) 또는 `phases/` 아래인 커밋들이 고친 테스트 묶음이다. 그 묶음에 테스트 파일이 하나도 없거나, 옛 `red`와 HEAD 사이 테스트 파일 내용 차이가 없으면 「고친 테스트 커밋이 없다」 종료 1. 묶음 앞(HEAD 쪽 끝이 아닌 자리)에 구현 · `wip` 커밋이 있는 것은 정상이다
  5. BASE 위 실패: BASE 트리에 HEAD의 테스트 파일(BASE와 HEAD 사이에 바뀐 테스트 파일, 지워진 것은 지움)을 얹은 상태에서 `verify.test`(앱별이면 테스트가 든 앱만, `$step.test`가 있으면 그것 — `red_check`와 같은 고르기)를 돌린다. **통과하면** 「고친 테스트가 구현 전(BASE)에서도 통과 — 아무것도 잡지 않는다」 종료 1. 작업 트리 · 브랜치 · 진행 중 index.json은 돌린 뒤 그대로여야 한다(임시 커밋 객체를 만들어 `red_passes`에 넘기는 방법을 권한다 — 브랜치를 움직이지 않는다)
- 통과하면 기록: `red` = HEAD sha, `status` = `pending`, `blocked_reason` · `blocked_at` 지움, `base` 그대로, `rejudged`(목록)에 `{"at": <stamp>, "red_before": <옛 red>}` 추가, index 커밋(`commit_index`). 출력 `✓ step N 재판정 — 테스트 고침 · red: <12자> · 구현 차례`, 종료 0
- 모듈 docstring 사용법(나눔 모드 줄들)에 `sdd_runner.py rejudge TASK --step N` 한 줄(ADR-023 R3 참조)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_rejudge_without_test_fix_refused`
  - 비정상 입력: `test_rejudge_fix_with_impl_file_refused` · `test_rejudge_dirty_tree_refused`
  - 실패 경로: `test_rejudge_fix_passing_on_base_refused`
  - 상태 전이: `test_rejudge_moves_red_keeps_impl` · `test_rejudge_second_block_goes_to_user`
  - 동시성: `test_rejudge_out_of_turn_changes_nothing`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 「지키는 것」(차례가 아니면 아무것도 안 바꾼다 · 구현 커밋은 지우지 않는다).
3. 결과를 `phases/runner-gate/index.json`의 step 3에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `git stash`를 쓰지 않는다(모든 worktree가 목록을 공유한다). `reset --hard` · 브랜치 옮기기로 구현 커밋을 빼지 않는다. 구현 쪽 `judge` 판정 5는 이 step에서 고치지 않는다(step 4)
