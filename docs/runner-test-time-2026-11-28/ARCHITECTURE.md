# ARCHITECTURE — runner-test-time

기존 구조 그대로 — 바뀌는 층: 없음(테스트 실행 방식만). (← 검증 세션)

## 코드 지도

| 파일 | 이번에 하는 일 | 출처 |
|---|---|---|
| `skills/sdd-run/scripts/parallel_suite.py`(새) | `ParallelSuite` · `jobs(env)` — 러너를 import하지 않는 테스트 실행 보조 | PRD AC-1 ~ AC-3 |
| `skills/sdd-run/scripts/test_sdd_runner.py` | (red 커밋, 검증 세션) `ParallelSuiteTest` 새 클래스 + 모듈 끝 `load_tests`가 `ParallelSuite(tests, jobs(os.environ))`를 돌려준다 | PRD AC-1 ~ AC-4 |
| `docs/sdd-runner.md` 검증 상태 | 개수 줄 · `RUNNER_TEST_JOBS` 한 줄 | PRD AC-4 |

묶음을 테스트 파일 밖 새 파일에 두는 이유: 테스트 파일은 red 뒤 구현이 고칠 수 없다(판정 4). 구현은 새 파일만 만들고, 묶는 줄(`load_tests`)은 red 커밋에 있다.

## 불변 규칙

- 기존 테스트 메서드 · 단언 · setUp · 헬퍼는 한 글자도 안 바뀐다 (← 사용자 지시)
- 묶음은 결과를 잃지 않는다 — 실패 · 에러 · 건너뜀 · 실행 수 (← PRD 결정 runner-test-time-proof)
- 러너 · `hooks/**` · ci.yml · test.sh는 그대로 (← PRD 하지 않을 것)

## 테스트 전략

- 묶음 테스트는 가짜 TestCase(통과 · 실패 · 에러 · 건너뜀)로 결과 객체를 단언한다. 동시성은 시간 대신 `threading.Barrier`로 본다(부하에 흔들리지 않게) (← 검증 세션)

## 배포와 롤백

- 플러그인 릴리스로 나간다. 문제가 나면 `RUNNER_TEST_JOBS=1`로 차례 실행 · 되돌릴 때는 PR revert 하나 (← 검증 세션)
