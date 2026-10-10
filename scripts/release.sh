#!/usr/bin/env bash
# 하네스 릴리스 — push → 마켓플레이스 갱신 → 플러그인 갱신 → 실제 반영 확인. 끝나면 gh 계정을 되돌린다.
#
# 왜 스크립트인가 (2026-10-11):
#   이 레포는 jtwjs 계정 private 이다. 평소 active 계정(회사)으로 push 하면 404, 마켓플레이스 갱신은
#   clone 실패를 경고로만 띄우고 "0.2.2 → 0.2.3 업데이트 성공"으로 보고한다(내용은 그대로, 캐시에 가짜 버전 폴더).
#   다섯 단계를 매번 손으로 밟다 계정 전환·원복·반영 확인을 빠뜨린 적이 있어 한 줄로 묶었다.
#
# 쓰는 법: scripts/release.sh [--dry-run]
#   RELEASE_GH_USER(기본 jtwjs) · RESTORE_GH_USER(기본: 실행 전 active 계정) · MARKETPLACE(기본 jtwjs-plugins)
set -euo pipefail

DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PLUGIN="claude-harness"
MARKETPLACE="${MARKETPLACE:-jtwjs-plugins}"
RELEASE_GH_USER="${RELEASE_GH_USER:-jtwjs}"

die() { printf '✗ %s\n' "$*" >&2; exit 1; }
step() { printf '\n▶ %s\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then printf '  (dry-run) %s\n' "$*"; else "$@"; fi; }

# ── 0. 사전 확인 — 하나라도 어긋나면 아무것도 바꾸기 전에 멈춘다 ─────────────
step "사전 확인"
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || die "main 브랜치가 아니다"
[ -z "$(git status --porcelain)" ] || die "커밋 안 된 변경이 있다"
ver="$(python3 -c 'import json;print(json.load(open(".claude-plugin/plugin.json"))["version"])')"
mver="$(python3 -c 'import json;d=json.load(open(".claude-plugin/marketplace.json"));print(next(p["version"] for p in d["plugins"] if p["name"]=="'"$PLUGIN"'"))')"
[ "$ver" = "$mver" ] || die "버전 불일치: plugin.json $ver · marketplace.json $mver"
skills=$(ls -d skills/*/ | wc -l | tr -d ' ')
bash hooks/test.sh >/dev/null 2>&1 || die "hooks/test.sh 실패 — 먼저 고친다"
ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')
printf '  버전 %s · 스킬 %s개 · push 할 커밋 %s건 · 훅 테스트 통과\n' "$ver" "$skills" "$ahead"

# ── 1. 계정 전환 — 어떤 이유로 끝나든 원래 계정으로 되돌린다 ─────────────────
step "gh 계정 → $RELEASE_GH_USER"
prev="$(gh api user -q .login 2>/dev/null || true)"
RESTORE_GH_USER="${RESTORE_GH_USER:-$prev}"
restore() { [ -n "$RESTORE_GH_USER" ] && [ "$DRY" = 0 ] && gh auth switch -u "$RESTORE_GH_USER" >/dev/null 2>&1 && printf '\n↩ gh 계정 → %s\n' "$RESTORE_GH_USER"; return 0; }
trap restore EXIT
run gh auth switch -u "$RELEASE_GH_USER"
[ "$DRY" = 1 ] || [ "$(gh api user -q .login)" = "$RELEASE_GH_USER" ] || die "계정 전환 실패"

# ── 2~4. push → 마켓플레이스 → 플러그인 ───────────────────────────────────
step "push"
run git push origin main
step "마켓플레이스 갱신"
run claude plugin marketplace update "$MARKETPLACE"
step "플러그인 갱신"
run claude plugin update "$PLUGIN@$MARKETPLACE"

# ── 5. 실제 반영 확인 — "업데이트 성공" 문구를 믿지 않고 버전과 스킬 수를 본다 ──
step "반영 확인"
if [ "$DRY" = 1 ]; then
  printf '  (dry-run) claude plugin details %s@%s → "%s %s" · Skills (%s) 기대\n' "$PLUGIN" "$MARKETPLACE" "$PLUGIN" "$ver" "$skills"
  exit 0
fi
details="$(claude plugin details "$PLUGIN@$MARKETPLACE" 2>&1)"
got_ver="$(printf '%s\n' "$details" | awk -v p="$PLUGIN" '$1==p{print $2; exit}')"
got_skills="$(printf '%s\n' "$details" | sed -n 's/.*Skills (\([0-9]*\)).*/\1/p' | head -1)"
[ "$got_ver" = "$ver" ] || die "설치본 버전 $got_ver ≠ $ver — 가짜 갱신일 수 있다. 다음 버전 번호는 $got_ver 와 겹치지 않게"
[ "$got_skills" = "$skills" ] || die "설치본 스킬 $got_skills개 ≠ 레포 $skills개"
printf '  ✓ 설치본 %s · 스킬 %s개. 새 세션부터 적용된다\n' "$got_ver" "$got_skills"
