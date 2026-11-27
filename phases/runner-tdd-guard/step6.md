# Step 6: review-fix-guard-gaps

## 읽어야 할 파일

- docs/runner-tdd-guard-2026-11-27/{PRD,ARCHITECTURE,ADR}.md — ADR-024 T6 · T7 · T8, T2 본문의 diff 명령, ARCHITECTURE 「지키는 것」
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `revert_test_edits` · `edits_problem` · `check`의 blocked 갈래 · `record`의 error 멈춤 갈래(`fails_now > self.max_retries`)
- `skills/sdd-run/scripts/test_sdd_runner.py` — 아래 엣지 칸 테스트들
- `docs/sdd-runner.md` 판정 4' 줄 · 「`test_edits` 칸」 항목

## 의도

- 채우는 수용 조건: AC-1 · AC-2를 리뷰가 찾은 갈래에서도 성립시킨다 — 이름 바꾸기 · 옮기기 · 공백/한글 경로 · 구현의 자기 허가 · error 멈춤 경로에서 기존 테스트 수정이 빠져나가지 않게(새 맥락 리뷰 1회차, ADR-024 T6~T8)

## 작업

- `revert_test_edits`: 순변화 목록을 `git -c core.quotePath=false diff --no-renames --name-only -z BASE HEAD`로 받아 `\0`으로 나눈다(빈 항목 버림). 되돌림 · 메시지는 그대로
- T6: 허용 칸은 진행 중 index.json이 아니라 BASE 커밋의 `phases/{task}/index.json`에서 그 step의 `test_edits`를 읽는다(`git show BASE:<경로>`). 없거나 읽을 수 없으면 빈 칸으로 본다. 지시문(`prompt`)에 보이는 칸 목록은 지금처럼 index.json 그대로 둔다
- T7: `record`에서 error로 멈추는 갈래(재시도 한도 초과)가 `wip:` 커밋 뒤 BASE를 지우기 전에, `tdd`가 아닌 step이면 `revert_test_edits`를 돌리고 되돌린 것이 있으면 `error_message` 끝에 「(테스트 수정 되돌림: <경로 최대 5개>)」를 붙인다. `red`가 있는 tdd step은 바꾸지 않는다
- T8: `edits_problem`이 키에 `*` · `?` · `[` 가 있거나 `./`로 시작하면 그 키를 보이는 이유 한 줄을 돌려준다
- 문서: `docs/sdd-runner.md` 판정 4' 줄에 「error로 멈출 때도 같은 되돌림(T7)」 · 「이름 바꾸기는 옛 경로 지움 + 새 경로 추가로 본다(`--no-renames`)」, 「`test_edits` 칸」 항목에 「BASE 커밋의 계획에서 읽는다(T6) — step 도중 더한 칸은 다음 시도부터」 · 「glob 글자 · `./` 키는 `start`가 거른다(T8)」. 「검증 상태」 테스트 개수를 실제 실행 결과로

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 `hooks/tests/sdd-runner-unit.sh`로 같이 돈다)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과(기존 테스트 포함)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_tdd_false_listed_rename_passes`
  - 비정상 입력: `test_tdd_false_space_and_nonascii_paths_reverted` · `test_start_test_edits_glob_key_refuses`
  - 실패 경로: `test_tdd_false_renamed_test_restored` · `test_tdd_false_moved_out_test_restored` · `test_tdd_false_self_granted_test_edits_ignored`
  - 상태 전이: `test_tdd_false_error_stop_reverts`
  - 동시성: 해당 없음: 판정은 차례인 세션 하나만 돈다(ADR-019 E12)

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-tdd-guard-2026-11-27/ARCHITECTURE.md` 「바뀌는 층」 · 「지키는 것」.
3. 결과를 `phases/runner-tdd-guard/index.json`의 step 6에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 테스트 먼저 step(`tdd: true`)의 판정 4 동작은 바꾸지 않는다 — 같은 이름 바꾸기 구멍이 있지만 #102로 따로 고친다
