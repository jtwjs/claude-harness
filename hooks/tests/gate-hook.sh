# 가설 게이트 훅(hooks/hypothesis-gate.sh, UserPromptSubmit) — AC1·AC2·AC7. test.sh 가 source 한다.
printf '\n[gate-hook] UserPromptSubmit 훅 · 판정 지시 · 가설 요구\n'
GH="$HOOKS/hypothesis-gate.sh"
GHD="$TMP/gh"; rm -rf "$GHD"; mkdir -p "$GHD/repo1"
(cd "$GHD/repo1" && git init -q)
GHL="$GHD/ledger.jsonl"
export CLAUDE_HYPOTHESIS_LEDGER="$GHL"
export CLAUDE_HYPOTHESIS_GATE_CONFIG="$GHD/gate.json"
ghrun() { (cd "$GHD/repo1" && printf '{"prompt":"x"}' | bash "$GH" 2>&1); }
ghblind() { # 이유 없는 수락 줄 n 개 (repo1, task null 아닌 t)
  local i
  for i in $(seq "$1"); do
    printf '{"ts":"g%s","repo":"repo1","task":"t","gate":"api","area":"BE","hyp":false,"rec":true,"acc":true,"why":false,"rebut":false,"skip":false}\n' "$i" >> "$GHL"
  done
}

# AC1: hooks.json 에 UserPromptSubmit 이 있고 이 훅을 부른다
if python3 - "$HOOKS/hooks.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))["hooks"]
cmds = [h["command"] for g in d.get("UserPromptSubmit", []) for h in g["hooks"]]
sys.exit(0 if any("hypothesis-gate.sh" in c for c in cmds) else 1)
PY
then ok "AC1 hooks.json 에 UserPromptSubmit → hypothesis-gate.sh"; else bad "AC1" "UserPromptSubmit 등록 없음"; fi

# 상태 off(원장 없음·설정 없음): 판정 지시만, 가설 요구 문구 없음
rm -f "$GHL" "$CLAUDE_HYPOTHESIS_GATE_CONFIG"
out=$(ghrun); code=$?
if [ "$code" = "0" ] && printf '%s' "$out" | grep -q '\[판정 지시\]'; then ok "판정 지시가 항상 나간다(원장 없음)"; else bad "판정 지시" "exit=$code out=[$out]"; fi
if printf '%s' "$out" | grep -q 'ledger.py append'; then ok "판정 지시에 ledger.py append 안내"; else bad "append 안내" "[$out]"; fi
if printf '%s' "$out" | grep -q '\[가설 요구\]'; then bad "AC7 off" "가설 요구가 나감"; else ok "AC7 off 면 가설 요구 문구 없음"; fi

# AC6: 설정 없이 연속이 길어도 off
ghblind 5
out=$(ghrun)
if printf '%s' "$out" | grep -q '\[가설 요구\]'; then bad "AC6 설정 없음" "가설 요구가 나감"; else ok "AC6 설정 없으면 가설 요구 없음"; fi

# AC7 on: 기준 횟수에 닿으면 가설 요구 한 줄 + 판정 지시
printf '{"threshold": 3}' > "$CLAUDE_HYPOTHESIS_GATE_CONFIG"
out=$(ghrun); code=$?
n=$(printf '%s\n' "$out" | grep -c '\[가설 요구\]')
if [ "$code" = "0" ] && [ "$n" = "1" ] && printf '%s' "$out" | grep -q '\[판정 지시\]'; then ok "AC7 on 이면 가설 요구 한 줄(+판정 지시)"; else bad "AC7 on" "exit=$code n=$n out=[$out]"; fi

# 아직 안 닿음: off
rm -f "$GHL"; ghblind 2
out=$(ghrun)
if printf '%s' "$out" | grep -q '\[가설 요구\]'; then bad "미달" "가설 요구가 나감"; else ok "기준 미달이면 가설 요구 없음"; fi

# AC2: 깨진 줄이 섞여도 exit 0 + 판정 지시
printf 'not json\n{"broken\n' >> "$GHL"
out=$(ghrun); code=$?
if [ "$code" = "0" ] && printf '%s' "$out" | grep -q '\[판정 지시\]'; then ok "AC2 깨진 줄이 섞여도 exit 0"; else bad "AC2 깨진 줄" "exit=$code out=[$out]"; fi
# 원장이 디렉터리여도 exit 0
rm -rf "$GHL"; mkdir -p "$GHL"
out=$(ghrun); code=$?
[ "$code" = "0" ] && ok "AC2 원장 경로가 디렉터리여도 exit 0" || bad "AC2 디렉터리" "exit=$code out=[$out]"
rmdir "$GHL" 2>/dev/null
# git 레포가 아닌 곳에서도 exit 0
mkdir -p "$GHD/plain"
out=$(cd "$GHD/plain" && printf '{}' | bash "$GH" 2>&1); code=$?
if [ "$code" = "0" ] && printf '%s' "$out" | grep -q '\[판정 지시\]'; then ok "git 밖에서도 exit 0 · 판정 지시"; else bad "git 밖" "exit=$code out=[$out]"; fi

# 훅은 원장에 쓰지 않는다
rm -f "$GHL"; printf '{"threshold": 1}' > "$CLAUDE_HYPOTHESIS_GATE_CONFIG"
ghrun >/dev/null
[ ! -e "$GHL" ] && ok "훅은 원장을 만들지 않는다" || bad "원장 쓰기" "훅이 원장을 만듦"

# task: 활성 phase(미완료 step 이 있는 phases/*)가 있으면 그 이름, 없으면 null
mkdir -p "$GHD/repo1/phases/p1"
printf '{"phase":"p1","steps":[{"step":1,"status":"completed"},{"step":2,"status":"pending"}]}' > "$GHD/repo1/phases/p1/index.json"
out=$(ghrun)
if printf '%s' "$out" | grep -q 'task=p1'; then ok "활성 phase 이름이 task 로 안내된다"; else bad "task=p1" "[$out]"; fi
printf '{"phase":"p1","steps":[{"step":1,"status":"completed"}]}' > "$GHD/repo1/phases/p1/index.json"
out=$(ghrun)
if printf '%s' "$out" | grep -q 'task=null'; then ok "활성 phase 가 없으면 task=null"; else bad "task=null" "[$out]"; fi
unset CLAUDE_HYPOTHESIS_LEDGER CLAUDE_HYPOTHESIS_GATE_CONFIG
