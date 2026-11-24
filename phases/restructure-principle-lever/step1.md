# Step 1: principle-build-the-lever

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- ADR-016 D-lever 행(값의 정본, 복사하지 말고 따른다)
- PStack 9e278fe `principle-build-the-lever` · `principle-encode-lessons-in-structure`(`gh api … ?ref=9e278fe`)
- `skills/harness-gaps/SKILL.md` 판정 문턱 문장

## 작업

바꾸는 파일:

- 새 `docs/principles/build-the-lever.md` · `docs/principles/INDEX.md` 행
- `skills/harness-gaps/SKILL.md`

- 한 파일에 두 원칙을 절로 나눠 쓴다: `build-the-lever`(사소하지 않은 일이면 도구 — 결과물이 분명할 때 만들고 모호하면 반복 관찰을 기다린다)와 `encode-lessons-in-structure`(같은 지시의 반복은 구조로). 문턱 값은 ADR-016 D-lever를 따른다
- `harness-gaps`의 판정 문턱 문장을 ADR-016 D-lever에 맞춘다(두 번째는 「후보」 표시만, 승격 후보는 지금처럼)
- 파일 끝 출처 한 줄(PStack MIT)
- tdd: false — 새 문서 한 장과 문장 한 줄이다. INDEX ↔ 파일 대응은 restructure-principles step 3 테스트가 본다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `test -f docs/principles/build-the-lever.md && grep -q build-the-lever docs/principles/INDEX.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-principle-lever/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
