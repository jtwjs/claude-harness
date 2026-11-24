# Step 1: split-sdd

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd/SKILL.md`
- `skills/sdd/references/design.md`(이미 있는 references 형식)
- `hooks/test.sh` 케이스 10이 `skills/sdd/SKILL.md`에서 찾는 문구

## 작업

바꾸는 파일:

- `skills/sdd/SKILL.md` · 새 `skills/sdd/references/reflect.md`
- `hooks/test.sh` 케이스 10의 sdd 문구 경로

- `sdd` 본문은 단계 → 스킬 · 체크포인트 표, 트랙 판단, 출구 조건만. REFLECT 상세는 `references/reflect.md`로 옮기고 본문은 `${CLAUDE_PLUGIN_ROOT}/skills/sdd/references/reflect.md` 한 줄(REVIEW §2-3)
- REVIEW 수렴 규칙 중 `sdd-review`와 같은 문장은 `sdd-review`만 남긴다
- `hooks/test.sh` 케이스 10이 `skills/sdd/SKILL.md`에서 찾던 문구가 references로 갔으면 그 줄의 경로만 새 파일로 맞춘다
- tdd: false — 문서 옮기기라 기계 판정할 동작이 없다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `test -f skills/sdd/references/reflect.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-trim/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`는 이 step이 바꾼 경로 · 문구를 따라 **기존 줄을 맞추는 것만** 한다(ADR-016 「대가」 Q3 예외). 새 케이스를 넣지 않는다 — 새 테스트는 `hooks/tests/*.sh`.
- push · PR 금지(러너 밖에서 사람이 한다).
