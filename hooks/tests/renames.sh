# 바뀌거나 지운 스킬 이름이 다시 들어오면 실패. test.sh 가 source 한다.
# 옛 이름 목록은 skills/harness-init/references/renames.tsv 1칸(머리 줄 제외)에서 읽고, 이름표 폴더(skills/harness-init/)에만 남는다.
# 세지 않는 것: 쌓기만 하는 기록(docs/ · phases/), 옛 이름을 검사 데이터로 품는 테스트(hooks/test.sh · hooks/tests/),
#   날짜(YYYY-MM-DD) · 버전(N.N.N)이 붙은 이력 줄 — 그 줄은 날짜 · 버전 줄 검사(ADR-016 D0)가 지운다.
# 지금 스킬 폴더 이름의 일부인 옛 이름(harness ⊂ harness-init)은 harness.json · harness-* 같은 낱말과 섞이므로 스킬 이름 · 경로 자리로만 센다.
# -I: 이름을 바꾸기 전에 생긴 __pycache__/*.pyc(gitignore)가 옛 경로를 품고 있어 바이너리는 세지 않는다.
printf '\n[renames] renames.tsv 옛 이름 참조 0(이름표 밖)\n'
_rn_root="$(cd "$HOOKS/.." && pwd)"
_rn_tsv="$_rn_root/skills/harness-init/references/renames.tsv"
_rn_names=$(awk -F'\t' 'NR>1 && $1!="" {print $1}' "$_rn_tsv" 2>/dev/null | sort -u)
if [ -z "$_rn_names" ]; then
  bad "옛 이름 목록 없음" "$_rn_tsv 가 없거나 1칸이 비었다"
else
  _rn_dirs=$(ls "$_rn_root/skills")
  _rn_pat=""
  for _rn_n in $_rn_names; do
    case "$_rn_dirs" in
      *"$_rn_n"*) _rn_p="claude-harness:$_rn_n([^-a-z]|\$)|skills/$_rn_n/" ;;
      *) _rn_p="$_rn_n" ;;
    esac
    _rn_pat="${_rn_pat:+$_rn_pat|}$_rn_p"
  done
  _rn_left=$(grep -rnIE "$_rn_pat" \
    "$_rn_root/skills" "$_rn_root/agents" "$_rn_root/hooks" "$_rn_root/templates" "$_rn_root/scripts" \
    "$_rn_root/README.md" "$_rn_root/BACKLOG.md" 2>/dev/null \
    | grep -vF -e "$_rn_root/hooks/test.sh:" -e "$_rn_root/hooks/tests/" -e "$_rn_root/skills/harness-init/" \
    | grep -vE '^[^:]*:[0-9]+:.*([0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]+\.[0-9]+\.[0-9]+)' || true)
  [ -z "$_rn_left" ] && ok "옛 스킬 이름 $(echo "$_rn_names" | wc -l | tr -d ' ')개 참조 0(이름표 밖)" \
    || bad "옛 스킬 이름 남음" "$(echo "$_rn_left" | head -3)"
fi
