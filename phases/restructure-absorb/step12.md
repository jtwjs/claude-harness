# Step 12: conductor-relay-card

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016 D-요약 · Q8). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/conductor/SKILL.md` §4 「사용자에게 올리는 현황」 단락 · §8 소통 표
- `templates/.claude/references/track-brief.md` 「끝나면 지휘에 보고」(트랙이 보내는 쪽)

## 작업

바꾸는 파일:

- `skills/conductor/SKILL.md`

- §4 「사용자에게 올리는 현황」 단락에 지휘가 받은 트랙 보고를 사용자에게 넘기는 규칙을 더한다(ADR-016 Q8, 사용자 결정):
  - 트랙 보고의 세 줄 요약 · 학습 카드는 사용자 보고에 **그대로** 싣는다. 지휘가 요약하거나 다시 풀어 쓰지 않는다
  - 학습 카드는 사용자의 개인 기록 자리가 있으면(설정이나 사용자가 알려 준 곳) 거기에도 붙인다. 없으면 보고에만 싣는다
  - 카드의 「내 한 줄」은 사용자만 쓴다. 지휘도 트랙도 채우지 않는다
- 공개 레포다. 개인 기록의 실제 경로 · 도구 이름을 적지 않는다(일반 문장으로). `~/.claude/conductor.json`에 새 키를 만들지 않는다 — 설정 형식을 바꿔야 할 것 같으면 멈추고 `blocked`로 보고한다
- 세 줄 요약 · 학습 카드의 형식은 다시 쓰지 않는다. 정본은 `${CLAUDE_PLUGIN_ROOT}/skills/sdd/SKILL.md` ⑤ 마무리(이미 그 단락이 가리킨다)
- §8 소통 표에 행이 필요하면 「지휘 → 사용자」 한 행만 더한다
- tdd: false — 지휘 지시문 한 단락이다. 지시문의 동작은 기계로 RED를 판정할 대상이 없다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `grep -q '그대로' skills/conductor/SKILL.md && grep -q '내 한 줄' skills/conductor/SKILL.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-absorb/index.json`의 step 12에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
