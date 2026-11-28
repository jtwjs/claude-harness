# Step 2: review-fix-guard-outside

## 읽어야 할 파일

- docs/runner-test-time-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음
- `phases/runner-test-time/index.json` `reviews` 1회차(새 맥락 code-reviewer 🟡 3)
- `skills/sdd-run/scripts/parallel_suite.py` · `skills/sdd-run/scripts/test_sdd_runner.py` 맨 끝(red 커밋의 새 테스트 · 바뀐 `load_tests`)

## 의도

- 채우는 수용 조건: AC-1(결과를 잃지 않음 — 클래스 · 모듈 준비 포함) · AC-4
- 리뷰 🟡: ① 묶음 검증 테스트(`ParallelSuiteTest`)가 그 묶음 안에서 돌아 실패를 버리는 변이에 눈이 멀었다 — red 커밋의 `load_tests`가 그 클래스를 일반 묶음으로 뺀다(검증 세션 몫, 끝남) ② subTest 단언 — red 커밋(끝남) ③ 클래스 · 모듈 준비를 쓰는 테스트는 결과가 일반 묶음과 같아야 한다 — 이 step의 구현

## 작업

- `ParallelSuite.run`: 클래스가 `setUpClass` · `tearDownClass`를 바꿨거나 그 클래스의 모듈에 `setUpModule` · `tearDownModule`이 있는 테스트는 동시 실행에서 빼서 일반 `unittest.TestSuite`로 돌린다(준비 · 정리 · 그 에러 보고를 unittest에 맡긴다). 나머지는 지금처럼 동시에
- 판단은 테스트 클래스 기준이다 — 같은 클래스의 테스트는 한쪽으로만 간다
- 모듈 docstring의 「클래스 · 모듈 단위 준비는 돌리지 않는다」 줄을 새 동작으로 고친다
- `test_sdd_runner.py`는 고치지 않는다
- `docs/sdd-runner.md` 검증 상태 개수 줄을 실제 `Ran N`으로, 이번 phase 몫 목록에 새 테스트 이름 몫(준비 쓰는 클래스 · 모듈 준비 · 검증 테스트 묶음 밖)을 더한다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 같이 돈다)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_class_fixture_matches_plain_suite`
  - 비정상 입력: `test_module_fixture_matches_plain_suite`
  - 실패 경로: `test_failures_errors_skips_carried_over`(실패하는 subTest 포함)
  - 상태 전이: 해당 없음: 묶음은 한 번 돌고 끝나는 상태 없는 실행이다
  - 동시성: `test_guard_tests_run_outside_parallel_suite`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-test-time-2026-11-28/ARCHITECTURE.md` 「불변 규칙」.
3. 결과를 `phases/runner-test-time/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- 러너(`sdd_runner.py`) · `hooks/**` · `.github/workflows/ci.yml`은 바꾸지 않는다(PRD 하지 않을 것).
