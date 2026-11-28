#!/usr/bin/env bash
# 하네스 릴리스 — push → 마켓플레이스 갱신 → 플러그인 갱신 → 실제 반영 확인 → 상시 비용 표 한 줄 제안. 끝나면 gh 계정을 되돌린다.
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
# 설치본 Always-on 을 읽어 design-notes §3 표에 넣을 한 줄을 제안만 한다 — 읽기 전용, 파일은 고치지 않는다
always_on() {
  step "상시 비용"
  command -v claude >/dev/null 2>&1 || { printf '  claude 없음 — 상시 비용 출력 건너뜀\n'; return 0; }
  local d v tok s a per
  d="$(claude plugin details "$PLUGIN@$MARKETPLACE" 2>&1)" || { printf '  claude plugin details 실패 — 상시 비용 출력 건너뜀\n'; return 0; }
  v="$(printf '%s\n' "$d" | awk -v p="$PLUGIN" '$1==p{print $2; exit}')"
  tok="$(printf '%s\n' "$d" | awk '$1=="Always-on:"{sub(/^~/,"",$2); print $2; exit}')"
  s="$(printf '%s\n' "$d" | awk '$1=="Skills"{gsub(/[()]/,"",$2); print $2; exit}')"
  a="$(printf '%s\n' "$d" | awk '$1=="Agents"{gsub(/[()]/,"",$2); print $2; exit}')"
  [ -n "$tok" ] || { printf '  Always-on 줄을 못 찾음 — 상시 비용 출력 건너뜀\n'; return 0; }
  per="$(awk -v t="${tok//,/}" -v n="$(( ${s:-0} + ${a:-0} ))" 'BEGIN{if(n>0)printf "%.1f",t/n; else printf "?"}')"
  printf '  Always-on ~%s tok · 스킬 %s + 에이전트 %s (설치본 %s)\n' "$tok" "${s:-?}" "${a:-?}" "${v:-?}"
  local idir="$HOME/.claude/plugins/cache/$MARKETPLACE/$PLUGIN/${v:-?}" chars
  [ -d "$idir" ] || idir="."   # 설치본 폴더가 없으면 레포를 잰다
  chars="$(python3 scripts/always-on.py "$idir" 2>/dev/null | awk -F'\t' '$1=="total"{print $2" 자 · "$3}')"
  printf '  모델이 보는 설명 %s (자동 입구 스킬 + 에이전트 description, scripts/always-on.py %s)\n' "${chars:-? (always-on.py 실패)}" "$idir"
  printf '  design-notes §3 표에 넣을 줄(직접 붙인다):\n  | %s | %s + %s | %s | %s |\n' "${v:-?}" "${s:-?}" "${a:-?}" "$tok" "$per"
}

# ── 0. 사전 확인 — 하나라도 어긋나면 아무것도 바꾸기 전에 멈춘다 ─────────────
step "사전 확인"
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || die "main 브랜치가 아니다"
[ -z "$(git status --porcelain)" ] || die "커밋 안 된 변경이 있다"
ver="$(python3 -c 'import json;print(json.load(open(".claude-plugin/plugin.json"))["version"])')"
mver="$(python3 -c 'import json;d=json.load(open(".claude-plugin/marketplace.json"));print(next(p["version"] for p in d["plugins"] if p["name"]=="'"$PLUGIN"'"))')"
[ "$ver" = "$mver" ] || die "버전 불일치: plugin.json $ver · marketplace.json $mver"
skills=$(ls -d skills/*/ | wc -l | tr -d ' ')
# 러너 단위 테스트는 hooks/tests/sdd-runner-unit.sh 가 test.sh 안에서 돌린다. 두 개수 모두 이 출력 한 번에서 읽는다(#111)
# test.sh 출력 문구에 기댄다: 「러너 단위 테스트 통과|실패」 · 「Ran N tests」 · 마지막 「통과 N · 실패 N」. 그 문구를 바꾸면 여기도 고친다(못 읽으면 멈춘다)
hout="$(bash hooks/test.sh 2>&1)" && hrc=0 || hrc=$?
runner_line="$(printf '%s\n' "$hout" | grep -E '러너 단위 테스트 (통과|실패)' | tail -1 || true)"
case "$runner_line" in *"러너 단위 테스트 실패"*) die "SDD 러너 테스트 실패 — 먼저 고친다";; esac
[ "$hrc" = 0 ] || die "hooks/test.sh 실패 — 먼저 고친다"
hook_n="$(printf '%s\n' "$hout" | LC_ALL=C sed -n 's/^통과 \([0-9][0-9]*\) · 실패 0$/\1/p' | tail -1)"
runner_n="$(printf '%s\n' "$runner_line" | LC_ALL=C sed -n 's/.*Ran \([0-9][0-9]*\) tests*.*/\1/p')"
[ -n "$runner_n" ] || die "hooks/test.sh 출력에 러너 테스트 결과 줄이 없다 — hooks/tests/sdd-runner-unit.sh 를 확인한다"
[ -n "$hook_n" ] || die "hooks/test.sh 출력에서 통과 개수를 못 읽었다"
ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo '?')
printf '  버전 %s · 스킬 %s개 · push 할 커밋 %s건 · 훅 테스트 통과 %s · 러너 테스트 통과 %s\n' "$ver" "$skills" "$ahead" "$hook_n" "$runner_n"

# ── 1. 계정 전환 — 어떤 이유로 끝나든 원래 계정으로 되돌린다 ─────────────────
step "gh 계정 → $RELEASE_GH_USER"
prev="$(gh api user -q .login 2>/dev/null || true)"
RESTORE_GH_USER="${RESTORE_GH_USER:-$prev}"
switched=0
restore() { [ "$switched" = 1 ] && [ -n "$RESTORE_GH_USER" ] && [ "$DRY" = 0 ] && gh auth switch -u "$RESTORE_GH_USER" >/dev/null 2>&1 && printf '\n↩ gh 계정 → %s\n' "$RESTORE_GH_USER"; return 0; }
trap restore EXIT
# 이미 릴리스 계정이면 전환을 건너뛴다 — 옛 gh(2.21 등)는 `gh auth switch` 가 없어 여기서 죽었다(2026-11-13)
if [ "$prev" = "$RELEASE_GH_USER" ]; then
  printf '  이미 %s — 전환 생략\n' "$RELEASE_GH_USER"
else
  run gh auth switch -u "$RELEASE_GH_USER" || die "gh auth switch 실패 — gh 가 옛 버전이면 직접 'gh auth login' 으로 $RELEASE_GH_USER 로 로그인한 뒤 다시"
  switched=1
fi
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
  always_on
  exit 0
fi
details="$(claude plugin details "$PLUGIN@$MARKETPLACE" 2>&1)"
got_ver="$(printf '%s\n' "$details" | awk -v p="$PLUGIN" '$1==p{print $2; exit}')"
got_skills="$(printf '%s\n' "$details" | sed -n 's/.*Skills (\([0-9]*\)).*/\1/p' | head -1)"
[ "$got_ver" = "$ver" ] || die "설치본 버전 $got_ver ≠ $ver — 가짜 갱신일 수 있다. 다음 버전 번호는 $got_ver 와 겹치지 않게"
[ "$got_skills" = "$skills" ] || die "설치본 스킬 ${got_skills}개 ≠ 레포 ${skills}개"
printf '  ✓ 설치본 %s · 스킬 %s개. 새 세션부터 적용된다\n' "$got_ver" "$got_skills"

# ── 6. 상시 비용 — 반영 확인 뒤에 재야 새 버전의 값이다 ─────────────────────
always_on
