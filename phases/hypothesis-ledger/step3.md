# Step 3: ledger-state

## 읽어야 할 파일

- CLAUDE.md, docs/desk-hypothesis-gate-2026-11-12/PRD.md · ARCHITECTURE.md · ADR.md · SDD-SIDE.md (줄 형식·판정 기준·계산 규칙의 정본)
- hooks/lib/ledger.py (step 2 결과 — 원장 읽기 도우미를 같이 쓴다) · hooks/test.sh

## 작업

`ledger.py` 의 **읽기 서브커맨드 셋**. 계산 규칙은 SDD-SIDE.md 「계산 규칙」이 정본이다.

- `state`: 원장을 처음부터 훑어 재요구 상태를 계산해 `on`/`off` 를 stdout 한 줄로 낸다. 상태 파일을 만들지 않는다(ADR-004). 연속 값(AC3)·켜짐 유지(AC4)·꺼짐 조건(AC5)을 따른다. 유효한 `gate` 는 보정 줄이 있으면 마지막 보정 줄의 값(AC16). 기준 횟수는 매번 `~/.claude/hypothesis-gate.json` 의 `threshold` 에서 읽고(ADR-006, 테스트용 환경 변수로 경로 덮어쓰기 가능), 파일·값이 없으면 항상 `off`(AC6). 인자로 현재 (repo, task) 를 받는다.
- `pending-hits <repo> <task>`: AC13. 출력은 한 줄에 `ts` 하나.
- `pending-gates <repo> <task>`: AC17 의 CLI 쪽. 유효한 `gate` 가 `null` 인 맡김 줄의 `ts`.
- 원장이 없거나 비었거나 깨진 줄이 섞여도 죽지 않는다. 깨진 줄은 건너뛴다(AC2). 읽기만 하고 원장을 쓰지 않는다.

- 🔴 **`hooks/test.sh` 는 고치지 않는다.** 러너의 테스트 파일 판정이 이 파일을 못 알아봐서 RED 확인이 깨진다. `hooks/test.sh` 가 `hooks/tests/*.sh` 를 source 하므로(이미 연결됨), 새 케이스 파일은 `hooks/tests/` 아래에 두고 `ok`·`bad`·`TMP`·`HOOKS` 변수·함수를 그대로 쓴다. 실제 `~/.claude` 원장은 건드리지 않는다(`CLAUDE_HYPOTHESIS_LEDGER` 로 임시 경로).

## Acceptance Criteria

- 새 케이스는 `hooks/tests/ledger-state.sh` 에 쓴다(AC2·AC3·AC4·AC5·AC6·AC13·AC16 + `pending-gates`): 원장 없음·빈 파일·깨진 줄 / 연속 값 증가·`why` 리셋·(repo, task) 변경 리셋·`gate=null`·`task=null` 건너뜀 / 켜짐 유지 / `hyp`+`rebut` 순서 무관 꺼짐 / 설정 없음 / 보정으로 `null` → 값(연속에 합류)과 값 → `null`(빠짐) / 유효한 적중 줄 있는 건 `pending-hits` 에서 제외.
- `bash hooks/test.sh` 전부 통과. 테스트 커밋 먼저, 그 시점에 새 케이스가 실패.

## 검증 절차

1. `bash hooks/test.sh` 실제 실행.
2. ARCHITECTURE 「상태 관리 규약」 대조: 상태 파일 없음 · 원장 자르기 없음 · 보정은 매 계산에 적용.
3. `phases/hypothesis-ledger/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 사용자의 실제 원장(`~/.claude/hypothesis-ledger.jsonl`)을 테스트에서 건드리지 않는다(환경 변수로 임시 경로를 지정한다).
- 원장에 이름 · 프롬프트 원문 · 코드를 넣지 않는다(허용 칸 목록 밖은 거부 — AC10).
- 기준 횟수의 기본값을 코드에 박지 않는다(설정이 없으면 `off`).
