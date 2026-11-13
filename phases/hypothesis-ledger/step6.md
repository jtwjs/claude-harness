# Step 6: fix-gate-null-collect

## 읽어야 할 파일

- CLAUDE.md, docs/desk-hypothesis-gate-2026-11-12/PRD.md · ARCHITECTURE.md · ADR.md · SDD-SIDE.md (줄 형식·판정 기준·계산 규칙의 정본. 결정 표의 「설계가 아닌 맡김」 행)
- hooks/lib/ledger.py (`compute_state`) · hooks/tests/ledger-state.sh · hooks/test.sh

## 작업

`ledger.py` 의 `compute_state` 한 곳만 SDD-SIDE.md 결정에 맞춘다. 결정: 설계가 아닌 맡김은 줄을 남기고 `gate=null`, **연속 계산에서만** 제외한다(결정 주체: 사용자).

- 지금 코드는 유효한 `gate` 가 `null` 인 줄을 루프에서 통째로 건너뛰어, 재요구가 켜진 뒤의 `hyp`·`rebut` 모으기에서도 뺀다. 이게 결정보다 넓다.
- 고칠 동작:
  - `gate=null`(보정 적용 뒤) 줄은 연속 값을 올리지도 끊지도 않는다(지금과 같다).
  - 단 상태가 `on` 인 동안, 같은 (repo, task) 의 `gate=null` 줄이라도 `hyp` 참·`rebut` 참은 꺼짐 조건에 모은다.
  - `task=null` 줄은 지금처럼 연속 계산과 모으기 둘 다에서 뺀다(SDD-SIDE.md 규칙, 바꾸지 않는다). `gate=null` 줄이 (repo, task) 가 바뀌는 신호가 되지도 않는다(그 줄의 repo·task 가 현재 키와 다르면 건너뛴다).
- 이 외는 고치지 않는다(`pending-gates`·`pending-hits`·`append` 등).

- 🔴 **`hooks/test.sh` 는 고치지 않는다.** 러너의 테스트 파일 판정이 이 파일을 못 알아봐서 RED 확인이 깨진다. 새 케이스는 `hooks/tests/ledger-state.sh` 끝에 더한다(`ok`·`bad`·`TMP`·`HOOKS` 그대로). 실제 `~/.claude` 원장은 건드리지 않는다(`CLAUDE_HYPOTHESIS_LEDGER` 로 임시 경로).

## Acceptance Criteria

- 새 케이스(`hooks/tests/ledger-state.sh`): 상태가 `on` 인 뒤에 `gate=null` 줄이 `hyp` 참, 이어서 `gate=null` 줄이 `rebut` 참이면 `off` 가 된다 / `gate=null` 줄만 `rec·acc` 참·`why` 거짓으로 이어져도 연속 값은 오르지 않는다(켜지지 않는다) / `task=null` 줄의 `hyp`+`rebut` 은 여전히 꺼짐에 쓰이지 않는다.
- `bash hooks/test.sh` 전부 통과. 테스트 커밋 먼저, 그 시점에 새 케이스가 실패.

## 검증 절차

1. `bash hooks/test.sh` 실제 실행. 기존 케이스 회귀 확인.
2. SDD-SIDE.md 결정 표 「설계가 아닌 맡김」 행과 코드 대조.
3. `phases/hypothesis-ledger/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 사용자의 실제 원장(`~/.claude/hypothesis-ledger.jsonl`)을 테스트에서 건드리지 않는다.
- 기준 횟수의 기본값을 코드에 박지 않는다.
