# Step 6: review-fixes

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 R3 「갱신: #86」 줄
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `phases/runner-gate-fix/index.json` `reviews` — 새 맥락 리뷰 1회차 지적
- `skills/sdd-run/scripts/sdd_runner.py` — `rejudge`(묶음 · 구현 구간) · blocked 판정 기록 · 재시도 출력 · `open_decisions` 라벨 붙여 쓴 내용 정리

## 의도

- 채우는 수용 조건: #86 F1 「구현 세션이 바꾼 테스트를 새 red로 씻지 않는다」를 실제로 지키게 · 리뷰 🟡 회귀 · 🟢 표시
- 결정(사용자, 2026-11-27): D4 = A(blocked 판정 때 러너가 step에 `blocked_head` 기록, 묶음 = blocked_head..HEAD, 구현 구간 = 옛 red..blocked_head) · D5 = A(거부 = 구현 구간 순변화 있음(옛 red ≠ blocked_head) 그리고 HEAD ≠ 옛 red). 사용자 원칙: 구현 세션은 기존 테스트 케이스를 고치지 못한다

## 작업

- D4: blocked 판정(wip · index 커밋 뒤)이 `blocked_head`를 적고, `rejudge`가 묶음 · 구현 구간을 그것으로 가른다(커밋 제목 `wip:` 기준은 버린다). 재판정 성공 시 `blocked_reason` · `blocked_at`과 같이 지운다. `blocked_head`가 없는 옛 기록은 지금 방식 그대로
- D5: 판정 4가 되돌려 순변화 0인 파일은 검증이 고쳐도 받는다
- 라벨 줄에 붙여 쓴 내용 앞의 `**` · `:` · 줄표(—, –, -)를 벗긴다 — `**남은 ⚠️:** 없음` · `— 없음`은 항목 없음
- 재판정 뒤 재시도 출력은 재판정 뒤 수(`재시도 1/3`)
- 묶음 · 구현 구간 가르기를 함수 하나로 빼도 된다(선택)
- 문서: `docs/sdd-runner.md` rejudge 설명을 D4 · D5로 · 「장치로 못 막는 갈래」에 `- **남은 ⚠️ (범위)**: X`(괄호로 시작하는 붙여 쓴 내용은 안 셈) · ADR-023 R3 갱신 줄에 D4 · D5 한 줄

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」):
  - 빈 값·경계: `test_rejudge_fix_of_runner_reverted_test_accepted`
  - 비정상 입력: `test_gate_label_inline_strips_marks`
  - 실패 경로: `test_rejudge_impl_committed_test_only_refused`
  - 상태 전이: `test_blocked_records_blocked_head` · `test_rejudge_retry_shows_count_since_rejudge`
  - 동시성: 해당 없음: 차례 장치는 `test_rejudge_out_of_turn_changes_nothing`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 「바뀌는 층」 재판정 행.
3. 결과를 `phases/runner-gate-fix/index.json`의 step 6에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. ADR-023에 바뀌는 행은 본문을 고치지 않고 「갱신」 줄로 단다.
