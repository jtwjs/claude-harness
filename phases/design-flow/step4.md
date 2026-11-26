# Step 4: design-doc-screen

## 읽어야 할 파일

- `docs/design-phase-2026-11-26/ADR.md` — ADR-022 「D3 설계서 검수에 plannotator를 어떻게 쓰나」(A안 · 결정 줄 · 「도구 자리」 줄) · 「D5」 표 P1~P4 · 「구현 이슈 분해」 J8 행. 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `docs/principles/write-for-agents.md`
- 바꾸는 파일: `skills/sdd/references/design.md`(`## 설계서` 절 — step 2 · 3이 만듦) · `skills/conductor/references/decisions.md`(「설계서 흐름」 줄 — step 2가 남겨 둔 plannotator · Send/Approve 실측 문장)

## 의도

- 채우는 끝 기준: 이슈 #82 단계 4(J8 설계서 화면) — 「설계서를 쓰는 요청이면 늘 연다」 한 줄 · 도구 이름이 설계서 흐름 문장에 한 곳. 「첫 설계서에서 Send로 받은 답 수 = 질문 수」는 실제 첫 설계서에서만 잴 수 있어 이 step 밖이다(PR에 미측정으로 남긴다). 이유: ADR-022 D3 — 규칙이 있어도 지휘가 설계 질문을 채팅으로 낸 사례가 있었다. 여는 때를 「늘」로 고정하고, 질문 판과 최종본의 버튼을 갈라 「Approve만 누르면 답 0」 함정을 막는다

## 작업

`tdd: false` — 스킬 · 문서 문장만 바꾸는 step이라 먼저 쓸 테스트 대상 동작이 없다(문서 면제). 끝은 아래 grep AC가 판정한다.

1. `design.md` `## 설계서` 절에 「화면」 묶음을 넣는다. 정본 문장은 도구가 아니라 동작으로 쓴다(「설계서를 한 화면에서 고치고 답한다」). 들어갈 규칙:
   - 설계서를 쓰는 요청이면 늘 설계서를 화면으로 연다(채팅으로 질문을 내지 않는다). 이 문장에 「설계서를 쓰는 요청이면 늘」 글자가 들어가게 쓴다
   - 재검토의 번호 질문은 설계서 「결정할 것」 칸에 질문 블록으로 넣어 같은 화면에서 답한다
   - 질문이 남은 판은 승인 버튼 없이 연다(사람은 피드백 보내기로 답한다). 최종본만 승인 버튼으로 연다. 이유 한 구절: 질문이 있는 판에서 승인만 누르면 답이 오지 않는다(실측: 승인 1회 답 0건 · 피드백 보내기 1회 5/5건 — `decisions.md`에서 옮겨 온 숫자, 날짜 2026-11-23)
   - 이미 정한 결정은 체크된 선택(`- [x]`)으로 두고 다시 열지 않는다
   - AI 재검토로 설계서가 바뀌면 바뀐 줄을 diff로 보인다(설계서를 커밋한 뒤 diff 화면으로)
   - 답의 메모 칸은 이유로, 「추천을 골랐음」 표시는 결정 주체(AI 추천 수용)로 설계서 결정 칸에 옮긴다
   - 연 뒤에는 턴을 끝내고 사람의 답 · 승인이 올 때까지 기다린다. 도구가 없거나 사람이 채팅으로 하겠다고 하면 채팅에서 받는다
   - **도구 이름은 이 묶음의 한 줄에만** 둔다: 「지금 화면 도구는 `plannotator`(`annotate`, 질문 블록 `:::question`, 승인 버튼 = `gate: true`, diff = `review`). 다른 판정 도구로 바뀌면 이 줄만 고친다」 같은 꼴. 위 규칙 문장에는 `plannotator` · `annotate` · `gate`를 쓰지 않는다
   - 계획 검토 모드(plan mode)로 설계서를 받지 않는다는 한 구절(ADR-022 D5 P7 — 계획을 서두르게 한다)
2. `decisions.md` 「설계서 흐름」 줄에서 plannotator · `:::question` · `annotate` · `gate:true` · Send/Approve 실측 문장을 지우고, 화면은 `design.md` 「설계서」 절을 가리키는 것으로 줄인다. 「지휘는 auto 모드 그대로라 plan mode를 쓰지 않는다」는 지휘 몫이라 도구 이름 없이 남긴다
3. 이 step이 끝나면 `skills/` 안 `plannotator` 글자는 `design.md` 한 줄과 `skills/harness-init/references/renames.tsv`(이름 바꿈 기록, 고치지 않는다)뿐이다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `grep -q '설계서를 쓰는 요청이면 늘' skills/sdd/references/design.md`
- `[ "$(grep -c 'plannotator' skills/sdd/references/design.md)" -eq 1 ]`
- `! grep -q 'plannotator' skills/conductor/references/decisions.md`
- `! grep -q 'gate' skills/conductor/references/decisions.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-022 D3 결정 줄과 D5 P1~P4가 다 들어갔는지 하나씩 대조한다.
3. 결과를 `phases/design-flow/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/` · `renames.tsv`)은 고치지 않는다.
- `skills/sdd-run/**` · `docs/sdd-runner.md` · `skills/sdd-plan/**`는 옆 트랙 소유라 고치지 않는다. 고쳐야 하면 blocked.
- 공개 레포다: 사람 · 회사 이름 · 개인 경로 · 개인 저장소 이름을 쓰지 않는다(「사용자」 · 「개인 기록」으로).
- 같은 문장을 두 곳에 쓰지 않는다. 다른 곳은 정본을 가리킨다.
- push · PR 금지.
