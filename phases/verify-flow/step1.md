# Step 1: ledger-intent-fields

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 — D1 · D2 · D3). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `hooks/lib/ledger.py`(`FIELDS` · `BOOLS` · `build_entry`) · `hooks/hypothesis-gate.sh`(판정 지시 문구 · 하네스 없는 폴더 분기 · `HOOK_RESULT` 이름) · `hooks/lib/hook-log.sh` · `hooks/tests/ledger-write.sh`(케이스 꼴) · `hooks/tests/hook-log-all.sh` · `hooks/tests/quiet-without-harness.sh` · `docs/desk-hypothesis-gate-2026-11-12/SDD-SIDE.md`(칸 정의)
- 이슈 #17 본문(판정 모호 5건 · 비사람 입력 줄)

## 작업

근거: ADR-019 D1 · D3. 점검 phase step 3 · 5(#56)가 이 훅에 기록(`hook_log_on_exit`)과 하네스 없는 폴더 분기를 넣었다 — 그 위에서 고친다.

바꾸는 파일:

- `hooks/lib/ledger.py` · `hooks/hypothesis-gate.sh` · `docs/desk-hypothesis-gate-2026-11-12/SDD-SIDE.md`(칸 정의 표에 세 칸) · 새 `hooks/tests/ledger-intent.sh`

- `append`가 `intent=` · `effort=` · `verify=`를 **선택 칸**으로 받는다. 세 칸 모두 값은 `true | false`다(effort도 수준이 아니라 「말했나」). 그 밖 값은 거부. 빠지면 줄에 쓰지 않는다(읽는 쪽은 없음 = null). 필수 칸으로 두지 않는 이유: 세션이 시작될 때의 훅 문구가 끝까지 쓰여(ADR-018 B-11) 옛 문구 세션의 append가 「빠진 칸」으로 거부된다
- 옛 줄은 고치지 않는다. `by` enum 값은 그대로(ADR-019 D2)
- 판정 지시 문구에 세 칸 정의 한 구절씩: intent = 맡기는 말에 무엇을 왜(의도)가 있음 · effort = 얼마나 깊이 볼지 말함 · verify = 끝을 어떻게 확인할지 말함
- 비사람 입력 거르기: 훅 입력의 프롬프트가 세션 간 메시지만으로 된 턴이면 판정 지시를 내지 않고 `HOOK_RESULT=nonhuman`으로 끝난다. 지금 훅은 입력을 버린다(`cat >/dev/null`) — 거르려면 입력을 읽어야 하고, 원문은 판별에만 쓰고 어디에도 남기지 않는다. 표식은 먼저 실제 훅 입력에서 확인하고(이 step의 첫 작업, summary에 표식 문자열), 표식을 못 찾으면 거르기만 빼고 진행한 뒤 summary에 「거르기 미적용: 이유」
- #17의 판정 문구 5건은 고치지 않는다(데이터를 본 뒤, #17 「다음 수」)
- 새 테스트 파일 첫 줄은 `printf '\n[ledger-intent] …\n'`(AC가 이 표식을 찾는다)
- 테스트 먼저: 선택 칸 있음 · 없음 · 허용 밖 값 거부 · 옛 줄 읽기 · 세션 간 메시지 턴에 출력 없음 + 기록 한 줄 `nonhuman`

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `bash hooks/test.sh 2>&1 | grep -F '[ledger-intent]'` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-019 값은 참조만 했는지 대조한다.
3. 결과를 `phases/verify-flow/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다. 단 `SDD-SIDE.md` 칸 정의 표는 살아 있는 계약 문서라 고친다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다. 원장 실물(`~/.claude/…`)을 읽거나 고치지 않는다 — 테스트는 `CLAUDE_HYPOTHESIS_LEDGER`로 임시 파일을 쓴다.
- push · PR 금지(러너 밖에서 사람이 한다).
