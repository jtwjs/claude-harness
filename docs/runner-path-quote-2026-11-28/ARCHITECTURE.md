# ARCHITECTURE — runner-path-quote

기존 구조 그대로 — 바뀌는 층: 없음. 러너 구조는 [`docs/sdd-runner.md`](../sdd-runner.md)가 정본이다. (← 검증 세션)

## 코드 지도

| 파일 | 이번에 하는 일 | 출처 |
|---|---|---|
| `skills/sdd-run/scripts/sdd_runner.py` `commits_since` | 커밋마다 파일 목록을 `git -c core.quotePath=false diff-tree --no-commit-id --name-only -z -r <sha>`로 받아 `\0`으로 나눈다 | PRD AC-1 · AC-2 |
| `sdd_runner.py` `check` red 테스트 목록 | `git -c core.quotePath=false diff --name-only -z <base> <red>`(이름 바꾸기 감지는 그대로) | PRD AC-6 |
| `sdd_runner.py` `base_with_tests` | `git -c core.quotePath=false diff --name-only -z <base> HEAD`(이름 바꾸기 감지는 그대로) | PRD AC-5 |
| `sdd_runner.py` `rejudge_split` `files_of` | `commits_since`와 같은 `diff-tree` 꼴 | PRD AC-3 · AC-4 |
| `skills/sdd-run/scripts/test_sdd_runner.py` | 재현 A~F 테스트 6개 | PRD AC-1~6 |
| `docs/sdd-runner.md` 검증 상태 | 테스트 개수 줄 | PRD AC-7 |

## 불변 규칙

- 판정 2 ~ 6 · 판정 4' · 재판정 확인 ① ~ ③의 판정 규칙은 그대로다. 바뀌는 것은 파일 목록을 받는 방법뿐이다 (← #113 할 것)
- 이미 같은 꼴인 판정 4 · 4' 두 자리는 건드리지 않는다 (← PRD 결정 runner-path-quote-inline)
- `commits_since`를 쓰는 판정 6 범위(앱 찾기) · `blame_earlier`도 같은 목록을 받게 되지만, 경로가 바르게 읽히는 것 말고 바뀌는 규칙은 없다 (← 검증 세션)

## 재현

PRD 「재현」 표 A~F(2026-11-28, origin/main 러너, 검증 세션 스크래치). E · F는 A~D 자리만 고친 복사본에서 드러났다.

## 테스트 전략

- 나눔 모드(`red_turn` → `judge --red` / `blocked_after_red` → `fix_tests` → `rejudge` / lint가 red 테스트 파일을 가리키는 `test_red_judge_impl_red_blame_blocks_without_discard` 꼴)로 끝에서 끝까지 돈다 (← 검증 세션)
- 「고치기 전 실패」 증거는 테스트 커밋 뒤 `judge --red` 출력이다. E · F는 A~D가 막혀 있어도 다른 자리에서 실패하므로 고치기 전 코드에서 같이 실패한다 (← 트랙 지시문 완료 조건)

## 배포와 롤백

- 플러그인 릴리스로 나간다. 되돌릴 때는 PR revert 하나다 (← 검증 세션)
