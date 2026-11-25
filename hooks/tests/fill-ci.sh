# harness-init CI 플레이스홀더는 skills/harness-init/scripts/fill_ci.py 가 채운다(REVIEW §2-3). test.sh 가 source 한다.
# $TMP 안에 <레포>/.claude/harness.json · <레포>/.github/workflows/ci.yml(템플릿 사본)을 만들고 스크립트를 돌린다. 레포 파일은 건드리지 않는다.
printf '\n[fill-ci] 플레이스홀더 7개 채움 · 빈 단계 삭제 · 남은 것 있으면 exit 1\n'
_fc_root="$(cd "$HOOKS/.." && pwd)"
_fc_py="$_fc_root/skills/harness-init/scripts/fill_ci.py"
_fc_tpl="$_fc_root/templates/.github/workflows/ci.yml"
_fc_skill="$_fc_root/skills/harness-init/SKILL.md"
_fc_re='\{\{[A-Z_]+\}\}'
_fc_mk() { # $1=레포 폴더  $2=harness.json 내용
  mkdir -p "$1/.claude" "$1/.github/workflows" && printf '%s' "$2" > "$1/.claude/harness.json" && cp "$_fc_tpl" "$1/.github/workflows/ci.yml"
}
_fc_run() { python3 "$_fc_py" "$1/.claude/harness.json" "$1/.github/workflows/ci.yml" >"$TMP/fc.out" 2>"$TMP/fc.err"; }
_fc_left() { grep -cE "$_fc_re" "$1/.github/workflows/ci.yml"; }

# ① 템플릿 플레이스홀더는 이 7개 — 늘면 fill_ci.py 도 같이 배운다
_fc_names=$(grep -oE "$_fc_re" "$_fc_tpl" | sort -u | tr '\n' ' ')
[ "$_fc_names" = "{{BASE_BRANCH}} {{SETUP_STEPS}} {{VERIFY_BUILD}} {{VERIFY_FORMAT}} {{VERIFY_LINT}} {{VERIFY_TEST}} {{VERIFY_TYPECHECK}} " ] \
  && ok "템플릿 플레이스홀더 7개" || bad "템플릿 플레이스홀더 목록" "[$_fc_names]"

# ② 다 채움 — verify 5개 · git.baseBranch · 팩 없음 → 남은 것 0 · exit 0
_fc_d="$TMP/fc-full"
_fc_mk "$_fc_d" '{"git":{"baseBranch":"develop"},"verify":{"format":"pnpm exec prettier --check .","lint":"pnpm lint","typecheck":"pnpm exec tsc --noEmit","test":"pnpm test","build":"pnpm build"},"ci":{"test":""}}'
_fc_run "$_fc_d"; _fc_code=$?
_fc_y="$_fc_d/.github/workflows/ci.yml"
[ "$_fc_code" = "0" ] && [ "$(_fc_left "$_fc_d")" = "0" ] && ok "다 채우면 exit 0 · 남은 플레이스홀더 0" || bad "다 채움" "exit=$_fc_code left=$(_fc_left "$_fc_d") err=[$(cat "$TMP/fc.err")]"
grep -qF 'branches: ["develop"]' "$_fc_y" && ok "{{BASE_BRANCH}} ← git.baseBranch" || bad "BASE_BRANCH" "$(grep -n 'branches' "$_fc_y")"
grep -qxF '        run: pnpm exec prettier --check .' "$_fc_y" && grep -qxF '        run: pnpm lint' "$_fc_y" \
  && grep -qxF '        run: pnpm exec tsc --noEmit' "$_fc_y" && grep -qxF '        run: pnpm test' "$_fc_y" && grep -qxF '        run: pnpm build' "$_fc_y" \
  && ok "{{VERIFY_*}} 5개 ← verify.format · lint · typecheck · test · build" || bad "VERIFY 채움" "$(grep -n 'run:' "$_fc_y")"
! grep -q 'SETUP_STEPS' "$_fc_y" && ok "팩 없음 → {{SETUP_STEPS}} 주석 줄째 삭제" || bad "SETUP_STEPS 줄" "$(grep -n 'SETUP_STEPS' "$_fc_y")"
grep -qF '${{ github.workflow }}' "$_fc_y" && ok "GitHub 식 \${{ … }} 는 건드리지 않음" || bad "GitHub 식" "concurrency 줄이 바뀜"
cp "$_fc_y" "$TMP/fc-full.before"
_fc_run "$_fc_d"; _fc_code=$?
[ "$_fc_code" = "0" ] && cmp -s "$_fc_y" "$TMP/fc-full.before" && ok "채운 파일에 다시 돌리면 exit 0 · 그대로" || bad "다시 돌림" "exit=$_fc_code"

# ③ 빈 단계는 스텝째 삭제 · test 는 지우지 않고 ci.test=deferred 면 echo 줄 · YAML 평문으로 못 쓰는 명령은 따옴표
_fc_d="$TMP/fc-sparse"
_fc_mk "$_fc_d" '{"git":{"baseBranch":"main"},"verify":{"format":"","lint":"echo lint: ok","test":""},"ci":{"test":"deferred"}}'
_fc_run "$_fc_d"; _fc_code=$?
_fc_y="$_fc_d/.github/workflows/ci.yml"
[ "$_fc_code" = "0" ] && [ "$(_fc_left "$_fc_d")" = "0" ] && ok "빈 단계가 있어도 exit 0 · 남은 것 0" || bad "빈 단계" "exit=$_fc_code err=[$(cat "$TMP/fc.err")]"
! grep -qE -- '- name: (format|typecheck|build)$' "$_fc_y" && grep -qE -- '- name: lint$' "$_fc_y" \
  && ok "verify 빈 값(format · typecheck · build) → 그 - name: 스텝 통째로 삭제" || bad "스텝 삭제" "$(grep -n -- '- name:' "$_fc_y")"
grep -qE -- '- name: test$' "$_fc_y" && grep -qxF '        run: echo "test deferred — .claude/harness.json ci.test 참고"' "$_fc_y" \
  && ok "verify.test 빈 값 + ci.test=deferred → test 스텝 유지 · echo 줄" || bad "deferred" "$(grep -n -A1 -- '- name: test' "$_fc_y")"
grep -qxF '        run: "echo lint: ok"' "$_fc_y" && ok "「: 」 든 명령은 따옴표로 감싼다" || bad "따옴표" "$(grep -n -A1 -- '- name: lint' "$_fc_y")"

# ④ 빈 값이면 exit 1 — verify.test 가 비었는데 ci.test 가 deferred 가 아니면 {{VERIFY_TEST}} 를 남긴다
_fc_d="$TMP/fc-notest"
_fc_mk "$_fc_d" '{"git":{"baseBranch":"main"},"verify":{"lint":"npm run lint","test":""},"ci":{"test":""}}'
_fc_run "$_fc_d"; _fc_code=$?
_fc_y="$_fc_d/.github/workflows/ci.yml"
[ "$_fc_code" = "1" ] && grep -qF '{{VERIFY_TEST}}' "$_fc_y" && grep -qF '{{VERIFY_TEST}}' "$TMP/fc.err" \
  && ok "verify.test 빈 값 · deferred 아님 → exit 1 · {{VERIFY_TEST}} 남김 · stderr 에 이름" || bad "빈 test" "exit=$_fc_code err=[$(cat "$TMP/fc.err")]"
grep -qF 'branches: ["main"]' "$_fc_y" && grep -qxF '        run: npm run lint' "$_fc_y" \
  && ok "exit 1 이어도 채울 수 있는 것은 채워 둔다" || bad "부분 채움" "$(grep -nE 'branches|run:' "$_fc_y")"

# ⑤ git.baseBranch 빈 값 → scripts/base-branch.sh(origin/HEAD). 그것도 없으면 {{BASE_BRANCH}} 남김 · exit 1
_fc_d="$TMP/fc-origin"
_fc_mk "$_fc_d" '{"git":{"baseBranch":""},"verify":{"test":"make test"}}'
(cd "$_fc_d" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init \
  && git update-ref refs/remotes/origin/trunk HEAD && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk)
_fc_run "$_fc_d"; _fc_code=$?
[ "$_fc_code" = "0" ] && grep -qF 'branches: ["trunk"]' "$_fc_d/.github/workflows/ci.yml" \
  && ok "baseBranch 빈 값 + origin/HEAD=trunk → base-branch.sh 값(trunk)" || bad "base-branch.sh" "exit=$_fc_code err=[$(cat "$TMP/fc.err")]"
_fc_d="$TMP/fc-nobase"
_fc_mk "$_fc_d" '{"git":{"baseBranch":""},"verify":{"test":"make test"}}'
_fc_run "$_fc_d"; _fc_code=$?
[ "$_fc_code" = "1" ] && grep -qF '{{BASE_BRANCH}}' "$_fc_d/.github/workflows/ci.yml" && grep -qF '{{BASE_BRANCH}}' "$TMP/fc.err" \
  && ok "기준 브랜치를 못 정함 → exit 1 · {{BASE_BRANCH}} 남김" || bad "기준 브랜치 없음" "exit=$_fc_code err=[$(cat "$TMP/fc.err")]"

# ⑥ 팩이 있으면 {{SETUP_STEPS}} 는 pack.md 셋업 스텝으로 먼저 채워 둔다 — 안 채웠으면 남김 · exit 1, 채웠으면 그대로
_fc_d="$TMP/fc-pack"
_fc_mk "$_fc_d" '{"stacks":{"packs":[{"pack":"kotlin-spring","root":"."}]},"git":{"baseBranch":"main"},"verify":{"test":"./gradlew test"}}'
_fc_run "$_fc_d"; _fc_code=$?
[ "$_fc_code" = "1" ] && grep -qF '{{SETUP_STEPS}}' "$_fc_d/.github/workflows/ci.yml" && grep -qF '{{SETUP_STEPS}}' "$TMP/fc.err" \
  && ok "팩 있음 + 셋업 스텝 안 채움 → exit 1 · {{SETUP_STEPS}} 남김" || bad "팩 셋업 남김" "exit=$_fc_code err=[$(cat "$TMP/fc.err")]"
python3 -c 'import sys; p=sys.argv[1]; s=open(p, encoding="utf-8").read(); open(p, "w", encoding="utf-8").write("".join("      - uses: actions/setup-java@v4\n" if "{{SETUP_STEPS}}" in l else l for l in s.splitlines(True)))' "$_fc_d/.github/workflows/ci.yml"
_fc_run "$_fc_d"; _fc_code=$?
[ "$_fc_code" = "0" ] && grep -qxF '      - uses: actions/setup-java@v4' "$_fc_d/.github/workflows/ci.yml" \
  && ok "팩 있음 + 셋업 스텝 채워 둠 → exit 0 · 셋업 스텝 그대로" || bad "팩 셋업 채움" "exit=$_fc_code err=[$(cat "$TMP/fc.err")]"

# ⑦ verify 가 앱별이면 VERIFY_* 를 건드리지 않는다(빈 값으로 보고 스텝을 지우면 안 된다) — jobs 를 앱별 형태로 바꾼 뒤 다시 돌린다
_fc_d="$TMP/fc-apps"
_fc_mk "$_fc_d" '{"git":{"baseBranch":"main"},"verify":{"apps/api":{"test":"./gradlew test"},"apps/web":{"lint":"pnpm lint","test":"pnpm test"}}}'
_fc_run "$_fc_d"; _fc_code=$?
_fc_y="$_fc_d/.github/workflows/ci.yml"
[ "$_fc_code" = "1" ] && grep -qF '{{VERIFY_FORMAT}}' "$_fc_y" && grep -qF '{{VERIFY_TEST}}' "$_fc_y" && grep -qE -- '- name: format$' "$_fc_y" \
  && grep -qF '앱별' "$TMP/fc.err" && ok "앱별 verify → VERIFY_* 그대로 · exit 1 · stderr 에 앱별" || bad "앱별" "exit=$_fc_code err=[$(cat "$TMP/fc.err")]"

# ⑧ 사용법 — 인자 없음은 exit 2
python3 "$_fc_py" >/dev/null 2>"$TMP/fc.err"; _fc_code=$?
[ "$_fc_code" = "2" ] && grep -qi 'usage' "$TMP/fc.err" && ok "인자 없음 → exit 2 · usage" || bad "사용법" "exit=$_fc_code err=[$(cat "$TMP/fc.err")]"

# ⑨ harness-init 은 표 대신 스크립트를 부른다
grep -qF 'python3 "${CLAUDE_PLUGIN_ROOT}/skills/harness-init/scripts/fill_ci.py"' "$_fc_skill" \
  && ok "harness-init 이 fill_ci.py 를 부른다" || bad "harness-init 에 fill_ci.py 호출 없음" "$_fc_skill"
grep -qE '^\| `\{\{(BASE_BRANCH|VERIFY_TEST)\}\}`' "$_fc_skill" \
  && bad "harness-init 본문에 플레이스홀더 표가 남음" "fill_ci.py 와 두 곳이 된다" || ok "harness-init 본문에 플레이스홀더 표 없음"
