# Step 5: principles-three-docs

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- PStack `cursor/plugins` 9e278fe: `gh api 'repos/cursor/plugins/contents/pstack/skills/principle-attack-the-premise/SKILL.md?ref=9e278fe' -q .content | base64 -d`(같은 방식으로 `principle-subtract-before-you-add` · `principle-explain-the-number` · `benchmark-checklist`)
- `docs/principles/ask-questions.md`(step 3, 형식 맞추기)

## 작업

바꾸는 파일:

- 새 `docs/principles/attack-the-premise.md` · `subtract-before-you-add.md` · `explain-the-number.md`
- `docs/principles/INDEX.md` 행 3개

- 세 원칙을 한국어 판단 규칙으로 고쳐 쓴다. `explain-the-number.md`에는 `benchmark-checklist`의 숫자 점검 7문항을 붙인다(ADR-016 D13)
- 각 파일 끝에 출처 한 줄: 「PStack(MIT, Copyright (c) 2026 Lauren Tan) `principle-…`을 고쳐 씀」
- PStack 문장 중 하네스와 부딪치는 것(설계 결정을 묻지 않고 정하기 · 바깥 행동 자동 진행)은 가져오지 않는다(REVIEW §4 머리말)
- tdd: false — 새 문서 세 장이다. INDEX ↔ 파일 대응은 step 3 테스트가 본다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `ls docs/principles/{attack-the-premise,subtract-before-you-add,explain-the-number}.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-principles/index.json`의 step 5에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
