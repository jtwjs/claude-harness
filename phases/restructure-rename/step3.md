# Step 3: rename-cartography-to-harness-score

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/ai-readiness-cartography/SKILL.md`
- `hooks/weekly-readiness-check.sh`

## 작업

바꾸는 파일:

- `skills/ai-readiness-cartography/` → `skills/harness-score/`
- `hooks/weekly-readiness-check.sh` · `BACKLOG.md` · `README.md`(이름만)
- `hooks/test.sh`의 가짜 플러그인 경로(`$FAKE/skills/ai-readiness-cartography/...` 두 줄)

- `git mv skills/ai-readiness-cartography skills/harness-score`, frontmatter `name: harness-score` · `disable-model-invocation: true`(ADR-016 D5)
- 스크립트 경로를 `skills/harness-score/scripts/`로. **리포트 파일 이름 `ai-readiness-score.json`과 상태줄 접두사 `ai-readiness — `는 바꾸지 않는다** — 대상 레포에 쌓인 지난 리포트와 비교하는 데 쓴다
- tdd: false — step 1과 같다(이름 · 경로 옮기기)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `test -f skills/harness-score/SKILL.md && grep -q 'disable-model-invocation: true' skills/harness-score/SKILL.md`
- `git grep -n 'ai-readiness-cartography' -- . ':!phases/' ':!docs/retro/' ':!docs/*-20*' ':!docs/design-notes.md' ':!skills/harness-init/SKILL.md' ':!skills/harness-init/references/'` 출력 0줄

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-rename/index.json`의 step 3에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`는 이 step이 바꾼 경로 · 문구를 따라 **기존 줄을 맞추는 것만** 한다(ADR-016 「대가」 Q3 예외). 새 케이스를 넣지 않는다 — 새 테스트는 `hooks/tests/*.sh`.
- push · PR 금지(러너 밖에서 사람이 한다).
