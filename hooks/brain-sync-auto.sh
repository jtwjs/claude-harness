#!/usr/bin/env bash
# SessionStart — brain-sync 자동 이관(사람 확인 없음)을 백그라운드로 띄운다. 비차단(exit 0), 무출력.
#
# 왜 (2026-10-12):
#   brain-sync 는 "사람 확인 후 이관"이라 레포 세션에서 누가 부르지 않으면 돌지 않았다 — 사본이 레포보다 20장 뒤처진 적이 있다.
#   활발한 레포에서만, _brain/wiki 가 바뀌었을 때만 `brain-sync auto` 를 헤드리스로 돌린다.
#
# 켜는 법 (opt-in — 플러그인을 깐 모든 사람의 vault 에 무승인으로 쓰지 않게):
#   사용자 설정 env 에 CLAUDE_BRAIN_SYNC_AUTO=1. 레포를 빼려면 CLAUDE_BRAIN_SYNC_AUTO_SKIP="bv-builder:bv-partners"(레포 폴더 이름, 콜론 구분).
#
# 조건 (전부 통과해야 띄운다)
#   1. harness.json 의 brainSync.wikiPath·targetFolder 가 있고, wikiPath 가 실재하며 targetFolder 의 부모 폴더가 그 안에 실재한다
#      — 옛 경로(구 vault 위치·옛 폴더 구조)를 가리키면 엉뚱한 곳에 쓰므로 건너뛴다
#   2. 활발한 레포 (lib/active-repo.sh)
#   3. 마지막 이관 뒤 _brain/wiki/ 를 건드린 커밋이 있다 (마지막 이관 커밋은 레포 밖 HINT_DIR 에 둔다)
#
# 결과: 로그는 /tmp/brain-sync-auto-<레포키>.log (CLAUDE_BRAIN_SYNC_LOG_DIR 로 바꿀 수 있다). 성공하면 그때의 HEAD 를 기록한다(실패하면 다음 세션에 다시 시도).
set -uo pipefail
cat >/dev/null 2>&1 || true   # hook 입력(JSON) 소비

[ "${CLAUDE_BRAIN_SYNC_AUTO:-}" = "1" ] || exit 0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v git >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
# 본 레포(메인 워크트리) 기준 — 워크트리마다 돌면 같은 이관이 여러 번 뜬다
COMMON="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
case "$COMMON" in */.git) [ -d "${COMMON%/.git}" ] && REPO_ROOT="${COMMON%/.git}" ;; esac
cd "$REPO_ROOT" 2>/dev/null || exit 0
[ -f .claude/harness.json ] || exit 0
[ -d _brain/wiki ] || exit 0

name="$(basename "$REPO_ROOT")"
case ":${CLAUDE_BRAIN_SYNC_AUTO_SKIP:-}:" in *":$name:"*) exit 0 ;; esac

# ── 1. 대상 경로 ────────────────────────────────────────────────────────────
IFS=$'\t' read -r WIKI TARGET < <(python3 - <<'PY' 2>/dev/null
import json, os
b = json.load(open(".claude/harness.json")).get("brainSync") or {}
w, t = (b.get("wikiPath") or "").strip(), (b.get("targetFolder") or "").strip().strip("/")
if w and t:
    w = os.path.realpath(os.path.expanduser(w))
    if os.path.isdir(w) and os.path.isdir(os.path.dirname(os.path.join(w, t))):
        print(w, t, sep="\t")
PY
)
[ -n "${WIKI:-}" ] && [ -n "${TARGET:-}" ] || exit 0

# ── 2. 활발한 레포 ──────────────────────────────────────────────────────────
# shellcheck source=lib/active-repo.sh
. "$SCRIPT_DIR/lib/active-repo.sh" 2>/dev/null || exit 0
active_repo "$REPO_ROOT" || exit 0

# ── 3. _brain/wiki 변경 ─────────────────────────────────────────────────────
HINT_DIR="${CLAUDE_SKILL_HINTS_DIR:-$HOME/.claude/skill-hints}"
HINT_KEY="$(printf '%s' "$REPO_ROOT" | tr '/' '-')"
LAST_FILE="$HINT_DIR/$HINT_KEY.brain-sync-last"
RUN_FILE="$HINT_DIR/$HINT_KEY.brain-sync-run"
mkdir -p "$HINT_DIR" 2>/dev/null || exit 0
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null)" || exit 0
last="$(cat "$LAST_FILE" 2>/dev/null)"
if [ -n "$last" ] && git cat-file -e "$last^{commit}" 2>/dev/null; then
  [ "$(git rev-list --count "$last..HEAD" -- _brain/wiki 2>/dev/null || echo 0)" -gt 0 ] || exit 0
fi
# 같은 날 두 번 띄우지 않는다(백그라운드 이관 중일 수 있다)
[ "$(cat "$RUN_FILE" 2>/dev/null)" = "$(date +%F)" ] && exit 0
date +%F > "$RUN_FILE" 2>/dev/null || true

LOG="${CLAUDE_BRAIN_SYNC_LOG_DIR:-/tmp}/brain-sync-auto-$HINT_KEY.log"   # /tmp 고정 — 다른 자동화 로그와 같은 자리(macOS $TMPDIR 는 /var/folders/… 라 찾기 어렵다)
CLAUDE_BIN="${CLAUDE_BRAIN_SYNC_BIN:-claude}"
run() {
  {
    echo "=== $(date '+%F %T') brain-sync auto start $REPO_ROOT → $WIKI/$TARGET ==="
    if "$CLAUDE_BIN" -p "/claude-harness:brain-sync auto" \
         --permission-mode acceptEdits \
         --allowedTools "Read,Write,Edit,Glob,Grep,Bash(git:*)" \
         --add-dir "$WIKI" \
         --output-format text; then
      printf '%s\n' "$HEAD_SHA" > "$LAST_FILE"
      echo "=== $(date '+%F %T') done ==="
    else
      echo "=== $(date '+%F %T') failed $? ==="
    fi
  } >> "$LOG" 2>&1
}
if [ -n "${CLAUDE_BRAIN_SYNC_SYNC:-}" ]; then run; else ( run & ) >/dev/null 2>&1; fi   # 테스트만 동기 실행
exit 0
