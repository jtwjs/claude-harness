#!/usr/bin/env bash
# SessionStart — guard.prodDb 를 적었는데 운영 DB 주소를 못 읽으면 소리 내서 알린다. 비차단(exit 0).
# 조용히 꺼진 차단은 켜진 줄 알게 만든다(block-dangerous-bash 의 python3 경고와 같은 이유). 호스트 값은 출력하지 않는다.
set -uo pipefail
cat >/dev/null 2>&1 || true
command -v python3 >/dev/null 2>&1 || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lines=$(python3 "$SCRIPT_DIR/lib/prod_db.py" status "$REPO_ROOT" 2>/dev/null)
[ -n "$lines" ] || exit 0
MSG="🔴 운영 DB 차단(guard.prodDb): $(printf '%s' "$lines" | paste -sd'·' -). harness.json 의 from 항목을 고친다" python3 -c '
import json, os
m = os.environ["MSG"]
print(json.dumps({"systemMessage": m, "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": m}}, ensure_ascii=False))'
exit 0
