#!/usr/bin/env python3
"""phases/*/index.json 전체 현황과 실행 전 점검. 읽기만 한다.

정본은 phase별 index.json 하나다. 상위 phases/index.json 은 만들지 않는다(2026-10-13 결정 —
상태가 두 곳에 적히면 어긋난다). 같은 PRD 묶음은 `docs`, 선행 phase 는 `after` 로 안다.

Usage:
    phases_status.py                 # 전체 현황 (docs 로 묶고 after 순서로)
    phases_status.py --check TASK    # TASK 를 돌려도 되나. 문제가 있으면 exit 1
"""
import json
import subprocess
import sys
from pathlib import Path

VALID = {"pending", "completed", "error", "blocked"}


def repo_root() -> Path:
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    return Path(r.stdout.strip()) if r.returncode == 0 and r.stdout.strip() else Path.cwd()


def load(phases_dir: Path) -> dict:
    out = {}
    for f in sorted(phases_dir.glob("*/index.json")):
        try:
            out[f.parent.name] = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as e:
            out[f.parent.name] = {"_error": f"index.json 을 읽지 못함: {e}"}
    return out


def problems_of(name: str, idx: dict, phases: dict) -> list:
    if "_error" in idx:
        return [idx["_error"]]
    probs = []
    for s in idx.get("steps", []):
        st = s.get("status")
        if st not in VALID:
            probs.append(f"step {s.get('step')} status '{st}' — 허용 값은 {'·'.join(sorted(VALID))}")
    for dep in idx.get("after", []) or []:
        if dep not in phases:
            probs.append(f"after '{dep}' — 그런 phase 가 없다")
        elif not is_done(phases[dep]):
            probs.append(f"after '{dep}' — 아직 completed 가 아니다")
    return probs


def is_done(idx: dict) -> bool:
    steps = idx.get("steps", [])
    return bool(steps) and all(s.get("status") == "completed" for s in steps)


def ordered(names: list, phases: dict) -> list:
    """after 를 따라 선행이 먼저 오게. 순환·묶음 밖 선행은 무시하고 이름순으로 둔다."""
    seen, out = set(), []

    def visit(n, stack):
        if n in seen or n in stack:
            return
        for dep in phases.get(n, {}).get("after", []) or []:
            if dep in names:
                visit(dep, stack | {n})
        seen.add(n)
        out.append(n)

    for n in sorted(names):
        visit(n, set())
    return out


def overview(phases: dict) -> int:
    if not phases:
        print("phases/ 아래에 index.json 이 없다")
        return 0
    groups = {}
    for name, idx in phases.items():
        groups.setdefault(idx.get("docs") or "(docs 없음)", []).append(name)
    for docs in sorted(groups):
        print(docs)
        for n in ordered(groups[docs], phases):
            idx = phases[n]
            steps = idx.get("steps", [])
            done = sum(1 for s in steps if s.get("status") == "completed")
            after = idx.get("after") or []
            mark = "✓" if is_done(idx) else "…"
            probs = problems_of(n, idx, phases)
            line = f"  {mark} {n} {done}/{len(steps)}"
            if after:
                line += f"  (after: {', '.join(after)})"
            print(line)
            for p in probs:
                print(f"      ⚠ {p}")
    return 0


def check(task: str, phases: dict) -> int:
    if task not in phases:
        print(f"phases/{task}/index.json 이 없다")
        return 1
    probs = problems_of(task, phases[task], phases)
    if probs:
        print(f"{task} 을(를) 돌리지 않는다:")
        for p in probs:
            print(f"  - {p}")
        return 1
    print(f"{task}: 점검 통과")
    return 0


def main(argv: list) -> int:
    phases = load(repo_root() / "phases")
    if len(argv) >= 2 and argv[0] == "--check":
        return check(argv[1], phases)
    return overview(phases)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
