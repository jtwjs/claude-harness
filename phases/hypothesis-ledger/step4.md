# Step 4: gate-hook

## 읽어야 할 파일

- CLAUDE.md, docs/desk-hypothesis-gate-2026-11-12/PRD.md · ARCHITECTURE.md · ADR.md · SDD-SIDE.md (줄 형식·판정 기준·계산 규칙의 정본)
- hooks/hooks.json · hooks/conductor-context.sh · hooks/todo-warn.sh (훅 진입점 형식, bash 3.2 주의) · hooks/lib/ledger.py (step 2·3 결과)
- hooks/test.sh

## 작업

- 새 `hooks/hypothesis-gate.sh`: 얇은 진입점. `ledger.py state` 를 불러 결과를 주입 문구로 stdout 에 낸다(ADR-005). 어떤 실패에도 exit 0, 프롬프트를 막지 않는다(AC2).
  - 항상 나가는 줄: 판정 지시(모델이 응답 중 `ledger.py append` 를 Bash 로 불러 `hyp rec acc why rebut skip gate area` 를 판정해 한 줄 붙이게 하는 지시. 칸 의미·`skip` 기준은 SDD-SIDE.md 를 그대로 인용).
  - 상태가 `on` 일 때만 더하는 줄: 가설 요구 한 줄(AC7). `off` 면 이 문구가 없어야 한다.
  - 현재 (repo, task) 는 훅이 cwd 의 git toplevel 이름과 활성 phase 로 구한다. task 를 못 구하면 `null`(SDD-SIDE.md 규칙).
- `hooks/hooks.json` 에 `UserPromptSubmit` 이벤트로 이 훅을 등록한다(AC1). 다른 이벤트는 건드리지 않는다.
- 모든 레포에서 돈다(ADR-001). 판정 지시는 사용자의 지시를 대체하지 않는다.

- 🔴 **`hooks/test.sh` 는 고치지 않는다.** 러너의 테스트 파일 판정이 이 파일을 못 알아봐서 RED 확인이 깨진다. `hooks/test.sh` 가 `hooks/tests/*.sh` 를 source 하므로(이미 연결됨), 새 케이스 파일은 `hooks/tests/` 아래에 두고 `ok`·`bad`·`TMP`·`HOOKS` 변수·함수를 그대로 쓴다. 실제 `~/.claude` 원장은 건드리지 않는다(`CLAUDE_HYPOTHESIS_LEDGER` 로 임시 경로).

## Acceptance Criteria

- 새 케이스는 `hooks/tests/gate-hook.sh` 에 쓴다(AC1·AC7): hooks.json 에 `UserPromptSubmit` 이 있다 / 상태 `off` 주입에 가설 요구 문구가 없다 / `on` 이면 있다 / 원장이 깨져도 exit 0.
- `bash hooks/test.sh` 전부 통과. 테스트 커밋 먼저, 그 시점에 새 케이스가 실패.

## 검증 절차

1. `bash hooks/test.sh` 실제 실행.
2. 기존 훅 케이스가 그대로 통과하는지 확인(회귀).
3. 변수 뒤에 한글이 오면 `${}` 로 감싼다.
4. `phases/hypothesis-ledger/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 사용자의 실제 원장(`~/.claude/hypothesis-ledger.jsonl`)을 테스트에서 건드리지 않는다(환경 변수로 임시 경로를 지정한다).
- 원장에 이름 · 프롬프트 원문 · 코드를 넣지 않는다(허용 칸 목록 밖은 거부 — AC10).
- 훅에서 원장에 쓰지 않는다(쓰기는 모델 → `ledger.py append` 한 경로, ARCHITECTURE 「경계」).
