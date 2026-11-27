# 설계서 흐름 · 세 장 규칙(#87) — design.md 설계서 순서 · 화면 · 설계서와 세 장 · 끝 · Readiness · 설계문서 3장 + sdd SKILL.md ① 행. test.sh 가 source 한다.
printf '\n[design-doc-flow] 설계서 흐름 · 출처 칸 · 세 장 틀 — 새 칸 이름으로\n'
_df_root="$(cd "$HOOKS/.." && pwd)"
_df_md="$_df_root/skills/sdd/references/design.md"
_df_sk="$_df_root/skills/sdd/SKILL.md"
# 「**<이름>**」 문단부터 다음 「**…**」 문단 머리 · ## 제목 앞까지
_df_sec() { awk -v h="**$1**" 'index($0,h)==1{f=1; print; next} f && (/^\*\*[^*]+\*\*/ || /^## /){exit} f{print}' "$_df_md"; }
_df_h2() { awk -v h="## $1" 'index($0,h)==1{f=1; print; next} f && /^## /{exit} f{print}' "$_df_md"; }

# df-old-cell-names-zero 옛 칸 이름 · 옛 규칙 문장이 design.md · SKILL.md 에 없다
_df_old=$(grep -nE '결정한 것|「결정」 칸|설계서 결정 칸|설계서 결정 번호|원문 \+ 에이전트|원문에 에이전트|구조 · 기술 결정은 여기서 묻지 않는다' "$_df_md" "$_df_sk" || true)
[ -z "$_df_old" ] && ok "df-old-cell-names-zero 옛 칸 이름 · 옛 규칙 문장 0줄" || bad "df-old-cell-names-zero 남은 줄" "$(printf '%s' "$_df_old" | cut -c1-160 | head -5)"

# df-screen-runs-check-first 화면: 열기 전에 칸 순서 검사 · 실패면 열지 않음 · 명령
_df_s=$(_df_sec '화면')
printf '%s' "$_df_s" | grep -q 'skills/sdd/scripts/design_doc_check.py' && printf '%s' "$_df_s" | grep -q '열지 않' \
  && ok "df-screen-runs-check-first 화면 절에 검사 명령 · 실패면 열지 않음" || bad "df-screen-runs-check-first 화면 절" "[$(printf '%s' "$_df_s" | head -3)]"

# df-open-questions-cell 질문 자리는 「열린 질문과 누가 정하나」 (설계서 순서 · 화면)
{ _df_sec '설계서 순서'; _df_sec '화면'; } | grep -q '열린 질문과 누가 정하나' && ok "df-open-questions-cell 질문 자리 = 열린 질문과 누가 정하나" || bad "df-open-questions-cell" "설계서 순서 · 화면 절에 없음"

# df-big-direction-asked 설계서 순서: 큰 방향(구조 상자)은 설계서에서 묻고, 코드 근거는 결정 묶음
_df_o=$(_df_sec '설계서 순서')
printf '%s' "$_df_o" | grep -q '구조 상자' && printf '%s' "$_df_o" | grep -q '결정 묶음' && ok "df-big-direction-asked 구조 상자는 설계서 · 코드 근거는 결정 묶음" || bad "df-big-direction-asked" "설계서 순서 절"

# df-deep-cells-rewrite 설계서 순서: 세 장 뒤 아주 자세히 3칸을 다시 써서 붙인다
printf '%s' "$_df_o" | grep -q '아주 자세히' && printf '%s' "$_df_o" | grep -q '상세 설계' && printf '%s' "$_df_o" | grep -q '배포와 롤백' \
  && ok "df-deep-cells-rewrite 설계서 순서에 아주 자세히 3칸 단계" || bad "df-deep-cells-rewrite" "설계서 순서 절"

# df-prd-from-cells 설계서와 세 장: 일곱 칸에서 뽑고 줄마다 출처 칸 (← 칸 이름)
_df_t=$(_df_sec '설계서와 세 장'); _df_miss=""
for _df_c in '한 줄 요약' '문제' '목표와 비목표' '상황별 동작' '제약' '가정' '사람이 볼 것' '출처' '(← '; do
  printf '%s' "$_df_t" | grep -qF "$_df_c" || _df_miss="$_df_miss [$_df_c]"
done
[ -n "$_df_t" ] && [ -z "$_df_miss" ] && ok "df-prd-from-cells 일곱 칸 · 출처 칸 꼴" || bad "df-prd-from-cells 없음" "${_df_miss:-절 없음}"

# df-picked-cell 결정 묶음 답 · 세 장 결정의 자리 = 「고른 안과 버린 안」
printf '%s' "$_df_t" | grep -q '고른 안과 버린 안' && _df_h2 '끝' | grep -q '고른 안과 버린 안' \
  && ok "df-picked-cell 설계서와 세 장 · 끝 절 = 고른 안과 버린 안" || bad "df-picked-cell" "설계서와 세 장 또는 끝 절"

# df-solo-design-doc 혼자 도는 sdd 는 같은 틀을 DESIGN-DOC.md 에
_df_sec '누가 · 어디에' | grep -q 'DESIGN-DOC.md' && ok "df-solo-design-doc 누가 · 어디에 = DESIGN-DOC.md" || bad "df-solo-design-doc" "누가 · 어디에 절"

# df-arch-cells ARCHITECTURE 정의에 네 칸
_df_a=$(grep -E '^\*\*ARCHITECTURE\.md\*\*:' "$_df_md"); _df_miss=""
for _df_c in '불변 규칙' '코드 지도' '요청 하나 따라가기' '배포와 롤백'; do printf '%s' "$_df_a" | grep -qF "$_df_c" || _df_miss="$_df_miss [$_df_c]"; done
[ -n "$_df_a" ] && [ -z "$_df_miss" ] && ok "df-arch-cells ARCHITECTURE 정의 네 칸" || bad "df-arch-cells 없음" "${_df_miss:-정의 줄 없음}"

# df-adr-link ADR 정의: 「고른 안과 버린 안」 링크 · 러너가 읽는 표 머리는 그대로
_df_d=$(grep -E '^\*\*ADR\.md\*\*:' "$_df_md")
printf '%s' "$_df_d" | grep -q '고른 안과 버린 안' && printf '%s' "$_df_d" | grep -qF '| # | 정할 것 | 선택지 | 추천 | 주체 |' && printf '%s' "$_df_d" | grep -q '주체 칸을 비운다' \
  && ok "df-adr-link ADR 정의 = 고른 안과 버린 안 링크 · 결정할 것 표 머리 그대로" || bad "df-adr-link" "[$(printf '%s' "$_df_d" | cut -c1-160)]"

# df-readiness Readiness 9 · 10 이 새 칸 이름으로 대조
_df_r9=$(grep -E '^\| 9 \|' "$_df_md"); _df_r10=$(grep -E '^\| 10 \|' "$_df_md")
printf '%s' "$_df_r9" | grep -q '목표와 비목표' && printf '%s' "$_df_r9" | grep -q '상황별 동작' && printf '%s' "$_df_r9" | grep -q '출처' \
  && printf '%s' "$_df_r10" | grep -q '고른 안과 버린 안' && ok "df-readiness 9 · 10 새 칸 이름 · 출처 칸" || bad "df-readiness" "9=[$(printf '%s' "$_df_r9" | cut -c1-80)] 10=[$(printf '%s' "$_df_r10" | cut -c1-80)]"

# df-keep-phrase 기존 테스트(test.sh 설계 3장 흐름)가 찾는 구절
grep -q 'ARCHITECTURE.md\*\* — PRD 확정 직후' "$_df_md" && ok "df-keep-phrase ARCHITECTURE.md — PRD 확정 직후 구절 남음" || bad "df-keep-phrase" "구절 없음"

# df-skill-row sdd ① 행 PRD 줄 = 출처 칸
grep -E '설계서를 받았을 때' "$_df_sk" | grep -q '출처' && ok "df-skill-row sdd ① 행에 출처 칸" || bad "df-skill-row" "sdd SKILL.md ① 행"
