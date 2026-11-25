# 옛 스킬 이름 → 지금 이름표는 skills/harness-init/references/renames.tsv 한 곳에 둔다(ADR-016 D1 · REVIEW R8). test.sh 가 source 한다.
# renames.sh 가 1칸을 옛 이름 목록으로 읽으므로 한 칸에 이름 하나만 둔다.
printf '\n[renames-data] renames.tsv 3칸(옛 이름 · 지금 · 언제) · harness-init 이 그 경로를 가리킨다\n'
_rd_root="$(cd "$HOOKS/.." && pwd)"
_rd_tsv="$_rd_root/skills/harness-init/references/renames.tsv"
_rd_skill="$_rd_root/skills/harness-init/SKILL.md"
if [ -f "$_rd_tsv" ]; then
  ok "renames.tsv 있음"
  [ "$(head -1 "$_rd_tsv")" = "$(printf '옛 이름\t지금\t언제')" ] \
    && ok "머리 줄 「옛 이름 · 지금 · 언제」" || bad "renames.tsv 머리 줄" "$(head -1 "$_rd_tsv")"
  _rd_badrow=$(awk -F'\t' 'NR>1 && (NF!=3 || $1=="" || $2=="" || $3=="" || $1 !~ /^[a-z0-9-]+$/) {print NR": "$0}' "$_rd_tsv")
  _rd_rows=$(awk 'NR>1 {n++} END {print n+0}' "$_rd_tsv")
  [ -z "$_rd_badrow" ] && [ "$_rd_rows" -gt 0 ] \
    && ok "행 ${_rd_rows}개 모두 3칸 · 1칸은 이름 하나" || bad "renames.tsv 행 모양" "${_rd_badrow:-데이터 행 없음}"
else
  bad "renames.tsv 없음" "$_rd_tsv"
fi
grep -qF '${CLAUDE_PLUGIN_ROOT}/skills/harness-init/references/renames.tsv' "$_rd_skill" \
  && ok "harness-init 이 renames.tsv 경로를 가리킴" || bad "harness-init 에 renames.tsv 경로 없음" "$_rd_skill"
grep -qF '| 옛 이름 | 지금 | 언제 |' "$_rd_skill" \
  && bad "harness-init 본문에 이름표 표가 남음" "renames.tsv 와 두 곳이 된다" || ok "harness-init 본문에 이름표 표 없음"
