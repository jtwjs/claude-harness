# Step 10: fix-read-hostile-input

## 읽어야 할 파일

- CLAUDE.md(없으면 건너뜀), `.claude/rules/non-obvious-patterns.md`, docs/desk-hypothesis-gate-2026-11-12/PRD.md · ARCHITECTURE.md · ADR.md · SDD-SIDE.md
- hooks/lib/ledger.py (`read_lines` · `_split` · `cmd_read`) · hooks/hypothesis-gate.sh · hooks/test.sh · hooks/tests/ledger-state.sh

## 작업

`code-reviewer` 심층 리뷰의 🟡 둘을 고친다(결정 주체: 사용자가 지금 고치기를 승인). 고칠 곳은 `hooks/lib/ledger.py` 한 파일이다. step 9 가 내건 "읽기 서브커맨드는 어떤 원장 내용에도 exit 0" 약속을 지킨다.

1. **깊게 중첩된 JSON 줄**: `read_lines` 의 `json.loads` 가 `RecursionError`(`ValueError` 아님)를 던지면 `state`·`pending-hits`·`pending-gates` 가 exit 1 로 죽는다. 그 줄만 건너뛰도록 `except (ValueError, RecursionError)` 로 바꾼다. 재현: `[` 20만 개 + `]` 20만 개 한 줄.
2. **`ts`·`ref` 값 모양 제한**: 맡김 줄의 `ts`, 적중·보정 줄의 `ref` 는 **출력 가능한 ASCII 한 토큰**(정규식 `[\x21-\x7e]{1,64}`, 공백·제어문자·비ASCII 없음)일 때만 인정한다. `_split` 에서 `isinstance(str)` 검사를 이 검사로 바꾼다. 이유: (a) 짝 없는 서로게이트가 든 `ts`(`"\ud800x"`)는 디코드를 통과하지만 `pending-*` 의 `print` 에서 `UnicodeEncodeError` 로 죽는다. (b) `ts` 에 줄바꿈(`"a\nb"`)이 들어가면 `pending-*` 가 한 `ts` 를 두 줄로 낸다("한 줄에 `ts` 하나" 계약 위반). `append` 가 만드는 `ts`(`<ISO>#<hex4>`)와 옛 형식 `ts` 는 이 모양에 맞으므로 정상 줄은 잃지 않는다. 건너뛴 줄은 다른 어떤 계산에도 쓰이지 않는다.

- 이 외는 고치지 않는다(`append`·`compute_state`·`threshold`·훅 셸 등). 어떤 입력에도 읽기 서브커맨드는 exit 0, 훅은 항상 exit 0. 새 의존을 만들지 않는다(표준 라이브러리 `re` 만).
- 🔴 **`hooks/test.sh` 는 고치지 않는다.** 새 케이스는 `hooks/tests/ledger-state.sh` 끝에만 더한다(`ok`·`bad`·`TMP`·`HOOKS`·`ls*` 도우미 그대로). 실제 `~/.claude` 원장은 건드리지 않는다(`CLAUDE_HYPOTHESIS_LEDGER` 로 임시 경로).

## Acceptance Criteria

- 새 케이스(`hooks/tests/ledger-state.sh`): 중첩 20만 단계 줄이 섞인 원장에서 `state`·`pending-hits`·`pending-gates` 가 exit 0 이고 나머지 줄로 계산한다 / 짝 없는 서로게이트 `ts`(맡김 줄)와 `ref`(적중·보정 줄)가 섞여도 `pending-hits`·`pending-gates` 가 exit 0 이고 그 줄은 쓰이지 않는다 / `ts` 에 줄바꿈이 든 줄이 있어도 `pending-*` 출력이 한 줄에 `ts` 하나다(그 줄은 출력에 안 나온다) / 공백이 든 `ts` 도 같다 / `append` 가 만든 정상 `ts`(`#hex4` 꼬리)와 `#` 없는 옛 형식 `ts` 는 그대로 인정된다.
- `bash hooks/test.sh` 전부 통과(기존 393 유지). 테스트 커밋 먼저, 그 시점에 새 케이스가 실패.

## 검증 절차

1. `bash hooks/test.sh` 실제 실행. 기존 케이스 회귀 확인.
2. 임시 원장에 위 적대적 줄들을 넣고 `state`·`pending-*` 를 직접 불러 exit 0 을 눈으로 확인.
3. `phases/hypothesis-ledger/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 사용자의 실제 원장(`~/.claude/hypothesis-ledger.jsonl`)을 테스트에서 건드리지 않는다.
- 원장에 이름 · 프롬프트 원문 · 코드를 넣지 않는다. 기준 횟수의 기본값을 코드에 박지 않는다.
