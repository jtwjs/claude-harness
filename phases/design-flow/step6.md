# Step 6: question-rounds

## 읽어야 할 파일

- `docs/design-phase-2026-11-26/ADR.md` — ADR-022 「D1 질문 방식」(결정: A 라운드 + 막는 장치 셋 · 이유 체인 · 버린 안 · 측정) · 「구현 이슈 분해」 J1 행 · 「#82 계획 때 정한 것」(범위 밖 세 줄). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `docs/principles/write-for-agents.md` 4번(늘 실리는 글은 더 깎는다 · `scripts/always-on.py`)
- 바꾸는 파일: `docs/principles/ask-questions.md` · `skills/sdd/references/design.md` · `skills/design-brief/SKILL.md` · `skills/design-critique/SKILL.md`(52행 한 줄만) · `hooks/test.sh`(541행 한 줄만)
- `hooks/test.sh` 케이스 10(530~550행 근처)의 `for need in …` 줄 — 원칙 문서에 있어야 할 표식을 찾는 꼴

## 의도

- 채우는 끝 기준: 이슈 #82 단계 6(J1 질문 규칙) — 「한 번에 한 질문」 · 「3개까지」 grep 0 · 이유 칸 · 새 갈래 찾기 · 물러서는 조건 세 줄이 원칙 한 곳에만. 이유: ADR-022 D1이 ADR-017 D7(한 번에 한 질문 + 독립 질문 3개까지)을 라운드로 대체했다. 라운드의 약점(이유에서 새 결정이 안 나옴 · 다 끄덕이기)은 막는 장치 셋으로 받는다

## 작업

테스트 먼저(tdd):

1. **테스트 커밋** — `hooks/test.sh` 541행의 표식 `'한 번에 한 질문:docs/principles/ask-questions.md'` 를 `'물러서는 조건:docs/principles/ask-questions.md'` 로 바꾼다. 이 한 토큰만 바꾸고 541행의 다른 표식 · 다른 줄은 건드리지 않는다(이 파일은 옆 트랙도 고친다). 이 시점에 `bash hooks/test.sh`는 실패해야 한다(원칙 문서에 「물러서는 조건」이 아직 없다). 커밋 메시지 `test: step 6 — question-rounds (red)`

구현:

2. `docs/principles/ask-questions.md` 5행 「**한 번에 한 질문이 기본이다.** …」를 라운드 규칙으로 바꾼다(ADR-022 D1 「결정: A」):
   - **라운드가 기본이다.** 앞선 결정이 끝난 질문(서로 기대지 않는 질문)을 한 라운드에 묻는다. 다른 답에 기대는 질문은 다음 라운드로. 설계서가 있으면 재검토의 번호 질문이 한 라운드, 결정 묶음 하나가 한 라운드다
   - 막는 장치 셋을 하위 불렛으로(이 셋은 **이 파일에만** 둔다):
     1. 이유 칸 — 질문마다 답 칸에 「선택 + 이유 한 줄(있으면)」. 채팅은 `1 B — 이유`, 화면 도구는 메모 칸
     2. 새 갈래 찾기 — 다음 라운드를 짜기 전에 받은 이유에서 표에 없던 결정을 찾아 넣는다
     3. 물러서는 조건 — 라운드에서 답 없이 지나간 질문이 2번 나오거나, 설계 결정이 이유 없이 전부 추천 수용으로 끝난 라운드가 2번 이어지면 남은 설계 결정은 하나씩 묻는다. 사람이 「하나씩」이라고 하면 바로 하나씩. 이 줄에 「물러서는 조건」 글자가 들어가게 쓴다(테스트가 찾는다)
   - 「설계 결정은 질문마다 선택을 따로 받는다」는 남긴다
   - 「한 번에 한 질문」 · 「3개까지」 글자는 남기지 않는다
3. `skills/sdd/references/design.md`:
   - 5행 「— 그래서 왜부터 묻고, 한 번에 하나씩 묻는다.」 → 「— 그래서 왜부터 묻고, 질문 규칙대로 라운드로 묻는다.」 같은 꼴(규칙 자체는 다시 적지 않는다)
   - 렌즈 점검 줄 「그중 결정이 필요한 것만 질문 규칙대로 하나씩 묻는다」 → 「… 질문 규칙대로 묻는다」
4. `skills/design-brief/SKILL.md`:
   - description 「상태·권한·데이터 결정을 한 질문씩 끝낸 뒤」 → 「상태·권한·데이터 결정을 질문 규칙대로 끝낸 뒤」 같은 꼴. description 길이를 늘리지 않는다
   - 본문 §2는 이미 원칙 문서를 가리키니, 「하나씩」 · 「한 질문씩」 낱말이 남아 있으면 같은 꼴로 고친다. 94행 「스타일 파일은 한 번에 하나만」은 질문 규칙이 아니라 그대로 둔다
   - 🔴 SKILL.md에 날짜 · 버전 숫자를 쓰지 않는다
5. `skills/design-critique/SKILL.md` 52행 「사람에게 **한 질문씩**, 추천 답과 함께. 회차당 **5개까지** …」 → 「사람에게 질문 규칙대로 라운드로, 추천 답과 함께. 회차당 **5개까지** …」(5개 상한 · 질문 피로 이유는 그대로). 이 파일의 다른 줄은 고치지 않는다
6. 상시 비용 대조(ADR-016): 바꾸기 전과 뒤에 `python3 scripts/always-on.py .`의 `total` 줄을 재서 summary에 둘 다 적는다. 바꾸기 전 값은 2150(계획 때 잼). `design-brief`는 사람만 부르는 스킬(`disable-model-invocation: true`)이라 이 합계에 안 잡히는 것이 예상이다 — 다르게 나오면 그대로 적는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `! git grep -n -E '한 번에 한 질문|3개까지' -- skills agents docs/principles templates`
- `[ "$(git grep -n -F '물러서는 조건' -- skills docs/principles templates | wc -l)" -eq 1 ]` (장치 줄이 원칙 한 곳)
- `! git grep -n -E '한 질문씩|하나씩 묻는다' -- skills/sdd skills/design-brief skills/design-critique`
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `물러서는 조건:docs/principles/ask-questions.md`
  - 비정상 입력: 해당 없음: 입력을 받는 코드가 아니라 원칙 문서의 표식 검사다
  - 실패 경로: 해당 없음: 표식이 없을 때 실패하는 경로는 케이스 10의 기존 `bad` 분기가 이미 맡는다
  - 상태 전이: 해당 없음: 상태가 없는 문서 검사다
  - 동시성: 해당 없음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-022 D1 막는 장치 셋이 `ask-questions.md` 한 곳에만 있고, 다른 파일은 원칙 문서를 가리키기만 하는지 대조한다.
3. 결과를 `phases/design-flow/index.json`의 step 6에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄 + 상시 비용 전후 `python3 scripts/always-on.py .` total 값. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 금지. **테스트 파일은 1번 테스트 커밋에서 541행 한 토큰만** 바꾸고, 구현 커밋에서는 건드리지 않는다.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `skills/sdd-run/**` · `docs/sdd-runner.md` · `skills/sdd-plan/**`는 옆 트랙 소유라 고치지 않는다. 고쳐야 하면 blocked.
- 유료 실행(eval 등)을 돌리지 않는다.
- 공개 레포다: 사람 · 회사 이름 · 개인 경로 · 개인 저장소 이름을 쓰지 않는다.
- 같은 문장을 두 곳에 쓰지 않는다. 다른 곳은 정본을 가리킨다.
- push · PR 금지.
