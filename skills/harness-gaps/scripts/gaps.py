#!/usr/bin/env python3
"""harness-gaps 전역 후보 — 재료 추리기(gather) · 설정(config) · 원장 적재(append).

정본: docs/observer-global-ledger-2026-11-23/ARCHITECTURE.md
- config: 설정 파일의 ledger 경로를 한 줄로. 없음 · 깨짐 · 칸 없음이면 빈 출력 exit 0.
- gather --days N: 지난 N일 대화 기록에서 레포별 재료 JSON 을 stdout 에. 아무 파일도 쓰지 않는다.
- append [--dry-run] [--known NAME,...] FILE: 후보 JSON 을 검증해 원장에 상태 `후보` 행 · 월별 파일에 근거 항목.
  모든 쓰기는 여기 한 곳. 원장의 기존 바이트는 그대로 두고 새 행만 넣는다.

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
    env = os.environ.get("CLAUDE_HARNESS_GAPS_CONFIG")
    return Path(env) if env else Path.home() / ".claude" / "harness-gaps.json"


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
    t = _parse_ts(os.environ.get("HARNESS_GAPS_NOW", ""))
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
    env = os.environ.get("CLAUDE_HARNESS_GAPS_PROJECTS")
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


# ── append ──────────────────────────────────────────────────────────────
KINDS = ("재지시", "재교정", "불발", "미위임", "반복 절차")
DIRECTIONS = ("direct", "investigate", "plan")
PATTERN_MAX_CHARS = 200
CANDIDATE_STATE = "후보"
_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_ID_RE = re.compile(r"^\| F-(\d+) \|", re.M)
_TABLE_HEAD = "| ID | 패턴 |"


def _valid_date(v):
    if not isinstance(v, str) or not _DATE_RE.match(v):
        return False
    try:
        dt.date.fromisoformat(v)
    except ValueError:
        return False
    return True


def _validate(c, today):
    """후보 dict → 정규화된 dict, 또는 (None, 사유)."""
    if not isinstance(c, dict):
        return None, "후보가 객체가 아님"
    pattern = c.get("pattern")
    if not isinstance(pattern, str) or not pattern.strip():
        return None, "패턴이 비어 있음"
    pattern = pattern.strip()
    if "\n" in pattern or "\r" in pattern:
        return None, "패턴이 여러 줄"
    if len(pattern) > PATTERN_MAX_CHARS:
        return None, "패턴이 %d자 초과" % PATTERN_MAX_CHARS
    kind = c.get("kind")
    if kind not in KINDS:
        return None, "유형 밖: %s" % kind
    repos = c.get("repos")
    if not isinstance(repos, list) or not all(isinstance(r, str) and r.strip() for r in repos):
        return None, "레포 목록 형식 아님"
    uniq = []
    for r in repos:
        if r.strip() not in uniq:
            uniq.append(r.strip())
    if len(uniq) < 2:
        return None, "레포 2곳 미만"
    direction = c.get("direction")
    if direction not in DIRECTIONS:
        return None, "방향 밖: %s" % direction
    dates = {}
    for k in ("first", "last"):
        v = c.get(k)
        if v is None or v == "":
            v = today
        if not _valid_date(v):
            return None, "%s 날짜 형식 아님: %s" % (k, v)
        dates[k] = v
    count = c.get("count")
    if count is None:
        count = len(uniq)
    if not isinstance(count, int) or isinstance(count, bool) or count < 1:
        return None, "횟수가 양의 정수 아님"
    ev = c.get("evidence") or []
    if not isinstance(ev, list):
        ev = [ev]
    ev = [" ".join(str(e).split()) for e in ev if str(e).strip()]
    return {"pattern": pattern, "kind": kind, "repos": uniq, "count": count,
            "first": dates["first"], "last": dates["last"], "direction": direction,
            "evidence": ev}, None


def _cell(v):
    return " ".join(str(v).split()).replace("|", "\\|")


def _link(ledger_dir, month):
    """원장 폴더에서 위로 .obsidian 이 있는 폴더를 찾아 그 기준 상대 경로 링크."""
    d = os.path.abspath(ledger_dir)
    while True:
        if os.path.isdir(os.path.join(d, ".obsidian")):
            rel = os.path.relpath(os.path.abspath(ledger_dir), d)
            if rel == ".":
                return "[[%s]]" % month
            return "[[%s/%s\\|%s]]" % (rel.replace(os.sep, "/"), month, month)
        parent = os.path.dirname(d)
        if parent == d:
            return "[[%s]]" % month
        d = parent


def _table_end(lines):
    """`| ID | 패턴 |` 첫 표의 마지막 `|` 줄 인덱스. 없으면 None."""
    start = None
    for i, line in enumerate(lines):
        if line.startswith(_TABLE_HEAD):
            start = i
            break
    if start is None:
        return None
    end = start
    for j in range(start + 1, len(lines)):
        if lines[j].lstrip().startswith("|"):
            end = j
        else:
            break
    return end


def _entry(c, fid, today):
    a = ", ".join(c["repos"])
    return "\n".join([
        "## %s · %s → %s" % (today, c["pattern"], fid),
        "",
        "> 근거(harness-gaps 헤드리스): %s" % " · ".join(c["evidence"]),
        "",
        "- 상황: 주 1회 헤드리스가 레포 %s의 지난 7일 대화 기록 · phases를 훑음" % a,
        "- 불편: %s" % c["pattern"],
        "- 비용: ⚠️",
        "- 유형: %s" % c["kind"],
        "- 대상: 레포(%s)" % a,
        "- 프로젝트: ⚠️",
        "- 방향: %s" % c["direction"],
    ]) + "\n"


def append(path, dry_run, known=None):
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception as e:
        print("gaps: 후보 파일을 읽지 못함 — %s" % e, file=sys.stderr)
        return 2
    if not isinstance(data, list):
        print("gaps: 후보 파일은 배열이어야 함", file=sys.stderr)
        return 2

    ledger = ledger_path()
    if ledger is None and not dry_run:
        print("원장 설정 없음")
        return 0

    today_d = _now().date()
    today = today_d.isoformat()
    month = today_d.strftime("%Y-%m")

    cands = []
    for i, c in enumerate(data):
        v, why = _validate(c, today)
        if v is None:
            label = c.get("pattern") if isinstance(c, dict) else None
            label = " ".join(str(label).split())[:60] if label else "#%d" % (i + 1)
            print("gaps: 후보 건너뜀(%s) — %s" % (label, why), file=sys.stderr)
            continue
        if known is not None:  # 재료(gather)에 없던 레포 이름이면 「2곳 이상」이 가짜로 참이 된다
            unknown = [r for r in v["repos"] if r not in known]
            if unknown:
                print("gaps: 레포 이름이 재료에 없음: %s" % ", ".join(unknown), file=sys.stderr)
                continue
        cands.append(v)
    if not cands:
        print("후보 없음")
        return 0

    # 원장 읽기 (dry-run · 설정 없음이면 빈 표 가정)
    if ledger is not None:
        try:
            text = ledger.read_text(encoding="utf-8")
        except Exception as e:
            print("gaps: 원장을 읽지 못함 — %s" % e, file=sys.stderr)
            return 2
        ledger_dir = str(ledger.parent)
    else:
        text = _TABLE_HEAD + " 유형 | 대상 | 프로젝트 | 횟수 | 처음 | 마지막 | 방향 | 상태 | 연결 |\n"
        ledger_dir = None

    lines = text.splitlines(keepends=True)
    end = _table_end(lines)
    if end is None:
        print("gaps: 원장에 `%s` 표가 없음 — 형식 불일치, 쓰지 않음" % _TABLE_HEAD, file=sys.stderr)
        return 2

    nums = [int(n) for n in _ID_RE.findall(text)]
    nxt = (max(nums) if nums else 0) + 1
    link = _link(ledger_dir, month) if ledger_dir else "[[%s]]" % month
    rows, entries = [], []
    for c in cands:
        fid = "F-%03d" % nxt
        nxt += 1
        cells = [fid, _cell(c["pattern"]), _cell(c["kind"]),
                 "레포(%s)" % _cell(", ".join(c["repos"])), "⚠️", str(c["count"]),
                 c["first"], c["last"], c["direction"], CANDIDATE_STATE, link]
        rows.append("| " + " | ".join(cells) + " |\n")
        entries.append(_entry(c, fid, today))

    if dry_run:
        sys.stdout.write("".join(rows))
        for e in entries:
            sys.stdout.write("\n" + e)
        return 0

    # 쓰기 순서: 월별 파일 → 원장(정본이라 마지막)
    monthly = ledger.parent / ("%s.md" % month)
    try:
        if monthly.exists():
            cur = monthly.read_text(encoding="utf-8")
            prefix = "" if cur.endswith("\n") or cur == "" else "\n"
        else:
            prefix = ("---\ntype: brain-note\ntags: [me, kind/friction]\n---\n\n"
                      "# 불편 원문 %s\n" % month)
        with open(monthly, "a", encoding="utf-8") as fh:
            fh.write(prefix + "".join("\n" + e for e in entries))
    except Exception as e:
        print("gaps: 월별 파일 쓰기 실패 — %s" % e, file=sys.stderr)
        return 1

    last = lines[end]
    if not last.endswith("\n"):
        lines[end] = last + "\n"
    new_text = "".join(lines[:end + 1]) + "".join(rows) + "".join(lines[end + 1:])
    tmp = ledger.parent / (".%s.tmp" % ledger.name)
    try:
        with open(tmp, "w", encoding="utf-8", newline="") as fh:
            fh.write(new_text)
        os.replace(tmp, ledger)
    except Exception as e:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        print("gaps: 원장 쓰기 실패 — %s" % e, file=sys.stderr)
        return 1
    sys.stdout.write("".join(rows))
    return 0


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
                print("gaps: --days 는 양의 정수", file=sys.stderr)
                return 2
        try:
            result = gather(days)
        except Exception as e:  # 어떤 입력에도 traceback 없이
            print("gaps: gather 실패 — %s" % e, file=sys.stderr)
            result = {"days": days, "repos": []}
        print(json.dumps(result, ensure_ascii=False, indent=1))
        return 0
    if cmd == "append":
        rest = argv[2:]
        dry, known, files = False, None, []
        i = 0
        while i < len(rest):
            a = rest[i]
            if a == "--dry-run":
                dry = True
            elif a == "--known" and i + 1 < len(rest):
                i += 1
                known = {n.strip() for n in rest[i].split(",") if n.strip()}
            else:
                files.append(a)
            i += 1
        if len(files) != 1:
            print("사용: gaps.py append [--dry-run] [--known NAME,...] FILE", file=sys.stderr)
            return 2
        return append(files[0], dry, known)
    print("사용: gaps.py config | gather [--days N] | append [--dry-run] [--known NAME,...] FILE", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
