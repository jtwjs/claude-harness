#!/usr/bin/env bash
# SessionStart — guard.prodDb 를 적었는데 운영 DB 주소를 못 읽으면 소리 내서 알린다. 비차단(exit 0).
# 조용히 꺼진 차단은 켜진 줄 알게 만든다(block-dangerous-bash 의 python3 경고와 같은 이유). 호스트 값은 출력하지 않는다.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/hook-log.sh" 2>/dev/null || hook_log_on_exit() { :; }
hook_log_on_exit prod-db-check   # 끝나는 모든 경로에서 기록 한 줄 — 경로마다 HOOK_RESULT 를 정하고 exit
cat >/dev/null 2>&1 || true
command -v python3 >/dev/null 2>&1 || { HOOK_RESULT=nopython; exit 0; }
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { HOOK_RESULT=norepo; exit 0; }
[ -f "$REPO_ROOT/.claude/harness.json" ] || { HOOK_RESULT=nocfg; exit 0; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lines=$(python3 "$SCRIPT_DIR/lib/prod_db.py" status "$REPO_ROOT" 2>/dev/null) \
  || lines="판별 스크립트가 죽음(종료 코드 $?) — 이 상태면 Bash 명령마다 차단된다"
[ -n "$lines" ] || { HOOK_RESULT=clean; exit 0; }
HOOK_RESULT=warn
MSG="🔴 운영 DB 차단(guard.prodDb): $(printf '%s' "$lines" | paste -sd'·' -). harness.json 의 from 항목을 고친다" python3 -c '
import json, os
m = os.environ["MSG"]
print(json.dumps({"systemMessage": m, "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": m}}, ensure_ascii=False))'
exit 0
