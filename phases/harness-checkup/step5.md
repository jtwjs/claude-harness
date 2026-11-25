# Step 5: hooks-quiet-without-harness

## 읽어야 할 파일

- `docs/harness-checkup-2026-11-25/ADR.md`(ADR-018 — A 정할 것 · B 판정표 · 시험 결과). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `hooks/hypothesis-gate.sh` · `hooks/conductor-context.sh` · `hooks/block-dangerous-bash.sh`(머리 주석 「하네스 미설치 레포도 보호」) · `hooks/lib/conductor.py`(`is_seat`)

## 작업

근거: ADR-018 B-3(사용자 결정 — `hypothesis-gate`만 `.claude/harness.json`이 있는 레포와 지휘 자리에서 켜진다. 안전 훅은 덜지 않는다).

바꾸는 파일:

- `hooks/hypothesis-gate.sh` · 새 `hooks/tests/quiet-without-harness.sh`

- 테스트 먼저: `.claude/harness.json`이 없고 지휘 자리도 아닌 폴더에서 `hypothesis-gate`는 출력 0줄 · exit 0. harness.json이 있는 레포에서는 지금처럼 판정 지시 한 줄. 지휘 자리(임시 conductor.json의 seat)에서도 한 줄
- `conductor-context`는 이미 지휘 자리에서만 출력한다 — 바꾸지 않고 테스트로 그 동작만 고정한다
- `block-dangerous-bash`는 바꾸지 않는다 — 모든 레포에서 켜 두는 안전 훅이다(ADR-018 B-3). 테스트에 「하네스 없는 폴더에서도 block-dangerous-bash는 deny 패턴 명령을 여전히 막는다(exit 2)」 한 줄을 넣어 고정한다
- tdd: true

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `bash hooks/test.sh 2>&1 | grep -F '[quiet-without-harness]'` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-018이 정한 값은 참조만 했는지 대조한다(값을 step에 복사하지 않는다).
3. 결과를 `phases/harness-checkup/index.json`의 step 5에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다.
- push · PR 금지(러너 밖에서 사람이 한다).
