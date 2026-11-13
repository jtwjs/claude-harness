# Step 1: injection-probe

## 읽어야 할 파일

- CLAUDE.md, docs/desk-hypothesis-gate-2026-11-12/PRD.md · ARCHITECTURE.md · ADR.md · SDD-SIDE.md (줄 형식·판정 기준·계산 규칙의 정본)
- hooks/hooks.json (이벤트 등록 형식) · hooks/conductor-context.sh (SessionStart 가 문구를 주입하는 기존 예)

## 작업

측정 전용 step(`kind: "measure"`). 코드·설정 변경 없음. 아래 둘을 실제로 재서 `summary`에 명령(백틱)과 결과를 남긴다.

1. **훅 주입이 모델에 닿는가** (PRD 「남은」 절 첫째). 스크래치 디렉터리에 임시 settings 파일을 만들어 `UserPromptSubmit` 훅 하나가 표식 문자열(예: `PROBE-7731`)을 stdout 으로 내게 한 뒤, `claude -p --settings <임시파일> "방금 훅이 넣은 표식 문자열을 그대로 말해줘"` 로 모델이 표식을 말하는지 본다. 이 레포의 `hooks/hooks.json` 은 고치지 않는다.
2. **줄 쓰기에 Bash 권한 확인이 뜨는가** (ADR-002 결과 절). 헤드리스에서 모델이 `python3 hooks/lib/ledger.py append ...` 형태의 명령을 부를 때 허용 목록 없이 막히는지 확인한다. 헤드리스로 재현이 안 되면 그 사실을 적고 `미측정: 대화형 세션에서 확인 / step 6` 로 넘긴다.

안 닿으면(1번 실패) status `blocked` + `blocked_reason` 에 실패 모습을 적는다. 주입 방식 설계를 다시 하는 결정은 사람이 한다.

## Acceptance Criteria

- summary 에 실행한 명령과 결과(표식이 모델 답에 나왔나 / 안 나왔나, 권한 확인 여부)가 있다.
- 이 step 은 변경이 없다. `git status` 가 깨끗해야 한다(스크래치 파일은 레포 밖).

## 검증 절차

1. 위 명령을 실제 실행하고 출력을 그대로 근거로 쓴다.
2. `phases/hypothesis-ledger/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 사용자의 실제 원장(`~/.claude/hypothesis-ledger.jsonl`)을 테스트에서 건드리지 않는다(환경 변수로 임시 경로를 지정한다).
- 원장에 이름 · 프롬프트 원문 · 코드를 넣지 않는다(허용 칸 목록 밖은 거부 — AC10).
