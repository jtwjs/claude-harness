# Step 6: commit-harness-json

## 읽어야 할 파일

- `docs/harness-checkup-2026-11-25/ADR.md`(ADR-018 — A 정할 것 · B 판정표 · 시험 결과). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `.git/info/exclude`(main clone) · `.claude/rules/non-obvious-patterns.md` · `.claude/harness.json`(main clone 사본)

## 작업

근거: ADR-018 B-17①(사용자 결정 — 이 레포의 harness.json을 커밋한다).

바꾸는 파일:

- `.claude/harness.json`(새로 추적) · `.claude/rules/non-obvious-patterns.md`(2번 항목 삭제)
- 레포 밖: main clone의 `.git/info/exclude`에서 `.claude/harness.json` 줄을 뺀다(커밋 대상 아님 — summary에 적는다)

- 처음에 뺀 이유는 git 기록에 없다(exclude 파일은 추적되지 않는다). 이 사실을 summary에 한 줄
- 커밋하는 harness.json에 `git.branchPattern`을 넣지 않는다(worktree 사본에만 있던 값). main clone 사본과 같은 내용으로
- non-obvious-patterns 2번(「worktree에는 harness.json이 없다 · 복사한다」)을 지운다. 파일에 항목이 하나도 안 남으면 제목만 둔다
- tdd: false — 설정 파일 추적과 규칙 한 줄 삭제다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `git ls-files --error-unmatch .claude/harness.json`
- `! grep -q 'harness.json' .claude/rules/non-obvious-patterns.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-018이 정한 값은 참조만 했는지 대조한다(값을 step에 복사하지 않는다).
3. 결과를 `phases/harness-checkup/index.json`의 step 6에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다.
- push · PR 금지(러너 밖에서 사람이 한다).
