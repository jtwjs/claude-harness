# Step 4: docs-align

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 R1 · R3와 「갱신」 줄
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- 이슈 #86 본문(`gh issue view 86`) — 이 step이 맡는 행
- `docs/sdd-runner.md` — rejudge · 구현 시작 관문 항목 · 검증 상태 개수
- `skills/sdd/references/design.md` — ADR.md 정의 줄 · `templates/.claude/references/track-brief.md` 「진행 방식」 · `skills/sdd-run/SKILL.md` §2 2번 · `.claude/harness.json`

## 의도

- 채우는 수용 조건: #86 F5 · F6 문서 · G1 · G2 · G3 · step 1~3 결과를 문서에

## 작업

- F5: `design.md` ADR.md 정의에 「결정할 것」 표(정할 것 · 선택지 · 추천 · 주체) — R1이 세는 칸 이름과 같게
- F6: `docs/sdd-runner.md` rejudge 「약하게 고쳐 통과시키는 것을 막는다」를 실제 범위(BASE에서 스위트 단위로 실패하는지만 본다)로 · 검증 상태 테스트 개수를 실제 값으로 · F1 · F2 · F3 · F4 반영 · 남는 못 막는 갈래를 「장치로 못 막는 갈래」에
- 「장치로 못 막는 갈래」에 step 3 뒤에도 통과하는 꼴(검증 탐침 확인): ADR 주체 칸이 「—」 · HTML 주석뿐인 행(채운 것으로 봄) · setext 제목(`결정할 것` + `---`) 아래 표 · 라벨 아래 첫 항목이 더 깊게 들여 쓰인 꼴의 깊은 항목 · 「없음 (단 …)」처럼 「없음」 뒤에 열린 내용. 반대 방향(쓸데없이 멈춤): 「결정할 것」 절의 둘째 표(선택지 표 등)도 센다
- G1: `.claude/harness.json` `review.gatePaths`에 `skills/sdd-run/scripts/**` · `hooks/**`
- G2: `track-brief.md` 「진행 방식」 한 줄(「위임」 조건이면 새 맥락 `code-reviewer`)
- G3: `sdd-run/SKILL.md` §2에 「나눔 모드는 두 세션이 직접 쓴다(ADR-019 E1)」
- ADR-023에 바뀐 결정이 있으면 「갱신」 줄
- ADR-023 R3 「갱신: #86 D1~D3」 줄 D2 문구를 구현에 맞춘다: 경계는 「마지막 재판정 때 attempts 개수」(`rejudged[].attempts_before`) 뒤 실패 — 시각은 초 단위라 같은 초 실패가 섞인다(step 2 탐침). D1에 「구현 시도(`wip:`) 커밋은 끝 묶음 밖 · HEAD 내용이 옛 red와 같으면 받음」
- kind: docs — 테스트 없음(tdd: false)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 흐름 그림과 문서 설명이 같은지.
3. 결과를 `phases/runner-gate-fix/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. ADR-023에 바뀌는 행은 본문을 고치지 않고 「갱신」 줄로 단다.
