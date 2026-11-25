# 흐름 스킬 본문에 날짜 · 버전 이력 줄이 없다(ADR-016 D0). test.sh 가 source 한다.
# 날짜(20YY-MM) · 버전(N.N.N) 숫자만 센다 — 경로 · 형식 예시(YYYY-MM-DD)는 숫자가 아니라 걸리지 않는다.
# pr-write 4.6 심각도는 sdd-review · code-reviewer 두 리뷰의 「확인 필요」를 모두 🟡로 센다(ADR-016 Q10).
printf '\n[no-history-flow] 흐름 스킬 13개 날짜 · 버전 이력 줄 0 · pr-write 확인 필요는 두 리뷰 다 🟡\n'
_nh_root="$(cd "$HOOKS/.." && pwd)"

# ① 날짜 · 버전 줄이 없다(파일이 없어도 실패 — 이름이 바뀌면 검사 대상도 같이 옮긴다)
_nh_left=""; _nh_missing=""; _nh_n=0
for _nh_s in sdd sdd-plan sdd-run sdd-review design-brief design-critique design-reconcile why how conductor commit pr-write changeset; do
  _nh_f="$_nh_root/skills/$_nh_s/SKILL.md"
  if [ ! -f "$_nh_f" ]; then _nh_missing="$_nh_missing $_nh_s"; continue; fi
  _nh_n=$((_nh_n+1))
  _nh_hit=$(grep -nE '20[0-9]{2}-[0-9]{2}|[0-9]+\.[0-9]+\.[0-9]+' "$_nh_f" 2>/dev/null | cut -c1-100 | sed "s#^#skills/$_nh_s/SKILL.md:#" || true)
  [ -n "$_nh_hit" ] && _nh_left="${_nh_left:+$_nh_left
}$_nh_hit"
done
[ -z "$_nh_missing" ] || bad "검사할 스킬 파일 없음" "[${_nh_missing# }]"
[ -z "$_nh_left" ] && [ "$_nh_n" -gt 0 ] && ok "흐름 스킬 ${_nh_n}개 — 날짜 · 버전 이력 줄 0" \
  || bad "날짜 · 버전 이력 줄 남음 ($(printf '%s\n' "$_nh_left" | grep -c .)줄)" "$(printf '%s\n' "$_nh_left" | head -3)"

# ② pr-write — 「🟡로 센다」 문장이 sdd-review · code-reviewer 둘 다의 「확인 필요」를 가리킨다. 붙여 쓴 「확인필요」는 0
_nh_pr="$_nh_root/skills/pr-write/SKILL.md"
_nh_rule=$(grep -oE '[^.]*🟡로 센다' "$_nh_pr" 2>/dev/null | grep -F '확인 필요' | grep -F 'sdd-review' | grep -F 'code-reviewer' || true)
[ -n "$_nh_rule" ] && ok "pr-write — sdd-review · code-reviewer 의 확인 필요를 🟡로 센다" \
  || bad "pr-write 심각도가 두 리뷰의 확인 필요를 다 세지 않음" "「🟡로 센다」 문장에 sdd-review · code-reviewer · 확인 필요"
_nh_glued=$(grep -nF '확인필요' "$_nh_pr" 2>/dev/null | cut -c1-100 || true)
[ -f "$_nh_pr" ] && [ -z "$_nh_glued" ] && ok "pr-write — 붙여 쓴 확인필요 0" \
  || bad "pr-write 에 붙여 쓴 확인필요" "$(echo "${_nh_glued:-skills/pr-write/SKILL.md 없음}" | head -3)"
