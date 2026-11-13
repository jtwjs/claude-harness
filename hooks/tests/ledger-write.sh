# 원장 쓰기(ledger.py append · hit · gate-fix) — AC8·AC9·AC12·AC15. test.sh 가 source 한다.
printf '\n[ledger-write] append · hit · gate-fix\n'
LW="$HOOKS/lib/ledger.py"
LWL="$TMP/lw/ledger.jsonl"
export CLAUDE_HYPOTHESIS_LEDGER="$LWL"
rm -rf "$TMP/lw"
GOOD="repo=r1 task=t1 gate=schema diff=easy area=BE hyp=true rec=true acc=true why=false rebut=false skip=false"

# append: 파일·폴더가 없으면 만들고 끝에 한 줄
python3 "$LW" append $GOOD 2>"$TMP/lw.err"; code=$?
[ "$code" = "0" ] && [ "$(wc -l < "$LWL" 2>/dev/null | tr -d ' ')" = "1" ] && ok "append: 폴더·파일 만들고 한 줄 추가" || bad "append 기본" "exit=$code"
TS1=$(python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["ts"])' "$LWL" 2>/dev/null)
[ -n "$TS1" ] && ok "append: ts 는 스크립트가 붙인다" || bad "ts" "없음"
python3 -c '
import json,sys
d=json.loads(open(sys.argv[1]).readline())
exp={"ts","repo","task","gate","diff","area","hyp","rec","acc","why","rebut","skip"}
assert set(d)==exp and d["hyp"] is True and d["why"] is False and d["gate"]=="schema", d
' "$LWL" 2>/dev/null && ok "append: 칸·불리언 형식" || bad "줄 형식" "$(cat "$LWL")"

# null 값(task·gate)
python3 "$LW" append repo=r1 task=null gate=null diff=easy area=unknown hyp=false rec=false acc=false why=false rebut=false skip=false 2>/dev/null; code=$?
python3 -c '
import json,sys
d=[json.loads(l) for l in open(sys.argv[1])][-1]
assert d["task"] is None and d["gate"] is None, d
' "$LWL" 2>/dev/null && [ "$code" = "0" ] && ok "append: task=null·gate=null 은 JSON null" || bad "null" "exit=$code"

# 거부 — 줄 수가 늘지 않고 exit 비0 · stderr 한 줄
lw_reject() { # $1=이름  나머지=인자
  local name="$1"; shift
  local before after err code
  before=$(wc -l < "$LWL" | tr -d ' ')
  err=$(python3 "$LW" "$@" 2>&1 >/dev/null); code=$?
  after=$(wc -l < "$LWL" | tr -d ' ')
  if [ "$code" != "0" ] && [ "$before" = "$after" ] && [ -n "$err" ] && [ "$(printf '%s\n' "$err" | wc -l | tr -d ' ')" = "1" ]; then ok "거부: $name"; else bad "거부 실패: $name" "exit=$code before=$before after=$after err=[$err]"; fi
}
lw_reject "허용 밖 gate" append repo=r1 task=t1 gate=bogus diff=easy area=BE hyp=true rec=true acc=true why=false rebut=false skip=false
lw_reject "허용 밖 area" append repo=r1 task=t1 gate=api diff=easy area=mobile hyp=true rec=true acc=true why=false rebut=false skip=false
lw_reject "불리언 아닌 값" append repo=r1 task=t1 gate=api diff=easy area=BE hyp=yes rec=true acc=true why=false rebut=false skip=false
lw_reject "허용 밖 칸(name)" append $GOOD name=kim
lw_reject "허용 밖 칸(prompt 원문)" append $GOOD prompt=hello
lw_reject "칸 누락" append repo=r1 task=t1 gate=api diff=easy area=BE hyp=true rec=true acc=true why=false rebut=false
lw_reject "repo 에 공백·경로 문자" append repo=a/b task=t1 gate=api diff=easy area=BE hyp=true rec=true acc=true why=false rebut=false skip=false
lw_reject "ts 를 직접 넣기" append $GOOD ts=2020-01-01
lw_reject "형식 없는 인자" append foo

# hit
python3 "$LW" hit "$TS1" right model 2>/dev/null; code=$?
python3 -c '
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][-1]
assert l=={"ref":sys.argv[2],"hit":"right","by":"model"}, l
' "$LWL" "$TS1" 2>/dev/null && [ "$code" = "0" ] && ok "hit: {ref,hit,by} 한 줄 추가" || bad "hit" "exit=$code"
python3 "$LW" hit "$TS1" wrong finn 2>/dev/null; code=$?
[ "$code" = "0" ] && [ "$(tail -n1 "$LWL" | grep -c '"wrong"')" = "1" ] && ok "hit: 같은 ref 를 또 쓰면 그냥 추가(마지막이 유효)" || bad "hit 재기록" "exit=$code"
lw_reject "hit 값이 허용 밖" hit "$TS1" great model
lw_reject "hit by 가 허용 밖" hit "$TS1" right kim
lw_reject "hit 없는 ref" hit 1999-01-01T00:00:00.000+00:00 right model
# hyp=false 줄을 ref 로
TSF=$(python3 -c 'import json,sys; print([json.loads(l) for l in open(sys.argv[1]) if "ts" in l][1]["ts"])' "$LWL" 2>/dev/null)
lw_reject "hyp=false 줄을 ref 로" hit "$TSF" right model
# 적중 줄의 ref 를 가리키지 못한다(ts 가 아님)
lw_reject "맡김 줄 아닌 ref" hit "right" right model

# gate-fix
python3 "$LW" gate-fix "$TSF" api 2>/dev/null; code=$?
python3 -c '
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][-1]
assert l=={"ref":sys.argv[2],"gate":"api","by":"finn"}, l
' "$LWL" "$TSF" 2>/dev/null && [ "$code" = "0" ] && ok "gate-fix: {ref,gate,by:finn} 한 줄 추가" || bad "gate-fix" "exit=$code"
python3 "$LW" gate-fix "$TS1" null 2>/dev/null; code=$?
python3 -c '
import json,sys
l=[json.loads(x) for x in open(sys.argv[1])][-1]
assert l["gate"] is None and l["by"]=="finn", l
' "$LWL" 2>/dev/null && [ "$code" = "0" ] && ok "gate-fix: null 허용" || bad "gate-fix null" "exit=$code"
lw_reject "gate-fix 허용 밖 gate" gate-fix "$TSF" bogus
lw_reject "gate-fix 없는 ref" gate-fix 1999-01-01T00:00:00.000+00:00 api
lw_reject "gate-fix 가 적중 줄을 ref 로" gate-fix right api

# 기존 줄 무변경 · 깨진 줄이 섞여도 ref 검사 동작
before_hash=$(cat "$LWL" | shasum | cut -d' ' -f1)
n=$(wc -l < "$LWL" | tr -d ' ')
python3 "$LW" hit "$TS1" partial finn 2>/dev/null
head -n "$n" "$LWL" | shasum | cut -d' ' -f1 | grep -qx "$before_hash" && ok "기존 줄은 그대로(끝에만 붙는다)" || bad "기존 줄 변경" "앞 ${n}줄이 달라짐"
printf 'not json {{{\n' >> "$LWL"
python3 "$LW" hit "$TS1" right model 2>/dev/null; code=$?
[ "$code" = "0" ] && ok "깨진 줄이 섞여도 ref 검사는 건너뛰고 동작" || bad "깨진 줄" "exit=$code"

# AC12: 쓸 수 없는 경로 — 비0 + stderr 한 줄
err=$(CLAUDE_HYPOTHESIS_LEDGER="/dev/null/x/ledger.jsonl" python3 "$LW" append $GOOD 2>&1 >/dev/null); code=$?
[ "$code" != "0" ] && [ -n "$err" ] && [ "$(printf '%s\n' "$err" | wc -l | tr -d ' ')" = "1" ] && ok "쓰기 실패: 비0 종료 + stderr 한 줄" || bad "쓰기 실패" "exit=$code err=[$err]"
err=$(CLAUDE_HYPOTHESIS_LEDGER="/dev/null/x/ledger.jsonl" python3 "$LW" hit "$TS1" right model 2>&1 >/dev/null); code=$?
[ "$code" != "0" ] && [ "$(printf '%s\n' "$err" | wc -l | tr -d ' ')" = "1" ] && ok "hit 쓰기 실패도 비0 + 한 줄" || bad "hit 쓰기 실패" "exit=$code err=[$err]"

# 사용자 원장은 건드리지 않는다
export CLAUDE_HYPOTHESIS_LEDGER="$LWL"

# ── step 9: ts 형식(#난수) · diff 칸 ─────────────────────────────────────────
rm -f "$LWL"
python3 "$LW" append $GOOD 2>/dev/null
TS9=$(python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["ts"])' "$LWL" 2>/dev/null)
printf '%s' "$TS9" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}[+-][0-9]{2}:[0-9]{2}#[0-9a-f]{4}$' && ok "step9 ts 는 <ISO 마이크로초>#<hex4>" || bad "step9 ts 형식" "[$TS9]"
python3 -c '
import json,sys
d=json.loads(open(sys.argv[1]).readline())
ks=list(d)
assert ks.index("diff")==ks.index("gate")+1 and d["diff"]=="easy", ks
' "$LWL" 2>/dev/null && ok "step9 줄에 diff 칸이 gate 다음" || bad "step9 diff 칸" "$(cat "$LWL")"

# 동시 50번 append — ts 가 모두 다르다
rm -f "$LWL"
for i in $(seq 50); do python3 "$LW" append repo=conc task=t gate=null diff=null area=BE hyp=false rec=false acc=false why=false rebut=false skip=false 2>/dev/null & done
wait
python3 -c '
import json,sys
ts=[json.loads(l)["ts"] for l in open(sys.argv[1])]
assert len(ts)==50 and len(set(ts))==50, (len(ts), len(set(ts)))
' "$LWL" 2>/dev/null && ok "step9 동시 append 50번도 ts 가 전부 다르다" || bad "step9 ts 겹침" "$(wc -l < "$LWL")줄"

# hit·gate-fix 가 # 꼬리 ts 를 ref 로 받는다
rm -f "$LWL"
python3 "$LW" append $GOOD 2>/dev/null
TSH=$(python3 -c 'import json,sys; print(json.loads(open(sys.argv[1]).readline())["ts"])' "$LWL" 2>/dev/null)
python3 "$LW" hit "$TSH" right model 2>/dev/null; c1=$?
python3 "$LW" gate-fix "$TSH" api 2>/dev/null; c2=$?
[ "$c1" = "0" ] && [ "$c2" = "0" ] && ok "step9 hit·gate-fix 가 #꼬리 ts 를 ref 로 받는다" || bad "step9 ref" "hit=$c1 gate-fix=$c2"

# diff 값 4종 통과 · 허용 밖 거부 · 빠지면 거부
for v in easy mid hard null; do
  rm -f "$LWL"
  python3 "$LW" append repo=r1 task=t1 gate=api diff=$v area=BE hyp=true rec=true acc=true why=false rebut=false skip=false 2>/dev/null; code=$?
  python3 -c '
import json,sys
d=json.loads(open(sys.argv[1]).readline())
exp=None if sys.argv[2]=="null" else sys.argv[2]
assert d["diff"]==exp, d
' "$LWL" "$v" 2>/dev/null && [ "$code" = "0" ] && ok "step9 diff=$v 통과" || bad "step9 diff=$v" "exit=$code"
done
rm -f "$LWL"; : > "$LWL"
lw_reject "step9 허용 밖 diff" append repo=r1 task=t1 gate=api diff=foo area=BE hyp=true rec=true acc=true why=false rebut=false skip=false
lw_reject "step9 diff 칸 빠짐" append repo=r1 task=t1 gate=api area=BE hyp=true rec=true acc=true why=false rebut=false skip=false
