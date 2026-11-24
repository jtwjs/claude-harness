# Step 2: review-proof-rules

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-review/SKILL.md`
- `agents/code-reviewer.md`
- PStack 9e278fe `interrogate` · `blast-radius`(참고만)

## 작업

바꾸는 파일:

- `skills/sdd-review/SKILL.md` · `agents/code-reviewer.md`

- 두 파일에 규칙(ADR-016 D7): 지적마다 돌린 명령 · 출력을 단다. 못 돌린 지적은 「확인 필요」로 강등. 리뷰 전에 의도(PRD · 이 변경의 목적)를 한 줄로 되비춘다. 확신 5단계(말만 → 줄 지목 → 못 일어남을 보임 → 돌림 → 앱에서 재현)
- tdd: false — 리뷰 지시문 규칙이라 기계 판정할 동작이 없다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `grep -q '확인 필요' skills/sdd-review/SKILL.md && grep -q '확인 필요' agents/code-reviewer.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-absorb/index.json`의 step 2에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
