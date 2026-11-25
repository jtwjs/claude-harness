# Step 7: emphasis-triage

## 읽어야 할 파일

- `docs/harness-checkup-2026-11-25/ADR.md`(ADR-018 — A 정할 것 · B 판정표 · 시험 결과). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `skills/` · `agents/` · `templates/`의 강조어 줄 · `templates/.claude/references/*.md`

## 작업

근거: ADR-018 B-1 · B-12.

바꾸는 파일:

- 바꿀 파일 없음

- 강조어 줄(`git grep -nE 'CRITICAL|반드시|MUST|절대|NEVER|ALWAYS' -- skills agents templates`)을 줄마다 「훅 · deny로 막을 수 있나 / 평문이면 되나 / 그대로 둬야 하나(이유)」로 가른 표를 summary에(경로:줄 · 판정)
- 템플릿 references 3개를 문단마다 「코드를 읽으면 아나 / 판단을 바꾸나」로 가른 표도 같이
- 뒤 step(deny-template · plain-wording)이 이 표만 보고 일한다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- summary에 백틱 명령과 표가 있다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-018이 정한 값은 참조만 했는지 대조한다(값을 step에 복사하지 않는다).
3. 결과를 `phases/harness-checkup/index.json`의 step 7에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다.
- push · PR 금지(러너 밖에서 사람이 한다).
