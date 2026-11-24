# pr-write 에 막는 이해 관문(퀴즈 · 못 풀면 draft)이 없고, 본문 첫머리가 sdd 마무리의 세 줄 요약이다(ADR-016 D-gate · D-요약). test.sh 가 source 한다.
# draft 는 사람이 원할 때만 남는다 — 퀴즈 · 미달 · draft 전환 문구가 돌아오면 실패. tables.md(_brain, ADR-013으로 없어짐) 줄도 0.
printf '\n[no-gate-pr] 이해 게이트 · 퀴즈 · draft 강제 0 · tables.md 0 · 본문 첫머리 세 줄 요약\n'
_np_root="$(cd "$HOOKS/.." && pwd)"
_np_f="$_np_root/skills/pr-write/SKILL.md"

# ① 이해 게이트 · 퀴즈 단계와 「못 풀면 draft」 강제가 없다
_np_gate=$(grep -nE '이해 게이트|퀴즈|pr-quiz|4\.9단계|못 풀면|미달|gh pr ready' "$_np_f" 2>/dev/null | cut -c1-120 || true)
[ -f "$_np_f" ] && [ -z "$_np_gate" ] && ok "pr-write — 이해 게이트 · 퀴즈 · draft 강제 문구 0" \
  || bad "pr-write 에 막는 관문 문구 남음" "$(echo "${_np_gate:-skills/pr-write/SKILL.md 없음}" | head -3)"

# ② tables.md 가 없다
_np_tables=$(grep -nF 'tables.md' "$_np_f" 2>/dev/null | cut -c1-120 || true)
[ -f "$_np_f" ] && [ -z "$_np_tables" ] && ok "pr-write — tables.md 0" \
  || bad "pr-write 에 tables.md 남음" "$(echo "${_np_tables:-skills/pr-write/SKILL.md 없음}" | head -3)"

# ③ 본문 첫머리에 세 줄 요약을 쓰라는 문구가 있다(한 줄에 「세 줄 요약」과 「첫머리」)
_np_sum=$(grep -F '세 줄 요약' "$_np_f" 2>/dev/null | grep -F '첫머리' || true)
[ -n "$_np_sum" ] && ok "pr-write — 본문 첫머리 세 줄 요약 문구 있음" \
  || bad "pr-write 에 본문 첫머리 세 줄 요약 문구 없음" "「세 줄 요약」+「첫머리」 한 줄"
