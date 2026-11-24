# Step 9: entry-and-stage-invocation

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- ARCHITECTURE §2 표(정본)

## 작업

바꾸는 파일:

- ARCHITECTURE §2의 단계 · 슬래시 입구 스킬 `SKILL.md` frontmatter

- 자동 입구 8개(`sdd` · `why` · `how` · `conductor` · `slack-writing` · `notion-writing` · `commit` · `pr-write`)만 모델 호출을 열어 둔다. 나머지는 `disable-model-invocation: true`(ADR-016 D0 · Q1 · Q2)
- 입구가 단계 스킬을 부르는 문장이 `${CLAUDE_PLUGIN_ROOT}/skills/<이름>/SKILL.md` 경로로 돼 있는지 확인하고, Skill 도구 호출로 돼 있으면 경로로 바꾼다
- tdd: false — frontmatter 한 줄씩이다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `for f in skills/*/SKILL.md; do n=$(basename $(dirname $f)); grep -q 'disable-model-invocation: true' $f && echo human:$n || echo auto:$n; done | grep -c '^auto:'`이 8

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-trim/index.json`의 step 9에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
