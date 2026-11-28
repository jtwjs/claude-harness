# doc_scope.py — 쌓인 양 장치가 켜진 날 첫 세션에 doctor §9 가 볼 자동 범위(ADR-021 Q4 B). test.sh 가 source 한다.
# 범위: CLAUDE.md + paths 없는 rules + 마지막 CLAUDE.md · rules 커밋 뒤 바뀐 파일에 paths 가 걸리는 rules.
# glob 은 Claude Code paths 꼴로 읽는다: `**/` 는 0개 이상 폴더, `*` · `?` 는 / 안에서만.
printf '\n[doc-scope] doctor §9 자동 범위 — 훅이 고르는 rules 목록\n'
_ds_py="$HOOKS/lib/doc_scope.py"
_ds_d="$TMP/_ds_"; rm -rf "$_ds_d"; mkdir -p "$_ds_d"
_ds_git() { git -C "$_ds_r" -c user.email=t@t -c user.name=t "$@"; }
_ds_new() { # $1 이름 → 임시 레포 하나, CLAUDE.md · rules 커밋까지
  _ds_r="$_ds_d/$1"; mkdir -p "$_ds_r/.claude/rules/sub"
  git -C "$_ds_r" init -q
  printf '# c\n' > "$_ds_r/CLAUDE.md"
  printf '# 늘 뜬다\n' > "$_ds_r/.claude/rules/always.md"
  printf -- '---\npaths: ["**/*.ts"]\n---\n# ts\n' > "$_ds_r/.claude/rules/ts.md"
  printf -- '---\npaths: ["src/*.css"]\n---\n# css\n' > "$_ds_r/.claude/rules/css.md"
  printf -- '---\npaths:\n  - "docs/**"\n---\n# 목록 꼴\n' > "$_ds_r/.claude/rules/sub/docs.md"
  printf -- '---\npaths: ["src/**/*.{js,jsx}"]\n---\n# 모르는 꼴\n' > "$_ds_r/.claude/rules/brace.md"
  _ds_git add -A && _ds_git commit -qm "docs: 문서"
}
_ds_pick() { python3 "$_ds_py" "$_ds_r" 10240 2>&1 | sed "s#^$_ds_r/##"; }

# 1. 문서 커밋 뒤 바뀐 것 없음 → CLAUDE.md · paths 없는 rules · 모르는 꼴(빠뜨리지 않게 넣는다)만
_ds_new base
_ds_out=$(_ds_pick)
[ "$(printf '%s\n' "$_ds_out" | sort | tr '\n' ' ')" = ".claude/rules/always.md .claude/rules/brace.md CLAUDE.md " ] \
  && ok "바뀐 파일 없음 — CLAUDE.md · paths 없는 rules · 모르는 꼴만" || bad "기본 범위" "[$_ds_out]"

# 2. 루트 a.ts · 하위 src/x/b.ts · docs/a/b.md · src/x/c.css 를 문서 커밋 뒤 커밋
mkdir -p "$_ds_r/src/x" "$_ds_r/docs/a"
printf 'x' > "$_ds_r/a.ts"; printf 'x' > "$_ds_r/docs/a/b.md"; printf 'x' > "$_ds_r/src/x/c.css"
_ds_git add -A && _ds_git commit -qm "feat: 코드"
_ds_out=$(_ds_pick)
printf '%s\n' "$_ds_out" | grep -qx '.claude/rules/ts.md' && ok "**/*.ts 가 루트 a.ts 에 걸린다(** 는 0개 폴더도)" || bad "** 0개" "[$_ds_out]"
printf '%s\n' "$_ds_out" | grep -qx '.claude/rules/sub/docs.md' && ok "목록 꼴 paths · 하위 폴더 rules 도 읽는다" || bad "목록 꼴" "[$_ds_out]"
printf '%s\n' "$_ds_out" | grep -qx '.claude/rules/css.md' && bad "* 가 / 를 넘었다" "src/*.css 가 src/x/c.css 에 걸렸다" || ok "src/*.css 는 src/x/c.css 에 안 걸린다(* 는 / 안에서만)"

# 3. 문서 커밋 전에 바뀐 파일은 세지 않는다 — rules 를 다시 커밋하면 위 걸림이 풀린다
printf '# c2\n' > "$_ds_r/CLAUDE.md"; _ds_git commit -qam "docs: 갱신"
_ds_out=$(_ds_pick)
printf '%s\n' "$_ds_out" | grep -qx '.claude/rules/ts.md' && bad "기준점" "문서 커밋 전 변경을 셌다 [$_ds_out]" || ok "마지막 문서 커밋 전 변경은 세지 않는다"

# 4. 합계가 상한을 넘으면 셋째 묶음(paths 걸린 rules)부터 빼고 그 사실을 한 줄로 남긴다
printf 'y' > "$_ds_r/b.ts"; _ds_git add -A && _ds_git commit -qm "feat: b"
_ds_out=$(python3 "$_ds_py" "$_ds_r" 30 2>&1 | sed "s#^$_ds_r/##")
printf '%s\n' "$_ds_out" | grep -qx '.claude/rules/ts.md' && bad "상한" "넘었는데 셋째 묶음을 안 뺐다 [$_ds_out]" || ok "상한 초과 — paths 걸린 rules 를 뺀다"
printf '%s\n' "$_ds_out" | grep -q '^(뺌: paths 걸린 rules 1개' && ok "상한 초과 — 뺀 수를 한 줄로 남긴다" || bad "뺀 줄" "[$_ds_out]"
printf '%s\n' "$_ds_out" | grep -qx 'CLAUDE.md' && ok "상한 초과 — 앞의 둘은 그대로" || bad "앞 묶음" "[$_ds_out]"

# 5. 템플릿 · 팩 rules 의 paths 는 전부 아는 꼴이다(모르는 꼴로 넘어가 늘 들어가는 파일이 없다)
_ds_unk=$(python3 - "$_ds_py" "$ROOT/templates" <<'PY'
import importlib.util, pathlib, sys
s = importlib.util.spec_from_file_location("ds", sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
for f in sorted(pathlib.Path(sys.argv[2]).rglob("rules/*.md")):
    p = m.read_paths(f.read_text(encoding="utf-8"))
    if p is not None and any(not m.known(x) for x in p):
        print(f)
PY
)
[ -z "$_ds_unk" ] && ok "템플릿 · 팩 rules paths 모두 아는 꼴" || bad "모르는 꼴" "$_ds_unk"

# 6. 템플릿 · 팩이 쓰는 glob 꼴을 고정 경로에 대 본다(Claude Code paths 꼴 기준)
_ds_tab=$(python3 - "$_ds_py" <<'PY'
import importlib.util, sys
s = importlib.util.spec_from_file_location("ds", sys.argv[1]); m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
cases = [
    ("**/*.ts", "a.ts", True), ("**/*.ts", "src/x/a.ts", True), ("**/*.ts", "a.tsx", False),
    ("src/**/*.tsx", "src/a.tsx", True), ("src/**/*.tsx", "src/x/y/a.tsx", True), ("src/**/*.tsx", "lib/a.tsx", False),
    ("src/**", "src/a/b.ts", True), ("src/**", "srcx/a.ts", False),
    ("**/controller/**", "controller/A.kt", True), ("**/controller/**", "x/controller/A.kt", True), ("**/controller/**", "x/controllers/A.kt", False),
    ("**/*.test.*", "src/a.test.ts", True), ("**/*.test.*", "src/atest.ts", False),
    ("**/src/test/**", "app/src/test/A.kt", True), ("**/src/test/**", "src/test/A.kt", True),
    ("playwright.*.config.*", "playwright.ci.config.ts", True), ("playwright.*.config.*", "e2e/playwright.ci.config.ts", False),
    ("next.config.*", "next.config.mjs", True), ("middleware.ts", "src/middleware.ts", False),
    ("**/resources/application*.yml", "src/main/resources/application-dev.yml", True),
    ("**/http/*.http", "api/http/a.http", True), ("**/http/*.http", "api/http/x/a.http", False),
    ("package.json", "package.json", True), ("package.json", "web/package.json", False),
]
for pat, path, want in cases:
    if bool(m.glob_re(pat).match(path)) != want:
        print(f"{pat} ~ {path} 기대 {want}")
PY
)
[ -z "$_ds_tab" ] && ok "glob 꼴 표 24줄 — 기대와 같다" || bad "glob 꼴" "$_ds_tab"

# 7. 훅 — 축 3(문서 크기)이 켜진 날 첫 세션: §9 와 고른 목록을 지시, 같은 날 둘째 세션은 생략
_ds_new hook
printf '{}' > "$_ds_r/.claude/harness.json"
python3 -c "print('x\n'*100, end='')" > "$_ds_r/CLAUDE.md"; _ds_git add -A && _ds_git commit -qm "docs: 큼"
printf 'x' > "$_ds_r/a.ts"; _ds_git add -A && _ds_git commit -qm "feat: ts"
_ds_hook() { (cd "$_ds_r" && printf '{}' | env CLAUDE_SKILL_HINTS_DIR="$_ds_d/hints" CLAUDE_HARNESS_HOOK_LOG="$_ds_d/log.tsv" bash "$HOOKS/cadence-reminder.sh" 2>&1); }
_ds_out=$(_ds_hook)
printf '%s' "$_ds_out" | grep -q '오늘 이 레포 첫 세션' && printf '%s' "$_ds_out" | grep -qF '§9' && printf '%s' "$_ds_out" | grep -qF '.claude/rules/ts.md' \
  && ok "축 3 첫 세션 — §9 를 고른 목록에 먼저 돌리라고 한다" || bad "축 3 첫 세션" "[$_ds_out]"
printf '%s' "$_ds_out" | grep -qF '.claude/rules/css.md' && bad "범위" "안 걸린 rules 가 목록에 [$_ds_out]" || ok "축 3 첫 세션 — 안 걸린 rules 는 목록에 없다"
printf '%s' "$_ds_out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && ok "축 3 첫 세션 — 출력은 유효한 JSON" || bad "JSON" "[$_ds_out]"
_ds_out=$(_ds_hook)
printf '%s' "$_ds_out" | grep -q '오늘 이 레포 첫 세션' && bad "반복" "같은 날 둘째 세션에도 지시" || ok "축 3 — 같은 날 둘째 세션은 생략"
