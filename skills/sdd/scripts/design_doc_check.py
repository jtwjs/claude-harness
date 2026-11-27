#!/usr/bin/env python3
"""설계서 칸 순서 검사 — sdd design.md 「화면」. 설계서를 화면에 열기 전에 돌린다.

Usage:
    design_doc_check.py <설계서.md>

    정본 칸 목록은 이 파일 기준 ../references/design.md 「**설계서 틀**」 줄 다음 첫 ```markdown 블록의
    ## · ### 제목 줄이다(급 + 「←」 뒤와 맨 앞 번호를 뗀 이름). 설계서의 ## · ### 제목 줄(코드 울타리 안은 뺀다)에서
    정본 칸을 순서대로 찾는다. 급이 같고 번호 뗀 제목이 칸 이름으로 시작하면 맞는다. 정본에 없는 제목은 건너뛴다.
    내용은 보지 않는다 — 제목만 있어도 그 칸은 있다.

    통과면 stdout 「칸 순서 통과: N칸」, exit 0.
    빠진 칸 · 순서 어긋남은 한 줄씩 stdout, exit 1.
    설계서를 못 읽거나 틀 블록을 못 찾으면(정본 칸 0개 포함) 이유를 stderr, exit 2.
"""
import re
import sys
from pathlib import Path

DESIGN_MD = Path(__file__).resolve().parent.parent / "references" / "design.md"
HEADING = re.compile(r"^(#{2,3})(?!#)\s+(.*?)\s*$")
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
    heads, fenced = [], False
    for l in text.splitlines():
        if l.startswith("```") or l.startswith("~~~"):
            fenced = not fenced
            continue
        if not fenced:
            c = cell(l)
            if c:
                heads.append(c)
    return heads


def check(cells, heads):
    def hit(c, h):
        return h[0] == c[0] and h[1].startswith(c[1])

    problems, pos = [], -1
    for c in cells:
        after = next((i for i in range(pos + 1, len(heads)) if hit(c, heads[i])), None)
        if after is not None:
            pos = after
        elif any(hit(c, h) for h in heads[:pos + 1]):
            problems.append(f"순서 어긋남: {c[1]}")
        else:
            problems.append(f"빠진 칸: {c[1]}")
    return problems


def main(argv):
    if len(argv) != 2:
        print("사용법: design_doc_check.py <설계서.md>", file=sys.stderr)
        return 2
    try:
        doc = Path(argv[1]).read_text(encoding="utf-8")
    except OSError as e:
        print(f"설계서를 못 읽음: {argv[1]} ({e.strerror})", file=sys.stderr)
        return 2
    try:
        cells = template_cells(DESIGN_MD.read_text(encoding="utf-8"))
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
