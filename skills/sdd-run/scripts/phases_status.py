#!/usr/bin/env python3
"""phases/*/index.json 전체 현황과 실행 전 점검. 읽기만 한다.

정본은 phase별 index.json 하나다. 상위 phases/index.json 은 만들지 않는다(2026-10-13 결정 —
상태가 두 곳에 적히면 어긋난다). 같은 PRD 묶음은 `docs`, 선행 phase 는 `after` 로 안다.

Usage:
    phases_status.py                 # 전체 현황 (docs 로 묶고 after 순서로)
    phases_status.py --check TASK    # TASK 를 돌려도 되나. 문제가 있으면 exit 1
    phases_status.py --retro TASK    # 회고용 숫자 — step별 결과·재시도·소요 + 합계 한 줄 (sdd REFLECT 회고 1장)
"""
import json
import re
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


DONE = {"completed", "done"}  # done 은 허용 밖이지만 옛 기록에 있어 회고 집계에선 완료로 센다


def parse_ts(v):
    """'2026-10-16T18:23:15+0900' · '+09:00' · 'Z' 를 초 단위 epoch 로. python 3.9 fromisoformat 은 +0900 을 못 읽는다."""
    from datetime import datetime, timedelta, timezone
    if not isinstance(v, str):
        return None
    m = re.match(r"(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$", v.strip())
    if not m:
        return None
    dt = datetime.strptime(f"{m.group(1)} {m.group(2)}", "%Y-%m-%d %H:%M:%S")
    tz = m.group(3)
    if tz and tz != "Z":
        sign = 1 if tz[0] == "+" else -1
        hh, mm = int(tz[1:3]), int(tz[-2:])
        dt = dt.replace(tzinfo=timezone(sign * timedelta(hours=hh, minutes=mm)))
    else:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.timestamp()


def fmt_dur(sec):
    if sec is None:
        return "-"
    m = int(round(sec / 60))
    return f"{m // 60}h{m % 60:02d}m" if m >= 60 else f"{m}m"


def retro_rows(idx: dict) -> tuple:
    """(step별 행, 합계 dict). 소요는 step 자기 started_at→completed_at(겹쳐 실행돼도 맞다). 없으면 None."""
    rows, tot = [], {"steps": 0, "done": 0, "retries": 0, "stuck": 0, "sec": 0.0, "timed": 0}
    for s in idx.get("steps", []):
        st = s.get("status")
        if st == "obsolete":
            continue
        r = s.get("retries")
        retries = r if isinstance(r, int) else len(s.get("attempts") or [])
        a, b = parse_ts(s.get("started_at")), parse_ts(s.get("completed_at"))
        sec = b - a if a is not None and b is not None and b >= a else None
        rows.append((s.get("step"), s.get("name") or "", st, retries, sec))
        tot["steps"] += 1
        tot["done"] += st in DONE
        tot["retries"] += retries
        tot["stuck"] += st in ("error", "blocked")
        if sec is not None:
            tot["sec"] += sec
            tot["timed"] += 1
    return rows, tot


def retro(task: str, phases: dict) -> int:
    if task not in phases or "_error" in phases[task]:
        print(f"phases/{task}/index.json 이 없다")
        return 1
    rows, t = retro_rows(phases[task])
    print("| step | 이름 | 결과 | 재시도 | 소요 |")
    print("|---|---|---|---|---|")
    for n, name, st, rt, sec in rows:
        print(f"| {n} | {name} | {st} | {rt} | {fmt_dur(sec)} |")
    total = fmt_dur(t["sec"]) if t["timed"] else "-"
    print()
    print(f"step {t['steps']} · 완료 {t['done']} · 재시도 {t['retries']} · error/blocked {t['stuck']} · 소요 {total}")
    if t["timed"] < t["steps"]:
        print(f"(소요는 시작·완료 시각이 둘 다 있는 step {t['timed']}개만 합산. 겹쳐 실행된 step 은 각각 센다)")
    return 0


def main(argv: list) -> int:
    phases = load(repo_root() / "phases")
    if len(argv) >= 2 and argv[0] == "--check":
        return check(argv[1], phases)
    if len(argv) >= 2 and argv[0] == "--retro":
        return retro(argv[1], phases)
    return overview(phases)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
