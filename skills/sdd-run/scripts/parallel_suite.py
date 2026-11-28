"""러너 단위 테스트 동시 실행 묶음(runner-test-time). 테스트 대부분이 하위 프로세스를 기다려서 스레드로 동시에 돌린다.

테스트마다 따로 받은 결과 호출을 기록해 두었다가, 원래 테스트 순서대로 원래 결과 객체에 다시 부른다 —
실패 · 에러 · 건너뜀 · 예상한 실패 · 예상 밖 성공 · subTest 결과와 실행 수를 잃지 않는다.
클래스 · 모듈 단위 준비(setUpClass · setUpModule)는 돌리지 않는다 — 쓰는 테스트가 생기면 jobs 1 로도 빠진다.
러너(sdd_runner.py)를 import 하지 않는다.
"""
import os
import unittest
from concurrent.futures import ThreadPoolExecutor

ADDS = ("addSuccess", "addFailure", "addError", "addSkip", "addExpectedFailure",
        "addUnexpectedSuccess", "addSubTest", "addDuration")


def jobs(env) -> int:
    """동시 개수. RUNNER_TEST_JOBS 가 양의 정수면 그 값, 아니면 min(3, CPU 수)."""
    v = (env.get("RUNNER_TEST_JOBS") or "").strip()
    if v.isdigit() and int(v) > 0:
        return int(v)
    return min(3, os.cpu_count() or 1)


class _Recorder(unittest.TestResult):
    """결과 호출(add*)을 순서대로 기록만 한다."""

    def __init__(self):
        super().__init__()
        self.calls = []

    def __getattribute__(self, name):
        if name in ADDS:
            calls = object.__getattribute__(self, "calls")
            return lambda *args: calls.append((name, args))
        return object.__getattribute__(self, name)


def _flat(tests):
    for t in tests:
        if isinstance(t, unittest.TestSuite):
            yield from _flat(t)
        else:
            yield t


class ParallelSuite(unittest.TestSuite):
    def __init__(self, tests, jobs):
        super().__init__(list(_flat(tests)))
        self.jobs = max(1, int(jobs))

    def run(self, result, debug=False):
        def one(test):
            rec = _Recorder()
            test(rec)
            return rec.calls

        with ThreadPoolExecutor(max_workers=self.jobs) as pool:
            futures = [(t, pool.submit(one, t)) for t in self]
            for test, fut in futures:   # 원래 순서대로 다시 부른다(끝난 순서가 아니라)
                calls = fut.result()
                result.startTest(test)
                for name, args in calls:
                    fn = getattr(result, name, None)
                    if fn is not None:   # 옛 파이썬 결과 객체에 addDuration 이 없을 수 있다
                        fn(*args)
                result.stopTest(test)
        return result
