#!/usr/bin/env bash
# TODO soft-warn — PreToolUse[Bash]
# git commit 직전, 스테이징된 변경에 새로 추가된 TODO/FIXME 가 있으면 경고(차단 아님).
# exit 0 으로 통과시킨다. 출력은 stdout JSON — additionalContext(모델이 본다) + systemMessage(사용자가 본다).
#   ⚠️ exit 0 의 stderr 는 디버그 로그에만 남고 모델도 사용자도 못 본다 (2026-10-08 공식 문서 확인).
#   그 전까지 이 훅은 stderr 에 썼으므로 한 번도 전달된 적이 없다.
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
[ -z "$todos" ] && exit 0

count=$(printf '%s\n' "$todos" | grep -c . | tr -d ' ')
sample=$(printf '%s\n' "$todos" | head -n 8)

# JSON 은 python 으로 싼다 — 코드 줄에 따옴표·백슬래시가 흔하다.
COUNT="$count" SAMPLE="$sample" python3 - <<'PY'
import json, os
n = os.environ["COUNT"]; sample = os.environ["SAMPLE"]
msg = (f"⚠️ TODO 경고: 스테이징된 변경에 TODO/FIXME {n}건이 포함돼 있습니다(차단 아님 — 인지용). "
       "의도된 것이면 그대로 커밋하고, 미완성 흔적이면 정리 후 커밋.\n" + sample)
print(json.dumps({
    "systemMessage": f"TODO/FIXME {n}건이 스테이징에 있습니다 (차단 아님)",
    "hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": msg},
}, ensure_ascii=False))
PY
exit 0
