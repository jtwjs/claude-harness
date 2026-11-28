#!/usr/bin/env python3
"""doctor §9 자동 범위 — 쌓인 양 장치가 켜진 날 첫 세션에 볼 문서 목록을 고른다(ADR-021 Q4 B).

범위는 셋이다.
  1. CLAUDE.md
  2. paths 없는 .claude/rules/**/*.md (Claude Code 가 늘 띄운다)
  3. 마지막 CLAUDE.md · rules 커밋 뒤 바뀐 파일에 paths 가 걸리는 rules
모델이 아니라 이 스크립트가 고른다. 합계 바이트가 상한을 넘으면 3을 큰 파일부터 빼고, 뺀 rules 이름을 마지막 줄로 남긴다.
1 · 2 는 상한을 넘어도 늘 넣는다(ADR 범위 정의). 그때는 넘었다는 사실을 마지막 줄로 남긴다.

쓰는 법: doc_scope.py <레포 루트> <상한 바이트>  → 고른 파일 경로(넘긴 레포 루트 기준)를 한 줄씩
"""
import pathlib
import re
import subprocess
import sys

UNKNOWN = re.compile(r"[{}\[\]!]")   # 중괄호 · 문자 묶음 · 부정은 읽지 않는다 → 그 rules 는 늘 넣는다(빠뜨리는 것보다 싸다)
UNPARSED = "[해석 못 함]"   # 앞머리를 확실히 못 읽은 표시. known() 이 거르므로 그 rules 는 늘 넣는다


def known(pat):
    # 앞의 ./ · / 나 끝의 / 는 Claude Code 가 어떻게 맞추는지 확인하지 않았다 → 모르는 꼴로 보낸다
    return not (UNKNOWN.search(pat) or pat.startswith(("./", "/")) or pat.endswith("/"))


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


QUOTED = re.compile(r"""\s*(?:"([^"]*)"|'([^']*)')\s*(?:#.*)?$""")   # 따옴표 값 하나 + 뒤 주석만 허용


def _item(raw):
    """목록 항목 하나. 따옴표가 있으면 그 안, 없으면 ` #` 앞까지. 읽을 수 없으면 None."""
    m = QUOTED.match(raw)
    if m:
        return m.group(1) if m.group(1) is not None else m.group(2)
    if raw.lstrip()[:1] in ("'", '"', "[", "{"):
        return None
    v = re.sub(r"\s+#.*$", "", raw).strip()
    return v or None


def read_paths(text):
    """앞머리의 paths 목록.
    앞머리나 paths 가 없거나 비었으면 None(= 늘 뜬다). 따옴표 인라인 배열과 목록 꼴만 읽는다.
    그 밖의 꼴(스칼라 · 여러 줄 배열 · 따옴표 없는 배열 항목 등)은 [UNPARSED] — 빠뜨리지 않게 늘 넣는 쪽으로 보낸다."""
    lines = text.lstrip("﻿").splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    head = []
    for ln in lines[1:]:
        if ln.strip() == "---":
            break
        head.append(ln)
    for n, ln in enumerate(head):
        m = re.match(r"paths\s*:(.*)$", ln)
        if not m:
            continue
        rest = m.group(1).strip()
        if rest.startswith("["):
            body = re.match(r"\[(.*)\]\s*(?:#.*)?$", rest)
            if not body:
                return [UNPARSED]
            got = []
            for raw in body.group(1).split(","):
                if not raw.strip():
                    continue
                q = QUOTED.match(raw)
                if not q:
                    return [UNPARSED]
                got.append(q.group(1) if q.group(1) is not None else q.group(2))
            return got or None
        if rest and not rest.startswith("#"):
            return [UNPARSED]
        got = []
        for item in head[n + 1:]:
            if not item.strip() or item.strip().startswith("#"):
                continue
            im = re.match(r"\s*-\s*(.*)$", item)
            if not im:
                if re.match(r"\S", item):   # 다음 키 — 목록 끝
                    break
                return [UNPARSED]
            v = _item(im.group(1))
            if v is None:
                return [UNPARSED]
            got.append(v)
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
    notes = []
    if size > limit:
        notes.append(f"(상한 넘음: 늘 넣는 묶음만 {size}바이트 · 상한 {limit}바이트)")
    kept, dropped = [], []
    for f in sorted(matched, key=lambda f: (f.stat().st_size, str(f))):
        if size + f.stat().st_size <= limit:
            kept.append(f)
            size += f.stat().st_size
        else:
            dropped.append(f)
    if dropped:
        names = " · ".join(str(f.relative_to(rootp)) for f in sorted(dropped))
        notes.append(f"(뺌: paths 걸린 rules {len(dropped)}개 — 상한 {limit}바이트를 넘어서: {names})")
    return [str(f) for f in always + sorted(kept)], " ".join(notes)


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
