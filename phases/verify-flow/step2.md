# Step 2: runner-error-tail

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 G1) · 이슈 #12 본문
- `skills/sdd-run/scripts/sdd_runner.py`(`check` · `run_out` · `record`의 `last_error`) · `skills/sdd-run/scripts/test_sdd_runner.py` · `hooks/tests/sdd-runner-unit.sh` · `docs/sdd-runner.md`

## 작업

근거: ADR-019 G1(#12).

바꾸는 파일:

- `skills/sdd-run/scripts/sdd_runner.py` · `skills/sdd-run/scripts/test_sdd_runner.py` · `docs/sdd-runner.md`(판정 표 「실패 사유」 칸 한 구절)

- verify 실패(`Fail("verify 실패: …")`) 사유에 그 명령 stdout · stderr의 마지막 40줄을 붙인다. 실패한 테스트 이름 줄(줄 앞 공백을 무시하고 `FAIL` · `FAILED` · `✗` · `✕` · `🔴`로 시작 — 이 레포 `hooks/test.sh`의 실패 줄은 `  🔴`)은 40줄 밖이어도 앞에 모아 넣는다(최대 10줄)
- `last_error` · `attempts`에 같은 글이 들어가고, 다음 지시문 「이전 시도 실패」에 그대로 붙는다
- 출력이 길어 index.json이 부푸는 것을 막는다: 붙이는 글 상한 4,000자, 넘으면 앞을 자르고 `…(앞 생략)` 표시
- 테스트 메서드 이름에 `error_tail`을 넣는다(AC의 `-k`가 이 이름으로 고른다. RED 커밋 뒤에는 이름을 못 바꾼다)
- 테스트 먼저: 실패 출력 끝 줄 포함 · 테스트 이름 줄 우선 · 상한 자르기

## Acceptance Criteria

- `bash hooks/test.sh` 통과
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py -k error_tail` 통과(`hooks/tests/sdd-runner-unit.sh`와 같은 방식)

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 러너 규칙의 정본이 `sdd_runner.py` 하나라는 것(`sdd-run` SKILL.md 7행)을 지켰는지 — 스킬 본문에 규칙을 복사하지 않았는지 대조한다.
3. 결과를 `phases/verify-flow/index.json`의 step 2에 기록(성공 · 실패 · 차단 꼴은 step 1과 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- push · PR 금지.
