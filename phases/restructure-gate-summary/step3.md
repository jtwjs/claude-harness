# Step 3: learning-card-only

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `docs/learning-level.md`
- `hooks/learn-setup.sh` · `hooks/hooks.json`
- `hooks/test.sh` 케이스 6-b(learn-setup) · 훅 목록 줄 · 맨 위 learn 관련 env 줄
- `skills/explain-diff/SKILL.md` Quiz 줄

## 작업

바꾸는 파일:

- `docs/learning-level.md`
- `hooks/learn-setup.sh` 삭제 · `hooks/hooks.json`
- `skills/explain-diff/SKILL.md` · `skills/sdd/references/design.md` · `skills/harness-init/SKILL.md` · `skills/pr-write/SKILL.md`의 `_learn` 언급
- `hooks/test.sh` 케이스 6-b · 케이스 1 훅 목록의 `learn-setup`(ADR-016 Q7)

- `docs/learning-level.md`는 학습 카드 형식만 남긴다(퀴즈 · 게이트 판정 · 빈틈 3곳 절 삭제, ADR-016 D-gate)
- `learn-setup.sh`의 `_learn/` 생성 · 기록 지시를 걷는다(ADR-016 Q4). 그 훅이 하는 일이 그것뿐이라 훅을 지우고 `hooks.json`에서 뺀다
- 스킬의 `_learn/` 기록 지시를 지운다. `scripts/daily-hub/daily_hub.py`의 기존 `_learn` 읽기 · `validate-session-end.sh`의 `_learn/*` 제외는 그대로 둔다(이미 있는 파일을 보기만 한다)
- `explain-diff`의 Quiz 줄을 지운다
- `docs/learning-level.md`에서 절을 지우거나 번호가 바뀌면, 그 절을 가리키는 스킬 문장(예: `skills/sdd/SKILL.md` ⑤ 마무리 「이해 증명」 리허설 줄이 §5의 3·4를 가리킨다)을 남는 절로 맞춘다. 가리킬 곳이 없어지면 그 참조를 지운다
- `hooks/test.sh`에서 지우는 것은 두 곳뿐이다(ADR-016 「대가」 Q7 예외): ① 「`# ── 케이스 6-b: learn-setup — 개인 학습 수신함 _learn/`」 머리줄부터 `ok "워크트리를 지워도 카드가 남는다"`가 있는 줄까지(eca41a4 기준 407~461번 줄, 바로 뒤 빈 줄 하나 포함) ② 케이스 1의 훅 목록 줄 `for h in auto-format tdd-guard … learn-setup prod-db-check; do`에서 `learn-setup` 한 단어. 맨 위 `CLAUDE_LEARN_SKIP` · `CLAUDE_LEARNING_LEVEL_FILE` · `CLAUDE_LEARN_REPOS` export 줄은 테스트가 아니라 실제 `~/.claude`에 쓰지 않게 막는 줄이라 그대로 둔다
- tdd: false — 문서 줄이기와 훅 삭제다. 삭제한 동작은 RED로 판정할 대상이 없다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `test ! -e hooks/learn-setup.sh && ! grep -q learn-setup hooks/hooks.json`
- `git grep -n '_learn/' -- skills` 출력 0줄

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-gate-summary/index.json`의 step 3에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`는 작업 절에 적은 두 곳만 지운다(ADR-016 「대가」 Q7 예외). 그 밖의 줄은 고치지 않고 새 케이스를 넣지 않는다 — 새 테스트는 `hooks/tests/*.sh`.
- push · PR 금지(러너 밖에서 사람이 한다).
