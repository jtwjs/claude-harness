#!/usr/bin/env bash
# conductor-context — SessionStart(시작·재개·압축 뒤). 지휘 자리에서만 대상 레포마다
#   트랙 한 줄(tracks_status.py --compact) + 열린 지휘 이슈(label conductor, 최대 10)를 additionalContext 로 넣는다.
#   레포 템플릿(.claude/harness.json harness.version) ≠ 설치본(CLAUDE_PLUGIN_ROOT plugin.json version)이면 그 레포 줄 끝에 「템플릿 X → 설치본 Y」(#80).
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


def template_suffix(top):
    h = (read_json(Path(top) / ".claude" / "harness.json") or {}).get("harness")
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
    lines.append(f"- {r.name} — {track}{template_suffix(top)}")
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
