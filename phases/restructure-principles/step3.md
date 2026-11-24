# Step 3: principles-index-and-questions

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/why/SKILL.md` 「질문 규칙」 절
- `skills/sdd/SKILL.md` · `skills/sdd-plan/SKILL.md` · `skills/design-brief/SKILL.md`에서 「질문 규칙」을 가리키는 줄
- `hooks/test.sh` 케이스 10의 `'질문 규칙 — 정본:skills/why/SKILL.md'`

## 작업

바꾸는 파일:

- 새 `docs/principles/INDEX.md` · 새 `docs/principles/ask-questions.md`
- 새 `hooks/tests/principles.sh`
- `skills/why/SKILL.md` · `skills/sdd/SKILL.md` · `skills/sdd-plan/SKILL.md` · `skills/design-brief/SKILL.md`
- `hooks/test.sh` 케이스 10의 질문 규칙 정본 경로

- 테스트 먼저(`hooks/tests/principles.sh`): ① `docs/principles/INDEX.md`가 있다 ② INDEX 표의 경로 칸이 가리키는 파일이 모두 있고, `docs/principles/*.md`(INDEX 제외)가 모두 표에 있다 ③ `skills/` 아래에서 `docs/principles/`를 가리키는 줄은 모두 `${CLAUDE_PLUGIN_ROOT}/docs/principles/` 형태다(상대 경로는 다른 레포 세션에서 첫 Read가 실패한다, ADR-016 「결과」) ④ `skills/why/SKILL.md`가 `${CLAUDE_PLUGIN_ROOT}/docs/principles/ask-questions.md`를 가리킨다. 새 테스트 파일은 `hooks/tests/no-brain.sh`처럼 `hooks/test.sh`가 source 하는 조각이다: `printf '\n[이름] …\n'`로 시작, `$HOOKS` · `$TMP` · `ok` · `bad`를 그대로 쓰고 변수는 파일 고유 접두사(`_xx_`)를 붙인다
- `INDEX.md`: 첫 줄에 「목차의 경로는 이 파일이 있는 폴더 기준」. 표 `이름 | 언제 | 경로`. 첫 행 `ask-questions`
- `ask-questions.md`: `why` 「질문 규칙」의 판단 규칙을 옮긴다(한 번에 한 질문 · 추천 표시 · 반박 · 이유 체인 등). 원칙 파일엔 판단 규칙만(ADR-016 D2)
- `why`의 「질문 규칙」 절은 원칙 경로 한 줄로 바꾼다. `sdd` · `sdd-plan` · `design-brief`의 「`why` 질문 규칙」 참조도 원칙 경로로
- `hooks/test.sh` 케이스 10의 `'질문 규칙 — 정본:skills/why/SKILL.md'`는 새 위치(`docs/principles/ask-questions.md`)와 그 파일에 실제로 있는 문구로 맞춘다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `bash hooks/test.sh 2>&1 | grep -F '[principles]'` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-principles/index.json`의 step 3에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`는 이 step이 바꾼 경로 · 문구를 따라 **기존 줄을 맞추는 것만** 한다(ADR-016 「대가」 Q3 예외). 새 케이스를 넣지 않는다 — 새 테스트는 `hooks/tests/*.sh`.
- push · PR 금지(러너 밖에서 사람이 한다).
