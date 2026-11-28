# Step 1: judge4-no-renames

## 읽어야 할 파일

- docs/runner-rename-guard-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`(「테스트 파일 변경은 `git diff --name-only` 기본값으로 세지 않는다」 줄)
- `skills/sdd-run/scripts/sdd_runner.py` — `check` 판정 4(:659-675, 목록은 :666) · 판정 4' `revert_test_edits`(:723-735, 따를 꼴)
- `skills/sdd-run/scripts/test_sdd_runner.py` — `red_turn` · `act` · `session` · `test_red_judge_impl_reverts_test_edit_keeps_red`(나눔 모드 판정 4 테스트 꼴) · `test_tdd_false_renamed_test_restored` · `test_tdd_false_space_and_nonascii_paths_reverted`(#91 같은 꼴)

## 의도

- 채우는 수용 조건: AC-1 · AC-2 · AC-3 — red 뒤 테스트 이름 바꾸기 · 공백 · 한글 경로 변경을 판정 4가 빠짐없이 되돌려 「테스트 통과」 신호를 믿을 수 있게

## 작업

- `check` 판정 4의 `changed` 목록(:666)을 판정 4'와 같은 꼴로 받는다: `self.git("-c", "core.quotePath=false", "diff", "--no-renames", "--name-only", "-z", f"{red_sha}..HEAD").stdout`를 `"\0"`으로 나누고 빈 조각은 버린다. 거르기(`TEST_FILE` · `phases/` 제외)와 되돌림(red에 있으면 `checkout red -- f`, 없으면 `git rm`) · 커밋 · `Fail` 메시지는 그대로 둔다
- `red_tests`(:663) · `base_with_tests`(:839) · `commits_since` · `rejudge_split`은 바꾸지 않는다 — #113 몫(PRD 결정 표)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 같이 돈다)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_red_impl_moved_out_test_restored`
  - 비정상 입력: `test_red_impl_space_path_test_reverted` · `test_red_impl_nonascii_path_test_reverted`
  - 실패 경로: `test_red_impl_renamed_test_restored`
  - 상태 전이: `test_red_impl_renamed_test_restored`
  - 동시성: 해당 없음: 판정은 차례인 세션 하나만 돈다(나눔 모드 차례 장치)

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-rename-guard-2026-11-28/ARCHITECTURE.md` 「불변 규칙」.
3. 결과를 `phases/runner-rename-guard/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 판정 4' · 판정 2 · 3 · 5 · 6 동작은 바꾸지 않는다(PRD 하지 않을 것).
