#!/usr/bin/env python3
"""하루 마감 페이지 — 오늘 어떤 세션에서 무엇을 요청했고, 어느 프로젝트가 어디까지 갔고, 무엇을 배웠는지 한 장.

모델을 거치지 않는 정적 HTML이다(토큰 0 · 서버 없음). 읽기만 한다.
  세션      ~/.claude/projects/*/*.jsonl — 사람이 친 요청(promptSource=typed)만. 헤드리스(entrypoint=sdk-cli)·/private cwd 제외
  프로젝트  세션 cwd 의 git 레포(worktree 는 본 레포로 묶음) — 오늘 커밋 수 · phases 진행 · 오늘 회고 한 줄
  배운 것   ~/.claude/learn-repos.txt 레포의 _learn/inbox.md 중 오늘 카드(보기만 — vault 이관은 /gauge week)
            + ~/.claude/daily-hub.json 의 extraDirs 에서 오늘 만든 md(예: vault concepts)
  막힌 것   phases error·blocked step · 오늘의 「막힌 질문」 카드
출력: ~/.claude/daily/YYYY-MM-DD.html + 같은 이름 .txt(evening 브리핑용 한 줄). 같은 날 다시 돌리면 덮어씀

아이디어 출처: lcalmsky/deadhd 허브(MIT — 코드는 가져오지 않음). 2026-10-18.

Usage:
    daily_hub.py [YYYY-MM-DD] [--out DIR] [--home DIR]
"""
import html
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "skills" / "harness-run" / "scripts"))
import phases_status  # noqa: E402

KST = timezone(timedelta(hours=9))
CARD = re.compile(r"^## (\d{4}-\d{2}-\d{2}) · (.+)$")
KINDS = ["기술", "직무", "도메인", "막힌 질문"]


def sh(args, cwd=None):
    try:
        r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def kst_day(ts: str):
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(KST)
    except (ValueError, AttributeError):
        return None


def text_of(msg) -> str:
    c = (msg or {}).get("content")
    if isinstance(c, list):
        c = " ".join(x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text")
    return " ".join(c.split()) if isinstance(c, str) else ""


# ── 세션 ─────────────────────────────────────────────────────────────
def sessions(home: Path, day: str) -> list:
    start = datetime.fromisoformat(day).replace(tzinfo=KST).timestamp()
    seen, out = set(), []
    for f in sorted((home / ".claude" / "projects").glob("*/*.jsonl")):
        rp = os.path.realpath(f)
        if rp in seen:
            continue
        seen.add(rp)
        try:
            if os.path.getmtime(rp) < start:
                continue
        except OSError:
            continue
        s = {"title": "", "cwd": "", "prompts": [], "first": None, "last": None, "headless": False}
        with open(rp, "rb") as fh:
            for raw in fh:
                if raw.startswith(b'{"type":"custom-title"'):
                    try:
                        s["title"] = json.loads(raw).get("customTitle") or s["title"]
                    except ValueError:
                        pass
                    continue
                if b'"type":"user"' not in raw or b'"promptSource":"typed"' not in raw:
                    if b'"entrypoint":"sdk-cli"' in raw[:4000]:
                        s["headless"] = True
                    continue
                try:
                    d = json.loads(raw)
                except ValueError:
                    continue
                if d.get("entrypoint") == "sdk-cli":
                    s["headless"] = True
                t = kst_day(d.get("timestamp", ""))
                if not t or t.strftime("%Y-%m-%d") != day:
                    continue
                txt = text_of(d.get("message"))
                if not txt:
                    continue
                s["cwd"] = d.get("cwd") or s["cwd"]
                s["prompts"].append(txt)
                s["first"] = s["first"] or t
                s["last"] = t
        if s["prompts"] and not s["headless"] and not s["cwd"].startswith(("/private/", "/tmp/")):
            out.append(s)
    return sorted(out, key=lambda x: x["first"])


# ── 프로젝트 ─────────────────────────────────────────────────────────
def repo_of(cwd: str, cache: dict):
    if cwd in cache:
        return cache[cwd]
    top = sh(["git", "rev-parse", "--show-toplevel"], cwd=cwd) if cwd and os.path.isdir(cwd) else None
    common = sh(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=cwd) if top else None
    main = str(Path(common).parent) if common and common.endswith(".git") else top
    cache[cwd] = (main, top)
    return cache[cwd]


def phase_lines(wt: Path, day: str) -> tuple:
    """(진행 표시들, 막힘 표시들). 미완료 phase 와 오늘 끝난 phase."""
    prog, stuck = [], []
    for name, idx in sorted(phases_status.load(wt / "phases").items()):
        if "_error" in idx:
            continue
        steps = [s for s in idx.get("steps", []) if s.get("status") != "obsolete"]
        if not steps:
            continue
        left = [s for s in steps if s.get("status") not in phases_status.DONE]
        done = len(steps) - len(left)
        today = any(str(s.get("completed_at", "")).startswith(day) for s in steps)
        for s in steps:
            if s.get("status") in ("error", "blocked"):
                stuck.append(f"{wt.name} · {name} step {s.get('step')} {s.get('name', '')} ({s.get('status')})")
        if left:
            prog.append(f"◆ {name} {done}/{len(steps)} ▶ {left[0].get('name', '')}")
        elif today:
            _, t = phases_status.retro_rows(idx)
            prog.append(f"✓ {name} {done}/{len(steps)} · 재시도 {t['retries']} · 소요 {phases_status.fmt_dur(t['sec']) if t['timed'] else '-'}")
    return prog, stuck


def retro_today(wt: Path, day: str) -> str:
    # 회고 한 장 = 파일 하나(retro/YYYY-MM-DD-<slug>.md). 옛 레포의 retro.md 한 파일도 읽는다
    dirs = (wt / "_brain" / "wiki" / "infra" / "retro", wt / "docs" / "retro")
    files = [f for d in dirs if d.is_dir() for f in sorted(d.glob(f"{day}-*.md"))]
    for f in files + [wt / "_brain" / "wiki" / "infra" / "retro.md", wt / "docs" / "retro.md"]:
        if f.exists():
            for line in f.read_text(encoding="utf-8").splitlines():
                if line.startswith(f"## {day}"):
                    return line[3:].strip()
    return ""


def projects(sess: list, day: str) -> tuple:
    cache, by = {}, {}
    for s in sess:
        main, top = repo_of(s["cwd"], cache)
        key = main or s["cwd"]
        p = by.setdefault(key, {"name": Path(key).name, "sessions": [], "worktrees": set()})
        p["sessions"].append(s)
        if top:
            p["worktrees"].add(top)
    stuck_all = []
    nxt = (datetime.fromisoformat(day) + timedelta(days=1)).strftime("%Y-%m-%d")
    for key, p in by.items():
        p["commits"] = 0
        p["progress"], p["retro"] = [], ""
        if not os.path.isdir(os.path.join(key, ".git")) and not p["worktrees"]:
            continue
        me = sh(["git", "config", "user.email"], cwd=key) or ""
        c = sh(["git", "log", "--all", "--no-merges", "--format=%H", f"--author={me}", f"--since={day} 00:00", f"--until={nxt} 00:00"], cwd=key)
        p["commits"] = len(c.splitlines()) if c else 0
        for wt in sorted(p["worktrees"] | ({key} if os.path.isdir(key) else set())):
            prog, stuck = phase_lines(Path(wt), day)
            p["progress"] += [x for x in prog if x not in p["progress"]]
            stuck_all += [x for x in stuck if x not in stuck_all]
            p["retro"] = p["retro"] or retro_today(Path(wt), day)
    return sorted(by.values(), key=lambda p: -len(p["sessions"])), stuck_all


# ── 배운 것 ──────────────────────────────────────────────────────────
def learn_cards(home: Path, day: str) -> list:
    f = home / ".claude" / "learn-repos.txt"
    repos = [l.strip() for l in f.read_text(encoding="utf-8").splitlines()] if f.exists() else []
    cards = []
    for r in repos:
        if not r or r.startswith(("#", "/private/", "/tmp/")):
            continue
        inbox = Path(os.path.expanduser(r)) / "_learn" / "inbox.md"
        if not inbox.exists():
            continue
        cur = None
        for line in inbox.read_text(encoding="utf-8").splitlines():
            m = CARD.match(line)
            if m:
                cur = {"repo": Path(r).name, "title": m.group(2), "kind": "", "src": "", "state": "", "gist": ""} if m.group(1) == day else None
                if cur:
                    cards.append(cur)
                continue
            if not cur or not line.startswith("- "):
                continue
            body = line[2:]
            if body.startswith("종류:"):
                parts = [x.strip() for x in body.split("·")]
                cur["kind"] = parts[0].replace("종류:", "").strip()
                cur["src"] = next((x.replace("출처:", "").strip() for x in parts if x.startswith("출처:")), "")
            elif body.startswith("상태:"):
                cur["state"] = body[3:].strip()
            elif body.startswith("요지:"):
                cur["gist"] = body[3:].strip()
    return cards


def extra_learned(home: Path, day: str) -> list:
    cfg = home / ".claude" / "daily-hub.json"
    try:
        dirs = json.loads(cfg.read_text(encoding="utf-8")).get("extraDirs", []) if cfg.exists() else []
    except ValueError:
        dirs = []
    out = []
    for d in dirs:
        base = Path(os.path.expanduser(d.get("path", "")))
        if not base.is_dir():
            continue
        for f in base.rglob("*.md"):
            try:
                head = f.read_text(encoding="utf-8")[:1500]
            except (OSError, UnicodeDecodeError):
                continue
            m = re.search(r"^created:\s*(\d{4}-\d{2}-\d{2})", head, re.M)
            if m and m.group(1) == day:
                t = re.search(r"^title:\s*(.+)$", head, re.M)
                out.append({"label": d.get("label", base.name), "title": (t.group(1).strip().strip("\"'") if t else f.stem)})
    return out


# ── HTML ─────────────────────────────────────────────────────────────
CSS = """
:root{--bg:#f6f7f8;--card:#fff;--fg:#1d2329;--muted:#5b6670;--line:#d9dee3;--accent:#2f6f73;--soft:#e3efef;--bad:#b42318;--badsoft:#fdecea}
@media (prefers-color-scheme: dark){:root{--bg:#14181b;--card:#1c2125;--fg:#e4e8eb;--muted:#9aa5ae;--line:#2e353b;--accent:#6fb3b6;--soft:#1f3032;--bad:#f97066;--badsoft:#3a1f1d;color-scheme:dark}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.65 -apple-system,"Apple SD Gothic Neo",system-ui,sans-serif}
.wrap{max-width:980px;margin:0 auto;padding:32px 16px 64px;display:flex;flex-direction:column;gap:28px}
h1{font-size:24px;margin:0}h2{font-size:17px;margin:0 0 10px}.muted{color:var(--muted);font-size:13px}
.nums{display:flex;flex-wrap:wrap;gap:10px}.num{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:10px 16px;min-width:110px}
.num b{display:block;font-size:22px;font-variant-numeric:tabular-nums}.num span{font-size:12px;color:var(--muted)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:12px}
.card{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:14px 16px;min-width:0}
.card h3{margin:0 0 6px;font-size:15px}.row{font-size:14px;margin:3px 0;overflow-wrap:anywhere}
.mono{font-family:ui-monospace,Menlo,monospace;font-size:13px}.tag{display:inline-block;font-size:11px;padding:0 7px;border-radius:999px;border:1px solid var(--line);color:var(--muted);margin-right:4px}
.tag.hl{color:var(--accent);border-color:var(--accent)}table{border-collapse:collapse;width:100%;font-size:14px}
td,th{text-align:left;padding:7px 10px;border-bottom:1px solid var(--line);vertical-align:top}th{font-size:12px;color:var(--muted);font-weight:500}
.tbl{overflow-x:auto;background:var(--card);border:1px solid var(--line);border-radius:8px}.bad{background:var(--badsoft);border-color:var(--bad)}
ul{margin:4px 0;padding-left:18px}
"""


def e(x) -> str:
    return html.escape(str(x))


def cut(t: str, n=70) -> str:
    return t if len(t) <= n else t[:n] + "…"


def render(day: str, sess: list, projs: list, stuck: list, cards: list, extra: list) -> str:
    wd = "월화수목금토일"[datetime.fromisoformat(day).weekday()]
    commits = sum(p["commits"] for p in projs)
    nums = [(len(sess), "세션"), (len(projs), "프로젝트"), (commits, "내 커밋(모든 브랜치)"), (len(cards), "새 학습 카드"), (len(extra), "vault 학습")]
    h = [f"<!doctype html><html lang='ko'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>",
         f"<title>하루 마감 {e(day)}</title><style>{CSS}</style></head><body><div class='wrap'>",
         f"<header><h1>{e(day)} {wd} 하루 마감</h1><div class='muted'>생성 {datetime.now(KST).strftime('%H:%M')} · 사람이 친 요청만 셈 · 헤드리스·/private 제외</div></header>",
         "<section class='nums'>" + "".join(f"<div class='num'><b>{n}</b><span>{l}</span></div>" for n, l in nums) + "</section>"]
    # 프로젝트
    h.append("<section><h2>프로젝트</h2><div class='grid'>")
    for p in projs:
        h.append(f"<div class='card'><h3>{e(p['name'])}</h3><div class='muted'>세션 {len(p['sessions'])} · 내 커밋 {p['commits']}</div>")
        for x in p["progress"]:
            h.append(f"<div class='row mono'>{e(x)}</div>")
        if p["retro"]:
            h.append(f"<div class='row'>회고: {e(p['retro'])}</div>")
        h.append("</div>")
    h.append("</div></section>")
    # 세션
    h.append("<section><h2>세션</h2><div class='tbl'><table><tr><th>시간</th><th>세션</th><th>요청</th><th>첫 요청</th><th>마지막 요청</th></tr>")
    for s in sess:
        name = s["title"] or Path(s["cwd"]).name
        h.append(f"<tr><td class='mono'>{s['first']:%H:%M}~{s['last']:%H:%M}</td><td>{e(name)}<div class='muted'>{e(Path(s['cwd']).name)}</div></td>"
                 f"<td>{len(s['prompts'])}</td><td>{e(cut(s['prompts'][0]))}</td><td>{e(cut(s['prompts'][-1]))}</td></tr>")
    h.append("</table></div></section>")
    # 배운 것
    h.append("<section><h2>배운 것</h2><div class='grid'>")
    kinds = KINDS + sorted({c["kind"] for c in cards} - set(KINDS))
    for k in kinds:
        cs = [c for c in cards if c["kind"] == k]
        if not cs:
            continue
        h.append(f"<div class='card'><h3>{e(k)} {len(cs)}</h3>")
        for c in cs:
            tag = "<span class='tag hl'>빈틈 3곳</span>" if "빈틈" in c["src"] else (f"<span class='tag'>{e(c['src'])}</span>" if c["src"] else "")
            h.append(f"<div class='row'>{tag}<b>{e(c['title'])}</b> <span class='muted'>{e(c['repo'])} · {e(c['state'])}</span></div>")
            if c["gist"]:
                h.append(f"<div class='row muted'>{e(cut(c['gist'], 160))}</div>")
        h.append("</div>")
    if extra:
        h.append("<div class='card'><h3>vault 학습 " + str(len(extra)) + "</h3><ul>" + "".join(f"<li>{e(x['title'])} <span class='muted'>{e(x['label'])}</span></li>" for x in extra) + "</ul></div>")
    h.append("</div></section>")
    # 막힌 것
    blocked = stuck + [f"막힌 질문 · {c['repo']} · {c['title']}" for c in cards if c["kind"] == "막힌 질문"]
    h.append("<section><h2>막힌 것</h2>")
    h.append(("<div class='card bad'><ul>" + "".join(f"<li>{e(b)}</li>" for b in blocked) + "</ul></div>") if blocked else "<div class='muted'>없음</div>")
    h.append("</section></div></body></html>")
    return "\n".join(h)


def main(argv: list) -> int:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("day", nargs="?", default=datetime.now(KST).strftime("%Y-%m-%d"))
    ap.add_argument("--home", default=str(Path.home()))
    ap.add_argument("--out")
    a = ap.parse_args(argv)
    day, home = a.day, Path(a.home)
    out_dir = Path(a.out) if a.out else home / ".claude" / "daily"
    sess = sessions(home, day)
    projs, stuck = projects(sess, day)
    cards, extra = learn_cards(home, day), extra_learned(home, day)
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{day}.html"
    out.write_text(render(day, sess, projs, stuck, cards, extra), encoding="utf-8")
    line = f"오늘 세션 {len(sess)} · 프로젝트 {len(projs)} · 새 학습 {len(cards) + len(extra)} — 자세히: {out}"
    (out_dir / f"{day}.txt").write_text(line + "\n", encoding="utf-8")   # evening 브리핑이 읽는 한 줄
    print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
