# Step 1: rename-harness-to-sdd-plan

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/harness/SKILL.md`
- `skills/harness-init/SKILL.md` 「이름표」(형식만 본다. 행 추가는 step 6)
- `hooks/test.sh` 케이스 10(「[10] 문서 정합」 근처)

## 작업

바꾸는 파일:

- `skills/harness/` → `skills/sdd-plan/`
- `skills/sdd/SKILL.md` · `skills/sdd/references/design.md`
- `skills/harness-run/SKILL.md` · `skills/conductor/SKILL.md` · `skills/why/SKILL.md`
- `agents/feature-builder.md` · `agents/test-writer.md`
- `templates/.claude/README.md` · `templates/.claude/references/track-brief.md`
- `docs/sdd-runner.md` · `.claude/rules/non-obvious-patterns.md` · `README.md`(이름만) · `BACKLOG.md`
- `hooks/test.sh` 케이스 10의 `skills/harness/SKILL.md` 경로

- `git mv skills/harness skills/sdd-plan`, frontmatter `name`을 `sdd-plan`으로. description · 본문 문장은 이름 말고 바꾸지 않는다(다듬기는 restructure-trim)
- **PLAN 스킬**을 가리키는 `harness`만 `sdd-plan`으로 바꾼다: `claude-harness:harness`, `/harness`, 「`harness` 스킬」, `skills/harness/` 경로. 플러그인 자체 · `harness.json` · `harness-*` 스킬 이름 · 「하네스」 일반어는 그대로
- `docs/design-notes.md`는 §9 변경 이력(쌓기만 하는 기록)을 고치지 않는다. 1~8절 원칙 문장에 PLAN 스킬 이름이 있으면 고친다
- tdd: false — 이름 · 경로 옮기기라 옮긴 즉시 통과하는 검사만 있다. RED를 만들 수 없어 회귀 검사는 step 6에서 넣는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `test ! -e skills/harness && test -f skills/sdd-plan/SKILL.md`
- `git grep -nE 'claude-harness:harness([^-a-z]|$)|skills/harness/' -- . ':!phases/' ':!docs/retro/' ':!docs/*-20*/' ':!docs/design-notes.md' ':!skills/harness-init/SKILL.md' ':!skills/harness-init/references/'` 출력 0줄

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-rename/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`는 이 step이 바꾼 경로 · 문구를 따라 **기존 줄을 맞추는 것만** 한다(ADR-016 「대가」 Q3 예외). 새 케이스를 넣지 않는다 — 새 테스트는 `hooks/tests/*.sh`.
- push · PR 금지(러너 밖에서 사람이 한다).
