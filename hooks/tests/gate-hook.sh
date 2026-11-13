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
if printf '%s' "$out" | grep -qE 'ledger.py"? append'; then ok "판정 지시에 ledger.py append 안내"; else bad "append 안내" "[$out]"; fi
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

# task 고르기(step 8): 미완료 phase 가 여럿이면 브랜치와 맞는 것, 맞는 게 없으면 null
export CLAUDE_HYPOTHESIS_LEDGER="$GHL"
export CLAUDE_HYPOTHESIS_GATE_CONFIG="$GHD/gate.json"
mkdir -p "$GHD/repo2/phases/aaa" "$GHD/repo2/phases/bbb"
(cd "$GHD/repo2" && git init -q)
printf '{"phase":"aaa","steps":[{"step":1,"status":"pending"}]}' > "$GHD/repo2/phases/aaa/index.json"
printf '{"phase":"bbb","steps":[{"step":1,"status":"pending"}]}' > "$GHD/repo2/phases/bbb/index.json"
ghrun2() { (cd "$GHD/repo2" && printf '{"prompt":"x"}' | bash "$GH" 2>&1); }
(cd "$GHD/repo2" && git symbolic-ref HEAD refs/heads/feat-bbb)
out=$(ghrun2)
if printf '%s' "$out" | grep -q 'task=bbb '; then ok "phase 둘 + 브랜치 feat-bbb 면 task=bbb"; else bad "task=bbb" "[$out]"; fi
(cd "$GHD/repo2" && git symbolic-ref HEAD refs/heads/feat/aaa)
out=$(ghrun2)
if printf '%s' "$out" | grep -q 'task=aaa '; then ok "브랜치 마지막 / 뒤 부분으로 맞춘다(feat/aaa)"; else bad "task=aaa" "[$out]"; fi
(cd "$GHD/repo2" && git symbolic-ref HEAD refs/heads/main)
out=$(ghrun2)
if printf '%s' "$out" | grep -q 'task=null '; then ok "phase 둘 + 맞는 브랜치 없음이면 task=null"; else bad "task=null(모호)" "[$out]"; fi
(cd "$GHD/repo2" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init && git checkout -q --detach)
if (cd "$GHD/repo2" && ! git symbolic-ref -q HEAD >/dev/null 2>&1); then ok "repo2 가 실제 detached HEAD 상태"; else bad "detached 준비" "HEAD 가 안 떼어짐"; fi
out=$(ghrun2); code=$?
if [ "$code" = "0" ] && printf '%s' "$out" | grep -q '\[판정 지시\]'; then ok "브랜치를 못 구해도 exit 0"; else bad "브랜치 없음" "exit=$code out=[$out]"; fi
printf '{"phase":"aaa","steps":[{"step":1,"status":"completed"}]}' > "$GHD/repo2/phases/aaa/index.json"
(cd "$GHD/repo2" && git symbolic-ref HEAD refs/heads/feat-zzz)
out=$(ghrun2)
if printf '%s' "$out" | grep -q 'task=bbb '; then ok "미완료 phase 가 하나면 브랜치와 무관하게 그 이름"; else bad "단일 후보" "[$out]"; fi
printf '{"phase":"bbb","steps":[{"step":1,"status":"completed"}]}' > "$GHD/repo2/phases/bbb/index.json"
out=$(ghrun2)
if printf '%s' "$out" | grep -q 'task=null '; then ok "후보가 없으면 task=null"; else bad "후보 없음" "[$out]"; fi

# 경로 따옴표(step 8): HOOKS 경로에 공백이 있어도 주입 문구의 ledger.py 경로가 따옴표로 감싸진다
SP="$GHD/with space/hooks"
mkdir -p "$SP/lib"
cp "$GH" "$SP/hypothesis-gate.sh"; cp "$HOOKS/lib/ledger.py" "$SP/lib/ledger.py"
out=$(cd "$GHD/repo1" && printf '{}' | bash "$SP/hypothesis-gate.sh" 2>&1)
if printf '%s' "$out" | grep -qF 'python3 "'"$SP"'/lib/ledger.py" append'; then ok "공백 경로의 ledger.py 가 따옴표로 감싸진다"; else bad "경로 따옴표" "[$out]"; fi
unset CLAUDE_HYPOTHESIS_LEDGER CLAUDE_HYPOTHESIS_GATE_CONFIG

# 주입 문구(step 9): diff 칸 예시와 정의
out=$(cd "$GHD/repo1" && printf '{}' | bash "$GH" 2>&1)
if printf '%s' "$out" | grep -qF 'gate=<schema|api|error|delete|security|null> diff=<easy|mid|hard|null> area='; then ok "주입 문구에 diff=<easy|mid|hard|null> 가 gate 다음"; else bad "diff 예시" "[$out]"; fi
if printf '%s' "$out" | grep -qF 'diff: 가설을 맞히기 어려운 정도. 범위(여러 레이어에 걸침)·되돌리기 어려움(마이그레이션·삭제·공개 API 계약)·선례 없음(레포에 같은 패턴이 없음) 중 하나라도 해당하면 hard, 하나도 해당하지 않으면 easy, 해당 여부가 애매하면 mid, hyp=false 면 null.'; then ok "주입 문구에 diff 정의 문장"; else bad "diff 정의" "[$out]"; fi
