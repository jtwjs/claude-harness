#!/usr/bin/env bash
# PostToolUse(Write|Edit) — 변경 파일 자동 포맷 (JS/TS/MD 계열 prettier · Kotlin ktlint)
# 실패해도 차단하지 않음 (exit 0 보장)
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/hook-log.sh" 2>/dev/null || hook_log_on_exit() { :; }
hook_log_on_exit auto-format   # 끝나는 모든 경로에서 기록 한 줄 — 경로마다 HOOK_RESULT 를 정하고 exit

# 하네스가 깔린 레포에서만 동작한다.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { HOOK_RESULT=norepo; exit 0; }
[ -f "$REPO_ROOT/.claude/harness.json" ] || { HOOK_RESULT=nocfg; exit 0; }

input=$(cat 2>/dev/null || true)
file_path=$(printf '%s' "$input" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

[ -z "$file_path" ] && { HOOK_RESULT=noinput; exit 0; }
[ -f "$file_path" ] || { HOOK_RESULT=nofile; exit 0; }

# 제외 경로
case "$file_path" in
  */node_modules/*|*/dist/*|*/.next/*|*/build/*|*/.turbo/*|*/coverage/*|*/.gradle/*) HOOK_RESULT=excluded; exit 0 ;;
  *.generated.ts|*.generated.tsx) HOOK_RESULT=excluded; exit 0 ;;
esac

# Kotlin — ktlint CLI 가 PATH 에 있을 때만 (gradle 태스크는 편집마다 돌리기엔 느리다)
case "$file_path" in
  *.kt|*.kts)
    HOOK_RESULT=nofmt HOOK_DETAIL=ktlint
    command -v ktlint >/dev/null 2>&1 && ktlint -F --log-level=error "$file_path" >/dev/null 2>&1 && HOOK_RESULT=formatted
    exit 0 ;;
esac

# 대상 확장자만
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.md|*.json|*.css|*.html) ;;
  *) HOOK_RESULT=ignore; exit 0 ;;
esac

# prettier 가 있을 때만 실행 (없으면 silent skip)
HOOK_RESULT=nofmt HOOK_DETAIL=prettier
npx --no-install prettier --write --log-level warn "$file_path" >/dev/null 2>&1 && HOOK_RESULT=formatted || true

exit 0
