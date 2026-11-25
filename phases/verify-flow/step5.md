# Step 5: runner-intent-effort

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 C1 · C2 · C3 · E1 · E3)
- `skills/sdd-run/scripts/sdd_runner.py`(`prompt` · `invoke` · `main`) · `skills/sdd-run/scripts/preamble.md`(6번 blocked) · `skills/sdd-run/scripts/test_sdd_runner.py` · `docs/sdd-runner.md`
- step 4 summary(나눔 모드 `--role` 옵션)

## 작업

근거: ADR-019 C1(의도 칸) · C2(effort는 역할이 정한다) · C3(멈춤 조건은 공용 규칙 한 곳).

바꾸는 파일:

- `skills/sdd-run/scripts/sdd_runner.py` · `skills/sdd-run/scripts/preamble.md` · `skills/sdd-run/scripts/test_sdd_runner.py` · `docs/sdd-runner.md`

- 의도 칸(ADR-019 C1): step 파일에 `## 의도` 절이 있는데 본문이 비면 `prompt`가 지시문을 내지 않고 종료 코드 비0 + 이유 한 줄. 절이 없으면(옛 phase) 지시문은 내고 stderr에 경고 한 줄
- effort(ADR-019 C2): `prompt`가 stderr에 `▶ effort <값>`을 낸다 — 세션 안 러너는 이 값을 Agent effort로 넘긴다. 헤드리스 `invoke`는 `claude -p`에 `--effort <값>`을 넘긴다. 값은 역할에서: `--role test` = 검증 역할, `--role impl` · 옵션 없는 1회 모드 = 구현 역할. 역할 → 값 대응은 ADR-019 E1을 따르되 코드에는 한 곳(상수 하나)에만 둔다. `--effort`로 덮을 수 있다
- 멈춤 조건(ADR-019 C3): `preamble.md` 6번 blocked 조건을 「사람만 할 수 있는 일 · 테스트가 수용 조건과 다르다 · 설계 문서에 없는 결정이 필요하다」로 넓힌다. 구현 역할 지시문에는 「테스트는 고치지 않는다 — 막히면 blocked + 이유, 검증 세션이 다시 판정한다」(ADR-019 E3)
- 테스트 먼저: 빈 의도 절 거부 · 의도 절 없음 경고 · 역할별 effort 출력 · 헤드리스 명령에 `--effort` · `--effort` 덮어쓰기

## Acceptance Criteria

- `bash hooks/test.sh` 통과
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py -k intent_effort` 통과(`hooks/tests/sdd-runner-unit.sh`와 같은 방식)

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. effort 값이 코드 한 곳에만 있는지(`git grep -n '"medium"\|"high"' -- skills/sdd-run/scripts/sdd_runner.py`) 대조한다.
3. 결과를 `phases/verify-flow/index.json`의 step 5에 기록(꼴은 step 4와 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지. step 파일에 effort 칸을 만들지 않는다(ADR-019 C2).
- 쌓기만 하는 기록은 고치지 않는다.
- push · PR 금지.
