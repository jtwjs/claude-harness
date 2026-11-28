# Step 1: align-test-edits-on-record

## 읽어야 할 파일

- docs/runner-resume-test-edits-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`(「누가 만든 커밋인지는 커밋 제목 · 내용으로 가르지 않는다」 줄)
- `skills/sdd-run/scripts/sdd_runner.py` — `planned_edits`(BASE 커밋의 index.json에서 그 step 칸을 읽는 꼴) · `record`의 세 갈래(`if res == "blocked":` · `if res is None:` · `if fails_now > self.max_retries:`) · `check`의 blocked 갈래(`revert_test_edits` 뒤 `blocked_reason`을 고쳐 쓰는 곳)
- `skills/sdd-run/scripts/test_sdd_runner.py` — 「blocked 보고 때 되돌림(ADR-024 T5)」 절과 `test_tdd_false_error_stop_reverts`(이 step 테스트가 같은 꼴을 쓴다)

## 의도

- 채우는 수용 조건: AC-1 · AC-2 · AC-3 · AC-4 · AC-5 · AC-7 — 러너가 멈춤 · 완료를 기록해 index.json을 커밋할 때 구현이 써 넣은 `test_edits`가 다음 BASE의 허가로 실려 가지 않게

## 작업

- `Runner`에 메서드 하나를 더한다: `align_test_edits(self, idx: dict, base: str) -> None`
  - `git show <base>:phases/<task>/index.json`을 한 번 읽는다. 없거나 JSON이 아니면 계획 없음(모든 step의 계획 값 = 칸 없음)으로 본다(PRD 결정 runner-resume-test-edits-no-plan)
  - `idx["steps"]`의 step마다 계획 값을 정한다: 계획 index에 같은 번호 step이 있고 그 `test_edits`가 dict면 그 dict, 아니면 「칸 없음」
  - 지금 값과 계획 값이 다르면 맞춘다(계획 값이 있으면 그 dict로 덮고, 없으면 키를 뺀다). 맞춘 step마다 stdout에 한 줄: `step {N} test_edits 되돌림: {전} → {계획 값}`. 값은 `json.dumps(…, ensure_ascii=False)`, 칸이 없으면 `없음`
  - 같으면 아무것도 출력하지 않는다(AC-4)
- `record`에서 index.json을 쓰고 커밋하는 세 갈래가 쓰기 전에 `self.align_test_edits(idx, base)`를 부른다
  - blocked 갈래: `s["blocked_at"]`를 적은 뒤, 첫 `self.write(idx)` 전
  - completed 갈래: `self.write(idx)` 전
  - error 멈춤 갈래: `commit_index` 바로 앞의 마지막 `self.write(idx)` 전
- 재시도(종료 10) 갈래 · `judge --red`(red 기록) · `rejudge` · `start`는 부르지 않는다(ARCHITECTURE 불변 규칙)
- 판정 4'가 허가를 읽는 곳(`planned_edits`)은 바꾸지 않는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 같이 돈다)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_align_no_plan_in_base_drops_edits`
  - 비정상 입력: `test_align_planned_edits_kept_and_reason_restored`
  - 실패 경로: `test_align_error_stop_drops_self_edits`
  - 상태 전이: `test_align_blocked_self_edits_not_granted_after_resume` · `test_align_completed_next_step_self_edits_not_granted`
  - 동시성: `test_align_other_session_later_edit_reverted_with_notice`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-resume-test-edits-2026-11-28/ARCHITECTURE.md` 「불변 규칙」.
3. 결과를 `phases/runner-resume-test-edits/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- 판정 1 ~ 6 · 판정 4' 동작과 실패 메시지는 바꾸지 않는다(PRD 하지 않을 것).
