# Step 3: sdd-flow-rules

## 읽어야 할 파일

- docs/design-doc-format-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음. ARCHITECTURE 「바뀌는 층」 표(설계서 순서 · 화면 · 설계서와 세 장 · 끝 · 설계문서 3장 · Readiness · ① 표 행) · 「결정할 것」 D4(출처 칸 꼴)
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd/references/design.md` 전체(설계서 틀 블록은 step 1에서 이미 바뀜)
- `skills/sdd/SKILL.md` 「단계 → 스킬 · 체크포인트」 표 ① 계획 · DESIGN 행
- `skills/sdd-run/scripts/sdd_runner.py` `open_decisions`(168행 근처) — 읽기만. ADR 「결정할 것」 표 · PRD 「→ 결정:」 · 「막지 않음:」 꼴을 러너가 읽는다
- `hooks/test.sh` 537행 — 기존 테스트가 `design.md`에서 「ARCHITECTURE.md** — PRD 확정 직후」 구절을 찾는다
- `hooks/tests/design-doc-flow.sh` — 이 step의 테스트(검증 세션이 먼저 커밋)

## 의도

- 채우는 수용 조건: AC-2 · AC-3 · AC-4(sdd 쪽) · AC-5 · AC-6(sdd 쪽) · AC-7 · AC-8 · AC-9 · AC-14 — 새 틀에 맞게 설계서 흐름 · 세 장 규칙을 바꾸고, 세 장 줄마다 출처 칸을 달아 설계서와 PRD가 갈리는 것을 줄 단위로 잡는다

## 작업

`skills/sdd/references/design.md`:

- 설계서 순서 그림 · 1~6:
  - 초안은 간단히 5칸 + 우리 칸 + 자세히 4칸으로 쓰고, 아주 자세히 3칸은 제목만 둔다
  - 3 보강: 「구조 · 기술 결정은 여기서 묻지 않는다 …」 문장을 지운다. 대신 큰 방향(큰 구조 상자 · 큰 선택)은 설계서 「열린 질문과 누가 정하나」에 올려 사람에게 묻고, 코드 근거(파일:줄)가 필요한 선택은 디스패치 뒤 결정 묶음으로 넘긴다
  - 4 재검토: 번호 질문 자리는 「열린 질문과 누가 정하나」
  - 그림의 결정 묶음 답 상자는 설계서 「고른 안과 버린 안」 · ADR 주체 칸. 세 장 뒤 「지휘가 ARCHITECTURE · ADR을 아주 자세히 3칸(상세 설계 · 공통 관심사 · 배포와 롤백)으로 다시 써서 붙인다」 단계를 그림과 목록에 넣는다(혼자 도는 sdd면 그 세션)
- 「누가 · 어디에」: 혼자 도는 sdd는 같은 틀을 `docs/{feature-YYYY-MM-DD}/DESIGN-DOC.md`에 쓴다(지금 문장 유지)
- 「화면」: 맨 앞에 「설계서를 화면에 열기 전에 칸 순서 검사를 돌린다. 실패면 열지 않고 먼저 고친다」 한 줄과 명령 `python3 ${CLAUDE_PLUGIN_ROOT}/skills/sdd/scripts/design_doc_check.py <설계서>`. 질문 블록 자리는 「열린 질문과 누가 정하나」, 답의 이유 · 결정 주체를 옮기는 자리는 「고른 안과 버린 안」
- 「설계서와 세 장」을 바꾼다:
  - PRD는 설계서 원문 복사가 아니다. 검증 세션이 한 줄 요약 · 문제 · 목표와 비목표 · 상황별 동작 · 제약 · 가정 · 사람이 볼 것에서 뽑는다
  - 세 장(PRD · ARCHITECTURE · ADR)의 줄마다 끝에 출처 칸을 단다: `(← 칸 이름)`. `👤`가 있는 줄은 그 앞에. 설계서에 없는 줄은 `(← 검증 세션)`이고, 그 안의 결정은 결정 묶음으로 올린다(D4). 출처 칸은 러너가 읽는 「→ 결정:」과 방향이 반대라 겹치지 않는다
  - 결정 묶음 답은 설계서 「고른 안과 버린 안」에 덧붙이고 ADR 「결정할 것」 표 주체 칸을 채운다. 「정할 것」 0이 돼야 구현을 시작한다(지금 문장 유지)
- 「끝 — 산출물」: 「세 장 안의 결정이 설계서 … 칸에 없으면 설계서로 돌아가 묻는다」의 칸 이름을 「고른 안과 버린 안」으로. PRD.md 1번 「설계서 원문으로 쓰고」 → 「설계서 칸에서 뽑아 쓰고(「설계서와 세 장」)」
- Readiness 9: 「설계서의 목표와 비목표 · 상황별 동작 · 제약 · 가정 · 사람이 볼 것이 PRD에 빠짐없이, 뜻이 바뀌지 않고 있다 — 줄마다 출처 칸으로 대조」 꼴. Readiness 10: 「ADR 결정마다 설계 문서 「고른 안과 버린 안」 행 링크가 있다」 꼴
- 「설계문서 3장」:
  - **PRD.md** 정의의 「설계서 원문 + 에이전트 칸이다」 → 「설계서 칸에서 뽑고 줄마다 출처 칸(「설계서와 세 장」)」
  - **ARCHITECTURE.md** 정의 칸에 더한다: 불변 규칙(바꾸면 안 되는 것) · 코드 지도(파일마다 이번에 하는 일) · 요청 하나 따라가기(입력 하나가 거치는 길, 데이터 흐름 그림과 같은 자리) · 배포와 롤백(배포 순서와 되돌리는 법)
  - **ADR.md** 정의의 「**설계서 결정 번호**(설계서 「결정」 칸의 번호 …)」 → 「**설계 문서 링크**(설계 문서 「고른 안과 버린 안」의 그 행. 설계서가 없는 작은 일이면 생략)」
- 꼭 남길 것: 「끝」 2번의 `**ARCHITECTURE.md** — PRD 확정 직후` 구절(기존 테스트 `hooks/test.sh:537`이 찾는다) · ADR 정의의 `| # | 정할 것 | 선택지 | 추천 | 주체 |` 표 머리와 「주체 칸을 비운다」 설명(러너 관문이 읽는다)

`skills/sdd/SKILL.md` ① 계획 · DESIGN 행:

- 「PRD(설계서 원문 + 에이전트 칸 `AC-N` · 맡는 쪽 · `👤` · 키워드, 뜻을 바꾸지 않는다. …)」 → 「PRD(설계서 칸에서 뽑고 줄마다 출처 칸, 에이전트 칸 `AC-N` · 맡는 쪽 · `👤` · 키워드는 그대로, `design.md` 「설계서와 세 장」. 결정 이슈 링크 · 「기능 키워드」 · 「API 계약 초안」을 옮긴다)」 꼴. 같은 행 나머지는 그대로

공통: 공개 레포라 사람 · 회사 이름 · 개인 경로 · 개인 기록 문구를 넣지 않는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test` — 이 레포 verify는 test 하나)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」):
  - 빈 값·경계: `df-old-cell-names-zero`
  - 비정상 입력: 해당 없음: 입력을 받는 코드가 아니라 문서다
  - 실패 경로: `df-screen-runs-check-first`
  - 상태 전이: 해당 없음: 상태가 없는 문서다
  - 동시성: 해당 없음: 문서다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/design-doc-format-2026-11-28/ARCHITECTURE.md` 「바뀌는 층」 · 「지키는 것 — 불변 규칙」.
3. 결과를 `phases/design-doc-format/index.json`의 step 3에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 설계서 틀 블록(step 1) · `skills/sdd/scripts/design_doc_check.py`(step 2)는 고치지 않는다. `skills/sdd-run/**` · `skills/sdd-plan/**` · `docs/sdd-runner.md`(옆 트랙) · `skills/conductor/**`(step 4)도 고치지 않는다.
