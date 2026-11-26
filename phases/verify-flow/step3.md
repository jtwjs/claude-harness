# Step 3: runner-defer-full-test

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 G1) · 이슈 #13 본문
- `skills/sdd-run/scripts/sdd_runner.py`(`verify_scope` · `full_reason` · `is_last` · `main` 인자) · `skills/sdd-run/scripts/test_sdd_runner.py` · `skills/sdd-run/SKILL.md` §2 3번 · `docs/sdd-runner.md`

## 작업

근거: ADR-019 G1(#13).

바꾸는 파일:

- `skills/sdd-run/scripts/sdd_runner.py` · `skills/sdd-run/scripts/test_sdd_runner.py` · `skills/sdd-run/SKILL.md`(§2 3번에 옵션 한 줄) · `docs/sdd-runner.md`

- `judge` · `run`에 `--defer-full-test` 옵션. 켜면 phase 마지막 step · 재개 step · 앱 밖 파일 때문에 「전체」로 넓어지는 verify도 `$step` 범위 명령만 돌린다. `harness.json` 키가 아니라 실행 옵션으로 두는 이유: 부하 판정은 사람이 그때그때 한다(#13 「부하 판정은 사람이 한다」)
- 옵션으로 줄인 step은 `summary` 끝에 `전체 test 미룸 — 릴리스 전 한 번` 한 구절을 러너가 붙인다(빠뜨리지 않게)
- 옵션은 `full_reason` 한 곳에서 건다 — 지시문의 검증 명령(`prompt`) · Stop 훅 환경(`invoke`) · `verify_scope`가 모두 이 함수로 「전체」를 정하므로, 한 곳에서 걸어야 셋이 엇갈리지 않는다
- `$step` 명령이 없는 앱은 줄일 범위가 없으니 그대로 전체를 돌린다
- 테스트 메서드 이름에 `defer_full`을 넣는다(AC의 `-k`)
- 테스트 먼저: 옵션 있음 · 없음 · `$step` 없는 앱 · summary 표시

## Acceptance Criteria

- `bash hooks/test.sh` 통과
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py -k defer_full` 통과(`hooks/tests/sdd-runner-unit.sh`와 같은 방식)

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 스킬 본문은 옵션 이름과 언제 쓰나 한 줄만 — 판정 규칙을 복사하지 않았는지 대조한다.
3. 결과를 `phases/verify-flow/index.json`의 step 3에 기록(꼴은 step 1과 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지. `uptime` 같은 부하 자동 판정을 넣지 않는다.
- 쌓기만 하는 기록은 고치지 않는다.
- push · PR 금지.
