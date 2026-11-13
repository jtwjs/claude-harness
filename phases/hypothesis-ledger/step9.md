# Step 9: fix-diff-ts-robust

## 읽어야 할 파일

- CLAUDE.md(없으면 건너뜀), docs/desk-hypothesis-gate-2026-11-12/PRD.md · ARCHITECTURE.md · ADR.md · SDD-SIDE.md (줄 형식·계산 규칙의 정본)
- hooks/lib/ledger.py · hooks/hypothesis-gate.sh · hooks/test.sh · hooks/tests/ledger-write.sh · ledger-state.sh · gate-hook.sh

## 작업

sdd 리뷰 2회차 결과와 desk 요청을 한 step 에 묶는다(결정 주체: 사용자가 묶음 진행을 승인. `diff` 칸·참고용·`null` 의미는 사용자 결정, `ts` 겹침 방식 A 와 난이도 합치는 문구는 AI 추천 수락). 고칠 곳은 `hooks/lib/ledger.py` 와 `hooks/hypothesis-gate.sh` 둘이다.

1. **`ts` 겹침 막기 (방식 A)**: `append` 가 붙이는 `ts` 를 `<ISO 시각, 마이크로초>#<소문자 hex 4자리 난수>` 로 바꾼다(예: `2026-11-13T10:02:00.123456+09:00#a1b2`). 줄 키·`ref` 의 의미는 그대로(`ref` = 맡김 줄의 `ts` 문자열 통째). `hit`·`gate-fix`·`pending-*`·`compute_state` 는 `ts` 를 불투명한 문자열로 다루므로 그대로 동작해야 한다.
2. **`diff` 칸 추가**: 맡김 줄에 `diff` 칸. 값은 `easy|mid|hard|null`(`null` 은 JSON `null`). `append` 의 필수 칸에 `diff=<값>` 을 더한다(빠지면 "빠진 칸", 허용 밖 값은 거부 exit 2). 줄에서는 `gate` 다음 칸으로 둔다. 모델이 매기는 참고용 칸이라 **계산(`compute_state`·`pending-*`)에는 쓰지 않는다.** 이 칸이 없는 옛 줄도 그대로 읽힌다(칸이 없음 = 안 적음, `null` = 적었지만 매길 대상 없음).
3. **훅 주입 문구**(`hooks/hypothesis-gate.sh`): 명령 예시에 `diff=<easy|mid|hard|null>` 를 `gate` 다음에 더하고, 정의 한 문장을 `gate:` 정의 뒤에 더한다: `diff: 가설을 맞히기 어려운 정도. 범위(여러 레이어에 걸침)·되돌리기 어려움(마이그레이션·삭제·공개 API 계약)·선례 없음(레포에 같은 패턴이 없음) 중 하나라도 해당하면 hard, 하나도 해당하지 않으면 easy, 해당 여부가 애매하면 mid, hyp=false 면 null.` 나머지 문구(`hyp rec acc why rebut skip gate` 정의, `[가설 요구]`)는 바꾸지 않는다.
4. **원장 읽기 보강** (`read_lines`·`_split`):
   - 원장 파일에 UTF-8 이 아닌 바이트가 섞여도 죽지 않는다. 깨진 줄만 건너뛰고 나머지 줄은 읽는다(파일 전체를 `errors="replace"` 로 읽거나 줄 단위로 디코드). `threshold()` 의 설정 파일 읽기도 `UnicodeDecodeError` 에 죽지 않고 `None` 이 된다.
   - 맡김 줄은 `ts` 가 문자열일 때만, 적중·보정 줄은 `ref` 가 문자열일 때만 인정한다. 리스트·객체 등 해시 안 되는 값이 와도 `TypeError` 로 죽지 않고 그 줄은 건너뛴다. 읽기 서브커맨드는 어떤 원장 내용에도 exit 0.
5. **detached HEAD 테스트 고치기** (`hooks/tests/gate-hook.sh`): 지금 `repo2` 에는 커밋이 없어 `git checkout --detach` 가 실패하고 그 케이스가 detached 상태를 만들지 못한다. `repo2` 에 빈 커밋을 먼저 만든 뒤 실제로 `HEAD` 를 떼어 놓고(`symbolic-ref -q HEAD` 가 실패하는 상태임을 확인) 같은 단언을 한다.

- 원장 줄 형식 정본(SDD-SIDE.md)과 문서는 이 step 에서 고치지 않는다(메인이 따로 갱신). 새 의존을 만들지 않는다. 어떤 실패에도 훅은 exit 0.
- 🔴 **`hooks/test.sh` 는 고치지 않는다.** 러너의 테스트 파일 판정이 이 파일을 못 알아봐서 RED 확인이 깨진다. 새·고친 케이스는 `hooks/tests/*.sh` 에만 둔다(`ok`·`bad`·`TMP`·`HOOKS` 그대로). 실제 `~/.claude` 원장은 건드리지 않는다(`CLAUDE_HYPOTHESIS_LEDGER` 로 임시 경로).
- `append` 에 `diff=` 가 필수가 되므로 기존 테스트의 `append` 호출에도 `diff=` 를 더해 고친다. 이 수정과 `ts` 형식 정규식 수정은 **테스트 커밋(RED)에 같이** 넣는다(구현 커밋에서 테스트 파일을 고치면 판정이 막힌다).

## Acceptance Criteria

- 새·고친 케이스: `ts` 가 위 형식에 맞는다 / 같은 순간 `append` 를 동시에 50번 불러도(백그라운드 실행) `ts` 가 모두 다르다 / `hit`·`gate-fix` 가 `#` 꼬리가 있는 `ts` 를 `ref` 로 받는다 / `diff` 값 4종은 통과·`diff=foo` 거부·`diff` 빠지면 거부, 줄에 `"diff"` 가 들어간다 / `diff` 가 `state`·`pending-*` 결과에 영향이 없다 / 옛 줄(`diff` 칸 없음)이 `state` 계산에 그대로 쓰인다 / 주입 문구에 `diff=<easy|mid|hard|null>` 와 정의 문장이 있다 / 원장에 깨진 UTF-8 줄이 섞여도 `state`·`pending-*` 가 exit 0 이고 나머지 줄로 계산한다 / `ts`·`ref` 가 리스트·객체인 줄이 섞여도 exit 0 / detached HEAD 케이스가 실제 detached 상태에서 exit 0 과 주입 문구를 확인한다.
- `bash hooks/test.sh` 전부 통과. 테스트 커밋 먼저, 그 시점에 새 케이스가 실패.

## 검증 절차

1. `bash hooks/test.sh` 실제 실행. 기존 케이스 회귀 확인.
2. 임시 원장으로 `append` 를 직접 한 번 불러 줄 한 개를 눈으로 확인(`ts` 형식·`diff` 칸 위치).
3. `phases/hypothesis-ledger/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 사용자의 실제 원장(`~/.claude/hypothesis-ledger.jsonl`)을 테스트에서 건드리지 않는다.
- 원장에 이름 · 프롬프트 원문 · 코드를 넣지 않는다(허용 칸 목록 밖은 거부).
- 기준 횟수의 기본값을 코드에 박지 않는다.
