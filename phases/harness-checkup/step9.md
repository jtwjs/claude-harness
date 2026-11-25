# Step 9: plain-wording

## 읽어야 할 파일

- `docs/harness-checkup-2026-11-25/ADR.md`(ADR-018 — A 정할 것 · B 판정표 · 시험 결과). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- step 7 summary · `statechart` · `comment-hunter` description

## 작업

근거: ADR-018 B-1 · B-12 · B-17②.

바꾸는 파일:

- step 5 표의 「평문」 줄이 있는 파일 · `skills/statechart/SKILL.md`(description) · `agents/comment-hunter.md`(description) · 템플릿 references(「코드를 읽으면 안다」 문단)

- 강조어를 평문으로(뜻은 그대로) · 「코드를 읽으면 안다」 문단 삭제 · 두 description을 180토큰 기준 안으로
- tdd: false — 지시문 문장 바꾸기다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `git grep -cE 'CRITICAL|반드시|MUST|절대|NEVER|ALWAYS' -- skills agents templates`가 step 7 summary의 「그대로 둠」 줄 수와 같다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-018이 정한 값은 참조만 했는지 대조한다(값을 step에 복사하지 않는다).
3. 결과를 `phases/harness-checkup/index.json`의 step 9에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다.
- push · PR 금지(러너 밖에서 사람이 한다).
