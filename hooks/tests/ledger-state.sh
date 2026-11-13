# 원장 읽기(ledger.py state · pending-hits · pending-gates) — AC2~AC6·AC13·AC16·AC17(CLI). test.sh 가 source 한다.
printf '\n[ledger-state] state · pending-hits · pending-gates\n'
LS="$HOOKS/lib/ledger.py"
LSD="$TMP/ls"; rm -rf "$LSD"; mkdir -p "$LSD"
LSL="$LSD/ledger.jsonl"
export CLAUDE_HYPOTHESIS_LEDGER="$LSL"
export CLAUDE_HYPOTHESIS_GATE_CONFIG="$LSD/gate.json"
LSN=0
# 맡김 줄 하나: lse <repo> <task|null> <gate|null> <rec> <acc> <why> [hyp] [rebut]  — ts 는 t1,t2,.. 순서
lse() {
  LSN=$((LSN+1))
  local task gate
  [ "$2" = "null" ] && task=null || task="\"$2\""
  [ "$3" = "null" ] && gate=null || gate="\"$3\""
  printf '{"ts":"t%s","repo":"%s","task":%s,"gate":%s,"area":"BE","hyp":%s,"rec":%s,"acc":%s,"why":%s,"rebut":%s,"skip":false}\n' \
    "$LSN" "$1" "$task" "$gate" "${7:-false}" "$4" "$5" "$6" "${8:-false}" >> "$LSL"
}
lsreset() { rm -f "$LSL"; LSN=0; }
lscfg() { printf '{"threshold": %s}' "$1" > "$CLAUDE_HYPOTHESIS_GATE_CONFIG"; }
lsstate() { python3 "$LS" state "${1:-r}" "${2:-t}" 2>/dev/null; }
# 이유 없는 수락 줄 n 개
lsblind() { local i; for i in $(seq "$1"); do lse "${2:-r}" "${3:-t}" api true true false; done; }
lscheck() { # $1=이름 $2=기대 $3=실제
  [ "$2" = "$3" ] && ok "$1" || bad "$1" "기대=[$2] 실제=[$3]"
}

# AC2: 원장 없음·빈 파일·깨진 줄 — exit 0, 죽지 않음
lscfg 2; lsreset
out=$(python3 "$LS" state r t 2>&1); code=$?
[ "$code" = "0" ] && [ "$out" = "off" ] && ok "AC2 원장 없음 → off · exit 0" || bad "원장 없음" "exit=$code out=[$out]"
: > "$LSL"
out=$(python3 "$LS" state r t 2>&1); code=$?
[ "$code" = "0" ] && [ "$out" = "off" ] && ok "AC2 빈 파일 → off · exit 0" || bad "빈 파일" "exit=$code out=[$out]"
printf 'not json\n{"a":\n[1,2]\n' > "$LSL"; lsblind 2
out=$(python3 "$LS" state r t 2>&1); code=$?
[ "$code" = "0" ] && [ "$out" = "on" ] && ok "AC2 깨진 줄은 건너뛰고 나머지로 계산(2건·기준 2 → on)" || bad "깨진 줄" "exit=$code out=[$out]"
for c in pending-hits pending-gates; do
  out=$(python3 "$LS" $c r t 2>&1); code=$?
  [ "$code" = "0" ] && [ -z "$out" ] && ok "AC2 깨진 줄 섞인 원장에서 $c 도 죽지 않음" || bad "$c 깨진 줄" "exit=$code out=[$out]"
done
lsreset
out=$(python3 "$LS" pending-hits r t 2>&1); code=$?
[ "$code" = "0" ] && [ -z "$out" ] && ok "AC13 원장 없음 → pending-hits 빈 출력 · exit 0" || bad "pending-hits 없음" "exit=$code out=[$out]"

# 읽기 전용: state 는 원장을 바꾸지 않고 상태 파일도 만들지 않는다 (ADR-004)
lsreset; lscfg 2; lsblind 3
before=$(cat "$LSL"; ls "$LSD" | sort)
python3 "$LS" state r t >/dev/null 2>&1; python3 "$LS" pending-hits r t >/dev/null 2>&1; python3 "$LS" pending-gates r t >/dev/null 2>&1
after=$(cat "$LSL"; ls "$LSD" | sort)
[ "$before" = "$after" ] && ok "읽기 서브커맨드는 원장을 쓰지 않고 새 파일도 만들지 않음" || bad "읽기 전용" "원장·폴더가 바뀜"

# AC3 연속 값 — 기준 3 으로 on 경계를 본다
lsreset; lscfg 3; lsblind 2
lscheck "AC3 2건 이어짐(기준 3) → off" off "$(lsstate)"
lsblind 1
lscheck "AC3 3건째 닿음 → on" on "$(lsstate)"

lsreset; lscfg 3; lsblind 2; lse r t api true true true; lsblind 1
lscheck "AC3 why=true 줄에서 0 — 2 → why → 1 이면 off" off "$(lsstate)"
lsreset; lscfg 3; lsblind 2; lse r t api true false false; lsblind 1
lscheck "AC3 acc=false 줄은 연속을 끊음(2 → acc없음 → 1 이면 off)" off "$(lsstate)"
lsreset; lscfg 3; lsblind 2; lse r t api false false false; lsblind 2
lscheck "AC3 rec=false 줄은 연속을 끊음(2 → rec없음 → 2 이면 off)" off "$(lsstate)"

lsreset; lscfg 3; lsblind 2 r t; lsblind 1 r other
lscheck "AC3 (repo, task) 가 바뀌면 0 (task 변경)" off "$(lsstate)"
lsreset; lscfg 3; lsblind 2 r t; lsblind 1 r2 t
lscheck "AC3 (repo, task) 가 바뀌면 0 (repo 변경)" off "$(lsstate)"
lsreset; lscfg 3; lsblind 2 r t; lsblind 2 r other; lsblind 1 r t
lscheck "AC3 갔다 돌아와도 이어붙지 않음" off "$(lsstate)"

lsreset; lscfg 3; lsblind 2; lse r t null true true false; lsblind 1
lscheck "AC3 gate=null 줄은 세지도 끊지도 않음(2 → null → 1 = 3 → on)" on "$(lsstate)"
lsreset; lscfg 3; lsblind 2; lse r t null true true true; lsblind 1
lscheck "AC3 gate=null 줄은 why=true 여도 끊지 않음" on "$(lsstate)"
lsreset; lscfg 3; lsblind 2; lse r null api true true false; lsblind 1
lscheck "AC3 task=null 줄은 세지도 끊지도 않음(3건째 → on)" on "$(lsstate)"
lsreset; lscfg 3; lsblind 1; lse r null api true true false; lse r null api true true false; lsblind 1
lscheck "AC3 task=null 줄이 세어지지 않음(1 + null 2 + 1 = 2 → off)" off "$(lsstate)"

# 적중 줄은 건너뜀
lsreset; lscfg 3; lsblind 2; printf '{"ref":"t1","hit":"right","by":"model"}\n' >> "$LSL"; lsblind 1
lscheck "AC3 적중 줄은 건너뜀(끊지 않음)" on "$(lsstate)"

# AC4 켜짐 유지
lsreset; lscfg 2; lsblind 2; lse r t api true true true
lscheck "AC4 연속이 0 이 되어도 켜진 채 유지(why=true)" on "$(lsstate)"
lsreset; lscfg 2; lsblind 2; lse r t api false false false
lscheck "AC4 연속이 0 이 되어도 켜진 채 유지(rec=false)" on "$(lsstate)"
lsreset; lscfg 2; lsblind 2; lsblind 1 r other
lscheck "AC4 (repo, task) 가 바뀌어도 켜진 채 유지" on "$(lsstate)"

# AC5 꺼짐 조건
lsreset; lscfg 2; lsblind 2; lse r t api false false false true
lscheck "AC5 hyp 만 나오면 on 유지" on "$(lsstate)"
lsreset; lscfg 2; lsblind 2; lse r t api false false false false true
lscheck "AC5 rebut 만 나오면 on 유지" on "$(lsstate)"
lsreset; lscfg 2; lsblind 2; lse r t api false false false true; lse r t api false false false false true
lscheck "AC5 hyp → rebut 순서로 모이면 off" off "$(lsstate)"
lsreset; lscfg 2; lsblind 2; lse r t api false false false false true; lse r t api false false false true
lscheck "AC5 rebut → hyp 순서로 모여도 off(순서 무관)" off "$(lsstate)"
lsreset; lscfg 2; lsblind 2; lse r t api false false false true; lsblind 1; lse r t api false false false false true
lscheck "AC5 사이에 다른 줄이 끼어도 모이면 off" off "$(lsstate)"
lsreset; lscfg 2; lsblind 2; lse r t api false false false true; lse r other api false false false false true
lscheck "AC5 (repo, task) 가 바뀌면 모은 것을 버림 → on 유지" on "$(lsstate)"
lsreset; lscfg 2; lsblind 2; lse r t api false false false true; lse r other api false false false false true; lse r other api false false false true
lscheck "AC5 바뀐 쪽에서 새로 둘 다 모으면 off" off "$(lsstate)"
lsreset; lscfg 2; lsblind 2; lse r null api false false false true; lse r null api false false false false true
lscheck "AC5 task=null 줄만으로는 못 끔" on "$(lsstate)"
lsreset; lscfg 2; lse r t api false false false true; lse r t api false false false false true; lsblind 2
lscheck "AC5 켜지기 전에 나온 hyp·rebut 은 모으지 않음 → on" on "$(lsstate)"
lsreset; lscfg 2; lsblind 2; lse r t api false false false true; lse r t api false false false false true; lsblind 1
lscheck "AC5 꺼진 뒤 연속은 0 부터 다시(1건 → off)" off "$(lsstate)"
lsblind 1
lscheck "AC5 꺼진 뒤 다시 기준만큼 쌓이면 다시 on" on "$(lsstate)"

# AC6 설정 없음 / 값 이상 → 항상 off
lsreset; lsblind 10; rm -f "$CLAUDE_HYPOTHESIS_GATE_CONFIG"
lscheck "AC6 설정 파일 없음 → off(줄이 많아도)" off "$(lsstate)"
printf '{}' > "$CLAUDE_HYPOTHESIS_GATE_CONFIG"
lscheck "AC6 threshold 없음 → off" off "$(lsstate)"
printf 'garbage' > "$CLAUDE_HYPOTHESIS_GATE_CONFIG"
lscheck "AC6 설정 파일이 깨짐 → off" off "$(lsstate)"
for v in 0 -1 '"3"' null true 1.5; do
  printf '{"threshold": %s}' "$v" > "$CLAUDE_HYPOTHESIS_GATE_CONFIG"
  lscheck "AC6 threshold=$v → off" off "$(lsstate)"
done
# 설정은 실행할 때마다 읽는다: 값을 바꾸면 과거도 새 기준으로
lsreset; lsblind 3; lscfg 5
lscheck "기준 5 → 3건은 off" off "$(lsstate)"
lscfg 3
lscheck "기준을 3 으로 바꾸면 같은 원장이 on" on "$(lsstate)"

# AC16 보정 줄
lsreset; lscfg 3; lsblind 2; lse r t null true true false
printf '{"ref":"t3","gate":"api","by":"finn"}\n' >> "$LSL"
lscheck "AC16 null → 값 보정: 연속에 합류(2 + 보정 1 = 3 → on)" on "$(lsstate)"
lsreset; lscfg 3; lsblind 3; printf '{"ref":"t2","gate":null,"by":"finn"}\n' >> "$LSL"
lscheck "AC16 값 → null 보정: 연속에서 빠짐(3 - 1 = 2 → off)" off "$(lsstate)"
lsreset; lscfg 3; lsblind 3; printf '{"ref":"t2","gate":null,"by":"finn"}\n{"ref":"t2","gate":"error","by":"finn"}\n' >> "$LSL"
lscheck "AC16 같은 ref 가 여러 번이면 마지막 보정이 유효(null → error 로 돌아옴 → on)" on "$(lsstate)"
lsreset; lscfg 3; lsblind 3; printf '{"ref":"t2","gate":"error","by":"finn"}\n{"ref":"t2","gate":null,"by":"finn"}\n' >> "$LSL"
lscheck "AC16 마지막 보정이 null 이면 빠짐" off "$(lsstate)"
lsreset; lscfg 3; lsblind 2; lse r t null true true false; printf '{"ref":"t3","gate":"api","by":"finn"}\n' >> "$LSL"
lse r t api false false false
lscheck "AC16 보정은 과거를 다시 셈 — 보정이 원장 끝에 있어도 앞 줄에 적용(켜짐 유지)" on "$(lsstate)"
lsreset; lscfg 3; lsblind 2; lse r t null true true true; printf '{"ref":"t3","gate":"api","by":"finn"}\n' >> "$LSL"
lscheck "AC16 보정으로 값이 된 줄의 why=true 는 연속을 끊음(2 → 0 → off)" off "$(lsstate)"

# AC13 pending-hits
lsreset
lse r t api true true false true    # t1 hyp
lse r t api true true false false   # t2 hyp 아님
lse r t api true true false true    # t3 hyp
lse r other api true true false true  # t4 다른 작업
lse r2 t api true true false true   # t5 다른 repo
printf '{"ref":"t1","hit":"right","by":"model"}\n' >> "$LSL"
lscheck "AC13 pending-hits: hyp 참 · 유효한 적중 없는 줄만, 같은 (repo, task) 만" "t3" "$(python3 "$LS" pending-hits r t 2>/dev/null)"
printf '{"ref":"t3","hit":"wrong","by":"finn"}\n' >> "$LSL"
out=$(python3 "$LS" pending-hits r t 2>&1); code=$?
[ "$code" = "0" ] && [ -z "$out" ] && ok "AC13 모두 판정되면 빈 출력 · exit 0" || bad "pending-hits 비움" "exit=$code out=[$out]"
lscheck "AC13 다른 (repo, task) 는 따로 셈" "t4" "$(python3 "$LS" pending-hits r other 2>/dev/null)"
lsreset; lse r t api true true false true; lse r t api true true false true
lscheck "AC13 여러 건은 한 줄에 ts 하나, 원장 순서" "$(printf 't1\nt2')" "$(python3 "$LS" pending-hits r t 2>/dev/null)"

# pending-gates (AC17 의 CLI 쪽)
lsreset
lse r t null true true false   # t1 null
lse r t api true true false    # t2
lse r t null true true false   # t3 null
lse r other null true true false  # t4 다른 작업
printf '{"ref":"t1","gate":"api","by":"finn"}\n' >> "$LSL"
lscheck "AC17 pending-gates: 유효한 gate 가 null 인 줄만(보정된 t1 은 제외)" "t3" "$(python3 "$LS" pending-gates r t 2>/dev/null)"
printf '{"ref":"t2","gate":null,"by":"finn"}\n' >> "$LSL"
lscheck "AC17 값 → null 로 보정된 줄은 대상에 들어옴" "$(printf 't2\nt3')" "$(python3 "$LS" pending-gates r t 2>/dev/null)"
out=$(python3 "$LS" pending-gates r none 2>&1); code=$?
[ "$code" = "0" ] && [ -z "$out" ] && ok "AC17 대상 없으면 빈 출력 · exit 0" || bad "pending-gates 비움" "exit=$code out=[$out]"

lsreset; rm -f "$CLAUDE_HYPOTHESIS_GATE_CONFIG"; unset CLAUDE_HYPOTHESIS_GATE_CONFIG
