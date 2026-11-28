#!/usr/bin/env python3
"""테스트 무변경 판정 — 검증 세션이 넘긴 테스트 커밋 뒤에 테스트 파일이 바뀌었나(ADR-028).

구현 세션은 테스트를 고치지 않는다. 검증 세션은 구현이 끝났다는 메시지를 받으면 이 스크립트에
자기가 넘긴 테스트 커밋 sha 를 준다. 커밋 제목으로 경계를 가르지 않는다(레포 규칙).

  python3 tests_unchanged.py <테스트 커밋 sha>

보는 범위: 그 커밋 뒤 커밋 · 스테이징 · 작업 트리 변경 · 추적 전 새 파일. 테스트 파일과 `.claude/harness.json`
(테스트 명령을 바꿔 테스트를 끄는 길)을 본다.
보지 않는 것(새 맥락 리뷰가 본다): 테스트 도구 설정(pytest.ini · conftest.py · jest.config 등) · 무시된(.gitignore ·
info/exclude) 경로 · skip-worktree · 서브모듈 안 · 아래 패턴 밖 테스트 자리(testdata/ · tests.py · *_spec.rb · *.cy.ts 등).
종료 코드: 0 테스트 파일 무변경 · 1 바뀐 테스트 파일 있음(목록) · 2 인자 · 커밋 · git 오류
"""
import re
import subprocess
import sys

# 테스트 파일 — TS *.test/*.spec · __tests__ · tests/ · JVM src/test · *Test.kt · py test_* · *_test.py/go · 셸 test.sh
TEST_FILE = re.compile(r"(\.(test|spec)\.[^/]+$|(^|/)__tests__/|(^|/)tests?/|(^|/)src/test/|Tests?\.(kt|java)$"
                       r"|(^|/)test_[^/]+\.py$|_test\.(py|go)$|(^|/)test\.sh$)")
# 실행 부산물 — tests/ 아래에 생겨도 테스트 수정이 아니다(tests/__pycache__ 오탐 1건)
NOT_TEST = re.compile(r"(^|/)__pycache__/|\.pyc$")
WATCH = {".claude/harness.json"}   # 테스트 파일은 아니지만 테스트 명령이 든 파일


class GitError(Exception):
    pass


def git_z(root, *args) -> list:
    """NUL 로 나눈 레포 루트 기준 경로 목록. 이름 바꾸기 숨김 · 비ASCII 따옴표를 피한다.
    루트에서 돌린다 — ls-files 는 실행 폴더 아래만 · 실행 폴더 기준 경로로 낸다."""
    r = subprocess.run(["git", "-c", "core.quotePath=false", *args], cwd=root, capture_output=True, text=True)
    if r.returncode:   # 실패를 「바뀐 것 없음」으로 읽지 않는다
        raise GitError(f"git {args[0]}: {r.stderr.strip()}")
    return [p for p in r.stdout.split("\0") if p]


def main(argv) -> int:
    if len(argv) != 1:
        print("사용: tests_unchanged.py <테스트 커밋 sha>", file=sys.stderr)
        return 2
    sha = argv[0]
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if top.returncode or subprocess.run(["git", "rev-parse", "--verify", "-q", f"{sha}^{{commit}}"],
                                        capture_output=True).returncode:
        print(f"테스트 무변경: 커밋을 읽을 수 없다 — {sha}", file=sys.stderr)
        return 2
    root = top.stdout.strip()
    try:
        changed = (git_z(root, "diff", "--no-renames", "--name-only", "-z", sha)
                   + git_z(root, "ls-files", "--others", "--exclude-standard", "-z"))
    except GitError as e:
        print(f"테스트 무변경: 판정할 수 없다 — {e}", file=sys.stderr)
        return 2
    hits = sorted({p for p in changed if p in WATCH or (TEST_FILE.search(p) and not NOT_TEST.search(p))})
    if not hits:
        print(f"테스트 무변경: {sha} 뒤 테스트 파일 무변경")
        return 0
    print(f"테스트 무변경: {sha} 뒤 테스트 파일 {len(hits)}개가 바뀌었다 — 구현 세션에 되돌려 보낸다")
    for p in hits:
        print(f"  - {p}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
