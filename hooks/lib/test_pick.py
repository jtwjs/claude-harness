#!/usr/bin/env python3
"""hooks/test.sh --since 가 돌릴 묶음을 고른다(ADR-025). 레포 루트에서 부른다.

Usage: test_pick.py <커밋> <표 파일> <tests 폴더>
출력 첫 줄: `pick<TAB>이유` 면 둘째 줄부터 묶음(main · runner · tests/<파일>), `all<TAB>이유` 면 전부 돈다.
바뀐 파일 = <커밋> 과 작업 트리의 차이 + 안 올린 새 파일. 표 꼴은 표 파일 머리 주석이 정본이다.
"""
import fnmatch
import os
import re
import subprocess
import sys


def glob_re(pat):
    """경로 glob → 정규식. `**` 는 / 를 넘고, `*` · `?` 는 / 안에서만 맞는다."""
    out, i = "", 0
    while i < len(pat):
        if pat.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pat[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pat[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pat[i]), i + 1
    return re.compile(out + r"\Z")


def git(*args):
    # 이름 바꾸기 감지를 끄고 -z 로 받는다 — 옛 경로 · 비ASCII 경로가 목록에서 빠지지 않게(non-obvious-patterns)
    r = subprocess.run(["git", "-c", "core.quotePath=false", *args], capture_output=True, text=True)
    return r.returncode, [x for x in r.stdout.split("\0") if x]


def read_table(path):
    groups, rows = {}, []
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            continue
        pat, _, toks = line.partition("\t")
        if pat.startswith("@"):
            groups[pat] = toks.split()
        else:
            rows.append((glob_re(pat), toks.split()))
    return groups, rows


def main(argv):
    since, table, tdir = argv
    rc, _ = git("rev-parse", "--verify", "-q", since + "^{commit}")
    if rc != 0:
        print(f"all\t커밋을 읽을 수 없다: {since}")
        return 0
    _, tracked = git("diff", "--no-renames", "--name-only", "-z", since)
    _, untracked = git("ls-files", "-o", "--exclude-standard", "-z")
    changed = sorted(set(tracked) | set(untracked))
    if not changed:
        print("all\t바뀐 파일 0개")
        return 0
    groups, rows = read_table(table)
    tests = sorted(f for f in os.listdir(tdir) if f.endswith(".sh"))
    body = {f: open(os.path.join(tdir, f), encoding="utf-8").read() for f in tests}

    class Typo(Exception):
        pass

    def expand(tok, f, seen=()):
        if tok.startswith("@"):
            if tok not in groups:
                raise Typo(f"표의 모르는 묶음: {tok}")
            return {x for t in groups[tok] if t not in seen for x in expand(t, f, seen + (tok,))}
        if tok == "{self}":
            return {"tests/" + os.path.basename(f)} if os.path.basename(f) in body else set()
        if tok == "{mentions}":
            return {"tests/" + t for t in tests if os.path.basename(f) in body[t]}
        if tok.startswith("tests/"):
            hit = fnmatch.filter(tests, tok[len("tests/"):])
            if not hit:
                raise Typo(f"표의 tests 묶음이 아무 파일에도 안 맞는다: {tok}")
            return {"tests/" + t for t in hit}
        if tok in ("main", "runner", "all"):
            return {tok}
        raise Typo(f"표의 모르는 묶음: {tok}")

    picked = set()
    for f in changed:
        got, hit = set(), False
        for pat, toks in rows:
            if pat.match(f):
                hit = True
                try:
                    got |= {x for t in toks for x in expand(t, f)}
                except Typo as e:
                    print(f"all\t{e}")
                    return 0
        if not hit:
            print(f"all\t표에 없는 파일: {f}")
            return 0
        if not got:
            print(f"all\t묶음이 비는 파일: {f}")
            return 0
        picked |= got
    if "all" in picked:
        print("all\t표가 전부를 고른 파일이 있다")
        return 0
    print(f"pick\t바뀐 파일 {len(changed)}개")
    for x in sorted(picked):
        print(x)
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1:]))
