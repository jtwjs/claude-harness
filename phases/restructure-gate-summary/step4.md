# Step 4: conductor-report-format

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/conductor/SKILL.md` 보고 · 판정 절
- `templates/.claude/references/track-brief.md` 「끝나면 지휘에 보고」 절

## 작업

바꾸는 파일:

- `skills/conductor/SKILL.md` · `templates/.claude/references/track-brief.md`

- 트랙 보고 형식 = 세 줄 요약(무엇 · 왜 · 위험/직접 확인할 것) + 학습 카드(ADR-016 D-요약 · D-gate)
- 지휘가 사용자에게 올리는 현황은 recall 출력 계약: 요약 ≤5 · 상태 태그 · 반복 문제 ≤5 · 다음 수 1(ADR-016 D13)
- tdd: false — 보고 형식 문장 바꾸기라 기계 판정할 동작이 없다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `grep -q '세 줄 요약' skills/conductor/SKILL.md && grep -q '세 줄 요약' templates/.claude/references/track-brief.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-gate-summary/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
