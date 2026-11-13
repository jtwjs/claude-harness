# Step 6: measure-ledger-cost

## 읽어야 할 파일

- CLAUDE.md, docs/desk-hypothesis-gate-2026-11-12/PRD.md · ARCHITECTURE.md · ADR.md · SDD-SIDE.md (줄 형식·판정 기준·계산 규칙의 정본)
- hooks/lib/ledger.py · hooks/hypothesis-gate.sh (step 2~4 결과)

## 작업

측정 전용 step(`kind: "measure"`). 코드 변경 없음. 아래를 재서 `summary`에 명령(백틱)과 결과를 남긴다. 못 재는 것은 `미측정: 방법 / 기한` 으로 적는다.

1. **훅 시간**: 스크래치 디렉터리에 임시 원장(줄 수천 개)을 만들어 `time bash hooks/hypothesis-gate.sh` 를 잰다(ADR-004 결과 절). 줄 수와 걸린 시간을 건수로 적는다.
2. **주입 문구 길이**: 훅 stdout 의 글자 수(토큰은 못 재면 `미측정`)를 적는다(ADR-001 결과 절).
3. **압축 뒤 줄 매칭**(PRD 「남은」 절 둘째): 대화형 세션이 필요하면 `미측정: 압축된 세션에서 /sdd REFLECT 를 돌려 pending-gates 줄을 프롬프트에 대응시킬 수 있나 확인 / 첫 실사용 REFLECT` 로 적고, 한계를 `docs/desk-hypothesis-gate-2026-11-12/SDD-SIDE.md` 「미확인」 절에 이미 적었으니 중복해 쓰지 않는다.
4. **동시 쓰기**: `ledger.py append` 를 병렬로 N번 불러 줄이 깨지거나 사라지지 않는지(ADR-003 결과 절) 센다.

## Acceptance Criteria

- summary 에 각 항목의 명령과 결과(또는 `미측정` 사유)가 있다.
- `git status` 가 깨끗하다(임시 원장은 스크래치 디렉터리).

## 검증 절차

1. 위 명령을 실제 실행한다.
2. `phases/hypothesis-ledger/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 사용자의 실제 원장(`~/.claude/hypothesis-ledger.jsonl`)을 테스트에서 건드리지 않는다(환경 변수로 임시 경로를 지정한다).
- 원장에 이름 · 프롬프트 원문 · 코드를 넣지 않는다(허용 칸 목록 밖은 거부 — AC10).
