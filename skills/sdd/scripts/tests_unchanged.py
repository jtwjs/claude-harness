#!/usr/bin/env python3
"""테스트 무변경 판정 — 검증 세션이 넘긴 테스트 커밋 뒤에 테스트 파일이 바뀌었나(ADR-028).

구현 세션은 테스트를 고치지 않는다. 검증 세션은 구현이 끝났다는 메시지를 받으면 이 스크립트에
자기가 넘긴 테스트 커밋 sha 를 준다. 커밋 제목으로 경계를 가르지 않는다(레포 규칙).

  python3 tests_unchanged.py <테스트 커밋 sha>

보는 범위: 그 커밋 뒤 커밋 · 스테이징 · 작업 트리 변경 · 추적 전 새 파일.
종료 코드: 0 테스트 파일 무변경 · 1 바뀐 테스트 파일 있음(목록) · 2 인자 · 커밋 오류
"""
import re
import subprocess
import sys

# 테스트 파일 — TS *.test/*.spec · __tests__ · tests/ · JVM src/test · *Test.kt · py test_* · *_test.py/go · 셸 test.sh
TEST_FILE = re.compile(r"(\.(test|spec)\.[^/]+$|(^|/)__tests__/|(^|/)tests?/|(^|/)src/test/|Tests?\.(kt|java)$"
                       r"|(^|/)test_[^/]+\.py$|_test\.(py|go)$|(^|/)test\.sh$)")
# 실행 부산물 — tests/ 아래에 생겨도 테스트 수정이 아니다(tests/__pycache__ 오탐 1건)
NOT_TEST = re.compile(r"(^|/)__pycache__/|\.pyc$")


def git_z(*args) -> list:
    """NUL 로 나눈 경로 목록. 이름 바꾸기 숨김 · 비ASCII 따옴표를 피한다."""
    r = subprocess.run(["git", "-c", "core.quotePath=false", *args], capture_output=True, text=True)
    return [p for p in r.stdout.split("\0") if p]


def main(argv) -> int:
    if len(argv) != 1:
        print("사용: tests_unchanged.py <테스트 커밋 sha>", file=sys.stderr)
        return 2
    sha = argv[0]
    if subprocess.run(["git", "rev-parse", "--verify", "-q", f"{sha}^{{commit}}"], capture_output=True).returncode:
        print(f"테스트 무변경: 커밋을 읽을 수 없다 — {sha}", file=sys.stderr)
        return 2
    changed = git_z("diff", "--no-renames", "--name-only", "-z", sha) + git_z("ls-files", "--others", "--exclude-standard", "-z")
    hits = sorted({p for p in changed if TEST_FILE.search(p) and not NOT_TEST.search(p)})
    if not hits:
        print(f"테스트 무변경: {sha} 뒤 테스트 파일 무변경")
        return 0
    print(f"테스트 무변경: {sha} 뒤 테스트 파일 {len(hits)}개가 바뀌었다 — 구현 세션에 되돌려 보낸다")
    for p in hits:
        print(f"  - {p}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
