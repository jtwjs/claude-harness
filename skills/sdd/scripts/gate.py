#!/usr/bin/env python3
"""구현 시작 관문 — DOCS_DIR 의 ADR.md · PRD.md 에 열린 「정할 것」이 있으면 목록 + 종료 2.

설계 결정이 다 나기 전에 계획 · 구현을 시작하지 않게 한다(ADR-022 D6 3번 · ADR-023 R1 · R2).
러너(sdd-run)에서 옮겼다(ADR-028). 읽기만 한다.

  python3 gate.py DOCS_DIR      상대 경로는 레포 루트 기준

종료 코드: 0 열린 것 없음(ADR · PRD 가 없을 때 포함) · 2 열린 「정할 것」 있음

세는 것:
  ADR.md  제목에 「결정할 것」이 든 절 안의 표에서 주체 칸이 빈 행. 주체 칸이 없는 표는 모든 행
  PRD.md  「남은 ⚠️」 제목 절 또는 불렛 라벨 아래 첫 단 항목. 「→ 결정:」 · 「막지 않음:」 · 「없음」 항목은 뺀다
"""
import re
import subprocess
import sys
from pathlib import Path

_LIST_ITEM = r"(?:[-*+]|\d+[.)])"   # 불렛 · 번호 목록
_OPEN_MARK = "남은 ⚠"   # 변이 선택자(U+FE0F) 있든 없든


def _md_heading(ln: str):
    m = re.match(r"^(#+)\s+(.*)$", ln)
    return (len(m.group(1)), m.group(2)) if m else None


def _cells(ln: str) -> list:
    """표 한 줄의 칸 — 셀 안 `\\|` 는 칸 나눔이 아니다."""
    parts = re.split(r"(?<!\\)\|", ln.strip())
    if parts and not parts[0].strip():
        parts = parts[1:]
    if parts and not parts[-1].strip():
        parts = parts[:-1]
    return [c.strip() for c in parts]


def _prd_open(t: str) -> bool:
    return "→ 결정:" not in t and "막지 않음:" not in t and not re.match(r"없음(?:$|[\s(])", t)


def _adr_open(text: str) -> list:
    out = []
    level, header, owner = None, None, None   # 「결정할 것」 절 급 · 지금 표 머리 · 주체 칸 번호
    for ln in text.splitlines():
        h = _md_heading(ln)
        if h:
            if level is not None and h[0] <= level:
                level = None
            if "결정할 것" in h[1]:
                level = h[0]
            header = None
            continue
        if level is None:
            continue
        if not ln.lstrip().startswith("|"):
            header = None
            continue
        cells = _cells(ln)
        if header is None:
            header = cells
            owner = next((i for i, c in enumerate(cells) if "주체" in c), None)
            continue
        if all(re.fullmatch(r":?-+:?", c) for c in cells if c):
            continue
        if owner is None or owner >= len(cells) or not cells[owner]:
            out.append(f"ADR {cells[0]}: {cells[1] if len(cells) > 1 else ''}".rstrip())
    return out


def _prd_open_items(text: str) -> list:
    out = []
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        ln = lines[i]
        h = _md_heading(ln)
        label = re.match(rf"^(\s*){_LIST_ITEM}\s+(?:\*\*)?{_OPEN_MARK}️?(?:\*\*)?(.*)$", ln)
        if h and _OPEN_MARK in h[1]:
            j = i + 1
            while j < len(lines) and not ((hh := _md_heading(lines[j])) and hh[0] <= h[0]):
                j += 1
        elif label:
            ind = len(label.group(1))
            inline = re.sub(r"^[\s*:：—–-]+", "", label.group(2)).strip()   # 라벨 줄에 붙여 쓴 내용 — 앞 ** · : · 줄표는 벗긴다
            if inline and not inline.startswith("(") and _prd_open(inline):
                out.append(f"PRD: {inline}")
            j = i + 1
            while j < len(lines) and (not lines[j].strip() or len(lines[j]) - len(lines[j].lstrip()) > ind):
                j += 1
        else:
            i += 1
            continue
        bullets = [(len(m.group(1)), m.group(2)) for m in
                   (re.match(rf"^(\s*){_LIST_ITEM}\s+(.*?)\s*$", x) for x in lines[i + 1:j]) if m]
        top = min((b[0] for b in bullets), default=0)
        out += [f"PRD: {t}" for k, t in bullets if k == top and _prd_open(t)]   # 「- 없음 (…)」은 항목 없음 표시
        i = j
    return out


def open_decisions(docs_dir) -> list:
    d = Path(docs_dir)
    out = []
    if (d / "ADR.md").is_file():
        out += _adr_open((d / "ADR.md").read_text(encoding="utf-8"))
    if (d / "PRD.md").is_file():
        out += _prd_open_items((d / "PRD.md").read_text(encoding="utf-8"))
    return out


def main(argv) -> int:
    if len(argv) != 1:
        print("사용: gate.py DOCS_DIR", file=sys.stderr)
        return 2
    d = Path(argv[0])
    if not d.is_absolute():
        r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        d = (Path(r.stdout.strip()) if r.returncode == 0 else Path.cwd()) / d
    if not (d / "ADR.md").is_file() and not (d / "PRD.md").is_file():
        print(f"구현 시작 관문: ADR · PRD 없음 — 막지 않는다 ({d})")   # 경로 오타와 가를 수 있게
        return 0
    items = open_decisions(d)
    if not items:
        print("구현 시작 관문: 열린 「정할 것」 0")
        return 0
    print(f"구현 시작 관문: 열린 「정할 것」 {len(items)}개 — 지휘(또는 사람)에게 묻고 닫은 뒤 다시")
    for it in items:
        print(f"  - {it}")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
