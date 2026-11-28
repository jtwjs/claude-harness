# Step 1: path-list-nul-quote

## 읽어야 할 파일

- docs/runner-path-quote-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`(「테스트 파일 변경은 `git diff --name-only` 기본값으로 세지 않는다」 줄)
- `skills/sdd-run/scripts/sdd_runner.py` — 고칠 네 자리: `commits_since`(diff-tree) · `check`의 `red_tests`(나눔 모드 구현 쪽, `git diff --name-only base red_sha`) · `base_with_tests`(`git diff --name-only base HEAD`) · `rejudge_split`의 `files_of`(diff-tree). 따를 꼴: `check` 판정 4의 `changed` 목록과 `revert_test_edits`(이미 `-z` + `core.quotePath=false`)
- `skills/sdd-run/scripts/test_sdd_runner.py` — `red_turn` · `blocked_after_red` · `fix_tests` · `test_red_judge_impl_red_blame_blocks_without_discard`(이 step 테스트가 같은 꼴을 쓴다)

## 의도

- 채우는 수용 조건: AC-1 ~ AC-7 — 한글 · 공백 테스트 경로 레포에서 red 기록 · 구현 판정 · 재판정이 경로 읽기 때문에 잘못 거절되지 않게

## 작업

- 네 자리의 파일 목록을 「같은 고침」으로 받는다: `self.git("-c", "core.quotePath=false", …, "--name-only", "-z", …).stdout.split("\0")`에서 빈 조각을 버린다
  - `commits_since` · `rejudge_split` `files_of`: `diff-tree --no-commit-id --name-only -z -r <sha>`
  - `check` `red_tests`: `diff --name-only -z <base> <red_sha>` — `--no-renames`는 넣지 않는다(PRD 결정 runner-path-quote-red-list)
  - `base_with_tests`: `diff --name-only -z <base> HEAD` — `--no-renames`는 넣지 않는다(PRD 결정 runner-path-quote-rejudge-renames)
- 자리마다 판정 4 · 4'와 같은 꼴을 그대로 적는다. 헬퍼로 묶지 않고 판정 4 · 4' 줄은 건드리지 않는다(PRD 결정 runner-path-quote-inline)
- 거르기(`TEST_FILE` · `phases/` 제외)와 판정 규칙 · 메시지는 그대로 둔다
- `docs/sdd-runner.md` 검증 상태의 테스트 개수 줄을 실제 `Ran N`으로 고치고, 괄호 목록 맨 앞에 이번 phase 몫(#113 runner-path-quote 6개: red 한글 · red 공백 · 재판정 한글 · 재판정 공백 · 재판정 BASE에 한글 새 테스트 · red 테스트 한글 경로 lint blocked)을 더한다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 같이 돈다)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_red_judge_space_path_recorded`
  - 비정상 입력: `test_red_judge_nonascii_path_recorded`
  - 실패 경로: `test_red_blame_nonascii_path_blocks`
  - 상태 전이: `test_rejudge_nonascii_path_bundle_accepted` · `test_rejudge_space_path_bundle_accepted` · `test_rejudge_nonascii_new_test_put_on_base`
  - 동시성: 해당 없음: 판정은 차례인 세션 하나만 돈다(나눔 모드 차례 장치)

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-path-quote-2026-11-28/ARCHITECTURE.md` 「불변 규칙」.
3. 결과를 `phases/runner-path-quote/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- 판정 4 · 4' 줄 · `hooks/**`는 바꾸지 않는다(PRD 하지 않을 것).
