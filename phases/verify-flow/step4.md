# Step 4: runner-red-judge

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 A4 · E2 · E3 · F1). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py`(`next_pending` · `prompt` · `check` 판정 1~6 · `record` · `discard_attempt` · `main`) · `skills/sdd-run/scripts/preamble.md` · `skills/sdd-run/scripts/test_sdd_runner.py` · `skills/sdd-run/scripts/phases_status.py` · `docs/sdd-runner.md`
- 앞 step 2 · 3이 같은 파일을 고쳤다 — 그 summary를 먼저 본다

## 작업

근거: ADR-019 A4(두 번 판정) · E2(검증이 테스트 → 구현이 맞춤) · F1(상태는 index.json).

바꾸는 파일:

- `skills/sdd-run/scripts/sdd_runner.py` · `skills/sdd-run/scripts/preamble.md` · `skills/sdd-run/scripts/test_sdd_runner.py` · `docs/sdd-runner.md`(판정 표에 나눔 모드 절)

- **나눔 모드**(검증 세션 · 구현 세션이 따로 있을 때)를 더한다. 옵션 없이 부르면 지금 1회 모드 그대로 — 헤드리스 `run` · 세션 하나 작업(ADR-019 F2)은 바뀌지 않는다
- `prompt --role test`(검증 세션): `tdd: true` step의 수용 조건을 실패하는 테스트로만 쓰고 `test: step N — {name} (red)`로 커밋하라는 지시문. 구현 파일을 만들지 않는다
- `judge --red --step N`(검증 세션): 판정 2 · 3만 돈다(테스트만 담긴 커밋이 BASE 뒤 첫 커밋 · 그 시점에 `verify.test` 실패). 통과하면 step에 `red: <테스트 커밋 sha>`를 적고 index를 커밋, 종료 0. 실패는 지금 RedFail과 같이 이번 시도를 버리고 10(재시도 사유 기록)
- `prompt --role impl`(구현 세션): `red`가 있는 `tdd: true` step, 또는 `tdd: false` step만 집는다(`red` 없는 `tdd: true` step은 건너뛴다). 지시문은 「테스트는 이미 있다 · 테스트 파일은 고치지 않는다 · 막히면 blocked + 이유」(ADR-019 E3)
- `judge --step N`(구현 뒤, `red`가 있으면): 판정 2 · 3은 다시 돌지 않고 `red` sha를 기준으로 4(그 뒤 테스트 파일 무변경) · 5 · 6을 돈다. 완료 · 실패 · blocked 처리와 `retries` · `attempts` 계수는 지금과 같다. 구현 쪽 재시도는 `red`를 지우지 않는다(테스트를 다시 쓰지 않는다)
- 나눔 모드 구현 쪽 judge에서 `RedFail`(판정 6의 `red_blame` 분기 — test 밖 verify가 RED 테스트 파일을 가리킴)이 나면 `discard_attempt`(BASE로 `reset --hard`)를 부르지 않는다. 검증 세션의 테스트 커밋이 지워지고 `red`가 고아 커밋을 가리키게 되기 때문이다. 대신 `red` sha 뒤의 구현 커밋만 버리거나, step을 `blocked`(이유: 테스트 파일이 verify에 걸림 — 검증 세션 재판정, ADR-019 E3)로 둔다
- 차례(ADR-019 E12): 두 세션이 같은 worktree · 같은 브랜치를 쓰고 차례는 index.json이 정한다(`red` 없음 = 검증 · `red` 있고 pending = 구현 · 구현 judge 끝 = 검증 리뷰). 차례가 아닌 역할로 `prompt --role` · `judge --red`를 부르면 아무것도 바꾸지 않고 비0 + 「지금은 <역할> 차례」 한 줄 — `judge --red`의 `checkout --detach` · `reset --hard`가 구현 중인 트리를 치지 않게 하는 장치다
- BASE는 `prompt --role test`에서 고정한 값을 구현 쪽이 그대로 쓴다(`pin_base`가 덮지 않는 지금 규칙)
- `red`는 index.json step의 선택 칸이다. `phases_status.py --check`는 지금도 status만 본다(이미 오류로 안 잡음) — 테스트로 고정만 한다. `status` 값은 4개 그대로
- 테스트 메서드 이름에 `red_judge`를 넣는다(AC의 `-k`)
- 테스트 먼저: 차례가 아닌 역할 호출 거부 · 나눔 모드 구현 judge의 RedFail이 테스트 커밋을 지우지 않음 · `--red` 통과 → `red` 기록 · `--red` RED 실패 → 시도 버림 · `--role impl`이 `red` 없는 step을 건너뜀 · `red` 있는 step의 judge가 2 · 3을 다시 안 돎 · 구현이 테스트 파일을 고치면 되돌림(판정 4) · 옵션 없는 1회 모드 회귀 없음

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py -k red_judge` 통과(`hooks/tests/sdd-runner-unit.sh`와 같은 방식)

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 러너 규칙의 정본은 `sdd_runner.py` 하나다(`sdd-run` SKILL.md 7행) — `docs/sdd-runner.md`는 판정 표 · 근거만, 스킬 본문 반영은 step 6이 한다.
3. 결과를 `phases/verify-flow/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 옵션 이름. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지. `status` 허용 값을 늘리지 않는다.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- push · PR 금지.
