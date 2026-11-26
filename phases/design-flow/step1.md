# Step 1: role-boundary

## 읽어야 할 파일

- `docs/design-phase-2026-11-26/ADR.md` — ADR-022 전체, 특히 「D6 지휘 역할과 설계 담당 경계」(결정 1~4 · 역할 표) · 「구현 이슈 분해」 J0 행 · 「#82 계획 때 정한 것」. 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `docs/principles/write-for-agents.md`(바꾸는 글이 에이전트가 읽는 스킬 문장이다)
- 바꾸는 파일 넷: `skills/conductor/SKILL.md` · `skills/conductor/references/seat.md` · `skills/conductor/references/decisions.md` · `skills/conductor/references/dispatch.md`

## 의도

- 채우는 끝 기준: 이슈 #82 단계 1(J0 역할 경계) — 「설계 문서(PRD · ARCHITECTURE · ADR 중 해당하는 것)가 확정됐을 때만」 grep 0 · 역할 표가 한 곳. 이유: ADR-022 D6이 「설계 결정은 지휘 한 곳, 문서 초안 · 코드 조사는 코드 옆」으로 경계를 바꿨는데 지휘 문서는 아직 「설계 문서 확정 뒤 디스패치」라서, 뒤 step(설계서 흐름 · Inbox)이 올라설 역할 문장이 먼저 맞아야 한다

## 작업

`tdd: false` — 스킬 · 문서 문장만 바꾸는 step이라 먼저 쓸 테스트 대상 동작이 없다(문서 면제). 끝은 아래 grep AC가 판정한다.

1. `skills/conductor/SKILL.md` 「지휘 원칙」의 「**설계는 지휘에서 끝내고 맡긴다.** …」 줄(지금 15행)을 D6으로 바꾼다: 설계 결정은 지휘에서 사용자와 정하고, 문서 초안 · 코드 조사는 코드 옆(트랙 세션)에서 한다. 관문 둘 — 디스패치는 설계서 최종본 뒤, 구현 시작(계획 쪼개기 포함)은 구조 · 기술 결정 「정할 것」 0일 때(§1). 역할은 `seat.md` 「세 자리 역할」 표를 가리킨다. 🔴 SKILL.md에는 날짜(20YY-MM) · 버전(N.N.N) 숫자를 쓰지 않는다(`hooks/tests/no-history-flow.sh`가 잡는다)
2. `skills/conductor/references/seat.md` 「세 자리 역할」 표를 역할 표의 **정본 한 곳**으로 고친다. 머리 괄호에 ADR-022 D6을 더한다(ADR-014를 좁힘).
   - 지휘 행: 하는 일 = 사용자와 설계서(사람이 읽고 고치는 설계 문서 한 장)를 쓴다 · 디스패치 · 우선순위 · 사용자 질문 모으기(§1 판정 거르기) · 결정 기록 · ADR 번호 · 관문 둘 · 트랙 보고 확인 · 세션 간 중계 · 개인 기록 넘기기. 안 하는 일 = 레포 문서(PRD · ARCHITECTURE · ADR) 쓰기 · 코드 깊게 읽기 · 설계서 최종본 전 디스패치 · 코드 고치기
   - 작업(트랙 세션) 행: 설계서 최종본으로 레포 문서(PRD · ARCHITECTURE · ADR)를 쓴다(나눔 모드는 검증 세션). 그 안의 결정은 혼자 정하지 않고 파일:줄 근거를 붙인 결정 묶음으로 지휘에 올린다. 코드 사실 조사 · 지시문대로 코드 고치기는 그대로
   - desk 행 · 판정함 문구는 **이 step에서 건드리지 않는다**(step 5가 바꾼다)
   - ADR-022 D6 표의 「옮김(지휘 재설계 뒤) — 감독 · 확인 모음」 행은 아직 안 옮긴 것이라 넣지 않는다
3. `skills/conductor/references/decisions.md` §1:
   - 머리 문단(지금 7행)을 D6으로: 설계 결정은 지휘에서 사용자와 정하고, 문서 초안 · 코드 조사는 코드 옆에서(ADR-022 D6 — ADR-014를 좁힘). 역할은 `seat.md` 「세 자리 역할」 표 한 곳을 가리키고 여기서 역할을 다시 나열하지 않는다. 「작업 중 새 설계 질문이 생기면 지휘에 보고」는 남긴다(판정함 문구는 step 5 몫이라 그대로 둔다)
   - 「디스패치 관문」 줄(지금 9행) → 「관문 둘」: ① 디스패치 = 결정 이슈 「정할 것」 0 · 설계서 최종본 ② 구현 시작(계획 쪼개기 포함) = 구조 · 기술 결정 「정할 것」 0. 둘째 관문은 지금 글이고, 장치(러너가 멈춤)는 러너 쪽 이슈 #83이 맡는다고 한 구절
   - 새 줄 「결정 묶음 받기」: 트랙(검증 세션)이 레포 문서를 쓰다 결정이 나오면 결정 묶음으로 올린다 → 지휘가 설계서 「결정」 칸에 넣고 사용자에게 → 사용자 답을 트랙에 회신. 지휘는 코드를 깊게 읽지 않는다(「코드 사실」 줄과 이어짐). 꼴은 `${CLAUDE_PLUGIN_ROOT}/skills/sdd/references/design.md` 「설계서」 절을 가리킨다(그 절은 step 2 · 3이 만든다 — 링크만 둔다)
   - 「설계 초안 받기」 줄 · 「PRD는 지휘가 쓴다」 줄 · 결정 이슈 틀 · `desk.py picks` 줄은 **건드리지 않는다**(step 2 · 5 몫)
4. `skills/conductor/references/dispatch.md` 7행 「보내기 전 관문(§1)」: 「설계 문서 확정」 → 「설계서 최종본」
5. 「디스패치 관문」이라는 이름을 다른 곳(`SKILL.md` 상황 표 · 결정 이슈 틀 주석 · `templates/.claude/references/track-brief.md`)에서 가리키면 새 이름 「관문 둘」과 맞춘다. `templates/.claude/references/track-brief.md`는 이 이름을 가리키는 줄만 고친다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `! git grep -n -F '설계 문서(PRD · ARCHITECTURE · ADR 중 해당하는 것)가 확정됐을 때만' -- skills templates agents`
- `! git grep -n -E '설계 문서 확정|설계 문서가 확정' -- skills/conductor templates`
- `[ "$(git grep -n -F '| 자리 | 하는 일' -- skills | wc -l)" -eq 1 ]` (역할 표가 한 곳)
- `! git grep -n -F '디스패치 관문' -- skills templates`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-022 D6 결정 1~4와 대조한다: 관문 둘 · 결정 묶음 경유 · 지휘는 코드를 깊게 읽지 않음이 다 들어갔나.
3. 결과를 `phases/design-flow/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 이름 · 경로를 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `skills/sdd-run/**` · `docs/sdd-runner.md` · `skills/sdd-plan/**`는 옆 트랙 소유라 고치지 않는다. 고쳐야 하면 blocked.
- 공개 레포다: 사람 · 회사 이름 · 개인 경로 · 개인 저장소 이름을 쓰지 않는다(「사용자」 · 「개인 기록」으로).
- 같은 문장을 두 곳에 쓰지 않는다. 다른 곳은 정본을 가리킨다.
- push · PR 금지.
