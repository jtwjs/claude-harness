# 재구성(ADR-016 D1 · D3)으로 바뀌거나 지운 스킬 이름이 다시 들어오면 실패. test.sh 가 source 한다.
# 옛 이름은 skills/harness-init/SKILL.md 이름표에만 남는다. 쌓기만 하는 기록(docs/ · phases/)은 세지 않는다.
# PLAN 스킬 옛 이름 harness 는 harness.json · harness-init 같은 낱말과 섞이므로 스킬 이름 · 경로 자리로만 센다.
# -I: 이름을 바꾸기 전에 생긴 __pycache__/*.pyc(gitignore)가 옛 경로를 품고 있어 바이너리는 세지 않는다.
printf '\n[renames] harness · harness-run · ai-readiness-cartography · plannotator-visual-explainer 참조 0\n'
_rn_root="$(cd "$HOOKS/.." && pwd)"
_rn_left=$(grep -rnIE 'claude-harness:harness([^-a-z]|$)|skills/harness/|harness-run|ai-readiness-cartography|plannotator-visual-explainer' \
  "$_rn_root/skills" "$_rn_root/agents" "$_rn_root/hooks" "$_rn_root/templates" "$_rn_root/scripts" \
  "$_rn_root/README.md" "$_rn_root/BACKLOG.md" 2>/dev/null \
  | grep -vF -e "$_rn_root/hooks/test.sh:" -e "$_rn_root/hooks/tests/renames.sh:" -e "$_rn_root/skills/harness-init/SKILL.md:" || true)
[ -z "$_rn_left" ] && ok "옛 스킬 이름 참조 0(이름표 밖)" || bad "옛 스킬 이름 남음" "$(echo "$_rn_left" | head -3)"
