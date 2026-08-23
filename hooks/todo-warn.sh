#!/usr/bin/env bash
# TODO soft-warn — PreToolUse[Bash]
# git commit 직전, 스테이징된 변경에 새로 추가된 TODO/FIXME 가 있으면 경고(차단 아님).
# exit 0 으로 통과시키되 stderr 로 인지만 시킨다. 파쇄(commit) 막지 않음.
set -uo pipefail

# 하네스가 깔린 레포에서만 동작한다.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0

input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[ -z "$cmd" ] && exit 0

# git commit 명령일 때만
echo "$cmd" | grep -qE '\bgit[[:space:]]+commit\b' || exit 0

command -v git >/dev/null 2>&1 || exit 0

# 스테이징 diff 의 추가 라인(+) 중 TODO/FIXME
todos=$(git diff --cached -U0 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | grep -nE 'TODO|FIXME|XXX|HACK' || true)

if [ -n "$todos" ]; then
  count=$(printf '%s\n' "$todos" | grep -c . | tr -d ' ')
  printf '⚠️  TODO 경고: 스테이징된 변경에 TODO/FIXME %s건이 포함돼 있습니다(차단 아님 — 인지용).\n' "$count" >&2
  printf '%s\n' "$todos" | head -n 8 | sed 's/^/   /' >&2
  printf '   의도된 것이면 그대로 커밋하세요. 미완성 흔적이면 정리 후 커밋 권장.\n' >&2
fi
exit 0
