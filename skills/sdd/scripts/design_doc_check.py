#!/usr/bin/env python3
"""설계서 칸 순서 검사 — sdd design.md 「화면」. 설계서를 화면에 열기 전에 돌린다.

Usage:
    design_doc_check.py <설계서.md>

    정본 칸 목록은 이 파일 기준 ../references/design.md 「**설계서 틀**」 줄 다음 첫 ```markdown 블록의
    ## · ### 제목 줄이다(급 + 「←」 뒤와 맨 앞 번호를 뗀 이름). 설계서의 ## · ### 제목 줄(코드 울타리 안은 뺀다)에서
    정본 칸마다 맞는 첫 제목을 찾는다. 급이 같고, 번호 뗀 제목이 칸 이름과 같거나 칸 이름 바로 뒤가 공백 · 「(」이면 맞는다.
    정본에 없는 제목은 건너뛴다. 찾은 칸들의 위치에서 가장 긴 증가 부분열에 든 칸은 통과, 안 든 칸만 순서 어긋남이다.
    제목 · 울타리 줄은 앞 공백 3칸까지 허용한다. 울타리는 연 문자와 같고 길이 이상인 줄에서만 닫는다. BOM은 무시한다.
    내용은 보지 않는다 — 제목만 있어도 그 칸은 있다.

    통과면 stdout 「칸 순서 통과: N칸」, exit 0.
    빠진 칸 · 순서 어긋남은 한 줄씩 stdout, exit 1.
    설계서를 못 읽거나 틀 블록을 못 찾으면(정본 칸 0개 포함) 이유를 stderr, exit 2.
"""
import re
import sys
from pathlib import Path

DESIGN_MD = Path(__file__).resolve().parent.parent / "references" / "design.md"
HEADING = re.compile(r"^ {0,3}(#{2,3})(?!#)\s+(.*?)\s*$")
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
NUMBER = re.compile(r"^\d+\.\s*")


def cell(line):
    """제목 줄이면 (급, 번호 뗀 이름), 아니면 None."""
    m = HEADING.match(line)
    if not m:
        return None
    name = m.group(2).split("←", 1)[0].strip()
    return len(m.group(1)), NUMBER.sub("", name)


def template_cells(text):
    lines = text.splitlines()
    start = next((i for i, l in enumerate(lines) if l.startswith("**설계서 틀**")), None)
    if start is None:
        return []
    fence = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("```")), None)
    if fence is None or lines[fence].rstrip() != "```markdown":
        return []
    cells = []
    for l in lines[fence + 1:]:
        if l.startswith("```"):
            break
        c = cell(l)
        if c:
            cells.append(c)
    return cells


def doc_headings(text):
    heads, fence = [], None   # fence: 연 울타리 (문자, 길이)
    for l in text.splitlines():
        m = FENCE.match(l)
        if fence is None:
            if m:
                fence = (m.group(1)[0], len(m.group(1)))
                continue
            c = cell(l)
            if c:
                heads.append(c)
        elif m and m.group(1)[0] == fence[0] and len(m.group(1)) >= fence[1] and not m.group(2).strip():
            fence = None
    return heads


def hit(c, h):
    if h[0] != c[0] or not h[1].startswith(c[1]):
        return False
    rest = h[1][len(c[1]):]
    return not rest or rest[0].isspace() or rest[0] == "("


def longest_increasing(found):
    """found: [(칸 순번, 위치)] — 위치가 증가하는 가장 긴 부분열의 칸 순번 집합."""
    best = [1] * len(found)
    prev = [-1] * len(found)
    for i in range(len(found)):
        for j in range(i):
            if found[j][1] < found[i][1] and best[j] + 1 > best[i]:
                best[i], prev[i] = best[j] + 1, j
    keep, i = set(), max(range(len(found)), key=best.__getitem__, default=-1)
    while i >= 0:
        keep.add(found[i][0])
        i = prev[i]
    return keep


def check(cells, heads):
    pos = [next((i for i, h in enumerate(heads) if hit(c, h)), None) for c in cells]
    keep = longest_increasing([(k, p) for k, p in enumerate(pos) if p is not None])
    problems = []
    for k, c in enumerate(cells):
        if pos[k] is None:
            problems.append(f"빠진 칸: {c[1]}")
        elif k not in keep:
            problems.append(f"순서 어긋남: {c[1]}")
    return problems


def main(argv):
    if len(argv) != 2:
        print("사용법: design_doc_check.py <설계서.md>", file=sys.stderr)
        return 2
    try:
        doc = Path(argv[1]).read_text(encoding="utf-8-sig")
    except OSError as e:
        print(f"설계서를 못 읽음: {argv[1]} ({e.strerror})", file=sys.stderr)
        return 2
    try:
        cells = template_cells(DESIGN_MD.read_text(encoding="utf-8-sig"))
    except OSError:
        cells = []
    if not cells:
        print(f"틀 블록을 못 찾음: {DESIGN_MD}", file=sys.stderr)
        return 2
    problems = check(cells, doc_headings(doc))
    if problems:
        print("\n".join(problems))
        return 1
    print(f"칸 순서 통과: {len(cells)}칸")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
