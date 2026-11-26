# Step 5: answer-inbox

## 읽어야 할 파일

- `docs/design-phase-2026-11-26/ADR.md` — ADR-022 「D5」 P6 행 · 「P6 결정: B Inbox + 조건 둘」 · 「D3」 「지휘 세션 구성에 미치는 영향」 줄 · 「구현 이슈 분해」 J4 행 · 「#82 계획 때 정한 것」. 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- 이슈 #82 본문 단계 5(J4) — `gh issue view 82 -R jtwjs/claude-harness`
- `docs/principles/write-for-agents.md`
- 바꾸는 파일: `skills/conductor/references/decisions.md` · `skills/conductor/references/seat.md` · `skills/conductor/SKILL.md` · `skills/conductor/references/doorbell.md` · `templates/.claude/references/track-brief.md`(37행 한 줄만, 지휘 경로 예외 승인)

## 의도

- 채우는 끝 기준: 이슈 #82 단계 5(J4 답하는 한 곳 = Inbox) — 지휘 문서에 판정함 확인 지시 grep 0 · 도구 이름이 흐름 문장 한 곳. 「첫 Inbox 질문에서 답이 그 턴에 결정 이슈로 옮겨진 기록 1건」은 실제 사용 때만 잴 수 있어 이 step 밖이다. 이유: 판정함 도구는 다시 설계(v2) 전까지 없는 것으로 본다(사용자). 사용자가 답하는 한 곳을 설계서 화면과 같은 도구의 Inbox로 모은다

## 작업

`tdd: false` — 스킬 · 문서 문장만 바꾸는 step이라 먼저 쓸 테스트 대상 동작이 없다(문서 면제). 끝은 아래 grep AC가 판정한다.

1. `decisions.md` §1:
   - 「**턴 시작마다** … `desk.py picks` …」 줄 → 「**사용자에게 가는 고르기 질문은 한 곳으로 보내고, 답은 그 턴에 결정 이슈 · ADR로 옮긴다**」(정본 문장, ADR-022 P6 「도구 자리」 줄). 조건 둘을 붙인다: ① 답을 받은 그 턴에 결정 이슈 · ADR(주체 · 이유)과 개인 기록으로 옮긴다. 결정 정본은 한 곳(도구)이 아니라 결정 이슈 · ADR이다. PR이 걸린 결정은 도구의 결정 내보내기로 PR에 남긴다 ② 보낼 때마다 지휘 탭에도 「Inbox에 질문 n개」 한 줄을 남긴다(알림이 사용자에게 뜨는지 아직 모른다). 한 곳에는 지휘만 쓴다 — 트랙은 지휘에 묻는다. 권한 확인 창(머지 등)은 지휘 탭에 남는다. 설계서가 걸린 질문은 설계서 화면으로(`design.md` 「설계서」 절), 문서 없는 짧은 고르기만 한 곳으로 간다
   - **도구 이름은 이 묶음의 한 줄에만**: 「지금 한 곳은 `plannotator` Inbox(질문 블록 · 막지 않음 · `export-decisions`로 PR에 결정 남기기). 판정함 도구 v2가 오면 이 줄만 되돌린다」 같은 꼴
   - 「작업 중 새 설계 질문이 생기면 작업 세션은 판정함이 아니라 지휘에 보고」(머리 문단) → 「판정함」을 지우고 「사용자에게 직접 묻지 않고 지휘에 보고」로
   - 「판정 거르기」 표: 「지휘가 정함」 칸 「판정함에는 「AI가 정함 + 근거 경로」로만 남긴다(`aiDecided`) … 반려(`aiRejected`)」 → 「결정 이슈에 「AI가 정함 + 근거 경로」로 남긴다. 사용자는 보기만 하고, 아니면 반려한다」. 「사용자에게 올림」 칸 「판정함에 올린다」 → 「한 곳으로 보낸다(위 줄)」
2. `seat.md`:
   - 「세 자리 역할」 표의 desk 행 → 「한 곳(사용자가 답하는 자리)」 행: 지휘가 보낸 고르기 질문 · 설계서를 읽고 답한다 / 사용자가 고른다 / 코드 · 이슈를 직접 만지지 않는다 / 상태 자리: 결정 이슈 · ADR(도구는 `decisions.md` §1 한 곳 줄이 가리킴). 지휘 행 「사용자에게 물을 것은 판정함에 올린다」 → 「한 곳으로 보낸다(§1)」. 작업 행 「판정함에 직접 올리기」 → 「사용자에게 직접 묻기(한 곳 포함)」
   - 머리 괄호 「ADR-012 「판정함 직행」 대체」는 이력이라 그대로 둬도 되고, 「판정함」 글자를 지우려면 「ADR-012 대체」로 줄인다(AC가 `판정함` grep 0이므로 지운다)
   - 표 아래 「판정함 질문 형식(… `decision-inbox` 스킬이 정본 …)」 줄 → 「질문 형식은 `${CLAUDE_PLUGIN_ROOT}/docs/principles/ask-questions.md`, 보내는 곳은 `decisions.md` §1 한 곳 줄」로
   - §0 준비 목록에 한 줄: 한 곳 도구가 Claude Code 전역 규칙에 넣는 안내 노트(모든 세션에 「사용자에게 바로 물어라」를 넣는 것)가 켜져 있으면 끄라고 사용자에게 알린다 — 켜 두면 트랙이 지휘를 거치지 않고 사용자에게 묻는다. 지휘는 전역 설정을 직접 고치지 않는다. 이 줄에는 도구 이름을 쓰지 않는다(「한 곳 도구」)
3. `skills/conductor/SKILL.md` 상황 표 「desk / 지휘 / 작업 역할」 → 「한 곳 / 지휘 / 작업 역할」. 🔴 날짜 · 버전 숫자를 쓰지 않는다
4. `doorbell.md` 표 「판정함에 직접 올리지 않는다」 → 「사용자에게 직접 묻지 않는다」
5. `templates/.claude/references/track-brief.md` 37행 「판정함에 직접 올리지 않는다」 → 「사용자에게 직접 묻지 않는다」. 이 파일의 다른 줄은 고치지 않는다(step 1이 바꾼 관문 이름 줄은 예외로 이미 고쳐져 있을 수 있다)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `! git grep -n -E '판정함|desk\.py|aiDecided|aiRejected' -- skills/conductor templates`
- `[ "$(grep -c 'plannotator' skills/conductor/references/decisions.md)" -eq 1 ]`
- `grep -q 'Inbox에 질문 n개' skills/conductor/references/decisions.md`
- `! git grep -n -F 'plannotator' -- skills/conductor/references/seat.md skills/conductor/SKILL.md skills/conductor/references/doorbell.md templates`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-022 P6 조건 1 · 2 · 「남는 것」(권한 확인 창) · 「Inbox는 지휘만」이 다 들어갔는지 대조한다.
3. 결과를 `phases/design-flow/index.json`의 step 5에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `skills/sdd-run/**` · `docs/sdd-runner.md` · `skills/sdd-plan/**`는 옆 트랙 소유라 고치지 않는다. 고쳐야 하면 blocked.
- 전역 설정(`~/.claude/**`)을 읽거나 고치지 않는다. Inbox에 실제로 보내지 않는다(문서만 고친다).
- 공개 레포다: 사람 · 회사 이름 · 개인 경로 · 개인 저장소 이름을 쓰지 않는다(「사용자」 · 「개인 기록」으로).
- 같은 문장을 두 곳에 쓰지 않는다. 다른 곳은 정본을 가리킨다.
- push · PR 금지.
