#!/usr/bin/env bash
# SessionStart — AI-Readiness 자동 채점 + 떨어졌을 때만 알림. 비차단(exit 0).
#
# 왜 이렇게 바뀌었나 (2026-10-11):
#   이 파일은 "주간 채점"이라는 이름으로 있었지만 hooks.json 어디에도 등록돼 있지 않았다 — 채점 기록 0.
#   그동안 cadence-reminder 축 4 가 "점수를 다시 잴 시점"을 94세션 환기했고 실행은 0번이었다.
#   그래서 환기를 버리고 이 훅이 직접 잰다. 점수가 떨어진 주만 신호다 — "뭔가 들어왔는데 문서가 안 따라왔다".
#
# 동작
#   1. 직전 두 리포트를 비교한다(빠르다). 떨어졌으면 그 리포트에 대해 한 번만 additionalContext 로 알리고,
#      상태줄 권고 파일($HINT_KEY.readiness)은 다음 채점까지 남긴다. 떨어지지 않았으면 권고 파일을 지운다.
#   2. 마지막 채점 뒤 7일 이상 + 커밋 20건 이상(리포트가 없으면 커밋 20건 이상)이면 채점을 **백그라운드로** 시작한다.
#      큰 레포는 5초가 걸려(실측: creator-cms-v2 5.17s, bv-builder 0.85s) 세션 시작을 막지 않는다. 결과 비교는 다음 세션.
#
# 레포에 쓰는 것: .claude/reports/<날짜>/ai-readiness-score.json 뿐이다. .claude/reports/ 는 .git/info/exclude 에도 넣어
#   gitignore 가 없는 옛 레포에서도 git status 에 뜨지 않게 한다. 권고·확인 기록은 레포 밖(HINT_DIR).
set -uo pipefail
cat >/dev/null 2>&1 || true   # hook 입력(JSON) 소비

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"          # 🔴 채점기는 '플러그인'에, 리포트는 '프로젝트'에
command -v git >/dev/null 2>&1 || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0
# 본 레포(메인 워크트리) 기준으로 잰다 — 워크트리마다 재면 새 워크트리 첫 세션마다 채점이 돌고,
# 리포트가 워크트리와 함께 지워져 하락 비교가 쌓이지 않는다(2026-10-11 리뷰).
COMMON="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
case "$COMMON" in */.git) [ -d "${COMMON%/.git}" ] && REPO_ROOT="${COMMON%/.git}" ;; esac
cd "$REPO_ROOT" 2>/dev/null || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

SCORER="$PLUGIN_ROOT/skills/ai-readiness-cartography/scripts/score.py"
[ -f "$SCORER" ] || exit 0
OUT_DIR=".claude/reports"
DATE="$(date +%F)"
GAP_DAYS=7
GAP_COMMITS=20
HINT_DIR="${CLAUDE_SKILL_HINTS_DIR:-$HOME/.claude/skill-hints}"
HINT_KEY="$(printf '%s' "$REPO_ROOT" | tr '/' '-')"
HINT_FILE="$HINT_DIR/$HINT_KEY.readiness"
SEEN_FILE="$HINT_DIR/$HINT_KEY.readiness-seen"

# ── 0. 리포트 폴더를 이 맥에서 git 제외 ─────────────────────────────────────
EXCLUDE="$(git rev-parse --git-path info/exclude 2>/dev/null)"
if [ -n "$EXCLUDE" ]; then
  case "$EXCLUDE" in /*) ;; *) EXCLUDE="$REPO_ROOT/$EXCLUDE" ;; esac
  mkdir -p "$(dirname "$EXCLUDE")" 2>/dev/null
  grep -qxF '.claude/reports/' "$EXCLUDE" 2>/dev/null || printf '.claude/reports/\n' >> "$EXCLUDE" 2>/dev/null || true
fi

# ── 1. 직전 두 리포트 비교 ───────────────────────────────────────────────────
# 출력: "drop<TAB>최근날짜<TAB>이전점수<TAB>최근점수<TAB>떨어진 범주" · "ok<TAB>최근날짜" · 빈 값(리포트 2개 미만)
cmp_line="$(python3 - "$OUT_DIR" <<'PY' 2>/dev/null
import json, os, re, sys
d = sys.argv[1]
dates = sorted(x for x in (os.listdir(d) if os.path.isdir(d) else [])
               if re.fullmatch(r"\d{4}-\d{2}-\d{2}", x) and os.path.isfile(os.path.join(d, x, "ai-readiness-score.json")))
if len(dates) < 2:
    sys.exit(0)
a, b = (json.load(open(os.path.join(d, x, "ai-readiness-score.json"))) for x in dates[-2:])
if b["total"] < a["total"]:
    fell = [f'{k} {v["name"]} {a["categories"][k]["score"]}→{v["score"]}'
            for k, v in b["categories"].items() if k in a["categories"] and v["score"] < a["categories"][k]["score"]]
    print("drop", dates[-1], a["total"], b["total"], " · ".join(fell), sep="\t")
else:
    print("ok", dates[-1], sep="\t")
PY
)"
msg=""
case "$cmp_line" in
  drop*)
    IFS=$'\t' read -r _ rdate before after fell <<<"$cmp_line"
    mkdir -p "$HINT_DIR" 2>/dev/null
    printf 'ai-readiness — %s→%s점\n' "$before" "$after" > "$HINT_FILE" 2>/dev/null || true
    if [ "$(cat "$SEEN_FILE" 2>/dev/null)" != "$rdate" ]; then
      # ⚠️ 큰따옴표를 쓰지 않는다 — JSON 으로 직접 싼다.
      msg="AI-Readiness 점수가 ${before}점에서 ${after}점으로 떨어졌다(${rdate} 채점, 떨어진 범주: ${fell:-총점만}). 뭔가 들어왔는데 문서가 안 따라왔다는 신호다 — 사용자에게 한 줄로 알리고, 원하면 ai-readiness-cartography 로 대시보드와 할 일 목록을 만든다."
      printf '%s\n' "$rdate" > "$SEEN_FILE" 2>/dev/null || true
    fi
    ;;
  ok*) rm -f "$HINT_FILE" 2>/dev/null || true ;;
esac

# ── 2. 채점할 때가 됐으면 백그라운드로 ──────────────────────────────────────
# 결과 파일이 있는 날짜만 센다 — 채점이 중간에 죽어 빈 폴더가 남으면 7일 동안 다시 안 재는 일이 생긴다(2026-10-11 리뷰).
last="$(for x in "$OUT_DIR"/*/ai-readiness-score.json; do [ -f "$x" ] && basename "$(dirname "$x")"; done 2>/dev/null \
  | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort | tail -1)"
due=0
if [ -z "$last" ]; then
  [ "$(git rev-list --count HEAD 2>/dev/null || echo 0)" -ge "$GAP_COMMITS" ] && due=1
else
  days=$(python3 -c "import datetime,sys; print((datetime.date.today()-datetime.date.fromisoformat(sys.argv[1])).days)" "$last" 2>/dev/null || echo 0)
  commits=$(git rev-list --count --since="$last 00:00" HEAD 2>/dev/null || echo 0)
  [ "${days:-0}" -ge "$GAP_DAYS" ] && [ "${commits:-0}" -ge "$GAP_COMMITS" ] && due=1
fi
if [ "$due" = 1 ] && [ ! -d "$OUT_DIR/$DATE" ]; then   # 같은 날 두 번 띄우지 않는다(백그라운드 채점 중일 수 있다)
  mkdir -p "$OUT_DIR/$DATE" 2>/dev/null || exit 0
  run() {
    # score.py 인자는 repo · --json · --markdown · --quiet 뿐이다. 실패하면 빈 날짜 폴더를 지운다(채점했다고 믿지 않게).
    python3 "$SCORER" "$REPO_ROOT" --quiet --json "$OUT_DIR/$DATE/ai-readiness-score.json" >/dev/null 2>&1 \
      || rm -rf "$OUT_DIR/$DATE" 2>/dev/null
  }
  if [ -n "${CLAUDE_READINESS_SYNC:-}" ]; then run; else ( run & ) >/dev/null 2>&1; fi   # 테스트만 동기 실행
fi

[ -n "$msg" ] && printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
exit 0
