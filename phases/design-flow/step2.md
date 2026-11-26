# Step 2: design-doc-flow

## 읽어야 할 파일

- `docs/design-phase-2026-11-26/ADR.md` — ADR-022 「D2 설계서」(흐름 mermaid · 조건 셋 · 혼자 도는 sdd 순서) · 「D6」 결정 2 · 「구현 이슈 분해」 J2 행 · 「#82 계획 때 정한 것」(설계서 자리 · 결정 이슈 틀). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `docs/principles/write-for-agents.md`
- 바꾸는 파일: `skills/conductor/references/decisions.md` · `skills/sdd/SKILL.md` · `skills/sdd/references/design.md`
- step 1이 바꾼 `decisions.md` §1 「관문 둘」 · 「결정 묶음 받기」 줄(이 step은 그 위에 쓴다)

## 의도

- 채우는 끝 기준: 이슈 #82 단계 2(J2 설계서 흐름) — 「PRD를 받았을 때」 grep 0 · 설계서 흐름 본문이 `design.md` 한 곳, 지휘 쪽은 가리킴. 이유: ADR-022 D2로 사람이 고치는 문서가 설계서 하나가 됐고(지휘가 씀), PRD · ARCHITECTURE · ADR은 검증 세션이 설계서로 쓴다. 지금 문서는 「PRD는 지휘가 결정 이슈에 쓴다」(ADR-019 E4)라 둘이 부딪힌다

## 작업

`tdd: false` — 스킬 · 문서 문장만 바꾸는 step이라 먼저 쓸 테스트 대상 동작이 없다(문서 면제). 끝은 아래 grep AC가 판정한다.

1. `skills/sdd/references/design.md`에 새 절 `## 설계서` 를 만든다(「끝 — 산출물」 절 바로 앞). 이 절이 설계서 흐름의 **정본 한 곳**이다. 이 step에서 넣는 것:
   - 설계서가 무엇인지 한 줄: 사람이 읽고 고치는 설계 문서 한 장. 레포의 PRD · ARCHITECTURE · ADR은 에이전트가 읽는 문서로 남고, 사람은 그 세 장을 직접 고치지 않는다
   - 순서(ADR-022 D2 mermaid를 이 절에 옮긴다, 「세컨드브레인」 낱말은 「개인 기록」으로): 설계서 초안 → 사람 검수 · 수정 → 보강(트랙의 코드 사실 · 결정 묶음) → AI 재검토(부딪힘 · 빠진 규칙을 번호 질문으로, 「요구사항에 해결책(기술 선택)이 섞였나」 한 줄 포함) → 사람이 번호마다 한 번에 답(질문 규칙 원칙 문서를 가리킴) → 최종본 → 세 장
   - 누가 · 어디에: 지휘가 있으면 지휘가 사용자와 쓰고 파일은 지휘 자리 폴더(비공개). 개인 기록이 연결돼 있으면 초안 전에 그 레포 맥락부터 읽는다. 혼자 도는 sdd면 같은 순서를 한 세션이 돌고 파일은 `docs/{feature-YYYY-MM-DD}/DESIGN-DOC.md`
   - 조건 1 · 2 요약 한 줄씩: 설계서가 원문이고 PRD는 뜻을 바꾸지 않는다 · 구조 결정은 설계서 「결정」 칸을 거친다(Readiness가 대조한다 — 줄은 step 3이 넣는다)
   - 틀 · 결정 묶음 꼴 · 화면 규칙은 **이 step에서 넣지 않는다**(step 3 · 4). 자리만 비워 두지 말고 아예 쓰지 않는다
2. `design.md` 「순서 (보통 이상)」: 6번 「남긴다」 → 1~5의 결과로 설계서를 쓰고 「설계서」 절 순서를 돈 뒤 「끝」으로 간다. 인터뷰 1~5는 그대로 둔다(지휘 경로에서는 지휘가 사용자와 이 인터뷰를 돈다)
3. `design.md` 「끝 — 산출물」 첫 문단: 「사람이 "됐다"고 하면 … 확인은 두 번 … plannotator …」를 「설계서 최종본이 승인되면 `docs/{feature-YYYY-MM-DD}/` 한 곳에 세 장을 쓴다. 사람은 세 장을 고치지 않고, 세 장 안의 결정이 설계서 결정 칸에 없으면 설계서로 돌아가 묻는다」로 바꾼다. plannotator 문장은 지운다(화면 규칙은 step 4가 「설계서」 절에 넣는다). 「문서가 목적(기획서 …)」 문장은 그대로 둔다. 「1. PRD.md — 확인받으면 바로 2번으로」의 「확인받으면」도 설계서 흐름에 맞게 고친다. 🔴 `**ARCHITECTURE.md** — PRD 확정 직후` 글자는 그대로 남긴다(`hooks/test.sh`가 찾는다)
4. `design.md` 11행 「PRD를 받았을 때」 갈래 → 「설계서를 받았을 때」: 지휘가 설계서 최종본 경로를 넘긴 트랙이면 0~6과 「설계서」 절을 건너뛰고 「끝」 1번 PRD부터(설계서 원문으로) 쓴다. 확인 자리는 `sdd` 표의 나눔 모드 칸
5. `skills/sdd/SKILL.md`:
   - ① 계획 · DESIGN 행의 「**PRD를 받았을 때** …」 → 「**설계서를 받았을 때**(지휘가 결정 이슈 「설계서」 칸에 최종본 경로를 넘긴 트랙)」: 설계서를 읽고 `docs/{feature-YYYY-MM-DD}/`에 PRD(설계서 원문 + 에이전트 칸 `AC-N` · 맡는 쪽 · `👤` · 키워드, 뜻을 바꾸지 않는다. 결정 이슈 링크 · 「기능 키워드」 · 「API 계약 초안」을 옮긴다) · ARCHITECTURE · ADR → 그 안의 결정은 결정 묶음으로 지휘에 → 의도 되비추기 한 줄(지휘 확인) → Readiness → PLAN. 인터뷰는 지휘 설계 대화에서 끝났으니 돌지 않는다
   - 같은 행 체크포인트 칸: 혼자 도는 sdd는 「PRD·수용 조건 확인 · ARCHITECTURE 초안」 → 「설계서 검수 · 최종본 승인」. 나눔 모드는 「의도 되비추기 · 결정 묶음 회신 · Readiness ❌는 지휘 확인(설계서를 고쳐야 하면 지휘가 사용자와)」
   - 맨 위 「한 줄 흐름」 코어 트랙의 DESIGN 괄호에 설계서를 넣는다(왜부터 캐물어 → 설계서 → PRD·ARCHITECTURE·ADR → Readiness)
   - 🔴 「절차를 건너뛰고 세 장을 바로 쓰지 않는다」 · 「출구 조건」 · 「REFLECT 건너뜀」 · 「마무리(SHIP)」 · 「지식 정리」 글자는 그대로 남긴다(`hooks/test.sh`가 찾는다). SKILL.md에 날짜 · 버전 숫자를 쓰지 않는다
6. `skills/conductor/references/decisions.md`:
   - 「설계 초안 받기」 줄 → 「설계서 흐름」: 지휘가 사용자와 설계서를 쓴다. 순서는 `${CLAUDE_PLUGIN_ROOT}/skills/sdd/references/design.md` 「설계서」 절을 가리키고 여기 다시 적지 않는다. 지금 그 줄에 있는 plannotator · Send/Approve 실측 문장은 **이 step에서 그대로 남긴다**(step 4가 옮긴다)
   - 「**PRD는 지휘가 쓴다** (ADR-019 E4) …」 → 「**설계서는 지휘, 레포 세 문서는 검증 세션** (ADR-022 D2 — ADR-019 E4 갱신)」: 지휘는 설계서를 지휘 자리 폴더에 쓰고 결정 이슈 「설계서」 칸에 경로를 적는다(다른 레포 worktree에 직접 쓰지 않는다). 검증 세션이 설계서 최종본으로 PRD · ARCHITECTURE · ADR을 쓰고 의도 되비추기 한 줄을 보낸다. 설계서를 고쳐야 하면 지휘가 사용자와 설계서를 고치고 검증 세션이 다시 반영한다. 공개 레포면 PRD에 사람 이름 · 개인 문서 문구 · 개인 기록 원문을 넣지 않고 일반화한다
   - 「기능 키워드 표 · API 계약 초안을 PRD 안에 두는 이유」 줄 → 결정 이슈에 두는 이유로(ADR-019 E9 · E10, #82 결정 2): FE · BE 검증 세션이 같은 원문을 PRD로 옮겨 가야 용어와 계약이 갈리지 않는다
   - 결정 이슈 틀: `## PRD` + 설명 줄 + `### 수용 조건` + 그 설명 → `## 설계서` + `<설계서 최종본 경로(지휘 자리 폴더). 트랙에 맡길 기능이 아니면 "해당 없음". 수용 조건은 검증 세션이 설계서로 PRD에 쓴다>`. `### 기능 키워드` · `### API 계약 초안`은 `##`로 올려 그대로 둔다. 「전파 체크리스트」의 PRD 줄은 그대로
   - §2 「나눔 모드 — 계약 먼저」의 「결정 이슈 「API 계약 초안」」 문장은 바꾸지 않는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `! git grep -n -F 'PRD를 받았을 때' -- skills templates agents`
- `! git grep -n -F 'PRD는 지휘가 쓴다' -- skills templates agents`
- `[ "$(grep -c '^## 설계서$' skills/sdd/references/design.md)" -eq 1 ]`
- `grep -q '「설계서」 절' skills/conductor/references/decisions.md`
- `grep -q 'DESIGN-DOC.md' skills/sdd/references/design.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-022 D2 흐름 · 조건 1 · 2 · 「#82 계획 때 정한 것」과 대조한다. 설계서 순서가 `design.md` 밖(`decisions.md` · `SKILL.md`)에 다시 적히지 않았나 본다.
3. 결과를 `phases/design-flow/index.json`의 step 2에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `skills/sdd-run/**` · `docs/sdd-runner.md` · `skills/sdd-plan/**`는 옆 트랙 소유라 고치지 않는다. 고쳐야 하면 blocked.
- 공개 레포다: 사람 · 회사 이름 · 개인 경로 · 개인 저장소 이름(「세컨드브레인」 포함)을 쓰지 않는다(「사용자」 · 「개인 기록」으로).
- 같은 문장을 두 곳에 쓰지 않는다. 다른 곳은 정본을 가리킨다.
- push · PR 금지.
