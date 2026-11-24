# Step 1: sdd-drop-gap3-add-summary

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd/SKILL.md`(🙋 빈틈 3곳 · 「내 한 줄」 · 마무리 · 재개 절)
- `hooks/test.sh` 케이스 10이 `skills/sdd/SKILL.md`에서 찾는 문구 목록(지우지 않는다)

## 작업

바꾸는 파일:

- `skills/sdd/SKILL.md`
- 새 `hooks/tests/no-gate-sdd.sh`

- 테스트 먼저(`hooks/tests/no-gate-sdd.sh`): `skills/sdd/SKILL.md`에 `빈틈 3곳` · 「내 한 줄」 잠금 문구가 없고, `세 줄 요약`과 학습 카드 · recall 출력 계약(`다음 수`) 문구가 있다. 새 테스트 파일은 `hooks/tests/no-brain.sh`처럼 `hooks/test.sh`가 source 하는 조각이다: `printf '\n[이름] …\n'`로 시작, `$HOOKS` · `$TMP` · `ok` · `bad`를 그대로 쓰고 변수는 파일 고유 접두사(`_xx_`)를 붙인다
- 막는 관문을 지운다: 🙋 빈틈 3곳 체크포인트, 「내 한 줄」 잠금(ADR-016 D-gate)
- 마무리(SHIP): PR 전에 터미널에 세 줄 요약(무엇 · 왜 · 위험/직접 확인할 것). 입력을 받지 않는다. 같은 세 줄을 PR 본문 첫머리 · 학습 카드 「작업 요약」 · 지휘 보고가 쓴다(ADR-016 D-요약)
- 작업 끝 보고에 학습 카드(작업 요약 · 목적 · 개념/키워드(beginner 기술 카드 형식, `${CLAUDE_PLUGIN_ROOT}/docs/learning-level.md`) · 새로 알게 된 것 · 선택: 내 한 줄). 레포에 쓰지 않는다. 카드 재료는 `${CLAUDE_PLUGIN_ROOT}/skills/explain-diff/SKILL.md`를 경로로 읽어 얻는다(restructure-absorb에서 `explain`으로 바뀐다)
- 재개 절에 recall 출력 계약: 요약 ≤5 · 상태 태그 · 반복 문제 ≤5 · 다음 수 1(ADR-016 D13)
- `hooks/test.sh` 케이스 10이 찾는 문구(`회고 1장 새 파일` · `출구 조건` · `REFLECT 건너뜀` · `마무리(SHIP)` · `docs/retro/YYYY-MM-DD` · `최신이 위` · `지식 정리`)는 지우지 않는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `bash hooks/test.sh 2>&1 | grep -F '[no-gate-sdd]'` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-gate-summary/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
