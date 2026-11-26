# Step 12: delegate-three-cells

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 C4 · C5 · A5)
- `docs/principles/write-for-agents.md`(#55가 만든 원칙 문서) · `docs/principles/INDEX.md` · `skills/sdd-review/SKILL.md` 「위임」 · `agents/code-reviewer.md` 절차 1(`SCOPE` · `CHECKED`) · `templates/.claude/references/track-brief.md`(step 8이 넣은 의도 · effort 칸)

## 작업

근거: ADR-019 C4. 선행: #55(`write-for-agents.md`를 만든다) — 그 머지 뒤에 한다. 먼저 이 브랜치 트리에서 `test -f docs/principles/write-for-agents.md`(#55 구현 PR이 만드는 파일)를 돌려 없으면 아무것도 바꾸지 말고 `blocked`(이유: #55 구현이 이 브랜치에 없음 — 기준 브랜치를 받은 뒤 재개)로 끝낸다.

바꾸는 파일:

- `docs/principles/write-for-agents.md` · `docs/principles/INDEX.md`(그 행 「언제」 칸) · `skills/sdd-review/SKILL.md`(「위임」 넘김 꼴 한 구절) · `agents/code-reviewer.md`(절차 1 입력에 `INTENT` 한 줄)

- `write-for-agents.md`에 절 「맡길 때 세 칸」: 의도(무엇을 왜, 채우는 수용 조건) · effort(역할 값, ADR-019 C2 참조) · 검증(끝을 무엇으로 확인하나). 즉석 Agent 호출 · 지휘 지시문 · 리뷰어 넘김에 같은 기준. fork는 검증자에게 쓰지 않는다는 한 구절은 호출 자리(ADR-019 A5)를 가리키기만
- INDEX 그 행 「언제」 칸에 「에이전트에 일을 맡길 때」를 더한다(새 행을 만들지 않는다)
- `code-reviewer` 넘김에 `INTENT`(의도 한 줄)를 `SCOPE` · `CHECKED` 옆에. 리뷰어의 의도 되비추기가 이것과 다르면 그 차이를 첫 줄에
- 훅(C5)은 만들지 않는다(보류)
- tdd: false — 문서 문장이다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(원칙 INDEX 검사 `hooks/tests/principles.sh` 포함)
- `grep -n '맡길 때 세 칸' docs/principles/write-for-agents.md` 출력 있음
- `grep -n 'INTENT' agents/code-reviewer.md skills/sdd-review/SKILL.md` 각 1줄 이상

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 원칙 문서에는 판단 규칙만, 절차 · 값은 넣지 않았는지(ADR-016 D2) 대조한다.
3. 결과를 `phases/verify-flow/index.json`의 step 12에 기록(꼴은 step 6과 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · 테스트 파일 수정 금지. 새 원칙 문서를 만들지 않는다.
- 쌓기만 하는 기록은 고치지 않는다.
- push · PR 금지.
