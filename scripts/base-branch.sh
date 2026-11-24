#!/usr/bin/env bash
# 기준 브랜치를 정하는 한 곳(ADR-016 D2). 스킬은 이 규칙을 본문에 다시 쓰지 않고 이 스크립트를 부른다.
# 사용: bash scripts/base-branch.sh [레포 경로=.] → 기준 브랜치 이름 한 줄(stdout)
# 순서: ① .claude/harness.json git.baseBranch ② origin/HEAD 에서 origin/ 을 뗀 값 ③ 둘 다 없으면 stderr 한 줄 + exit 2
# exit 2 를 받은 쪽은 사람에게 묻는다 — main 으로 짐작하면 기준이 다른 레포에서 엉뚱한 diff 를 본다.
set -uo pipefail
DIR="${1:-.}"
ROOT="$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$DIR")"
CFG="$ROOT/.claude/harness.json"

if [ -f "$CFG" ]; then
  base="$(python3 -c 'import json,sys; g=json.load(open(sys.argv[1], encoding="utf-8")).get("git") or {}; print(str(g.get("baseBranch") or "").strip())' "$CFG" 2>/dev/null)"
  [ -n "$base" ] && { printf '%s\n' "$base"; exit 0; }
fi

ref="$(git -C "$ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
[ -n "$ref" ] && { printf '%s\n' "${ref#origin/}"; exit 0; }

echo "기준 브랜치를 못 정함: $CFG 의 git.baseBranch 도 origin/HEAD 도 없다 — 사람에게 묻는다" >&2
exit 2
