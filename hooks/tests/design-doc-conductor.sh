# 지휘 문서 · ADR-022 갱신(#87) — 옛 설계서 칸 이름 0 · 아주 자세히 3칸 · ADR-022 갱신 줄(표 밖). test.sh 가 source 한다.
printf '\n[design-doc-conductor] 지휘 문서 새 칸 이름 · ADR-022 갱신 줄 · 러너 관문 0\n'
_dcn_root="$(cd "$HOOKS/.." && pwd)"
_dcn_dec="$_dcn_root/skills/conductor/references/decisions.md"
_dcn_adr="$_dcn_root/docs/design-phase-2026-11-26/ADR.md"

# dcn-old-cell-names-zero 지휘 스킬 문서에 옛 칸 이름이 없다
_dcn_old=$(grep -nE '결정한 것|「결정」 칸|설계서 결정 칸|설계서 결정 번호' "$_dcn_root"/skills/conductor/SKILL.md "$_dcn_root"/skills/conductor/references/*.md || true)
[ -z "$_dcn_old" ] && ok "dcn-old-cell-names-zero 지휘 문서 옛 칸 이름 0줄" || bad "dcn-old-cell-names-zero 남은 줄" "$(printf '%s' "$_dcn_old" | cut -c1-160 | head -5)"

# dcn-picked-cell 결정 묶음 받기: 답 → 설계서 「고른 안과 버린 안」
# 출력을 grep -q 로 바로 넘기지 않는다(pipefail SIGPIPE)
_dcn_l1=$(grep -E '결정 묶음 받기' "$_dcn_dec")
printf '%s' "$_dcn_l1" | grep -q '고른 안과 버린 안' && ok "dcn-picked-cell 결정 묶음 받기 = 고른 안과 버린 안" || bad "dcn-picked-cell" "decisions.md 결정 묶음 받기 줄"

# dcn-deep-cells 설계서 흐름: 아주 자세히 3칸은 세 장 뒤 지휘가
_dcn_l2=$(grep -E '설계서 흐름' "$_dcn_dec")
printf '%s' "$_dcn_l2" | grep -q '아주 자세히' && ok "dcn-deep-cells 설계서 흐름에 아주 자세히 3칸" || bad "dcn-deep-cells" "decisions.md 설계서 흐름 줄"

# dcn-adr022-update ADR-022 머리(결정할 것 표 앞)에 「- 갱신: #87」 줄 · 근거 폴더
_dcn_head=$(awk '/^## ADR-022/{f=1; next} f && /^### /{exit} f{print}' "$_dcn_adr")
_dcn_up=$(printf '%s\n' "$_dcn_head" | grep -E '^- 갱신: #87')
printf '%s' "$_dcn_up" | grep -q 'docs/design-doc-format-2026-11-28' && ok "dcn-adr022-update ADR-022 갱신 줄(#87 · 근거 폴더)" || bad "dcn-adr022-update" "ADR-022 머리에 「- 갱신: #87 … docs/design-doc-format-2026-11-28」 없음"

# dcn-adr022-gate 갱신 줄이 「결정할 것」 표에 빈 주체 행을 만들지 않았다 — 러너 관문 0
python3 "$_dcn_root/skills/sdd-run/scripts/sdd_runner.py" gate "$_dcn_root/docs/design-phase-2026-11-26" >"$TMP/dcn.out" 2>&1 \
  && ok "dcn-adr022-gate ADR-022 폴더 러너 관문 열린 「정할 것」 0" || bad "dcn-adr022-gate" "$(cat "$TMP/dcn.out" | head -3)"
