# Step 4: remove-rehearsal

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- 이슈 #40 D-gate 원문(`gh issue view 40 -R jtwjs/claude-harness`) — 「퀴즈 · 리허설은 나중 학습 흐름으로.」
- `skills/sdd/references/reflect.md` · `skills/sdd/SKILL.md` · `skills/harness-gaps/SKILL.md` · `skills/sdd/references/design.md`

## 작업

바꾸는 파일:

- `skills/sdd/references/reflect.md` · `skills/sdd/SKILL.md` · `skills/harness-gaps/SKILL.md` · `skills/sdd/references/design.md`
- `docs/harness-restructure-2026-11-24/ADR.md`(D-gate 행 한 곳)

D-gate(#40 원문)는 「퀴즈 · 리허설은 나중 학습 흐름으로」인데 ADR.md D-gate 행이 이 구절을 옮겨 적지 않아 PR 3 계획이 리허설을 남겼다(지휘 판정 · 사용자 결정 불필요 — D-gate 범위). 걷는다:

- `reflect.md`: 1행 제목의 「→ 이해 증명」 · §4 「이해 증명 🎤」 절 전체
- `sdd/SKILL.md`: 12행 코어 트랙 요약의 이해 증명 · 리허설 언급 · 38행 REFLECT 칸 「🎤 설명 리허설」
- `harness-gaps/SKILL.md`: 92행 순서 괄호의 「→ 이해 증명」
- `design.md`: 73행 끝 구절 「— 후자가 많으면 그 결정들이 리허설 대상이다」만. **「결정 주체」 칸은 남긴다**(「내가 고른 것 / 추천받은 것」을 가르는 용도는 리허설 없이도 쓰인다)
- 지운 뒤 `git grep -n '리허설\|이해 증명\|🎤' -- skills agents hooks templates` 0줄(README는 step 2가 이미 다시 썼다)
- ADR.md D-gate 행(지휘 지시 — 새 결정이 아니라 #40 원문에서 옮겨 적다 빠진 구절을 되돌리는 것이라 「쌓기만 하는 기록」 대상이 아니다): 그 행 결정 칸에 #40 원문 구절 「퀴즈 · 리허설은 나중 학습 흐름으로.」를 원문 그대로 넣고, 그 칸 끝에 `(#40 원문에서 빠진 구절 복원)`. 다른 행 · 문장은 건드리지 않는다
- tdd: false — 지시문 절을 걷는 일이다(리허설 문구를 검사하는 테스트는 0곳, 확인함)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `! git grep -q '리허설\|이해 증명\|🎤' -- skills agents hooks templates && grep -q '#40 원문에서 빠진 구절 복원' docs/harness-restructure-2026-11-24/ADR.md && grep -q '결정 주체' skills/sdd/references/design.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-readme/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
