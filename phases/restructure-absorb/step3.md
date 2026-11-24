# Step 3: statechart-import

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- PStack 9e278fe `pstack/skills/statechart/`(SKILL.md · references/render.md · scripts/** · `pstack/LICENSE`)

## 작업

바꾸는 파일:

- 새 `skills/statechart/`(SKILL.md · references · scripts 전부 · LICENSE 사본)

- 원본을 그대로 가져온다(`gh api`로 파일마다 받기). `scripts/test/**`도 같이
- SKILL.md만 고친다: 사람만(`disable-model-invocation: true`), 실행은 스크래치 폴더에서만(레포에 산출물을 남기지 않는다), 첫 실행에 mise로 Java · TLC를 깔고 네트워크가 필요하다는 경고 한 줄, Cursor 전용 문장 제거(ADR-016 D8)
- `skills/statechart/LICENSE`에 PStack MIT 고지를 그대로 둔다
- tdd: false — 외부 코드를 원본 테스트와 함께 들이는 일이다. 원본 TS 테스트는 이 레포 verify 밖이다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `test -f skills/statechart/SKILL.md && test -f skills/statechart/LICENSE && test -f skills/statechart/scripts/statechart.ts`
- `grep -q 'disable-model-invocation: true' skills/statechart/SKILL.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-absorb/index.json`의 step 3에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
