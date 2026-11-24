# Step 8: how-skill

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- PStack 9e278fe `pstack/skills/how/SKILL.md`
- `skills/why/SKILL.md` description
- `docs/harness-restructure-2026-11-24/trigger-eval/README.md` · `evals.json`(문항 형식)

## 작업

바꾸는 파일:

- 새 `skills/how/SKILL.md`
- `docs/harness-restructure-2026-11-24/trigger-eval/evals.json`(`how` 20문항)

- `how`: 자동 입구, 읽기 전용(`allowed-tools`에 쓰기 도구 없음). description은 「코드가 어떻게 도나 · 어느 레이어에 두나」로 `why`(이유 · 근거)와 갈리게(ADR-016 Q2). diff 없이도 쓴다
- 입구 공통 줄: 「판단 전에 `${CLAUDE_PLUGIN_ROOT}/docs/principles/INDEX.md`」 · 보고 「쓴 원칙 · 바뀐 결정」
- `evals.json`에 `how` 20문항(떠야 할 말 10 · 안 떠야 할 말 10). 안 떠야 할 말에 why형 질문 · 단순 검색 질문을 넣는다(ADR-016 Q2)
- tdd: false — 새 지시문과 측정 문항이다. 발동은 restructure-readme의 After 측정이 잰다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `test -f skills/how/SKILL.md && ! grep -q 'disable-model-invocation: true' skills/how/SKILL.md`
- `python3 -c "import json; e=json.load(open('docs/harness-restructure-2026-11-24/trigger-eval/evals.json')); assert len(e['how'])==20"`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-absorb/index.json`의 step 8에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
