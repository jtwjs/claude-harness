# 칸 순서 검사(#87) — skills/sdd/scripts/design_doc_check.py. test.sh 가 source 한다.
# 정본 칸 목록은 design.md 「설계서 틀」 블록(ARCHITECTURE D2). 설계서는 $TMP 에 만들고 레포 파일은 건드리지 않는다.
printf '\n[design-doc-check] 칸 순서 검사 — 통과 · 빠짐 · 순서 · 제목만 · 크게 실패\n'
_dc_root="$(cd "$HOOKS/.." && pwd)"
_dc_py="$_dc_root/skills/sdd/scripts/design_doc_check.py"
_dc_md="$_dc_root/skills/sdd/references/design.md"
_dc_dir="$TMP/dc"; mkdir -p "$_dc_dir"
_dc_run() { python3 "$_dc_py" "$@" >"$_dc_dir/out" 2>"$_dc_dir/err"; }
_dc_all() { cat "$_dc_dir/out" "$_dc_dir/err" 2>/dev/null; }

# 새 틀로 쓴 설계서 — 지휘 되비추기 절 · 칸 제목 뒤 덧붙인 말 · 칸 안 #### · 코드 블록 안 제목이 섞여 있다
_dc_good() { cat <<'EOF'
# 예시 기능 설계 문서

> 이슈 링크 · 날짜

## 들은 것 · 빈칸

- 들은 것

## 간단히

### 1. 한 줄 요약

제안했다: 예시를 바꾼다.

### 2. 문제

장면 하나.

### 3. 전체 구조

```mermaid
flowchart TD
  A --> B
```

### 4. 고른 안과 버린 안

- 고른 안: A. 이유 한 줄

### 5. 트레이드오프

- 잃는 것: 하나

### 우리 칸 (원본 포맷에 없고 유지)

- 제약 · 가정 · 사람이 볼 것

## 자세히

### 6. 목표와 비목표

- 목표

### 7. 대안 비교

| 안 | 기준 |
|---|---|

### 8. 상황별 동작

| 이럴 때 | 이렇게 |
|---|---|

### 9. 열린 질문과 누가 정하나

없음.

## 아주 자세히

### 10. 상세 설계

#### 데이터

내용.

### 11. 공통 관심사

내용.

### 12. 배포와 롤백

내용.
EOF
}
_dc_good > "$_dc_dir/good.md"

# dc-real-template-pass 새 틀 설계서 → exit 0 · 칸 수
_dc_run "$_dc_dir/good.md"; _dc_code=$?
[ "$_dc_code" = "0" ] && grep -q '칸 순서 통과: 16칸' "$_dc_dir/out" && ok "dc-real-template-pass 새 틀 설계서 → exit 0 · 16칸" || bad "dc-real-template-pass" "exit=$_dc_code [$(_dc_all)]"

# dc-template-agrees 틀 블록 자체를 설계서로 → exit 0 (틀과 검사가 같은 정본을 본다)
awk '/^\*\*설계서 틀\*\*/{f=1; next} f==1 && /^```markdown[[:space:]]*$/{f=2; next} f==2 && /^```[[:space:]]*$/{exit} f==2{print}' "$_dc_md" | sed -E 's/[[:space:]]*←.*$//' > "$_dc_dir/tpl.md"
_dc_run "$_dc_dir/tpl.md"; _dc_code=$?
[ "$_dc_code" = "0" ] && ok "dc-template-agrees 틀 블록 제목만 → exit 0" || bad "dc-template-agrees" "exit=$_dc_code [$(_dc_all)]"

# dc-deep-title-only-passes 아주 자세히 3칸 제목만 · 내용 없음 → exit 0
_dc_good | awk '/^## 아주 자세히/{print; print "### 10. 상세 설계"; print "### 11. 공통 관심사"; print "### 12. 배포와 롤백"; exit} {print}' > "$_dc_dir/deep.md"
_dc_run "$_dc_dir/deep.md"; _dc_code=$?
[ "$_dc_code" = "0" ] && ok "dc-deep-title-only-passes 아주 자세히 3칸 제목만 → exit 0" || bad "dc-deep-title-only-passes" "exit=$_dc_code [$(_dc_all)]"

# dc-missing-cell 칸 하나(대안 비교) 뺌 → exit 1 · 「빠진 칸: 대안 비교」
_dc_good | grep -v '^### 7\. 대안 비교' > "$_dc_dir/miss.md"
_dc_run "$_dc_dir/miss.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && grep -q '빠진 칸: 대안 비교' "$_dc_dir/out" && ok "dc-missing-cell 칸 뺌 → exit 1 · 빠진 칸 이름" || bad "dc-missing-cell" "exit=$_dc_code [$(_dc_all)]"

# dc-swapped-cells 두 칸(문제 ↔ 전체 구조) 순서 바꿈 → exit 1 · 「순서 어긋남: 전체 구조」
_dc_good | sed -e 's/^### 2\. 문제$/### @@A/' -e 's/^### 3\. 전체 구조$/### 2. 문제/' -e 's/^### @@A$/### 3. 전체 구조/' > "$_dc_dir/swap.md"
# 바꾼 뒤 제목 순서: 1 한 줄 요약 · 전체 구조 · 문제
_dc_run "$_dc_dir/swap.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && grep -q '순서 어긋남: ' "$_dc_dir/out" && grep -qE '순서 어긋남: (문제|전체 구조)' "$_dc_dir/out" && ! grep -q '빠진 칸' "$_dc_dir/out" \
  && ok "dc-swapped-cells 두 칸 순서 바꿈 → exit 1 · 순서 어긋남(빠진 칸 아님)" || bad "dc-swapped-cells" "exit=$_dc_code [$(_dc_all)]"

# dc-level-mismatch 칸 급이 다름(### 간단히) → 그 칸은 없는 것
_dc_good | sed 's/^## 간단히$/### 간단히/' > "$_dc_dir/level.md"
_dc_run "$_dc_dir/level.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && grep -q '빠진 칸: 간단히' "$_dc_dir/out" && ok "dc-level-mismatch 급이 다르면 빠진 칸" || bad "dc-level-mismatch" "exit=$_dc_code [$(_dc_all)]"

# dc-fenced-heading-ignored 코드 블록 안 제목은 칸이 아니다
_dc_good | grep -v '^### 12\. 배포와 롤백' > "$_dc_dir/fence.md"
printf '\n```markdown\n### 12. 배포와 롤백\n```\n' >> "$_dc_dir/fence.md"
_dc_run "$_dc_dir/fence.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && grep -q '빠진 칸: 배포와 롤백' "$_dc_dir/out" && ok "dc-fenced-heading-ignored 코드 블록 안 제목 무시" || bad "dc-fenced-heading-ignored" "exit=$_dc_code [$(_dc_all)]"

# dc-empty-file 빈 파일 → exit 1 · 빠진 칸 16줄
: > "$_dc_dir/empty.md"
_dc_run "$_dc_dir/empty.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && [ "$(grep -c '빠진 칸: ' "$_dc_dir/out")" = "16" ] && ok "dc-empty-file 빈 파일 → exit 1 · 빠진 칸 16줄" || bad "dc-empty-file" "exit=$_dc_code [$(_dc_all)]"

# dc-missing-file-exit2 없는 파일 · 인자 없음 → exit 2
_dc_run "$_dc_dir/nope.md"; _dc_code=$?
[ "$_dc_code" = "2" ] && [ -s "$_dc_dir/err" ] && ok "dc-missing-file-exit2 없는 파일 → exit 2 · 이유" || bad "dc-missing-file-exit2 없는 파일" "exit=$_dc_code [$(_dc_all)]"
_dc_run; _dc_code=$?
[ "$_dc_code" = "2" ] && ok "dc-missing-file-exit2 인자 없음 → exit 2" || bad "dc-missing-file-exit2 인자 없음" "exit=$_dc_code [$(_dc_all)]"

# dc-template-block-missing-exit2 틀 블록 꼴이 깨진 design.md 옆에서 → exit 2 · 「틀 블록을 못 찾음」, 통과로 끝나지 않는다
_dc_fake="$_dc_dir/fake/skills/sdd"; mkdir -p "$_dc_fake/scripts" "$_dc_fake/references"
cp "$_dc_py" "$_dc_fake/scripts/" 2>/dev/null
sed 's/^```markdown$/```md/' "$_dc_md" > "$_dc_fake/references/design.md"   # 울타리 꼴이 바뀜
python3 "$_dc_fake/scripts/design_doc_check.py" "$_dc_dir/good.md" >"$_dc_dir/out" 2>"$_dc_dir/err"; _dc_code=$?
[ "$_dc_code" = "2" ] && grep -q '틀 블록을 못 찾음' "$_dc_dir/err" && ok "dc-template-block-missing-exit2 울타리 꼴 바뀜 → exit 2" || bad "dc-template-block-missing-exit2 울타리" "exit=$_dc_code [$(_dc_all)]"
sed 's/^\*\*설계서 틀\*\*/**틀**/' "$_dc_md" > "$_dc_fake/references/design.md"   # 머리 줄이 바뀜
python3 "$_dc_fake/scripts/design_doc_check.py" "$_dc_dir/good.md" >"$_dc_dir/out" 2>"$_dc_dir/err"; _dc_code=$?
[ "$_dc_code" = "2" ] && grep -q '틀 블록을 못 찾음' "$_dc_dir/err" && ok "dc-template-block-missing-exit2 머리 줄 바뀜 → exit 2" || bad "dc-template-block-missing-exit2 머리 줄" "exit=$_dc_code [$(_dc_all)]"
: > "$_dc_fake/references/design.md"   # 빈 design.md
python3 "$_dc_fake/scripts/design_doc_check.py" "$_dc_dir/good.md" >"$_dc_dir/out" 2>"$_dc_dir/err"; _dc_code=$?
[ "$_dc_code" = "2" ] && ok "dc-template-block-missing-exit2 빈 design.md → exit 2" || bad "dc-template-block-missing-exit2 빈 design.md" "exit=$_dc_code [$(_dc_all)]"

# ── REVIEW 1회차(step 5) — 옮긴 칸만 짚기 · 칸 이름 경계 · 들여쓰기 · 울타리 꼴 · BOM · #### ──
_dc_n() { grep -c . "$_dc_dir/out"; }

# dc-far-move-one-cell 「한 줄 요약」 제목 하나를 맨 끝으로 → 출력은 그 칸 한 줄
_dc_good | grep -v '^### 1\. 한 줄 요약' > "$_dc_dir/far.md"; printf '\n### 1. 한 줄 요약\n' >> "$_dc_dir/far.md"
_dc_run "$_dc_dir/far.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && [ "$(_dc_n)" = "1" ] && grep -qx '순서 어긋남: 한 줄 요약' "$_dc_dir/out" && ok "dc-far-move-one-cell 멀리 옮긴 칸 하나만 짚음" || bad "dc-far-move-one-cell" "exit=$_dc_code [$(_dc_all)]"

# dc-swap-far 「문제」 ↔ 「대안 비교」 맞바꿈 → 그 두 칸만
_dc_good | sed -e 's/^### 2\. 문제$/### @@P/' -e 's/^### 7\. 대안 비교$/### 2. 문제/' -e 's/^### @@P$/### 7. 대안 비교/' > "$_dc_dir/swapfar.md"
_dc_run "$_dc_dir/swapfar.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && [ "$(_dc_n)" = "2" ] && grep -qx '순서 어긋남: 문제' "$_dc_dir/out" && grep -qx '순서 어긋남: 대안 비교' "$_dc_dir/out" \
  && ok "dc-swap-far 멀리 맞바꾼 두 칸만 짚음" || bad "dc-swap-far" "exit=$_dc_code [$(_dc_all)]"

# dc-name-boundary 「문제점 메모」는 「문제」가 아니다 · 「우리 칸 (…)」은 「우리 칸」이다(good.md)
_dc_good | sed 's/^### 2\. 문제$/### 2. 문제점 메모/' > "$_dc_dir/bound.md"
_dc_run "$_dc_dir/bound.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && grep -qx '빠진 칸: 문제' "$_dc_dir/out" && ok "dc-name-boundary 칸 이름 뒤가 글자면 다른 제목" || bad "dc-name-boundary" "exit=$_dc_code [$(_dc_all)]"

# dc-indented-heading 앞 공백 3칸 제목은 칸 · 4칸은 칸이 아니다
_dc_good | sed 's/^### 6\. 목표와 비목표$/   ### 6. 목표와 비목표/' > "$_dc_dir/ind3.md"
_dc_run "$_dc_dir/ind3.md"; _dc_code=$?
[ "$_dc_code" = "0" ] && ok "dc-indented-heading 공백 3칸 제목 → 칸" || bad "dc-indented-heading 3칸" "exit=$_dc_code [$(_dc_all)]"
_dc_good | sed 's/^### 6\. 목표와 비목표$/    ### 6. 목표와 비목표/' > "$_dc_dir/ind4.md"
_dc_run "$_dc_dir/ind4.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && grep -qx '빠진 칸: 목표와 비목표' "$_dc_dir/out" && ok "dc-indented-heading 공백 4칸 → 칸 아님" || bad "dc-indented-heading 4칸" "exit=$_dc_code [$(_dc_all)]"

# dc-bom BOM 으로 시작하고 첫 줄이 칸인 설계서 → 통과
{ printf '\357\273\277'; _dc_good | sed -n '/^## 간단히$/,$p'; } > "$_dc_dir/bom.md"
_dc_run "$_dc_dir/bom.md"; _dc_code=$?
[ "$_dc_code" = "0" ] && ok "dc-bom BOM 무시" || bad "dc-bom" "exit=$_dc_code [$(_dc_all)]"

# dc-fence-4backtick ```` 울타리 안 ``` 줄은 닫지 않는다 — 뒤 진짜 제목은 칸
_dc_good | awk '/^## 아주 자세히$/{print "````markdown"; print "```"; print "````"} {print}' > "$_dc_dir/f4.md"
_dc_run "$_dc_dir/f4.md"; _dc_code=$?
[ "$_dc_code" = "0" ] && ok "dc-fence-4backtick 긴 울타리 안 짧은 울타리 무시" || bad "dc-fence-4backtick 닫힘" "exit=$_dc_code [$(_dc_all)]"
_dc_good | grep -v '^### 12\. 배포와 롤백' > "$_dc_dir/f4b.md"; printf '\n````\n```\n### 12. 배포와 롤백\n```\n````\n' >> "$_dc_dir/f4b.md"
_dc_run "$_dc_dir/f4b.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && grep -qx '빠진 칸: 배포와 롤백' "$_dc_dir/out" && ok "dc-fence-4backtick 긴 울타리 안 제목은 칸 아님" || bad "dc-fence-4backtick 안 제목" "exit=$_dc_code [$(_dc_all)]"

# dc-tilde-in-backtick ``` 울타리 안 ~~~ 줄은 닫지 않는다
_dc_good | awk '/^## 아주 자세히$/{print "```"; print "~~~"; print "```"} {print}' > "$_dc_dir/tl.md"
_dc_run "$_dc_dir/tl.md"; _dc_code=$?
[ "$_dc_code" = "0" ] && ok "dc-tilde-in-backtick 다른 문자 울타리 무시" || bad "dc-tilde-in-backtick" "exit=$_dc_code [$(_dc_all)]"

# dc-h4-not-cell #### 대안 비교 는 칸이 아니다
_dc_good | sed 's/^### 7\. 대안 비교$/#### 대안 비교/' > "$_dc_dir/h4.md"
_dc_run "$_dc_dir/h4.md"; _dc_code=$?
[ "$_dc_code" = "1" ] && grep -qx '빠진 칸: 대안 비교' "$_dc_dir/out" && ok "dc-h4-not-cell #### 는 칸 아님" || bad "dc-h4-not-cell" "exit=$_dc_code [$(_dc_all)]"
