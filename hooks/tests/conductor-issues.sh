# conductor issues.py — 이슈 의존(막힘 · 하위)과 「지금 진행 가능한 것」을 gh api graphql 로 감싼다. test.sh 가 source 한다.
# 가짜 gh(CLAUDE_CONDUCTOR_GH)가 받은 인자를 파일에 적고, 하위 명령마다 넘긴 graphql 인자를 본다. 진짜 gh 는 부르지 않는다.
printf '\n[conductor-issues] block · unblock · sub · ready — graphql 인자 · 진행 가능 필터\n'
_ci_py="$(cd "$HOOKS/.." && pwd)/skills/conductor/scripts/issues.py"
_ci_log="$TMP/ci-gh.log"
_ci_ready="$TMP/ci-ready.json"
_ci_gh="$TMP/ci-gh"
{
  printf '#!/bin/sh\n'
  printf 'printf "%%s\\n" "$*" >> "%s"\n' "$_ci_log"
  cat <<'SH'
case "$1 $2" in
  "issue view") [ "$3" = 404 ] && { echo "no issue 404" >&2; exit 1; }; echo "I_$3";;
  "repo view") echo "acme/cur";;
  "api graphql")
    case "$*" in
      *"i=I_500"*) echo "Resource not accessible by integration" >&2; exit 1;;
      *mutation*) echo '{"data":{"x":{"issue":{"number":1}}}}';;
SH
  printf '      *) cat "%s";;\n' "$_ci_ready"
  cat <<'SH'
    esac;;
  *) echo "unexpected: $*" >&2; exit 9;;
esac
SH
} > "$_ci_gh"
chmod +x "$_ci_gh"
cat > "$_ci_ready" <<'JSON'
{"data":{"repository":{"issues":{"nodes":[
 {"number":1,"title":"결정 D","labels":{"nodes":[{"name":"conductor"},{"name":"decision"}]},"blockedBy":{"nodes":[]}},
 {"number":2,"title":"막힌 후속","labels":{"nodes":[{"name":"conductor"},{"name":"follow-up"},{"name":"track:fe"}]},"blockedBy":{"nodes":[{"number":1,"state":"OPEN"}]}},
 {"number":3,"title":"풀린 후속","labels":{"nodes":[{"name":"conductor"},{"name":"follow-up"},{"name":"track:fe"},{"name":"track:be"}]},"blockedBy":{"nodes":[{"number":7,"state":"CLOSED"}]}},
 {"number":4,"title":"계약 변경","labels":{"nodes":[{"name":"conductor"},{"name":"contract-change"}]},"blockedBy":{"nodes":[]}}
]}}}}
JSON
_ci_run() { : > "$_ci_log"; CLAUDE_CONDUCTOR_GH="$_ci_gh" python3 "$_ci_py" "$@" 2>"$TMP/ci.err"; }

# ① block 12 10 — 노드 id 를 -R 레포에서 받아 addBlockedBy(#12 가 #10 에 막힌다)
_ci_out=$(_ci_run block 12 10 --repo acme/x); _ci_code=$?
[ "$_ci_code" = "0" ] && grep -qE '^issue view 12 .*-R acme/x' "$_ci_log" && grep -qE '^issue view 10 .*-R acme/x' "$_ci_log" \
  && ok "block: 두 이슈의 노드 id 를 --repo 레포에서 받는다" || bad "block id 조회" "exit=$_ci_code log=[$(cat "$_ci_log")]"
grep -qF 'api graphql -f query=mutation($i:ID!,$b:ID!){addBlockedBy(input:{issueId:$i,blockingIssueId:$b}){issue{number}}} -f i=I_12 -f b=I_10' "$_ci_log" \
  && ok "block: addBlockedBy · issueId=#12 · blockingIssueId=#10" || bad "block graphql" "$(cat "$_ci_log")"

# ② unblock 12 10 — removeBlockedBy (§4 「풀기」)
_ci_out=$(_ci_run unblock 12 10 --repo acme/x); _ci_code=$?
[ "$_ci_code" = "0" ] && grep -qF 'api graphql -f query=mutation($i:ID!,$b:ID!){removeBlockedBy(input:{issueId:$i,blockingIssueId:$b}){issue{number}}} -f i=I_12 -f b=I_10' "$_ci_log" \
  && ok "unblock: removeBlockedBy · issueId=#12 · blockingIssueId=#10" || bad "unblock graphql" "exit=$_ci_code log=[$(cat "$_ci_log")]"

# ③ sub 9 12 — #12 를 #9 의 하위로. --repo 가 없으면 -R 없이(지금 레포)
_ci_out=$(_ci_run sub 9 12); _ci_code=$?
[ "$_ci_code" = "0" ] && grep -qF 'api graphql -f query=mutation($p:ID!,$c:ID!){addSubIssue(input:{issueId:$p,subIssueId:$c}){issue{number}}} -f p=I_9 -f c=I_12' "$_ci_log" \
  && ok "sub: addSubIssue · issueId=부모 #9 · subIssueId=자식 #12" || bad "sub graphql" "exit=$_ci_code log=[$(cat "$_ci_log")]"
grep -q '^issue view' "$_ci_log" && ! grep -qF -- '-R' "$_ci_log" && ok "--repo 없으면 issue view 에 -R 을 붙이지 않는다" || bad "sub -R" "$(cat "$_ci_log")"

# ④ ready --repo acme/x — 열린 conductor 이슈를 한 번에 받아 decision · 열린 차단을 뺀다
_ci_out=$(_ci_run ready --repo acme/x); _ci_code=$?
_ci_flat=$(tr '\n' ' ' < "$_ci_log")
[ "$_ci_code" = "0" ] && [ "$(grep -c '^api graphql' "$_ci_log")" = "1" ] \
  && printf '%s' "$_ci_flat" | grep -qF -- '-f owner=acme' && printf '%s' "$_ci_flat" | grep -qF -- '-f name=x' \
  && printf '%s' "$_ci_flat" | grep -qF 'issues(first:100,states:OPEN,labels:["conductor"])' \
  && printf '%s' "$_ci_flat" | grep -qF 'blockedBy(first:20){nodes{number state}}' \
  && ok "ready: graphql 한 번 · owner/name · 열린 conductor 이슈 · blockedBy" || bad "ready graphql" "exit=$_ci_code log=[$_ci_flat]"
[ "$_ci_out" = "$(printf '#3 [track:fe,track:be] 풀린 후속\n#4 [] 계약 변경')" ] \
  && ok "ready: decision · 열린 차단은 빼고 「#번호 [track:…] 제목」" || bad "ready 출력" "[$_ci_out]"

# ⑤ ready (--repo 없음) — 지금 레포를 gh repo view 로 받는다
_ci_out=$(_ci_run ready); _ci_code=$?
_ci_flat=$(tr '\n' ' ' < "$_ci_log")
[ "$_ci_code" = "0" ] && grep -q '^repo view' "$_ci_log" \
  && printf '%s' "$_ci_flat" | grep -qF -- '-f owner=acme' && printf '%s' "$_ci_flat" | grep -qF -- '-f name=cur' \
  && ok "ready: --repo 없으면 gh repo view 의 레포(acme/cur)" || bad "ready 지금 레포" "exit=$_ci_code log=[$_ci_flat]"

# ⑥ 실패는 0 이 아닌 종료 — 부른 쪽이 §4 「실패하면」(Blocked-by 본문 · blocked 라벨)으로 간다
_ci_out=$(_ci_run block 404 10 --repo acme/x); _ci_code=$?
[ "$_ci_code" != "0" ] && ! grep -q '^api graphql' "$_ci_log" && [ -s "$TMP/ci.err" ] \
  && ok "id 조회 실패 → 0 아닌 종료 · mutation 안 부름 · stderr" || bad "id 실패" "exit=$_ci_code log=[$(cat "$_ci_log")]"
_ci_out=$(_ci_run block 500 10 --repo acme/x); _ci_code=$?
[ "$_ci_code" != "0" ] && grep -q 'Resource not accessible' "$TMP/ci.err" \
  && ok "graphql 실패(권한 · 기능 미지원) → 0 아닌 종료 · gh 오류를 stderr 로" || bad "graphql 실패" "exit=$_ci_code err=[$(cat "$TMP/ci.err")]"
_ci_out=$(_ci_run); _ci_code=$?
[ "$_ci_code" = "2" ] && grep -qi 'usage' "$TMP/ci.err" && [ ! -s "$_ci_log" ] \
  && ok "하위 명령 없음 → exit 2 · usage · gh 안 부름" || bad "사용법" "exit=$_ci_code err=[$(cat "$TMP/ci.err")]"
