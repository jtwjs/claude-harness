# Step 7: gate-none-item

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 R1
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `open_decisions`의 PRD 부분(`:186-208`)
- 오탐 실례: `docs/single-conductor-2026-10-31/PRD.md:130-132`(「## 남은 ⚠️」 아래 「- 없음 (…)」)

## 의도

- 채우는 수용 조건: AC-1 — 리뷰 1회차 🟡: 「남은 ⚠️」 아래에 항목이 없다는 표시(「- 없음」)를 열린 항목으로 세어 거짓으로 멈춘다. 관문이 거짓으로 멈추면 사람이 관문을 우회하는 습관이 생긴다

## 작업

- `open_decisions` PRD 쪽: 첫 단 불렛 본문이 「없음」으로 시작하고 그 뒤가 줄 끝 · 공백 · 괄호(`(`)면 세지 않는다. 「없음」이 본문 가운데 있는 항목(예: `⚠️ 기본값 없음 처리`)은 그대로 센다
- `docs/sdd-runner.md` 「구현 시작 관문」 항목의 뺄 줄 설명에 한 구절: 「없음」으로 시작하는 항목(항목 없음 표시)도 뺀다
- `docs/runner-gate-2026-11-26/ADR.md` R1 「PRD:」 줄 끝에 한 구절: 「없음」으로 시작하는 항목은 항목 없음 표시라 뺀다(리뷰 1회차)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_gate_prd_none_item_passes`
  - 비정상 입력: `test_gate_prd_none_inside_text_still_counts`
  - 실패 경로: 해당 없음: 멈춤 경로는 step 1 `test_gate_open_rows_stop_with_list`가 덮는다
  - 상태 전이: 해당 없음: 파일 내용 하나로 정해진다
  - 동시성: 해당 없음: 읽기만 한다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 「지키는 것」.
3. 결과를 `phases/runner-gate/index.json`의 step 7에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 지난 PRD(`docs/single-conductor-2026-10-31/` 등)는 고치지 않는다
