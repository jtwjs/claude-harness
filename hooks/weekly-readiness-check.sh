#!/usr/bin/env bash
# 주간 AI-Readiness 채점 (문서 04 "자동화 — Hook 연동").
#
# 목적: 점수가 떨어진 주가 곧 신호 — "뭔가 들어왔는데 문서 갱신이 안 됐다".
# 트리거: 아직 cron/CI 에 등록하지 않는다(파일만 준비). 수동 또는 추후 cron 으로 연결.
#   예) crontab:  0 9 * * 1  cd <repo> && bash "$CLAUDE_PLUGIN_ROOT/hooks/weekly-readiness-check.sh"
#
# 동작: score.py 를 돌려 .claude/reports/ 에 날짜별 리포트를 남긴다(stdlib만, 비차단).
set -uo pipefail

# 🔴 두 경로를 갈라야 한다 — 채점기는 '플러그인'에, 리포트는 '프로젝트'에 있다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"          # 플러그인 리소스 기준
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0
cd "$REPO_ROOT" 2>/dev/null || exit 0

command -v python3 >/dev/null 2>&1 || { printf 'python3 없음 — skip\n' >&2; exit 0; }

DATE=$(date +%F)
SCORER="$PLUGIN_ROOT/skills/ai-readiness-cartography/scripts/score.py"
OUT_DIR=".claude/reports"

[ -f "$SCORER" ] || { printf '채점 스크립트 없음: %s\n' "$SCORER" >&2; exit 0; }

# 날짜별 보관 디렉터리(추세 추적용). 최신본은 기본 위치에도 갱신됨.
python3 "$SCORER" "$REPO_ROOT" --out-dir "$OUT_DIR/$DATE" >/dev/null 2>&1 || true

printf '📊 AI-Readiness 주간 리포트 생성: %s/%s/ai-readiness-report.html\n' "$OUT_DIR" "$DATE" >&2
exit 0
