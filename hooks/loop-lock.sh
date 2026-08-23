#!/usr/bin/env bash
# Loop Lock — PostToolUse[Bash]
# 같은 검증성 명령(test/vitest/typecheck/build/lint)이 N회 연속 반복되면 자기수정 루프로 보고
# 모델에 stop 신호(exit 2 = stderr 를 차단 피드백으로 전달). 무한 루프·토큰 낭비 방지.
# 다른 명령이 끼면 카운터 리셋. 검증성 명령이 아니면 무시.
set -uo pipefail

THRESHOLD=3

input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
[ -z "$cmd" ] && exit 0

# 🔴 stamp 는 반드시 프로젝트 루트에 둔다.
# 플러그인 디렉토리에 두면 모든 프로젝트가 카운터를 공유해 다른 레포에서 오탐한다.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0
stamp="$REPO_ROOT/.claude/.last-loop-lock"  # .claude/.last-* 는 .gitignore 처리

# 검증성(루프 위험) 명령만 추적. 그 외 명령은 스트릭을 끊으므로 카운터 리셋.
# → "정확히 같은 검증 명령을 사이에 아무것도 없이 N회"일 때만 발동(오탐 최소).
if ! echo "$cmd" | grep -qE '\b(vitest|typecheck|tsc|turbo run (lint|typecheck|build|test)|build|eslint|lint)\b' \
   && ! echo "$cmd" | grep -qE '\b(pnpm|npm|yarn)[^|;&]*\btest\b'; then
  rm -f "$stamp" 2>/dev/null || true
  exit 0
fi

hash=$(printf '%s' "$cmd" | git hash-object --stdin 2>/dev/null || printf '%s' "$cmd" | cksum | awk '{print $1}')

prev_hash=""; prev_count=0
if [ -f "$stamp" ]; then
  prev_hash=$(sed -n '1p' "$stamp" 2>/dev/null || echo "")
  prev_count=$(sed -n '2p' "$stamp" 2>/dev/null || echo "0")
fi

if [ "$hash" = "$prev_hash" ]; then
  count=$((prev_count + 1))
else
  count=1
fi
printf '%s\n%s\n' "$hash" "$count" >"$stamp" 2>/dev/null || true

if [ "$count" -ge "$THRESHOLD" ]; then
  printf '🔁 LOOP LOCK: 같은 검증 명령을 %s회 연속 실행했습니다. 자기수정 루프로 보입니다.\n   접근을 바꾸거나(가설 재검토·다른 파일 확인) 사람에게 상황을 보고하세요. 같은 명령 반복 금지.\n' "$count" >&2
  exit 2
fi
exit 0
