#!/usr/bin/env bash
# PostToolUse(Write|Edit) — 변경 파일 자동 prettier
# 실패해도 차단하지 않음 (exit 0 보장)
set -uo pipefail

# 하네스가 깔린 레포에서만 동작한다.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0

input=$(cat 2>/dev/null || true)
file_path=$(printf '%s' "$input" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

# 대상 확장자만
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.md|*.json|*.css|*.html) ;;
  *) exit 0 ;;
esac

# 제외 경로
case "$file_path" in
  */node_modules/*|*/dist/*|*/.next/*|*/build/*|*/.turbo/*|*/coverage/*) exit 0 ;;
  *.generated.ts|*.generated.tsx) exit 0 ;;
esac

# prettier 가 있을 때만 실행 (없으면 silent skip)
npx --no-install prettier --write --log-level warn "$file_path" >/dev/null 2>&1 || true

exit 0
