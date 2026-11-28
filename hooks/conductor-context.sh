#!/usr/bin/env bash
# conductor-context — SessionStart(시작·재개·압축 뒤). 지휘 자리에서만 대상 레포마다
#   트랙 한 줄(tracks_status.py --compact) + 열린 지휘 이슈(label conductor, 최대 10)를 additionalContext 로 넣는다.
#   레포 템플릿(.claude/harness.json harness.version) ≠ 설치본(CLAUDE_PLUGIN_ROOT plugin.json version)이면 그 레포 줄 끝에 「템플릿 X → 설치본 Y」(#80). 하네스 원본 줄은 빼고(#95).
#   하네스 원본 줄에는 설치본 버전 뒤 원격 main 머지(gh api compare, 5초) 「릴리스 안 된 머지 n건」 · 못 세면 「릴리스 확인 실패」(#80).
# 지휘 설정(~/.claude/conductor.json)이 없거나 지휘 자리가 아니면 무출력 exit 0 (ADR-005, 2026-10-31).
# gh 는 레포당 5초 제한, 실패하면 (조회 실패). CLAUDE_CONDUCTOR_GH·CLAUDE_CONDUCTOR_TS 로 gh·tracks_status 를 바꿔 끼운다(테스트).
# 전체 마감 CLAUDE_CONDUCTOR_DEADLINE(기본 25초, hooks.json timeout 30 안) — 넘으면 남은 레포는 건너뛰고 모은 현황은 낸다(REVIEW 1회차).
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/hook-log.sh" 2>/dev/null || hook_log_on_exit() { :; }
hook_log_on_exit conductor-context   # 끝나는 모든 경로에서 기록 한 줄 — 경로마다 HOOK_RESULT 를 정하고 exit
REPO_ROOT="$PWD"   # 기록의 레포 칸 — 지휘 자리 폴더 이름
cat >/dev/null 2>&1   # 훅 입력은 쓰지 않는다
command -v python3 >/dev/null 2>&1 || { HOOK_RESULT=nopython; exit 0; }
# 지휘 자리가 아니면 무출력 exit 0, 자리면 JSON 한 줄. 출력을 받아 그대로 내보낸다 — 기록에서 둘을 가르려고
out="$(HERE="$HERE" python3 - <<'PY' 2>/dev/null
import json, os, re, subprocess, sys, time
from pathlib import Path

here = Path(os.environ["HERE"])
sys.path.insert(0, str(here / "lib"))
import conductor

if not conductor.is_seat(os.getcwd()):
    sys.exit(0)
ts = os.environ.get("CLAUDE_CONDUCTOR_TS")
ts_cmd = [ts] if ts else [sys.executable, str(here.parent / "skills" / "conductor" / "scripts" / "tracks_status.py")]
gh = os.environ.get("CLAUDE_CONDUCTOR_GH") or "gh"
try:
    deadline = time.monotonic() + float(os.environ.get("CLAUDE_CONDUCTOR_DEADLINE", "25"))
except ValueError:
    deadline = time.monotonic() + 25


def run(args, cwd, timeout=10):
    timeout = min(timeout, max(0.1, deadline - time.monotonic()))
    try:
        r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def slug(repo):
    url = run(["git", "remote", "get-url", "origin"], repo) or ""
    m = re.search(r"github\.com[:/]([^/]+/[^/]+?)(?:\.git)?/?$", url)
    return m.group(1) if m else None


def read_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
    except (OSError, ValueError):
        return None
    return d if isinstance(d, dict) else None


def nonempty_str(v):
    return v if isinstance(v, str) and v else None


plugin_root = Path(os.environ.get("CLAUDE_PLUGIN_ROOT") or here.parent)
installed = read_json(plugin_root / ".claude-plugin" / "plugin.json") or {}
inst_ver = nonempty_str(installed.get("version"))


READ_FAIL = object()   # git 읽기 실패(시간 초과 · 오류) — 「파일 없음」과 가른다


def version_at(top, rev):
    # rev 의 plugin.json version. 파일 없음 → None, git 읽기 실패 → READ_FAIL
    listed = run(["git", "ls-tree", "--name-only", rev, "--", ".claude-plugin/plugin.json"], top)
    if listed is None:
        return READ_FAIL
    if not listed:
        return None
    raw = run(["git", "show", f"{rev}:.claude-plugin/plugin.json"], top)
    if raw is None:
        return READ_FAIL
    try:
        d = json.loads(raw)
    except ValueError:
        return None
    return d.get("version") if isinstance(d, dict) else None


def release_base(top):
    # origin/main first-parent 에서 version 이 설치본 버전이 된 가장 최근 커밋(태그가 없어서, #80 D2). 로컬 ref 는 읽기만.
    # 버전 그대로 plugin.json 다른 칸만 고친 커밋은 건너뛴다. 읽기 실패는 기준점 실패(너무 최근 커밋을 잡아 적게 세지 않게)
    log = run(["git", "log", "--first-parent", "--format=%H", "refs/remotes/origin/main",
               "--", ".claude-plugin/plugin.json"], top)
    if log is None:
        return None
    for sha in log.split():
        v = version_at(top, sha)
        if v is READ_FAIL:
            return None
        if v != inst_ver:
            continue
        parents = run(["git", "rev-list", "--parents", "-n", "1", sha], top)
        if parents is None:
            return None
        ps = parents.split()[1:]
        pv = version_at(top, ps[0]) if ps else None
        if pv is READ_FAIL:
            return None
        if pv != inst_ver:
            return sha
    return None


def pr_number(message):
    m = re.search(r"\(#(\d+)\)\s*$", (message or "").split("\n", 1)[0])
    return m.group(1) if m else None


def release_suffix(top):
    # 하네스 원본(레포 plugin.json name = 설치본 name, #80 D1)만 원격 main 을 센다. 실패는 0건과 다른 글로
    path = Path(top) / ".claude-plugin" / "plugin.json"
    if not path.is_file():
        return ""
    name = nonempty_str(installed.get("name"))
    if name is None:
        return " · 릴리스 확인 실패(설치본)"
    mine = read_json(path)
    if mine is None:   # 있는데 못 읽음(JSON 깨짐 · 충돌 표시) — 조용히 사라지지 않는다
        return " · 릴리스 확인 실패(레포 plugin.json)"
    if mine.get("name") != name:
        return ""
    if inst_ver is None:
        return " · 릴리스 확인 실패(설치본)"
    base = release_base(top)
    if base is None:
        return " · 릴리스 확인 실패(기준점)"
    s = slug(top)
    out = run([gh, "api", f"repos/{s}/compare/{base}...main"], top, timeout=5) if s else None
    try:
        d = json.loads(out) if out is not None else None
    except ValueError:
        d = None
    commits = d.get("commits") if isinstance(d, dict) else None
    if not isinstance(commits, list):
        return " · 릴리스 확인 실패(원격)"
    total = d.get("total_commits")
    n = total if isinstance(total, int) and not isinstance(total, bool) else len(commits)
    if n <= 0:
        return ""
    nums = [x for x in (pr_number(((c or {}).get("commit") or {}).get("message"))
                        for c in commits if isinstance(c, dict)) if x][:5]
    shown = "".join(f" #{x}" if i == 0 else f" · #{x}" for i, x in enumerate(nums))
    rest = n - len(nums)
    more = f" 외 {rest}건" if nums and rest > 0 else ""
    return f" · 릴리스 안 된 머지 {n}건{shown}{more} (설치본 {inst_ver})"


def template_suffix(top):
    # 하네스 원본 줄에는 붙이지 않는다 — 버전 올림이 템플릿 · plugin.json 을 같이 올려 릴리스 전엔 거꾸로 보이고, 그 정보는 릴리스 꼬리에 있다(#95)
    name = nonempty_str(installed.get("name"))
    if name and (read_json(Path(top) / ".claude-plugin" / "plugin.json") or {}).get("name") == name:
        return ""
    h =(read_json(Path(top) / ".claude" / "harness.json") or {}).get("harness")
    repo_ver = nonempty_str(h.get("version")) if isinstance(h, dict) else None
    if repo_ver and inst_ver and repo_ver != inst_ver:
        return f" · 템플릿 {repo_ver} → 설치본 {inst_ver}"
    return ""


repos = conductor.repos()
lines = [f"[지휘 현황] 대상 레포 {len(repos)} — conductor.json. 판정 전에 그 레포 CLAUDE.md·tracks.md 를 읽는다"]
for r in repos:
    if time.monotonic() >= deadline:
        lines.append(f"- {r.name} (시간 초과 — 건너뜀)")
        continue
    top = run(["git", "rev-parse", "--show-toplevel"], r) if r.is_dir() else None
    if not top:
        lines.append(f"- {r.name} (경로 없음)")
        continue
    track = run(ts_cmd + ["--compact"], top)
    track = "(조회 실패)" if track is None else track or "트랙 손댈 것 없음"   # 실패를 「할 일 없음」으로 보이지 않는다
    try:
        rel = release_suffix(top)
    except Exception:   # 한 레포의 실패가 다른 레포 줄을 막지 않는다
        rel = " · 릴리스 확인 실패"
    lines.append(f"- {r.name} — {track}{rel}{template_suffix(top)}")
    s = slug(top)
    out = run([gh, "issue", "list", "-R", s, "--label", "conductor", "--state", "open",
               "--limit", "10", "--json", "number,title"], top, timeout=5) if s else None
    try:
        issues = json.loads(out) if out is not None else None
    except ValueError:
        issues = None
    if issues is None:
        lines.append(f"  열린 지휘 이슈 ({s or 'origin 없음'}): (조회 실패)")
    elif issues:
        lines.append(f"  열린 지휘 이슈 ({s}): " + " · ".join(f"#{i['number']} {i['title']}" for i in issues))
    else:
        lines.append(f"  열린 지휘 이슈 ({s}): 없음")
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
                                         "additionalContext": "\n".join(lines)}}, ensure_ascii=False))
PY
)"; rc=$?
if [ "$rc" -ne 0 ]; then HOOK_RESULT=error HOOK_DETAIL="exit $rc"
elif [ -z "$out" ]; then HOOK_RESULT=noseat
else HOOK_RESULT=shown
fi
[ -n "$out" ] && printf '%s\n' "$out"
exit 0
