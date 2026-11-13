# Step 2: ledger-write

## 읽어야 할 파일

- CLAUDE.md, docs/desk-hypothesis-gate-2026-11-12/PRD.md · ARCHITECTURE.md · ADR.md · SDD-SIDE.md (줄 형식·판정 기준·계산 규칙의 정본)
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴) · hooks/lib/conductor.py (lib 형식: CLI + import 둘 다)

## 작업

새 `hooks/lib/ledger.py` 의 **쓰기 세 서브커맨드**. 줄 형식·허용 값은 SDD-SIDE.md 가 정본이다(값을 이 파일에 복사하지 않는다).

- 원장 경로: 환경 변수(테스트용 `CLAUDE_HYPOTHESIS_LEDGER`)가 있으면 그것, 없으면 `~/.claude/hypothesis-ledger.jsonl`(ADR-003). 파일·폴더가 없으면 만든다.
- `append`: 맡김 줄 한 개를 끝에 추가. `ts` 는 스크립트가 붙인다. 허용 칸·값(`gate`, `area` 목록, 불리언 칸) 밖은 거부(AC8). 기존 줄은 고치지 않는다.
- `hit <ref> <right|partial|wrong> <model|finn>`: 적중 줄 추가. `ref` 가 `hyp=true` 인 맡김 줄의 `ts` 가 아니면 거부(AC9). 같은 `ref` 는 마지막 줄이 유효하다(읽는 쪽 규칙, 여기선 그냥 추가).
- `gate-fix <ref> <gate>`: 보정 줄 `{"ref","gate","by":"finn"}` 추가. `ref` 가 맡김 줄의 `ts` 가 아니거나 `gate` 가 허용 목록(`null` 포함) 밖이면 거부(AC15).
- 쓰기 실패(권한·디스크): 0 이 아닌 종료 코드와 stderr 한 줄만. 재시도·알림·복구 없음(AC12, ADR-002).
- 깨진 줄이 섞인 원장이어도 `ref` 검사는 깨진 줄을 건너뛰고 동작한다.

- 🔴 **`hooks/test.sh` 는 고치지 않는다.** 러너의 테스트 파일 판정이 이 파일을 못 알아봐서 RED 확인이 깨진다. `hooks/test.sh` 가 `hooks/tests/*.sh` 를 source 하므로(이미 연결됨), 새 케이스 파일은 `hooks/tests/` 아래에 두고 `ok`·`bad`·`TMP`·`HOOKS` 변수·함수를 그대로 쓴다. 실제 `~/.claude` 원장은 건드리지 않는다(`CLAUDE_HYPOTHESIS_LEDGER` 로 임시 경로).

## Acceptance Criteria

- 새 케이스는 `hooks/tests/ledger-write.sh` 에 쓴다(AC8·AC9·AC12·AC15): 허용 밖 칸·값 거부 / 기존 줄 무변경 / `hyp=false` 줄을 `ref` 로 하면 거부 / 존재하지 않는 `ref` 거부 / 허용 밖 `gate` 거부 / 쓸 수 없는 경로에서 비0 종료 + stderr 한 줄.
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나). 테스트 커밋이 먼저, 그 시점에 새 케이스가 실패해야 한다.

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조: 쓰기 경로는 `ledger.py` 한 곳뿐.
3. macOS bash 3.2 호환: 변수 뒤에 한글이 오면 `${}` 로 감싼다(0.35.0 수정 사례).
4. `phases/hypothesis-ledger/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 사용자의 실제 원장(`~/.claude/hypothesis-ledger.jsonl`)을 테스트에서 건드리지 않는다(환경 변수로 임시 경로를 지정한다).
- 원장에 이름 · 프롬프트 원문 · 코드를 넣지 않는다(허용 칸 목록 밖은 거부 — AC10).
