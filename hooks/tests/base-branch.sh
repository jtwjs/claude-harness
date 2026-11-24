# 기준 브랜치는 scripts/base-branch.sh 한 곳에서 정한다(ADR-016 D2). test.sh 가 source 한다.
# 순서: harness.json git.baseBranch → origin/HEAD 에서 origin/ 을 뗀 값 → 둘 다 없으면 exit 2(부른 쪽이 사람에게 묻는다).
printf '\n[base-branch] harness.json baseBranch → origin/HEAD → exit 2\n'
_bb_sh="$(cd "$HOOKS/.." && pwd)/scripts/base-branch.sh"
_bb_repo() { # $1=폴더  $2=origin/HEAD 가 가리킬 브랜치(빈 값이면 origin/HEAD 를 만들지 않는다)
  mkdir -p "$1" && (cd "$1" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init \
    && if [ -n "$2" ]; then git update-ref "refs/remotes/origin/$2" HEAD && git symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/$2"; fi)
}

# ① harness.json 값이 origin/HEAD 보다 먼저
_bb_repo "$TMP/bb-dev" main
mkdir -p "$TMP/bb-dev/.claude" && printf '{"git":{"baseBranch":"develop"}}' > "$TMP/bb-dev/.claude/harness.json"
_bb_out=$(bash "$_bb_sh" "$TMP/bb-dev" 2>/dev/null); _bb_code=$?
[ "$_bb_code" = "0" ] && [ "$_bb_out" = "develop" ] && ok "baseBranch=develop → develop" || bad "baseBranch 우선" "exit=$_bb_code out=[$_bb_out]"

# ② baseBranch 빈 값 → origin/HEAD (인자 없이 레포 안에서 부르면 . 이 기본)
_bb_repo "$TMP/bb-empty" main
mkdir -p "$TMP/bb-empty/.claude" && printf '{"git":{"baseBranch":""}}' > "$TMP/bb-empty/.claude/harness.json"
_bb_out=$(cd "$TMP/bb-empty" && bash "$_bb_sh" 2>/dev/null); _bb_code=$?
[ "$_bb_code" = "0" ] && [ "$_bb_out" = "main" ] && ok "baseBranch 빈 값 + origin/HEAD=main → main (기본 경로 .)" || bad "빈 값 → origin/HEAD" "exit=$_bb_code out=[$_bb_out]"

# ③ harness.json 없음 → origin/HEAD
_bb_repo "$TMP/bb-nocfg" main
_bb_out=$(bash "$_bb_sh" "$TMP/bb-nocfg" 2>/dev/null); _bb_code=$?
[ "$_bb_code" = "0" ] && [ "$_bb_out" = "main" ] && ok "harness.json 없음 + origin/HEAD=main → main" || bad "설정 없음 → origin/HEAD" "exit=$_bb_code out=[$_bb_out]"

# ④ 둘 다 없음 → stdout 비고 stderr 한 줄 + exit 2 (main 으로 짐작하지 않는다)
_bb_repo "$TMP/bb-none" ""
_bb_out=$(bash "$_bb_sh" "$TMP/bb-none" 2>"$TMP/bb-none.err"); _bb_code=$?
_bb_err=$(cat "$TMP/bb-none.err" 2>/dev/null)
[ "$_bb_code" = "2" ] && [ -z "$_bb_out" ] && [ -n "$_bb_err" ] && [ "$(printf '%s\n' "$_bb_err" | wc -l | tr -d ' ')" = "1" ] \
  && ok "둘 다 없음 → exit 2 · stdout 빈 값 · stderr 한 줄" || bad "둘 다 없음" "exit=$_bb_code out=[$_bb_out] err=[$_bb_err]"
