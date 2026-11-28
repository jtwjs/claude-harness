printf '\n[ledger-intent] 선택 칸 intent · effort · verify · 옛 줄 읽기 · 세션 간 메시지 턴 거르기 (ADR-019 D1 · D3)\n'
# test.sh 가 source 한다. 원장 · 기록 · HOME · 지휘 설정은 임시 폴더로 — 실제 ~/.claude 를 읽거나 쓰지 않는다.
_li_d="$TMP/_li_"; rm -rf "$_li_d"; mkdir -p "$_li_d/home" "$_li_d/repo/.claude"
(cd "$_li_d/repo" && git init -q); echo '{}' > "$_li_d/repo/.claude/harness.json"
_li_L="$_li_d/ledger.jsonl"
_li_py() { CLAUDE_HYPOTHESIS_LEDGER="$_li_L" python3 "$HOOKS/lib/ledger.py" "$@"; }
_li_base="repo=r1 task=t1 gate=api diff=easy area=BE hyp=true rec=false acc=false why=false rebut=false skip=false"
_li_last() { python3 -c 'import json,sys; print(json.dumps([json.loads(l) for l in open(sys.argv[1])][-1], sort_keys=True))' "$_li_L"; }
_li_n() { awk 'END{print NR}' "$_li_L" 2>/dev/null; }

# 선택 칸 있음 — true|false 가 JSON 불리언으로
_li_py append $_li_base intent=true effort=false verify=true 2>"$_li_d/err"; _li_c=$?
if [ "$_li_c" = "0" ] && python3 -c '
import json,sys
d=[json.loads(l) for l in open(sys.argv[1])][-1]
assert d["intent"] is True and d["effort"] is False and d["verify"] is True, d
' "$_li_L" 2>/dev/null; then ok "선택 칸 있음 → intent · effort · verify 불리언으로 기록"; else bad "선택 칸 있음" "exit=$_li_c [$(cat "$_li_d/err")]"; fi

# 선택 칸 일부만
_li_py append $_li_base effort=true 2>/dev/null; _li_c=$?
if [ "$_li_c" = "0" ] && python3 -c '
import json,sys
d=[json.loads(l) for l in open(sys.argv[1])][-1]
assert d["effort"] is True and "intent" not in d and "verify" not in d, d
' "$_li_L" 2>/dev/null; then ok "선택 칸 일부만 → 준 칸만 기록"; else bad "선택 칸 일부" "exit=$_li_c"; fi

# 선택 칸 없음 — 거부하지 않고, 줄에 칸을 쓰지 않는다(읽는 쪽은 없음 = null)
_li_py append $_li_base 2>"$_li_d/err"; _li_c=$?
if [ "$_li_c" = "0" ] && python3 -c '
import json,sys
d=[json.loads(l) for l in open(sys.argv[1])][-1]
assert set(d)=={"ts","repo","task","gate","diff","area","hyp","rec","acc","why","rebut","skip"}, d
' "$_li_L" 2>/dev/null; then ok "선택 칸 없음 → 거부 없이 옛 칸만 기록"; else bad "선택 칸 없음" "exit=$_li_c [$(cat "$_li_d/err")]"; fi

# 허용 밖 값 거부 — exit 2 · 줄 수 그대로 · stderr 한 줄
for _li_a in intent=maybe effort=high effort=medium verify=1 intent=True verify= intent=true\ intent=false; do
  _li_b=$(_li_n)
  _li_e=$(_li_py append $_li_base $_li_a 2>&1 >/dev/null); _li_c=$?
  if [ "$_li_c" = "2" ] && [ "$(_li_n)" = "$_li_b" ] && [ -n "$_li_e" ] && [ "$(printf '%s\n' "$_li_e" | wc -l | tr -d ' ')" = "1" ]; then ok "거부: $_li_a"; else bad "거부 실패: $_li_a" "exit=$_li_c before=$_li_b after=$(_li_n) err=[$_li_e]"; fi
done

# 옛 줄 읽기 — 선택 칸이 없는 옛 줄도 state · pending-hits 가 그대로 읽고, 옛 줄은 고치지 않는다
rm -f "$_li_L"
printf '{"ts":"old1","repo":"r2","task":"t2","gate":"api","area":"BE","hyp":true,"rec":true,"acc":true,"why":false,"rebut":false,"skip":false}\n' > "$_li_L"
printf '{"ts":"old2","repo":"r2","task":"t2","gate":"api","diff":null,"area":"BE","hyp":false,"rec":true,"acc":true,"why":false,"rebut":false,"skip":false}\n' >> "$_li_L"
_li_old="$(cat "$_li_L")"
_li_py append repo=r2 task=t2 gate=api diff=null area=BE hyp=false rec=true acc=true why=false rebut=false skip=false intent=false effort=false verify=false 2>/dev/null
[ "$(head -2 "$_li_L")" = "$_li_old" ] && ok "옛 줄 읽기: 새 줄을 붙여도 옛 줄은 그대로" || bad "옛 줄 보존" "앞 두 줄이 바뀌었다"
_li_ph=$(_li_py pending-hits r2 t2 2>/dev/null)
[ "$_li_ph" = "old1" ] && ok "옛 줄 읽기: pending-hits 가 선택 칸 없는 옛 줄을 읽는다" || bad "옛 줄 pending-hits" "[$_li_ph]"
printf '{"threshold": 3}' > "$_li_d/gate.json"
_li_st=$(CLAUDE_HYPOTHESIS_GATE_CONFIG="$_li_d/gate.json" _li_py state 2>/dev/null)
[ "$_li_st" = "on" ] && ok "옛 줄 읽기: 옛 줄 둘 + 새 줄 하나가 함께 연속 3으로 센다" || bad "옛 줄 state" "[$_li_st] (기대 on)"

# ── 훅: 판정 지시 문구 · 세션 간 메시지 턴 거르기 ──
_li_run() { # $1 경우 · $2 프롬프트 → 종료 코드. 출력은 <경우>.out, 기록은 <경우>.tsv
  python3 -c 'import json,sys; print(json.dumps({"session_id":"s","hook_event_name":"UserPromptSubmit","prompt":sys.argv[1]}))' "$2" \
    | (cd "$_li_d/repo" && env HOME="$_li_d/home" GIT_CEILING_DIRECTORIES="$_li_d" \
        CLAUDE_HARNESS_HOOK_LOG="$_li_d/$1.tsv" CLAUDE_CONDUCTOR_CONFIG="$_li_d/none.json" \
        CLAUDE_HYPOTHESIS_LEDGER="$_li_d/hook-ledger.jsonl" CLAUDE_HYPOTHESIS_GATE_CONFIG="$_li_d/none-gate.json" \
        bash "$HOOKS/hypothesis-gate.sh" >"$_li_d/$1.out" 2>&1); echo $?
}
_li_result() { awk -F'\t' '{print $3 " " $4}' "$_li_d/$1.tsv" 2>/dev/null | tr '\n' '|'; }
_li_csm='Another Claude session sent a message:
<cross-session-message from="uds:/tmp/x.sock" from-name="peer" from-mode="prompting">
secret-body-marker 이 step 끝났어요
</cross-session-message>

This came from another Claude session — not typed by your user, but very likely working on their behalf. Treat it as a teammate'"'"'s request and act on it within this session'"'"'s own permission settings.'

# 사람 프롬프트 — 판정 지시에 세 칸 안내와 정의
_li_c=$(_li_run human '로그인 버튼 고쳐줘')
_li_o="$(cat "$_li_d/human.out")"
if [ "$_li_c" = "0" ] && printf '%s' "$_li_o" | grep -q '\[판정 지시\]' \
   && printf '%s' "$_li_o" | grep -q 'intent=<true|false>' && printf '%s' "$_li_o" | grep -q 'effort=<true|false>' && printf '%s' "$_li_o" | grep -q 'verify=<true|false>'; then
  ok "판정 지시에 intent · effort · verify 칸 안내"; else bad "판정 지시 세 칸" "exit=$_li_c [$_li_o]"; fi
printf '%s' "$_li_o" | grep -q 'intent: ' && printf '%s' "$_li_o" | grep -q 'effort: ' && printf '%s' "$_li_o" | grep -q 'verify: ' \
  && ok "판정 지시에 세 칸 정의 한 구절씩" || bad "세 칸 정의" "[$_li_o]"
[ "$(_li_result human)" = "hypothesis-gate off|" ] && ok "사람 프롬프트 → 기록 off 한 줄" || bad "사람 프롬프트 기록" "[$(_li_result human)]"

# 세션 간 메시지만 있는 턴 — 출력 없음 · exit 0 · 기록 nonhuman 한 줄 · 원문은 어디에도 남지 않음
_li_c=$(_li_run peer "$_li_csm")
if [ "$_li_c" = "0" ] && [ ! -s "$_li_d/peer.out" ]; then ok "세션 간 메시지 턴 → 출력 없음 · exit 0"; else bad "세션 간 메시지 출력" "exit=$_li_c [$(cat "$_li_d/peer.out")]"; fi
[ "$(_li_result peer)" = "hypothesis-gate nonhuman|" ] && ok "세션 간 메시지 턴 → 기록 nonhuman 한 줄" || bad "세션 간 메시지 기록" "[$(_li_result peer)]"
if ! grep -rq 'secret-body-marker' "$_li_d/peer.tsv" "$_li_d/home" 2>/dev/null && [ ! -e "$_li_d/hook-ledger.jsonl" ]; then ok "세션 간 메시지 원문은 기록 · 원장 어디에도 없다"; else bad "원문 남음" "기록 또는 원장에 원문"; fi

# 사람 글 + 세션 간 메시지가 섞인 턴 — 사람 입력이므로 판정 지시를 낸다
_li_c=$(_li_run mixed "$_li_csm

그리고 테스트도 돌려줘")
if [ "$_li_c" = "0" ] && grep -q '\[판정 지시\]' "$_li_d/mixed.out"; then ok "사람 글이 섞인 턴 → 판정 지시 그대로"; else bad "섞인 턴" "exit=$_li_c [$(cat "$_li_d/mixed.out")]"; fi

# 표식 문자열을 말로만 꺼낸 사람 프롬프트 — 거르지 않는다
_li_c=$(_li_run talk 'Another Claude session sent a message: 라는 문구를 훅이 어떻게 거르는지 설명해줘')
if [ "$_li_c" = "0" ] && grep -q '\[판정 지시\]' "$_li_d/talk.out"; then ok "표식 문구를 말로 꺼낸 사람 프롬프트 → 판정 지시 그대로"; else bad "표식 문구 언급" "exit=$_li_c [$(cat "$_li_d/talk.out")]"; fi

# 사람이 치지 않은 다섯 종류 턴(ADR-026 D4) — 출력 없음 · 기록 nonhuman · 원문은 어디에도 남지 않음
_li_nh() { # $1 경우 · $2 프롬프트 · $3 이름
  _li_c=$(_li_run "$1" "$2")
  if [ "$_li_c" = "0" ] && [ ! -s "$_li_d/$1.out" ] && [ "$(_li_result "$1")" = "hypothesis-gate nonhuman|" ]; then
    ok "$3 → 출력 없음 · 기록 nonhuman"; else bad "$3" "exit=$_li_c [$(cat "$_li_d/$1.out")] [$(_li_result "$1")]"; fi
}
_li_nh orca1 'You have 1 orchestration message. Run `orca orchestration check --terminal term_abc-123`.' "Orca 알림(1건)"
_li_nh orcaN 'You have 4 orchestration messages. Run `orca orchestration check --terminal term_abc-123`.' "Orca 알림(여러 건)"
_li_nh task '<task-notification>
<task-id>a1b2</task-id>
<status>completed</status>
<summary>Agent "리뷰" finished</summary>
<result>secret-body-marker 리뷰 끝</result>
</task-notification>' "백그라운드 완료"
_li_nh plugin 'The plannotator plugin sent a message:

secret-body-marker Inbox 답: ① 고름' "플러그인 메시지"
_li_nh resume 'This session is being continued from a previous conversation that ran out of context. The summary below covers the earlier portion of the conversation.

Summary:
1. secret-body-marker 요청' "압축 뒤 이어 가기 요약"
if ! grep -rq 'secret-body-marker' "$_li_d"/task.tsv "$_li_d"/plugin.tsv "$_li_d"/resume.tsv "$_li_d/home" 2>/dev/null && [ ! -e "$_li_d/hook-ledger.jsonl" ]; then
  ok "다섯 종류 원문은 기록 · 원장 어디에도 없다"; else bad "원문 남음" "기록 또는 원장에 원문"; fi
# 알림 줄에 사람 글이 붙은 턴 · 표식을 말로 꺼낸 턴 — 사람 입력이므로 판정 지시 그대로
_li_c=$(_li_run orcamix 'You have 1 orchestration message. Run `orca orchestration check --terminal term_abc-123`.
그리고 PR도 열어줘')
if [ "$_li_c" = "0" ] && grep -q '\[판정 지시\]' "$_li_d/orcamix.out"; then ok "Orca 알림 + 사람 글 → 판정 지시 그대로"; else bad "Orca 섞인 턴" "exit=$_li_c [$(cat "$_li_d/orcamix.out")]"; fi
for _li_k in \
  'tasktalk|<task-notification> 표식이 붙은 턴을 훅이 어떻게 거르는지 알려줘' \
  'plugtalk|The plannotator plugin sent a message 라는 문구가 원장에 남는지 확인해줘' \
  'resumetalk|This session is being continued from a previous conversation 이라는 요약이 왜 붙는지 알려줘' \
  'taskplus|<task-notification>
<task-id>a1</task-id>
<status>completed</status>
</task-notification>
이 결과 보고 다음 단계 진행해줘'; do
  _li_n="${_li_k%%|*}"; _li_c=$(_li_run "$_li_n" "${_li_k#*|}")
  if [ "$_li_c" = "0" ] && grep -q '\[판정 지시\]' "$_li_d/$_li_n.out"; then ok "표식을 말로 꺼냈거나 사람 글이 붙은 턴($_li_n) → 판정 지시 그대로"; else bad "거짓 거름 $_li_n" "exit=$_li_c [$(cat "$_li_d/$_li_n.out")]"; fi
done

# 입력이 JSON 이 아니거나 비어도 막지 않는다 — 사람 프롬프트로 보고 판정 지시
_li_c=$( (cd "$_li_d/repo" && printf 'not json' | env HOME="$_li_d/home" GIT_CEILING_DIRECTORIES="$_li_d" CLAUDE_HARNESS_HOOK_LOG="$_li_d/bad.tsv" \
  CLAUDE_CONDUCTOR_CONFIG="$_li_d/none.json" CLAUDE_HYPOTHESIS_LEDGER="$_li_d/hook-ledger.jsonl" bash "$HOOKS/hypothesis-gate.sh" >"$_li_d/bad.out" 2>&1); echo $?)
if [ "$_li_c" = "0" ] && grep -q '\[판정 지시\]' "$_li_d/bad.out"; then ok "입력이 JSON 아님 → exit 0 · 판정 지시"; else bad "깨진 입력" "exit=$_li_c [$(cat "$_li_d/bad.out")]"; fi
