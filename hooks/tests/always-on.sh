# 모델이 늘 보는 설명 글자 수 (ADR-018 B-16). test.sh 가 source 한다.
# details 의 Always-on 은 닫힌 스킬(disable-model-invocation: true)도 세므로, 자동 입구 스킬 + 에이전트 description 만 센다.
printf '\n[always-on] 자동 입구 스킬 + 에이전트 description 글자 수\n'
_ao_root="$(cd "$HOOKS/.." && pwd)"
_ao_py="$_ao_root/scripts/always-on.py"
_ao_p="$TMP/ao-plugin"
mkdir -p "$_ao_p/skills/open" "$_ao_p/skills/off" "$_ao_p/skills/closed" "$_ao_p/agents"
printf -- '---\nname: open\ndescription: abc\n---\n본문은 세지 않는다\n' > "$_ao_p/skills/open/SKILL.md"
printf -- '---\nname: off\ndescription: '"'"'d'"''"'e'"'"'\ndisable-model-invocation: false\n---\n' > "$_ao_p/skills/off/SKILL.md"
printf -- '---\nname: closed\ndescription: zzzzzzzzzz\ndisable-model-invocation: true\n---\n' > "$_ao_p/skills/closed/SKILL.md"
printf -- '---\nname: rev\ndescription: "he said \\"hi\\""\ntools: Read\n---\n' > "$_ao_p/agents/rev.md"
_ao_out="$(python3 "$_ao_py" "$_ao_p" 2>&1)"; _ao_rc=$?
[ "$_ao_rc" -eq 0 ] && ok "always-on.py 가 돈다" || bad "always-on.py 실패" "$_ao_out"
[ "$_ao_rc" -eq 0 ] && ! printf '%s\n' "$_ao_out" | grep -q 'closed' \
  && ok "닫힌 스킬은 세지 않는다" || bad "닫힌 스킬을 셈" "$_ao_out"
printf '%s\n' "$_ao_out" | awk -F'\t' '$1=="skill"&&$2=="open"&&$3==3{f=1} END{exit !f}' \
  && ok "자동 입구 스킬은 센다 (본문 제외)" || bad "자동 입구 스킬" "$_ao_out"
printf '%s\n' "$_ao_out" | awk -F'\t' '$1=="skill"&&$2=="off"&&$3==3{f=1} END{exit !f}' \
  && ok "disable-model-invocation: false 는 센다 · 작은따옴표 벗김" || bad "false 스킬" "$_ao_out"
printf '%s\n' "$_ao_out" | awk -F'\t' '$1=="agent"&&$2=="rev"&&$3==12{f=1} END{exit !f}' \
  && ok "에이전트는 센다 · 큰따옴표 벗김" || bad "에이전트" "$_ao_out"
printf '%s\n' "$_ao_out" | awk -F'\t' '$1=="skill"||$1=="agent"{s+=$3} $1=="total"{t=$2} END{exit !(t==18 && s==t)}' \
  && ok "합계 = 컴포넌트 합 (18)" || bad "합계" "$_ao_out"
_ao_real="$(python3 "$_ao_py" "$_ao_root" 2>&1)"
printf '%s\n' "$_ao_real" | awk -F'\t' '$1=="skill"||$1=="agent"{s+=$3;n++} $1=="total"{t=$2} END{exit !(n>0 && t>0 && s==t)}' \
  && ok "이 레포 합계 = 컴포넌트 합" || bad "이 레포 합계" "$(printf '%s\n' "$_ao_real" | tail -3)"
