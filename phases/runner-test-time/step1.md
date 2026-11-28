# Step 1: parallel-suite

## 읽어야 할 파일

- docs/runner-test-time-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/test_sdd_runner.py` 맨 끝 — red 커밋의 `ParallelSuiteTest` · `load_tests`(이 step이 맞출 계약)

## 의도

- 채우는 수용 조건: AC-1 ~ AC-4 — 러너 단위 테스트를 스레드로 동시에 돌리되 결과를 하나도 잃지 않게. AC-5(CI 3회)는 PR에서 검증 세션이 잰다

## 작업

- 새 파일 `skills/sdd-run/scripts/parallel_suite.py`(러너를 import하지 않는다)
  - `jobs(env)`: 환경 매핑(`load_tests`는 `os.environ`을 넘긴다)을 인자로 받는다. `RUNNER_TEST_JOBS`가 양의 정수면 그 값, 비었거나 0 이하 · 숫자 아님이면 `min(3, os.cpu_count() or 1)`
  - `ParallelSuite(tests, jobs)`(`unittest.TestSuite` 하위): `run(result)`가 묶음 안 테스트(중첩 묶음은 펼친다)를 스레드 `jobs`개로 돌리고, 테스트마다 따로 받은 결과의 실패 · 에러 · 건너뜀 · 예상한 실패 · 예상 밖 성공을 원래 `result`에 그 테스트와 함께 옮긴다. `result.testsRun`은 실행한 수와 같아야 한다. 옮기는 순서는 원래 테스트 순서
  - `jobs`가 1이면 동시에 도는 테스트가 1개를 넘지 않는다
- `test_sdd_runner.py`는 고치지 않는다(red 커밋에 `load_tests`가 이미 있다)
- `docs/sdd-runner.md` 검증 상태: 개수 줄을 실제 `Ran N`으로, 괄호 목록 맨 앞에 이번 phase 몫(runner-test-time N개: 결과 옮김 · 동시 실행 · 차례 실행 · 동시 개수) · 「`RUNNER_TEST_JOBS`(기본 min(3, CPU 수), 1이면 차례 실행)로 동시 개수를 바꾼다」 한 줄

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 같이 돈다)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_jobs_env_blank_or_invalid_uses_default`
  - 비정상 입력: `test_failures_errors_skips_carried_over`
  - 실패 경로: `test_any_failure_makes_run_unsuccessful`
  - 상태 전이: 해당 없음: 묶음은 한 번 돌고 끝나는 상태 없는 실행이다
  - 동시성: `test_runs_tests_concurrently` · `test_jobs_one_runs_serially`

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
