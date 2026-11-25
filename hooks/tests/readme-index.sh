# README 목차가 실제와 맞는지 본다. test.sh 가 source 한다.
# 스킬 표 = ls skills · 훅 개수 = hooks.json 고유 스크립트 · 에이전트 = ls agents · 상대 링크는 실제 파일을 가리킨다.
printf '\n[readme-index] README 스킬 · 훅 · 에이전트 · 상대 링크\n'
_ri_root="$(cd "$HOOKS/.." && pwd)"
_ri_readme="$_ri_root/README.md"

_ri_want_skills=$(cd "$_ri_root/skills" && ls -d */ | tr -d '/' | sort)
_ri_got_skills=$(grep -oE '\]\(skills/[a-z0-9-]+/SKILL\.md\)' "$_ri_readme" | sed -E 's#\]\(skills/([a-z0-9-]+)/SKILL\.md\)#\1#' | sort -u)
[ -n "$_ri_got_skills" ] && [ "$_ri_got_skills" = "$_ri_want_skills" ] \
  && ok "README 스킬 표 = ls skills" \
  || bad "README 스킬 표 ≠ ls skills" "$(diff <(echo "$_ri_want_skills") <(echo "$_ri_got_skills") | grep '^[<>]' | head -5 | tr '\n' ' ')"

_ri_want_agents=$(cd "$_ri_root/agents" && ls *.md | sed 's/\.md$//' | sort)
_ri_got_agents=$(grep -oE '\]\(agents/[a-z0-9-]+\.md\)' "$_ri_readme" | sed -E 's#\]\(agents/([a-z0-9-]+)\.md\)#\1#' | sort -u)
[ -n "$_ri_got_agents" ] && [ "$_ri_got_agents" = "$_ri_want_agents" ] \
  && ok "README 에이전트 = ls agents" \
  || bad "README 에이전트 ≠ ls agents" "$(diff <(echo "$_ri_want_agents") <(echo "$_ri_got_agents") | grep '^[<>]' | head -5 | tr '\n' ' ')"

_ri_want_hooks=$(grep -oE 'hooks/[a-z0-9-]+\.sh' "$_ri_root/hooks/hooks.json" | sort -u | wc -l | tr -d ' ')
_ri_got_hooks=$(grep -E '<summary>' "$_ri_readme" | grep -oE '훅 [0-9]+개' | head -1 | grep -oE '[0-9]+')
[ -n "$_ri_got_hooks" ] && [ "$_ri_got_hooks" = "$_ri_want_hooks" ] \
  && ok "README 훅 개수 = hooks.json 고유 스크립트($_ri_want_hooks)" \
  || bad "README 훅 개수 ≠ hooks.json" "README <summary> 훅 ${_ri_got_hooks:-없음}개 · hooks.json ${_ri_want_hooks}개"

_ri_broken=""
_ri_links=$(grep -oE '\]\([^)]+\)' "$_ri_readme" | sed -E 's/^\]\(//; s/\)$//; s/[[:space:]].*$//' | grep -vE '^(https?:|mailto:|#)' || true)
_ri_n=0
for _ri_l in $_ri_links; do
  _ri_n=$((_ri_n + 1))
  _ri_p="${_ri_l%%#*}"
  [ -e "$_ri_root/$_ri_p" ] || _ri_broken="$_ri_broken $_ri_l"
done
[ "$_ri_n" -gt 0 ] && [ -z "$_ri_broken" ] \
  && ok "README 상대 링크 ${_ri_n}개가 실제 파일 · 폴더를 가리킨다" \
  || bad "README 상대 링크 깨짐(또는 0개)" "${_ri_broken:-상대 링크 0개}"
