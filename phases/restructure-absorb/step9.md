# Step 9: explain-diff-to-explain

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/explain-diff/SKILL.md`
- `skills/how/SKILL.md`(step 8) · `skills/why/SKILL.md`
- `skills/harness-init/SKILL.md` 이름표 · `hooks/tests/renames.sh`

## 작업

바꾸는 파일:

- `skills/explain-diff/` → `skills/explain/`
- `skills/sdd/SKILL.md`(학습 카드 재료 경로) · `skills/pr-write/SKILL.md` · `docs/learning-level.md` · `README.md`(이름만)
- `skills/harness-init/SKILL.md` 이름표 행 · `hooks/tests/renames.sh` 옛 이름 목록

- `git mv skills/explain-diff skills/explain`. 사람만(`disable-model-invocation: true`, ADR-016 Q2). `sdd` 마무리가 학습 카드 재료로 `${CLAUDE_PLUGIN_ROOT}/skills/explain/SKILL.md`를 경로로 부른다
- 내용: how(어떻게 도나) + why(왜 이렇게)를 엮어 레벨에 맞게 설명. 대화가 기본, 「문서로」면 HTML/노션. 퀴즈 없음(ADR-016 D13)
- 이름표에 `explain-diff` → `explain` 행, `renames.sh` 옛 이름 목록에 `explain-diff`(이 파일은 테스트지만 tdd false step이라 고쳐도 된다)
- tdd: false — 이름 · 경로 옮기기와 지시문 다시 쓰기다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `test ! -e skills/explain-diff && grep -q 'disable-model-invocation: true' skills/explain/SKILL.md`
- `git grep -n 'explain-diff' -- . ':!phases/' ':!docs/retro/' ':!docs/*-20*/' ':!docs/design-notes.md' ':!skills/harness-init/SKILL.md' ':!skills/harness-init/references/'` 출력 0줄

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-absorb/index.json`의 step 9에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
