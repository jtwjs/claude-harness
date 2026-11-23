#!/usr/bin/env python3
"""task-observer 전역 후보 — 재료 추리기(gather) · 설정(config).

정본: docs/observer-global-ledger-2026-11-23/ARCHITECTURE.md
- config: 설정 파일의 ledger 경로를 한 줄로. 없음 · 깨짐 · 칸 없음이면 빈 출력 exit 0.
- gather --days N: 지난 N일 대화 기록에서 레포별 재료 JSON 을 stdout 에. 아무 파일도 쓰지 않는다.

표준 라이브러리만 쓴다.
"""
import datetime as dt
import glob
import json
import os
import re
import subprocess
import sys
from pathlib import Path

USER_MAX_CHARS = 400
USER_MAX_ITEMS = 150
BASH_MAX_CHARS = 200
BASH_MAX_ITEMS = 150
REASON_MAX_CHARS = 200
GLOBAL_SCOPE = "전역 후보"


# ── config ──────────────────────────────────────────────────────────────
def _config_file() -> Path:
    env = os.environ.get("CLAUDE_TASK_OBSERVER_CONFIG")
    return Path(env) if env else Path.home() / ".claude" / "task-observer.json"


def ledger_path():
    """설정의 ledger 경로(~ 펼침). 없음 · 깨짐 · 칸 없음이면 None."""
    try:
        data = json.loads(_config_file().read_text(encoding="utf-8"))
    except Exception:
        return None
    if not isinstance(data, dict):
        return None
    v = data.get("ledger")
    if not isinstance(v, str) or not v.strip():
        return None
    return Path(os.path.expanduser(v.strip()))


# ── 시간 ────────────────────────────────────────────────────────────────
def _parse_ts(s):
    if not isinstance(s, str) or not s:
        return None
    try:
        t = dt.datetime.fromisoformat(s.strip().replace("Z", "+00:00"))
    except ValueError:
        return None
    if t.tzinfo is None:
        t = t.astimezone()
    return t


def _now():
    t = _parse_ts(os.environ.get("TASK_OBSERVER_NOW", ""))
    return t if t else dt.datetime.now().astimezone()


# ── 레포 식별 ───────────────────────────────────────────────────────────
_repo_cache = {}


def _repo_of(cwd):
    """cwd → (공통 git 디렉터리, 레포 이름, toplevel) 또는 None. 결과는 캐시."""
    if cwd in _repo_cache:
        return _repo_cache[cwd]
    res = None
    if isinstance(cwd, str) and cwd and os.path.isdir(cwd):
        try:
            p = subprocess.run(
                ["git", "-C", cwd, "rev-parse", "--path-format=absolute",
                 "--git-common-dir", "--show-toplevel"],
                capture_output=True, text=True, timeout=10)
            lines = p.stdout.splitlines() if p.returncode == 0 else []
            if lines:
                common = os.path.realpath(lines[0])
                top = os.path.realpath(lines[1]) if len(lines) > 1 else None
                base = os.path.basename(common)
                name = os.path.basename(os.path.dirname(common)) if base == ".git" else base
                res = (common, name, top)
        except Exception:
            res = None
    _repo_cache[cwd] = res
    return res


# ── 대화 기록 줄 ────────────────────────────────────────────────────────
def _user_texts(msg):
    content = msg.get("content") if isinstance(msg, dict) else None
    if isinstance(content, str):
        return [content]
    out = []
    if isinstance(content, list):
        for c in content:
            if isinstance(c, dict) and c.get("type") == "text" and isinstance(c.get("text"), str):
                out.append(c["text"])
    return out


def _bash_cmds(msg):
    content = msg.get("content") if isinstance(msg, dict) else None
    out = []
    if isinstance(content, list):
        for c in content:
            if (isinstance(c, dict) and c.get("type") == "tool_use" and c.get("name") == "Bash"
                    and isinstance(c.get("input"), dict)
                    and isinstance(c["input"].get("command"), str)):
                out.append(c["input"]["command"])
    return out


def _first_line(s):
    for line in s.splitlines():
        if line.strip():
            return line.strip()
    return ""


# ── observations.md ─────────────────────────────────────────────────────
def _cells(line):
    s = line.strip()
    if not s.startswith("|"):
        return None
    s = s[1:-1] if s.endswith("|") else s[1:]
    return [c.strip() for c in re.split(r"(?<!\\)\|", s)]


def _observations(top, since_date, now_date):
    path = os.path.join(top, ".claude", "observations.md")
    try:
        text = Path(path).read_text(encoding="utf-8")
    except Exception:
        return []
    rows, header, in_open = [], None, False
    for line in text.splitlines():
        if line.startswith("## "):
            if in_open:
                break
            in_open = line[3:].strip() == "열린 것"
            continue
        if not in_open:
            continue
        cells = _cells(line)
        if cells is None:
            if header is not None:
                break  # 표가 끝남
            continue
        if header is None:
            header = cells
            continue
        if all(re.fullmatch(r":?-+:?", c or "-") for c in cells):
            continue  # 구분선
        if "범위" not in header or "마지막" not in header:
            return []  # 범위 칸 없는 옛 표
        row = dict(zip(header, cells))
        if row.get("범위") != GLOBAL_SCOPE:
            continue
        try:
            last = dt.date.fromisoformat(row.get("마지막", "").strip())
        except ValueError:
            continue
        if since_date <= last <= now_date:
            rows.append(row)
    return rows


# ── phases 미위임 ───────────────────────────────────────────────────────
def _undelegated(top):
    out = []
    for f in sorted(glob.glob(os.path.join(top, "phases", "*", "index.json"))):
        try:
            data = json.loads(Path(f).read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(data, dict) or not isinstance(data.get("steps"), list):
            continue
        phase = data.get("phase") if isinstance(data.get("phase"), str) else os.path.basename(os.path.dirname(f))
        for s in data["steps"]:
            if not isinstance(s, dict):
                continue
            retries = s.get("retries")
            many = isinstance(retries, int) and not isinstance(retries, bool) and retries >= 3
            if s.get("status") != "blocked" and not many:
                continue
            reason = s.get("blocked_reason") or s.get("last_error") or s.get("error_message") or ""
            out.append({"phase": phase, "step": s.get("step"), "name": s.get("name"),
                        "reason": str(reason)[:REASON_MAX_CHARS]})
    return out


# ── gather ──────────────────────────────────────────────────────────────
def _projects_dir() -> Path:
    env = os.environ.get("CLAUDE_TASK_OBSERVER_PROJECTS")
    return Path(env) if env else Path.home() / ".claude" / "projects"


def gather(days: int) -> dict:
    now = _now()
    since = now - dt.timedelta(days=days)
    repos = {}  # common → {name, tops, sessions, user[(ts,text)], bash[(ts,cmd)]}

    for f in sorted(glob.glob(str(_projects_dir() / "*" / "*.jsonl"))):
        try:
            if os.path.getmtime(f) < since.timestamp():
                continue
            fh = open(f, encoding="utf-8", errors="replace")
        except OSError:
            continue
        with fh:
            for raw in fh:
                try:
                    d = json.loads(raw)
                except ValueError:
                    continue
                if not isinstance(d, dict) or d.get("isSidechain") or d.get("isMeta"):
                    continue
                t = _parse_ts(d.get("timestamp"))
                if t is None or not (since <= t <= now):
                    continue
                kind = d.get("type")
                if kind not in ("user", "assistant"):
                    continue
                info = _repo_of(d.get("cwd"))
                if info is None:
                    continue
                common, name, top = info
                r = repos.setdefault(common, {"name": name, "tops": set(), "sessions": set(),
                                              "user": [], "bash": []})
                if top:
                    r["tops"].add(top)
                r["sessions"].add(t.astimezone(now.tzinfo).date().isoformat())
                if kind == "user":
                    for text in _user_texts(d.get("message")):
                        s = text.strip()
                        if s and not s.startswith("<"):
                            r["user"].append((t, s[:USER_MAX_CHARS]))
                else:
                    for cmd in _bash_cmds(d.get("message")):
                        s = _first_line(cmd)
                        if s:
                            r["bash"].append((t, s[:BASH_MAX_CHARS]))

    out = []
    for r in repos.values():
        obs, und = [], []
        for top in sorted(r["tops"]):
            for row in _observations(top, since.date(), now.date()):
                if row not in obs:
                    obs.append(row)
            for u in _undelegated(top):
                if u not in und:
                    und.append(u)
        user = [x for _, x in sorted(r["user"], key=lambda p: p[0])][-USER_MAX_ITEMS:]
        bash = [x for _, x in sorted(r["bash"], key=lambda p: p[0])][-BASH_MAX_ITEMS:]
        out.append({"name": r["name"], "sessions": sorted(r["sessions"]), "user": user,
                    "bash": bash, "observations": obs, "undelegated": und})
    out.sort(key=lambda x: x["name"])
    return {"days": days, "since": since.isoformat(), "now": now.isoformat(), "repos": out}


# ── CLI ─────────────────────────────────────────────────────────────────
def main(argv) -> int:
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "config":
        p = ledger_path()
        if p is not None:
            print(p)
        return 0
    if cmd == "gather":
        days = 7
        rest = argv[2:]
        if rest[:1] == ["--days"] and len(rest) > 1:
            try:
                days = max(1, int(rest[1]))
            except ValueError:
                print("observer: --days 는 양의 정수", file=sys.stderr)
                return 2
        try:
            result = gather(days)
        except Exception as e:  # 어떤 입력에도 traceback 없이
            print("observer: gather 실패 — %s" % e, file=sys.stderr)
            result = {"days": days, "repos": []}
        print(json.dumps(result, ensure_ascii=False, indent=1))
        return 0
    print("사용: observer.py config | gather [--days N]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
