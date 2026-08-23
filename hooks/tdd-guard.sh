#!/usr/bin/env bash
# TDD Guard — PreToolUse[Write|Edit] (HARD BLOCK)
#
# 구현 파일을 쓰려는데 짝 테스트가 없으면 차단한다.
# 🔴 대상·면제는 하드코딩하지 않는다 — .claude/harness.json 의 tdd.include / tdd.exclude 를 읽는다.
#    (무엇을 테스트하고 무엇을 안 하는지의 '이유'는 .claude/rules/testing.md §0 이 정본이고,
#     이 훅의 exclude 는 그 표와 같은 내용을 가리켜야 한다. 어긋나면 막는 것과 적힌 것이 달라진다.)
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
CFG="$REPO_ROOT/.claude/harness.json"
[ -f "$CFG" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || exit 0

INPUT="$input" CFG="$CFG" ROOT="$REPO_ROOT" python3 <<'PY'
import json, os, sys, fnmatch, pathlib

try:
    payload = json.loads(os.environ["INPUT"])
    cfg = json.load(open(os.environ["CFG"], encoding="utf-8"))
except Exception:
    sys.exit(0)

root = pathlib.Path(os.environ["ROOT"])
tdd = cfg.get("tdd") or {}
if not tdd.get("enabled"):
    sys.exit(0)

fp = (payload.get("tool_input") or {}).get("file_path") or ""
if not fp:
    sys.exit(0)

try:
    rel = str(pathlib.Path(fp).resolve().relative_to(root))
except Exception:
    sys.exit(0)                      # 레포 밖 파일은 대상 아님

include = tdd.get("include") or []
exclude = tdd.get("exclude") or []
match = lambda pats: any(fnmatch.fnmatch(rel, p) for p in pats)

if not include or not match(include):
    sys.exit(0)                      # 대상 범위 밖
if match(exclude):
    sys.exit(0)                      # 면제

p = pathlib.Path(rel)
if any(s in p.name for s in (".test.", ".spec.")) or "__tests__" in p.parts:
    sys.exit(0)                      # 테스트 파일 자체

stem = p.name.rsplit(".", 1)[0]
ext  = p.suffix
cands = [p.with_name(f"{stem}.test{ext}"), p.with_name(f"{stem}.spec{ext}"),
         p.parent / "__tests__" / f"{stem}.test{ext}"]
for c in (p.with_suffix("").with_name(f"{stem}.test.ts"),
          p.with_suffix("").with_name(f"{stem}.test.tsx")):
    cands.append(c)

if any((root / c).is_file() for c in cands):
    sys.exit(0)

reason = (
    f"TDD GUARD: '{p.name}' 의 짝 테스트가 없습니다. 구현 전 실패 테스트를 먼저 작성하세요.\n"
    f"  기대 경로: {stem}.test{ext} 또는 __tests__/{stem}.test{ext}\n"
    f"  대상 범위는 .claude/harness.json 의 tdd.include, 면제는 tdd.exclude 이고,\n"
    f"  '무엇을 테스트하고 무엇을 안 하는가'의 정본은 .claude/rules/testing.md §0 입니다."
)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": reason,
}}, ensure_ascii=False))
PY
exit 0
