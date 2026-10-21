#!/usr/bin/env python3
"""트랙 현황 — 지휘 세션이 디스패치·예외 판정 전에 보는 표 한 장. 읽기만 한다.

worktree 하나 = 트랙 작업 하나(`.claude/references/tracks.md`). worktree마다
  브랜치 → 트랙(브랜치 `feature/<트랙>-…` 로 매칭, 폴더 이름은 트랙과 다를 수 있다)
  진행   → 그 worktree 의 phases/*/index.json (phases 는 git 에 있어 worktree 마다 따로다)
  마지막 신호 → 최신 커밋 시각과 index.json 수정 시각 중 늦은 것. --stale 분(기본 30)을 넘으면 💤
  막힘   → error·blocked step
  후속 이슈 → 열린 `track:<트랙>` + `follow-up` 이슈 수(gh 실패 시 ?)
  겹침   → 기준 브랜치가 아닌 worktree 둘 이상이 같이 바꾸고 있는 파일(기준 브랜치와 갈라진 지점 이후 커밋 + 안 올린 변경).
           병합하면 충돌할 자리다. 표 아래에 파일별로 낸다(2026-10-21 병렬 PR 충돌 3건)
정렬: ⛔ → 💤 → 진행 중 → 끝남.

아이디어 출처: lcalmsky/deadhd 레인 보드(작업 × 단계 · 멈춤 감지, MIT — 코드는 가져오지 않음). 2026-10-18.

Usage:
    tracks_status.py [--stale MIN] [--no-gh] [--base BRANCH]
    tracks_status.py --compact     # 상태줄용 한 줄: 트랙 ⛔admin 💤renderer 진행1 끝1 겹침2 (gh 안 부름. 트랙 표가 없거나 worktree 1개면 빈 출력)
    --base 기본값은 origin/HEAD 가 가리키는 브랜치, 없으면 origin/main
"""
import json
import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "harness-run" / "scripts"))
import phases_status  # noqa: E402

DONE = phases_status.DONE


def sh(args, cwd=None):
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def worktrees(root: Path) -> list:
    out = sh(["git", "worktree", "list", "--porcelain"], cwd=root) or ""
    items, cur = [], {}
    for line in out.splitlines() + [""]:
        if not line:
            if cur:
                items.append(cur)
            cur = {}
        elif line.startswith("worktree "):
            cur["path"] = Path(line[9:])
        elif line.startswith("branch "):
            cur["branch"] = line[7:].replace("refs/heads/", "")
    return items


def tracks_of(root: Path) -> list:
    f = root / ".claude" / "references" / "tracks.md"
    if not f.exists():
        return []
    names = []
    for line in f.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\|\s*`([^`]+)`\s*\|", line)
        if m:
            names.append(m.group(1))
    return names


def track_for(branch: str, tracks: list) -> str:
    b = (branch or "").split("/", 1)[-1]
    for t in sorted(tracks, key=len, reverse=True):
        if b == t or b.startswith(t + "-"):
            return t
    return ""


def progress(wt: Path, track: str) -> tuple:
    """(표시 문자열, 막힘 여부, index.json 최신 mtime). 트랙 접두 phase 를 먼저, 미완료 중 최근 것."""
    phases = phases_status.load(wt / "phases")
    newest = 0.0
    cands = []
    for name, idx in phases.items():
        if "_error" in idx:
            continue
        mt = (wt / "phases" / name / "index.json").stat().st_mtime
        newest = max(newest, mt)
        steps = [s for s in idx.get("steps", []) if s.get("status") != "obsolete"]
        left = [s for s in steps if s.get("status") not in DONE]
        if left:
            cands.append((not (track and name.startswith(track + "-")), -mt, name, steps, left))
    if not cands:
        return ("—", False, newest)
    _, _, name, steps, left = sorted(cands)[0]
    done = len(steps) - len(left)
    stuck = [s for s in steps if s.get("status") in ("error", "blocked")]
    if stuck:
        return (f"⛔ {name} {done}/{len(steps)} {stuck[0].get('name', '')}", True, newest)
    return (f"◆ {name} {done}/{len(steps)} ▶ {left[0].get('name', '')}", False, newest)


def followups(root: Path, track: str):
    if not track:
        return ""
    out = sh(["gh", "issue", "list", "--label", f"track:{track}", "--label", "follow-up",
              "--state", "open", "--json", "number", "--jq", "length"], cwd=root)
    return out if out is not None and out.isdigit() else "?"


def base_ref(root: Path, argv: list) -> str:
    if "--base" in argv:
        b = argv[argv.index("--base") + 1]
        return b if b.startswith("origin/") else f"origin/{b}"
    head = sh(["git", "symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD"], cwd=root)
    return head or "origin/main"


def changed(wt: Path, base: str) -> set:
    """기준 브랜치와 갈라진 뒤 바뀐 파일 + 안 올린 변경. 기준을 못 찾으면 안 올린 변경만."""
    files = set()
    mb = sh(["git", "merge-base", base, "HEAD"], cwd=wt)
    if mb:
        files |= set((sh(["git", "diff", "--name-only", mb, "HEAD"], cwd=wt) or "").splitlines())
    for line in (sh(["git", "status", "--porcelain", "-uall"], cwd=wt) or "").splitlines():   # -uall: 새 폴더를 폴더 하나로 접지 않는다
        files.add(line[3:].split(" -> ")[-1].strip('"'))
    return {f for f in files if f}


def overlaps(by_track: dict) -> list:
    """[(파일, [worktree…])] — 트랙 worktree 둘 이상이 같이 바꾸는 파일."""
    seen = {}
    for name, files in by_track.items():
        for f in files:
            seen.setdefault(f, []).append(name)
    return sorted((f, ws) for f, ws in seen.items() if len(ws) > 1)


def ago(sec: float) -> str:
    m = int(sec // 60)
    return f"{m}분 전" if m < 120 else f"{m // 60}시간 전"


def main(argv: list) -> int:
    stale = 30
    if "--stale" in argv:
        stale = int(argv[argv.index("--stale") + 1])
    compact = "--compact" in argv
    use_gh = "--no-gh" not in argv and not compact
    root = Path(sh(["git", "rev-parse", "--show-toplevel"]) or ".")
    tracks = tracks_of(root)
    base = base_ref(root, argv)
    touched = {}
    if compact and not tracks:
        return 0
    now = time.time()
    rows = []
    for w in worktrees(root):
        wt, br = w["path"], w.get("branch", "(detached)")
        if not wt.exists():
            continue
        track = track_for(br, tracks)
        if br != base.split("/", 1)[-1]:   # 지휘가 앉은 기준 worktree 는 뺀다. 트랙 표가 없어도 본다
            touched[wt.name] = changed(wt, base)
        prog, stuck, idx_mt = progress(wt, track)
        ct = sh(["git", "log", "-1", "--format=%ct"], cwd=wt)
        last = max(float(ct) if ct else 0.0, idx_mt)
        dirty = len((sh(["git", "status", "--porcelain"], cwd=wt) or "").splitlines())
        is_stale = last and (now - last) > stale * 60 and prog != "—"
        rank = 0 if stuck else 1 if is_stale else 2 if prog != "—" else 3
        mark = "⛔" if stuck else "💤" if is_stale else "…" if prog != "—" else "✓"
        rows.append((rank, mark, track or "-", wt.name, br, prog,
                     ago(now - last) if last else "-", str(dirty),
                     followups(root, track) if use_gh else ""))
    if compact:
        rows = sorted(r for r in rows if r[2] != "-")   # 트랙에 안 걸린 worktree(지휘가 앉은 기준 브랜치)는 뺀다
        if not rows:
            return 0
        named = [f"{r[1]}{r[2]}" for r in rows if r[0] <= 1]
        counts = [f"{w}{sum(1 for r in rows if r[1] == m)}" for m, w in (("…", "진행"), ("✓", "끝")) if any(r[1] == m for r in rows)]
        ov = overlaps(touched)
        print("트랙 " + " ".join(named + counts + ([f"겹침{len(ov)}"] if ov else [])))
        return 0
    if not rows:
        print("worktree 가 없다")
        return 0
    print("| | 트랙 | worktree | 브랜치 | 진행 | 마지막 신호 | 안 올린 변경 | 후속 이슈 |")
    print("|---|---|---|---|---|---|---|---|")
    for r in sorted(rows):
        print("| " + " | ".join(r[1:]) + " |")
    print(f"\n⛔ 막힌 step · 💤 {stale}분 넘게 신호 없음 · … 진행 중 · ✓ 남은 SDD step 없음")
    ov = overlaps(touched)
    if ov:
        print(f"\n겹침 {len(ov)} — worktree 둘 이상이 같이 바꾸는 파일(기준 {base}). 병합하면 충돌한다. conductor §5")
        for f, ws in ov:
            print(f"- `{f}` — {', '.join(ws)}")
    if not tracks:
        print("(.claude/references/tracks.md 트랙 표가 없어 트랙 칸은 비어 있다)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
