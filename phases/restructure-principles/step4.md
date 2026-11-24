# Step 4: principles-write-for-readers

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/slack-writing/SKILL.md` · `skills/notion-writing/SKILL.md`(겹치는 규칙: 지어내지 않음 · 해석 문장 · em dash · 12살 설명 · AI 티)
- `docs/principles/INDEX.md`(step 3)

## 작업

바꾸는 파일:

- 새 `docs/principles/write-for-readers.md` · `docs/principles/INDEX.md` 행
- `skills/slack-writing/SKILL.md` · `skills/notion-writing/SKILL.md`

- 두 스킬이 같이 쓰는 규칙을 `write-for-readers.md`로 옮기고 규칙마다 번호를 붙인다(다른 스킬이 번호로 인용). 형식별 규칙(슬랙 1~2줄 · 노션 유형표)은 각 스킬에 남긴다
- 두 스킬은 `${CLAUDE_PLUGIN_ROOT}/docs/principles/write-for-readers.md`를 가리킨다
- 두 스킬 절차의 마지막 단계에 「밖으로 내기 전 출처 점검」(숫자 · 인용마다 출처가 있는지, 개인 노트 경로 · 내부 경로가 섞이지 않았는지)을 더한다(ADR-016 D13)
- tdd: false — 두 스킬의 공용 문장을 옮기는 일이다. INDEX ↔ 파일 대응은 step 3 테스트가 본다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `test -f docs/principles/write-for-readers.md`
- `grep -c 'write-for-readers.md' skills/slack-writing/SKILL.md skills/notion-writing/SKILL.md`가 둘 다 1 이상

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-principles/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
