# Step 8: deny-template

## 읽어야 할 파일

- `docs/harness-checkup-2026-11-25/ADR.md`(ADR-018 — A 정할 것 · B 판정표 · 시험 결과). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- step 7 summary(「막을 수 있나」로 가른 줄) · `templates/.claude/` · `skills/harness-init/SKILL.md`(템플릿을 까는 절)

## 작업

근거: ADR-018 B-7.

바꾸는 파일:

- 새 `templates/.claude/settings.json` · `skills/harness-init/SKILL.md`(까는 목록 한 줄)

- step 5에서 「deny로 막을 수 있다」로 가른 것만 `permissions.deny`에. 레포에 settings.json이 이미 있으면 덮지 않고 빠진 줄만 제안
- tdd: false — 설정 템플릿 파일이다(JSON 파싱 AC로 확인)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `python3 -c "import json;json.load(open('templates/.claude/settings.json'))"`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-018이 정한 값은 참조만 했는지 대조한다(값을 step에 복사하지 않는다).
3. 결과를 `phases/harness-checkup/index.json`의 step 8에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다.
- push · PR 금지(러너 밖에서 사람이 한다).
