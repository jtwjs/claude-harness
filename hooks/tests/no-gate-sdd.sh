# sdd 에 입력을 기다리며 막는 이해 관문이 없고, 마무리가 세 줄 요약 · 학습 카드를 낸다(ADR-016 D-gate · D-요약 · D13). test.sh 가 source 한다.
# 「내 한 줄」은 학습 카드의 선택 항목으로만 남는다 — 잠그는 문구(입력 뒤 고치지 않는다 등)가 돌아오면 실패.
printf '\n[no-gate-sdd] 빈틈 3곳 · 내 한 줄 잠금 0 · 세 줄 요약 · 학습 카드 · recall 출력 계약\n'
_ng_root="$(cd "$HOOKS/.." && pwd)"
_ng_f="$_ng_root/skills/sdd/SKILL.md"

# ① 막는 관문 문구가 없다
_ng_gate=$(grep -nE '빈틈 3곳|입력 뒤 고치지 않는다|입력 시점에 잠근다|자기 말 한 줄' "$_ng_f" 2>/dev/null | cut -c1-120 || true)
[ -f "$_ng_f" ] && [ -z "$_ng_gate" ] && ok "sdd — 빈틈 3곳 · 내 한 줄 잠금 문구 0" \
  || bad "sdd 에 막는 관문 문구 남음" "$(echo "${_ng_gate:-skills/sdd/SKILL.md 없음}" | head -3)"

# ② 「내 한 줄」이 나오는 줄은 모두 선택 항목이다
_ng_mine=$(grep -nF '내 한 줄' "$_ng_f" 2>/dev/null | grep -vF '선택' | cut -c1-120 || true)
[ -f "$_ng_f" ] && [ -z "$_ng_mine" ] && ok "sdd — 내 한 줄은 선택 항목으로만" \
  || bad "sdd 에 선택이 아닌 내 한 줄" "$(echo "${_ng_mine:-skills/sdd/SKILL.md 없음}" | head -3)"

# ③ 마무리 세 줄 요약 · 학습 카드(작업 요약) · 재개 recall 출력 계약(다음 수)
_ng_miss=""
for _ng_need in '세 줄 요약' '학습 카드' '작업 요약' '다음 수'; do
  grep -qF "$_ng_need" "$_ng_f" 2>/dev/null || _ng_miss="$_ng_miss $_ng_need"
done
[ -z "$_ng_miss" ] && ok "sdd — 세 줄 요약 · 학습 카드 · 작업 요약 · 다음 수 있음" \
  || bad "sdd 에 없는 문구" "[${_ng_miss# }]"
