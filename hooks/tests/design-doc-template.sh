# 설계서 틀(#87) — design.md 「설계서 틀」 블록이 간단히 → 우리 칸 → 자세히 → 아주 자세히 순서이고 칸마다 안내가 있다. test.sh 가 source 한다.
# 이 블록은 칸 순서 검사(skills/sdd/scripts/design_doc_check.py)가 정본으로 읽는 계약이다(ARCHITECTURE D2).
printf '\n[design-doc-template] 설계서 틀 블록 — 칸 이름 · 급 · 순서 · 칸마다 안내\n'
_dt_root="$(cd "$HOOKS/.." && pwd)"
_dt_md="$_dt_root/skills/sdd/references/design.md"
# 「**설계서 틀**」로 시작하는 줄 다음 첫 ```markdown 블록
_dt_block=$(awk '/^\*\*설계서 틀\*\*/{f=1; next} f==1 && /^```markdown[[:space:]]*$/{f=2; next} f==2 && /^```[[:space:]]*$/{exit} f==2{print}' "$_dt_md" 2>/dev/null)

# 칸 이름 · 급 · 순서 — ## · ### 줄에서 ← 뒤와 번호를 뗀 것
_dt_got=$(printf '%s\n' "$_dt_block" | grep -E '^#{2,3} ' | sed -E 's/[[:space:]]*←.*$//; s/^(#{2,3}) ([0-9]+\.[[:space:]]*)?/\1 /' | tr '\n' '|')
_dt_want='## 간단히|### 한 줄 요약|### 문제|### 전체 구조|### 고른 안과 버린 안|### 트레이드오프|### 우리 칸|## 자세히|### 목표와 비목표|### 대안 비교|### 상황별 동작|### 열린 질문과 누가 정하나|## 아주 자세히|### 상세 설계|### 공통 관심사|### 배포와 롤백|'
[ "$_dt_got" = "$_dt_want" ] && ok "dt-cell-order 틀 블록 칸 16개 · 급 · 순서" || bad "dt-cell-order 틀 블록 칸" "[$_dt_got]"

# 번호: 간단히 1~5 · 자세히 6~9 · 아주 자세히 10~12
_dt_nums=$(printf '%s\n' "$_dt_block" | grep -oE '^### [0-9]+\.' | grep -oE '[0-9]+' | tr '\n' ' ')
[ "$_dt_nums" = "1 2 3 4 5 6 7 8 9 10 11 12 " ] && ok "dt-cell-numbers 칸 번호 1~12" || bad "dt-cell-numbers 칸 번호" "[$_dt_nums]"

# dt-every-cell-has-guide — ### 줄(칸)마다 ← 뒤 한 줄 안내가 비지 않는다
_dt_cells=$(printf '%s\n' "$_dt_block" | grep -cE '^### ')
_dt_noguide=$(printf '%s\n' "$_dt_block" | grep -E '^### ' | grep -vE '←[[:space:]]*[^[:space:]]' || true)
[ "$_dt_cells" -gt 0 ] && [ -z "$_dt_noguide" ] && ok "dt-every-cell-has-guide 칸 ${_dt_cells}개 모두 ← 안내" || bad "dt-every-cell-has-guide 안내 없는 칸" "[${_dt_noguide:-칸 0개}]"

# 옛 틀에만 있던 안내가 따라왔다(빠지면 그 규칙이 사라진다)
_dt_line() { printf '%s\n' "$_dt_block" | grep -E "^### ([0-9]+\. )?$1"; }
_dt_line '상황별 동작' | grep -q 'Given' && ok "dt-guide-moved 상황별 동작 ← 위험 큰 기능 Given · When · Then" || bad "dt-guide-moved 상황별 동작" "[$(_dt_line '상황별 동작')]"
_dt_line '공통 관심사' | grep -q '숫자' && ok "dt-guide-moved 공통 관심사 ← 비기능은 숫자로" || bad "dt-guide-moved 공통 관심사" "[$(_dt_line '공통 관심사')]"
_dt_us=$(_dt_line '우리 칸')
printf '%s' "$_dt_us" | grep -q '제약' && printf '%s' "$_dt_us" | grep -q '가정' && printf '%s' "$_dt_us" | grep -q '사람이 볼 것' \
  && ok "dt-guide-moved 우리 칸 ← 제약 · 가정 · 사람이 볼 것" || bad "dt-guide-moved 우리 칸" "[$_dt_us]"

# dt-old-headings-gone — 옛 틀 칸이 블록에 없다
_dt_old=$(printf '%s\n' "$_dt_block" | grep -E '^## (핵심 요구사항 한 줄 요약|결정할 것 / 결정한 것|사용자 흐름|기능 요구사항|비기능 요구사항|제약|가정|수용 기준)' || true)
[ -n "$_dt_block" ] && [ -z "$_dt_old" ] && ok "dt-old-headings-gone 옛 틀 8칸 없음" || bad "dt-old-headings-gone 옛 틀 칸 남음" "[${_dt_old:-블록 없음}]"

# 공개 레포 — 틀에 개인 경로가 없다
printf '%s\n' "$_dt_block" | grep -qE '/Users/|~/' && bad "dt-no-private-path 틀에 개인 경로" "$(printf '%s\n' "$_dt_block" | grep -E '/Users/|~/')" || ok "dt-no-private-path 틀에 개인 경로 없음"
