# hypothesis-gate 는 하네스 레포(.claude/harness.json) · 지휘 자리에서만 켜진다(ADR-018 B-3). test.sh 가 source 한다.
# 그 밖 폴더 · git 밖은 0줄 · exit 0. conductor-context(지휘 자리에서만)와 block-dangerous-bash(모든 레포)는 지금 동작 그대로 고정한다.
# HOME · 원장 · 기록 · 지휘 설정은 임시 폴더로 — 실제 ~/.claude 를 읽거나 쓰지 않는다.
printf '\n[quiet-without-harness] hypothesis-gate 는 하네스 레포 · 지휘 자리에서만, 안전 훅은 그대로\n'
_qh_d="$TMP/_qh_"; rm -rf "$_qh_d"
mkdir -p "$_qh_d/home" "$_qh_d/harness/.claude" "$_qh_d/harness/src" "$_qh_d/bare" "$_qh_d/plain" "$_qh_d/seat"
(cd "$_qh_d/harness" && git init -q); echo '{}' > "$_qh_d/harness/.claude/harness.json"
(cd "$_qh_d/bare" && git init -q)
(cd "$_qh_d/seat" && git init -q)   # 지휘 자리 — harness.json 없음
printf '{"seat":"%s","repos":[]}' "$_qh_d/seat" > "$_qh_d/conductor.json"
_qh_run() { # $1 경우 · $2 폴더 · $3 훅 파일 · $4 stdin → 종료 코드. 출력은 $_qh_d/<경우>.out, 기록은 <경우>.tsv
  (cd "$2" && printf '%s' "$4" | env HOME="$_qh_d/home" GIT_CEILING_DIRECTORIES="$_qh_d" \
    CLAUDE_HARNESS_HOOK_LOG="$_qh_d/$1.tsv" CLAUDE_CONDUCTOR_CONFIG="$_qh_d/conductor.json" \
    CLAUDE_HYPOTHESIS_LEDGER="$_qh_d/ledger.jsonl" CLAUDE_HYPOTHESIS_GATE_CONFIG="$_qh_d/gate.json" \
    CLAUDE_GH_ACCOUNTS="$_qh_d/gh-accounts.txt" \
    bash "$HOOKS/$3" >"$_qh_d/$1.out" 2>&1); echo $?
}
_qh_lines() { awk 'END{print NR}' "$_qh_d/$1.out"; }
_qh_result() { awk -F'\t' '{print $4}' "$_qh_d/$1.tsv" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'; }

# ── hypothesis-gate ──
_qh_c=$(_qh_run hg-harness "$_qh_d/harness" hypothesis-gate.sh '{"prompt":"x"}')
if [ "$_qh_c" = "0" ] && [ "$(_qh_lines hg-harness)" = "1" ] && grep -q '\[판정 지시\]' "$_qh_d/hg-harness.out"; then ok "hypothesis-gate 하네스 레포 → 판정 지시 한 줄"; else bad "hg 하네스 레포" "exit=$_qh_c [$(cat "$_qh_d/hg-harness.out")]"; fi
_qh_c=$(_qh_run hg-sub "$_qh_d/harness/src" hypothesis-gate.sh '{"prompt":"x"}')
if [ "$_qh_c" = "0" ] && grep -q '\[판정 지시\]' "$_qh_d/hg-sub.out"; then ok "hypothesis-gate 하네스 레포 하위 폴더 → 판정 지시(레포 루트로 찾는다)"; else bad "hg 하위 폴더" "exit=$_qh_c [$(cat "$_qh_d/hg-sub.out")]"; fi
_qh_c=$(_qh_run hg-seat "$_qh_d/seat" hypothesis-gate.sh '{"prompt":"x"}')
if [ "$_qh_c" = "0" ] && [ "$(_qh_lines hg-seat)" = "1" ] && grep -q '\[판정 지시\]' "$_qh_d/hg-seat.out"; then ok "hypothesis-gate 지휘 자리(conductor.json seat) → 판정 지시 한 줄"; else bad "hg 지휘 자리" "exit=$_qh_c [$(cat "$_qh_d/hg-seat.out")]"; fi
_qh_c=$(_qh_run hg-bare "$_qh_d/bare" hypothesis-gate.sh '{"prompt":"x"}')
if [ "$_qh_c" = "0" ] && [ ! -s "$_qh_d/hg-bare.out" ]; then ok "hypothesis-gate 하네스 없는 git 레포 → 0줄 · exit 0"; else bad "hg 하네스 없음" "exit=$_qh_c [$(cat "$_qh_d/hg-bare.out")]"; fi
[ "$(_qh_result hg-bare)" = "noharness" ] && ok "hypothesis-gate 하네스 없음 → 기록 결과 noharness 한 줄" || bad "hg 하네스 없음 기록" "[$(_qh_result hg-bare)]"
_qh_c=$(_qh_run hg-plain "$_qh_d/plain" hypothesis-gate.sh '{"prompt":"x"}')
if [ "$_qh_c" = "0" ] && [ ! -s "$_qh_d/hg-plain.out" ]; then ok "hypothesis-gate git 밖 → 0줄 · exit 0"; else bad "hg git 밖" "exit=$_qh_c [$(cat "$_qh_d/hg-plain.out")]"; fi
[ ! -e "$_qh_d/ledger.jsonl" ] && [ ! -e "$_qh_d/home/.claude/hypothesis-ledger.jsonl" ] && ok "hypothesis-gate 원장을 만들지 않는다" || bad "hg 원장" "원장 파일이 생겼다"
# 지휘 설정이 없으면 seat 폴더도 그냥 하네스 없는 레포
_qh_c=$( (cd "$_qh_d/seat" && printf '{}' | env HOME="$_qh_d/home" GIT_CEILING_DIRECTORIES="$_qh_d" CLAUDE_HARNESS_HOOK_LOG="$_qh_d/x.tsv" \
  CLAUDE_CONDUCTOR_CONFIG="$_qh_d/none.json" CLAUDE_HYPOTHESIS_LEDGER="$_qh_d/ledger.jsonl" bash "$HOOKS/hypothesis-gate.sh" 2>&1); echo "rc=$?")
[ "$_qh_c" = "rc=0" ] && ok "hypothesis-gate 지휘 설정 없음 → seat 폴더도 0줄" || bad "hg 설정 없음" "[$_qh_c]"

# ── conductor-context — 지휘 자리에서만(바꾸지 않음) ──
for _qh_w in harness bare plain; do
  _qh_c=$(_qh_run cc-$_qh_w "$_qh_d/$_qh_w" conductor-context.sh '{}')
  if [ "$_qh_c" = "0" ] && [ ! -s "$_qh_d/cc-$_qh_w.out" ]; then ok "conductor-context $_qh_w → 0줄 · exit 0"; else bad "cc $_qh_w" "exit=$_qh_c [$(cat "$_qh_d/cc-$_qh_w.out")]"; fi
done
_qh_c=$(_qh_run cc-seat "$_qh_d/seat" conductor-context.sh '{}')
if [ "$_qh_c" = "0" ] && grep -q '지휘 현황' "$_qh_d/cc-seat.out"; then ok "conductor-context 지휘 자리 → 현황"; else bad "cc 지휘 자리" "exit=$_qh_c [$(cat "$_qh_d/cc-seat.out")]"; fi

# ── block-dangerous-bash — 하네스 없는 폴더에서도 deny 패턴을 막는다(바꾸지 않음) ──
_qh_cmd='{"tool_input":{"command":"git push -f origin main"}}'
for _qh_w in bare plain; do
  _qh_c=$(_qh_run bd-$_qh_w "$_qh_d/$_qh_w" block-dangerous-bash.sh "$_qh_cmd")
  [ "$_qh_c" = "2" ] && ok "block-dangerous-bash $_qh_w(하네스 없음)에서도 deny 패턴 → exit 2" || bad "bd $_qh_w" "exit=$_qh_c [$(cat "$_qh_d/bd-$_qh_w.out")]"
done
rm -rf "$_qh_d"
