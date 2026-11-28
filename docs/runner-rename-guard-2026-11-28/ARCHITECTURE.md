# ARCHITECTURE — runner-rename-guard

기존 구조 그대로 — 바뀌는 층: 없음. 러너 구조는 [`docs/sdd-runner.md`](../sdd-runner.md)가 정본이다. (← 검증 세션)

## 코드 지도

| 파일 | 이번에 하는 일 | 출처 |
|---|---|---|
| `skills/sdd-run/scripts/sdd_runner.py` `check` 판정 4 | red 뒤 바뀐 테스트 파일 목록을 `git -c core.quotePath=false diff --no-renames --name-only -z <red>..HEAD`로 받아 `\0`으로 나눈다. 판정 4'(`revert_test_edits`)와 같은 꼴 | PRD AC-1~3 |
| `skills/sdd-run/scripts/test_sdd_runner.py` | 나눔 모드 판정 4 테스트 3개(이름 바꾸기 · 공백 · 한글) | PRD AC-1~3 |
| `docs/sdd-runner.md` `test_edits` 항목 | 「다음 시도(새 BASE)부터」 → 0.45.0 변경 이력 업그레이드 영향 줄과 같은 뜻 | PRD AC-4 |

## 불변 규칙

- 판정 4의 되돌림 규칙은 그대로다: red에 있던 경로는 red 내용으로 복원, red에 없던 경로는 지움, 되돌림 커밋 뒤 실패. 바뀌는 것은 목록을 받는 방법뿐이다 (← #102 할 것)
- 판정 2 · 3 · 5 · 6과 판정 4'는 바꾸지 않는다 (← PRD 하지 않을 것)

## 재현 (2026-11-28, main b3f7a53, 검증 세션 스크래치)

| # | 경우 | 지금 결과 | 출처 |
|---|---|---|---|
| A | 나눔 모드 red 뒤 구현이 `tests/a.expect` → `tests/a2.expect` 이름 바꾸기 | 종료 10, 두 파일 다 없음 — #102 현상 그대로 | 검증 세션 |
| B | BASE에 있던 `tests/my q.expect` · `tests/한글.expect`를 red 뒤 구현이 고침 | 종료 10이지만 둘 다 안 되돌림. 실패 이유에 `tests/my`(쪼개진 경로)만 보임 | 검증 세션 |
| C | red 커밋의 테스트 파일이 한글 경로(`tests/한글.expect`) | `RED: 테스트 커밋이 없다`로 거절 — `commits_since`의 `diff-tree` 출력에 따옴표가 붙어 테스트 파일 판별이 안 맞음 | 검증 세션 |
| D | 재판정 고친 테스트 묶음이 한글 경로 | `blocked 뒤 커밋 … 테스트 · phases/ 밖 파일을 담았다`로 거절 — `rejudge_split`의 `diff-tree`가 같은 이유. `base_with_tests`까지 가지 않음 | 검증 세션 |
| E | 재판정 묶음이 BASE에 있던 테스트를 이름 바꿈 | 종료 0(받음). `base_with_tests`에 옛 경로가 남지만 BASE에 있던 파일이라 BASE에서 통과해 결과가 안 바뀜 | 검증 세션 |

## 테스트 전략

- 나눔 모드(`red_turn` → `judge --red` → `prompt --role impl` → `judge`)로 판정 4를 끝에서 끝까지 돈다. 1회 모드 판정 4도 같은 줄을 지나 따로 덮지 않는다 (← 검증 세션)
- 공백 · 한글 경로 테스트 파일은 BASE에 미리 둔다 — red 커밋에 한글 경로를 넣으면 재현 C로 RED에서 먼저 거절된다 (← 검증 세션)

## 배포와 롤백

- 플러그인 릴리스로 나간다. 되돌릴 때는 PR revert 하나다 (← 검증 세션)
