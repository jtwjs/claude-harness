# Step 4: conductor-adr-lines

## 읽어야 할 파일

- docs/design-doc-format-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음. ARCHITECTURE 「바뀌는 층」 지휘 설계서 흐름 행 · ADR-022 행 · 「ADR 판정」
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/conductor/references/decisions.md` 12 · 14행(「설계서 흐름」 · 「결정 묶음 받기」)
- `docs/design-phase-2026-11-26/ADR.md` ADR-022 머리 불렛(5~15행) — 갱신 줄 꼴은 `docs/runner-gate-2026-11-26/ADR.md` 8 · 48행(`- 갱신: #N (날짜, 주체) — …`)
- `skills/sdd/references/design.md` 「설계서」 절(step 1 · 3이 바꾼 뒤 — 순서 정본)
- `hooks/tests/design-doc-conductor.sh` — 이 step의 테스트(검증 세션이 먼저 커밋)

## 의도

- 채우는 수용 조건: AC-4(지휘 쪽) · AC-6(지휘 쪽) · AC-15 — 지휘 문서가 옛 칸 이름을 가리키지 않게 하고, 상위 결정(ADR-022)에 바뀐 흐름을 갱신 줄로 남긴다

## 작업

- `skills/conductor/references/decisions.md`
  - 「결정 묶음 받기」: 「답을 설계서 「결정한 것」 칸에 덧붙이고」 → 「답을 설계서 「고른 안과 버린 안」에 덧붙이고」. 나머지 그대로
  - 「설계서 흐름」: 한 구절 더한다 — 검증 세션이 ARCHITECTURE · ADR을 쓴 뒤 지휘가 설계서 아주 자세히 3칸(상세 설계 · 공통 관심사 · 배포와 롤백)을 다시 써서 붙인다. 순서 정본은 `design.md` 「설계서」 절이라 순서를 다시 적지 않는다(지금 문장 유지)
- `skills/conductor/references/*.md` 어디에도 옛 칸 이름(「결정한 것」 칸 · 설계서 「결정」 칸)을 가리키는 줄이 남지 않게 한다
- `docs/design-phase-2026-11-26/ADR.md` ADR-022 머리 불렛(「- 겹침:」 줄 다음)에 한 줄: `- 갱신: #87 (2026-11-28, 사용자 — AI 추천 수용) — D2 설계서 틀을 간단히 · 자세히 · 아주 자세히 + 우리 칸으로 바꾼다. 설계서 순서 3: 큰 방향(구조 상자 · 큰 선택)은 설계서에서 묻고, 코드 근거가 필요한 선택은 결정 묶음으로. 「설계서와 세 장」: PRD는 설계서 칸에서 뽑고 세 장 줄마다 출처 칸. 칸 순서 검사를 화면에 열기 전에 돌린다. 근거: docs/design-doc-format-2026-11-28/` 꼴(문장은 다듬어도 된다). ADR-022의 다른 줄 · 본문 D2 코드 블록은 고치지 않는다(그 시점의 기록)
- 갱신 줄은 머리 불렛(표 밖 문장)으로만 단다. ADR-022 「결정할 것」 표에 행을 더하지 않는다 — 주체 칸이 빈 행이 생기면 러너 구현 시작 관문(`sdd_runner.py` `open_decisions`)이 그 행을 열린 「정할 것」으로 센다
- 공개 레포라 사람 · 회사 이름 · 개인 경로 · 개인 기록 문구를 넣지 않는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test` — 이 레포 verify는 test 하나)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」):
  - 빈 값·경계: `dcn-old-cell-names-zero`
  - 비정상 입력: 해당 없음: 입력을 받는 코드가 아니라 문서다
  - 실패 경로: 해당 없음: 실패 동작이 없는 문서 문구다
  - 상태 전이: 해당 없음: 상태가 없는 문서다
  - 동시성: 해당 없음: 문서다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/design-doc-format-2026-11-28/ARCHITECTURE.md` 「바뀌는 층」 · 「지키는 것 — 불변 규칙」.
3. 결과를 `phases/design-doc-format/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다. ADR-022는 갱신 줄 한 줄만 더한다.
- `skills/sdd/**` · `skills/sdd-run/**` · `skills/sdd-plan/**` · `docs/sdd-runner.md` · `templates/**`는 고치지 않는다.
