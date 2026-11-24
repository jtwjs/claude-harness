# 원칙은 docs/principles/ 한 곳에 두고 스킬은 경로로 가리킨다(ADR-016 D2). test.sh 가 source 한다.
# 스킬 안 원칙 경로는 ${CLAUDE_PLUGIN_ROOT}/docs/principles/ 형태만 — 상대 경로는 다른 레포 세션에서 그 레포 기준으로 풀려 첫 Read가 실패한다(ADR-016 「결과」).
printf '\n[principles] INDEX ↔ 원칙 파일 · 스킬은 플러그인 절대 경로로 가리킨다\n'
_pr_root="$(cd "$HOOKS/.." && pwd)"
_pr_dir="$_pr_root/docs/principles"
_pr_idx="$_pr_dir/INDEX.md"

# ① INDEX 가 있다
[ -f "$_pr_idx" ] && ok "docs/principles/INDEX.md 있음" || bad "INDEX 없음" "docs/principles/INDEX.md"

# ② 표(이름 | 언제 | 경로)의 경로 칸 → 파일이 있다 · INDEX 밖 원칙 파일은 모두 표에 있다
#    경로 칸은 INDEX.md 가 있는 폴더 기준. 백틱 · 앞의 ./ · [글](경로) 링크 꼴을 벗긴다.
_pr_paths=$(awk -F'|' 'NF>=5 { p=$4; if (p ~ /경로/ || p ~ /^[ :-]+$/) next;
  if (p ~ /\]\(/) { sub(/.*\]\(/, "", p); sub(/\).*/, "", p) }
  gsub(/[` ]/, "", p); sub(/^\.\//, "", p); if (p != "") print p }' "$_pr_idx" 2>/dev/null)
_pr_n=0; _pr_missing=""
while IFS= read -r _pr_p; do
  [ -n "$_pr_p" ] || continue
  _pr_n=$((_pr_n+1))
  [ -f "$_pr_dir/$_pr_p" ] || _pr_missing="$_pr_missing $_pr_p"
done <<< "$_pr_paths"
[ "$_pr_n" -gt 0 ] && [ -z "$_pr_missing" ] && ok "INDEX 경로 칸 ${_pr_n}개 → 파일 있음" \
  || bad "INDEX 경로 칸" "행 ${_pr_n}개 · 없는 파일:[${_pr_missing# }]"
_pr_unlisted=""
for _pr_f in "$_pr_dir"/*.md; do
  [ -f "$_pr_f" ] || continue
  _pr_b=$(basename "$_pr_f"); [ "$_pr_b" = "INDEX.md" ] && continue
  printf '%s\n' "$_pr_paths" | grep -qxF "$_pr_b" || _pr_unlisted="$_pr_unlisted $_pr_b"
done
[ -f "$_pr_idx" ] && [ -z "$_pr_unlisted" ] && ok "docs/principles/*.md 모두 INDEX 표에 있음" \
  || bad "INDEX 표에 없는 원칙 파일" "[${_pr_unlisted# }]"

# ③ skills/ 안에서 docs/principles/ 를 가리키는 곳은 모두 ${CLAUDE_PLUGIN_ROOT}/docs/principles/ 형태다
_pr_rel=$(grep -rnIF 'docs/principles/' "$_pr_root/skills" 2>/dev/null \
  | sed 's#\${CLAUDE_PLUGIN_ROOT}/docs/principles/##g' | grep -F 'docs/principles/' || true)
[ -z "$_pr_rel" ] && ok "skills/ 의 원칙 경로는 모두 \${CLAUDE_PLUGIN_ROOT}/docs/principles/" \
  || bad "상대 원칙 경로 남음" "$(echo "$_pr_rel" | head -3)"

# ④ why 가 질문 규칙 원칙 원문을 가리킨다
grep -qF '${CLAUDE_PLUGIN_ROOT}/docs/principles/ask-questions.md' "$_pr_root/skills/why/SKILL.md" 2>/dev/null \
  && ok "why → \${CLAUDE_PLUGIN_ROOT}/docs/principles/ask-questions.md" \
  || bad "why 가 질문 규칙 원칙을 안 가리킴" "skills/why/SKILL.md"
