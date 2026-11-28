#!/usr/bin/env python3
"""doctor §9 자동 범위 — 쌓인 양 장치가 켜진 날 첫 세션에 볼 문서 목록을 고른다(ADR-021 Q4 B).

범위는 셋이다.
  1. CLAUDE.md
  2. paths 없는 .claude/rules/**/*.md (Claude Code 가 늘 띄운다)
  3. 마지막 CLAUDE.md · rules 커밋 뒤 바뀐 파일에 paths 가 걸리는 rules
모델이 아니라 이 스크립트가 고른다. 합계 바이트가 상한을 넘으면 3을 큰 파일부터 빼고, 뺀 수를 마지막 줄로 남긴다.

쓰는 법: doc_scope.py <레포 루트> <상한 바이트>  → 고른 파일 절대 경로를 한 줄씩
"""
import pathlib
import re
import subprocess
import sys

UNKNOWN = re.compile(r"[{}\[\]!]")   # 중괄호 · 문자 묶음 · 부정은 읽지 않는다 → 그 rules 는 늘 넣는다(빠뜨리는 것보다 싸다)


def known(pat):
    return not UNKNOWN.search(pat)


def glob_re(pat):
    """Claude Code paths 꼴: `**/` 는 0개 이상 폴더, 끝의 `**` 는 아래 전부, `*` · `?` 는 / 안에서만."""
    out, i = "", 0
    while i < len(pat):
        if pat.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pat.startswith("**", i):
            out, i = out + ".*", i + 2
        elif pat[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pat[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pat[i]), i + 1
    return re.compile(out + r"\Z")


def read_paths(text):
    """앞머리의 paths 목록. 앞머리나 paths 가 없거나 비었으면 None(= 늘 뜬다). 인라인 배열 · 목록 꼴만 읽는다."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    head = []
    for ln in lines[1:]:
        if ln.strip() == "---":
            break
        head.append(ln)
    for n, ln in enumerate(head):
        m = re.match(r"paths:\s*(.*)$", ln)
        if not m:
            continue
        rest = re.sub(r"\s+#.*$", "", m.group(1)).strip()
        if rest.startswith("["):
            got = re.findall(r"""["']([^"']+)["']""", rest)
        else:
            got = []
            for item in head[n + 1:]:
                im = re.match(r"\s+-\s*(.+)$", item)
                if not im:
                    break
                got.append(im.group(1).strip().strip("\"'"))
        return got or None
    return None


def git(root, *args):
    r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def changed(root):
    anchor = git(root, "log", "-1", "--format=%H", "--", "CLAUDE.md", ".claude/rules/").strip()
    if not anchor:
        return []
    # 이름 바꾸기 감지를 끄고 -z 로 받는다 — 옛 경로 · 비ASCII 경로가 빠지지 않게(non-obvious-patterns)
    out = git(root, "-c", "core.quotePath=false", "diff", "--no-renames", "--name-only", "-z", anchor, "HEAD")
    return [p for p in out.split("\0") if p]


def pick(root, limit):
    rootp = pathlib.Path(root)
    always, matched = [], []
    if (rootp / "CLAUDE.md").is_file():
        always.append(rootp / "CLAUDE.md")
    files = changed(root)
    rules = rootp / ".claude" / "rules"
    for f in sorted(rules.rglob("*.md")) if rules.is_dir() else []:
        pats = read_paths(f.read_text(encoding="utf-8", errors="replace"))
        if pats is None or not all(known(p) for p in pats):
            always.append(f)
        elif any(glob_re(p).match(x) for p in pats for x in files):
            matched.append(f)
    # 앞의 둘은 늘 넣는다. 셋째 묶음은 작은 파일부터 상한 안에 드는 만큼만 넣는다(통째로 빼면 템플릿 레포에서 거의 늘 빈다)
    size = sum(f.stat().st_size for f in always)
    kept, dropped = [], 0
    for f in sorted(matched, key=lambda f: (f.stat().st_size, str(f))):
        if size + f.stat().st_size <= limit:
            kept.append(f)
            size += f.stat().st_size
        else:
            dropped += 1
    note = f"(뺌: paths 걸린 rules {dropped}개 — 상한 {limit}바이트를 넘어서)" if dropped else ""
    return [str(f) for f in always + sorted(kept)], note


def main():
    if len(sys.argv) != 3:
        sys.exit("쓰는 법: doc_scope.py <레포 루트> <상한 바이트>")
    got, note = pick(sys.argv[1], int(sys.argv[2]))
    for p in got:
        print(p)
    if note:
        print(note)


if __name__ == "__main__":
    main()
