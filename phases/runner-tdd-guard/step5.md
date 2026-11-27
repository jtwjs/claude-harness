# Step 5: docs-align

## 읽어야 할 파일

- docs/runner-tdd-guard-2026-11-27/{PRD,ARCHITECTURE,ADR}.md — ADR-024 T1~T5
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `docs/sdd-runner.md` — 판정 표 · 「나눔 모드」 차례 표 · 「테스트 파일 판별」 줄 · 「검증 상태」 줄
- `skills/sdd-run/SKILL.md` §2-b(55행 구현 세션 줄)
- `skills/sdd-plan/SKILL.md` — 39행 이동 리팩터 줄 · index.json 칸 설명(`kind` · `model` 근처)
- step 1~4가 바꾼 `skills/sdd-run/scripts/sdd_runner.py`(문서가 코드와 같은 말을 하는지 대조)

## 의도

- 채우는 수용 조건: 없음(문서). tdd: false 이유: 러너 문서 · 스킬 문장만 바꾸고 코드 동작은 step 1~4가 테스트로 덮었다

## 작업

- `docs/sdd-runner.md`
  - 판정 표에 판정 4' 줄(tdd가 아닌 step · 측정 포함: BASE 대비 순변화에서 BASE에 있던 테스트 파일 중 `test_edits`에 없는 것을 되돌림 → 실패 → 재시도. 추가는 남김. blocked 보고 때도 되돌리고 사유에 붙임)
  - 「테스트 파일 판별」 줄에 `test.sh`(코드 `TEST_FILE`과 같게)
  - 나눔 모드 차례 표 tdd:false 행 · 「BASE는 …」 줄: tdd:false는 `prompt --role impl`이 BASE가 없으면 HEAD를 고정
  - `test_edits` 칸(꼴 · `start` 검사)을 한 항목으로. ADR-024를 처음 가리킬 때 괄호로 무엇을 정했는지 한 줄
  - 「검증 상태」의 러너 단위 테스트 개수를 실제 실행 결과로 고친다
- `skills/sdd-run/SKILL.md:55`: 「BASE는 검증 쪽이 고정한 값」에 「tdd:false step은 `prompt --role impl`이 고정」을 더한다
- `skills/sdd-plan/SKILL.md`: 39행 이동 step에 「바뀌는 기존 테스트 파일을 `test_edits`에 이유와 함께 적는다(없으면 러너가 되돌린다)」, index.json 칸 설명에 `test_edits`(선택, tdd:false step만, 경로 → 이유, glob 없음) 한 항목
- ADR-023 행은 바뀌지 않는다(「갱신」 줄 없음)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- `grep -n "test_edits" docs/sdd-runner.md skills/sdd-plan/SKILL.md` — 둘 다 1줄 이상
- `grep -n "role impl" skills/sdd-run/SKILL.md` — 55행 근처에 tdd:false BASE 고정 문구

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-tdd-guard-2026-11-27/ARCHITECTURE.md` 「바뀌는 층」 문서 행.
3. 결과를 `phases/runner-tdd-guard/index.json`의 step 5에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지. `hooks/test.sh` · `hooks/tests/**` · `test_sdd_runner.py`를 고치지 않는다
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `skills/conductor/**` · `hooks/conductor-context.sh`(옆 트랙) · `templates/.claude/references/track-brief.md`(대기 이슈)는 건드리지 않는다
