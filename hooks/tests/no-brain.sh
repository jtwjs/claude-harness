# 레포에 팀 위키 폴더(_brain/)를 두지 않는다 (ADR-013, 2026-11-23). test.sh 가 source 한다.
# 스킬·훅·템플릿·스크립트·README 에 옛 경로·옛 스킬 이름이 다시 들어오면 실패. 역사 기록(docs/)은 센다에서 뺀다.
printf '\n[no-brain] _brain · brain-sync · brain-walk 참조 0\n'
_nb_root="$(cd "$HOOKS/.." && pwd)"
_nb_left=$(grep -rnE '_brain|brain-sync|brain-walk|rules/brain\.md' \
  "$_nb_root/skills" "$_nb_root/agents" "$_nb_root/hooks" "$_nb_root/templates" "$_nb_root/scripts" \
  "$_nb_root/README.md" "$_nb_root/BACKLOG.md" 2>/dev/null \
  | grep -v '/hooks/tests/no-brain.sh:' | grep -vE 'ADR-013' || true)
[ -z "$_nb_left" ] && ok "_brain 참조 0" || bad "_brain 참조 남음" "$(echo "$_nb_left" | head -3)"
for _nb_gone in skills/brain-sync skills/brain-walk hooks/brain-sync-auto.sh templates/_brain templates/.claude/rules/brain.md; do
  [ -e "$_nb_root/$_nb_gone" ] && bad "지운 것이 남음" "$_nb_gone"
done
[ ! -e "$_nb_root/skills/brain-sync" ] && [ ! -e "$_nb_root/templates/_brain" ] && ok "brain 스킬·템플릿 파일 없음"
