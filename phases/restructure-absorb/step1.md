# Step 1: no-comments-skill-agent

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- PStack 9e278fe `pstack/skills/no-comments/SKILL.md` · `pstack/agents/comment-sicko.md`(`gh api … ?ref=9e278fe -q .content | base64 -d`)
- `agents/code-reviewer.md`(에이전트 frontmatter 형식)

## 작업

바꾸는 파일:

- 새 `skills/no-comments/SKILL.md` · 새 `agents/comment-hunter.md`
- `skills/sdd/SKILL.md` REVIEW 절 한 줄

- `no-comments`: 사람만(`disable-model-invocation: true`). 찾는 쪽은 `comment-hunter` 에이전트, 판정은 메인. 거절한 보고는 한 번만 다시 돌린다. 제약 주석은 승인 뒤 타입 · 런타임 검사 · 테스트 · 린트로 옮기자고 제안한다(ADR-016 D6)
- Cursor `Task` 호출 → Agent 도구, `poteto-mode` 의존 문장 → 하네스 문장. 끝에 출처 한 줄(PStack MIT)
- `sdd` REVIEW에 「선택: `/no-comments`」 한 줄
- tdd: false — 외부 지시문을 고쳐 들이는 일이라 기계 판정할 동작이 없다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `grep -q 'disable-model-invocation: true' skills/no-comments/SKILL.md && test -f agents/comment-hunter.md`
- `! grep -n 'subagent_type\|poteto' skills/no-comments/SKILL.md agents/comment-hunter.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-absorb/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
