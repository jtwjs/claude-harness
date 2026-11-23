# harness-gaps gaps.py config · gather — PRD AC1(config)·AC2·AC3·AC4·AC5. test.sh 가 source 한다.
printf '\n[harness-gaps-gather] config · gather\n'
OBS="$HOOKS/../skills/harness-gaps/scripts/gaps.py"
TOG="$TMP/tog"
rm -rf "$TOG"; mkdir -p "$TOG"
export CLAUDE_HARNESS_GAPS_CONFIG="$TOG/harness-gaps.json"
export CLAUDE_HARNESS_GAPS_PROJECTS="$TOG/projects"
export HARNESS_GAPS_NOW="2026-11-23T12:00:00+09:00"

# ── config (AC1 일부) ──
out=$(python3 "$OBS" config 2>&1); code=$?
[ "$code" = "0" ] && [ -z "$out" ] && ok "config: 설정 파일 없음 → 빈 출력 exit 0" || bad "config 없음" "exit=$code out=[$out]"
printf '{not json' > "$CLAUDE_HARNESS_GAPS_CONFIG"
out=$(python3 "$OBS" config 2>&1); code=$?
[ "$code" = "0" ] && [ -z "$out" ] && ok "config: 깨진 JSON → 빈 출력 exit 0" || bad "config 깨짐" "exit=$code out=[$out]"
printf '{"other": 1}' > "$CLAUDE_HARNESS_GAPS_CONFIG"
out=$(python3 "$OBS" config 2>&1); code=$?
[ "$code" = "0" ] && [ -z "$out" ] && ok "config: ledger 칸 없음 → 빈 출력 exit 0" || bad "config 칸 없음" "exit=$code out=[$out]"
printf '{"ledger": "~/fake-vault/ledger/index.md"}' > "$CLAUDE_HARNESS_GAPS_CONFIG"
out=$(python3 "$OBS" config 2>&1); code=$?
[ "$code" = "0" ] && [ "$out" = "$HOME/fake-vault/ledger/index.md" ] && ok "config: ledger 경로 ~ 펼쳐 한 줄" || bad "config 경로" "exit=$code out=[$out]"
out=$(cd "$HOOKS/../skills/harness-gaps/scripts" && python3 -c 'import gaps; p=gaps.ledger_path(); print(p)' 2>&1)
[ "$out" = "$HOME/fake-vault/ledger/index.md" ] && ok "config: ledger_path() 함수로 import 가능" || bad "ledger_path import" "$out"
rm -f "$CLAUDE_HARNESS_GAPS_CONFIG"

# ── gather 픽스처: 레포 A(main + worktree) · 레포 B · git 아닌 폴더 · 없는 경로 ──
gq() { git -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
mkdir -p "$TOG/repoA" "$TOG/repoB" "$TOG/plain"
(cd "$TOG/repoA" && gq init -q && gq commit -q --allow-empty -m init && gq worktree add -q "$TOG/repoA-wt" -b wt)
(cd "$TOG/repoB" && gq init -q && gq commit -q --allow-empty -m init)

# observations — repoA main: 범위 칸 있는 표(전역 후보 창 안 · 창 밖 · 레포 고유), repoA worktree: 전역 후보 한 행, repoB: 범위 칸 없는 옛 표
mkdir -p "$TOG/repoA/.claude" "$TOG/repoA-wt/.claude" "$TOG/repoB/.claude"
cat > "$TOG/repoA/.claude/observations.md" <<'EOF'
## 열린 것
| 패턴 | 종류 | 횟수 | 마지막 | 범위 | 근거 |
|---|---|---|---|---|---|
| 전역창안패턴 | 재지시 | 2 | 2026-11-20 | 전역 후보 | #1 |
| 전역창밖패턴 | 재교정 | 1 | 2026-10-01 | 전역 후보 | #2 |
| 고유패턴 | 재지시 | 3 | 2026-11-21 | 레포 고유 | #3 |

## 닫힌 것
| 패턴 | 횟수 | 판정 | 어디로 |
|---|---|---|---|
| 닫힌패턴 | 3 | 버림 | - |
EOF
cat > "$TOG/repoA-wt/.claude/observations.md" <<'EOF'
## 열린 것
| 패턴 | 종류 | 횟수 | 마지막 | 범위 | 근거 |
|---|---|---|---|---|---|
| 워크트리전역패턴 | 반복 절차 | 1 | 2026-11-22 | 전역 후보 | #9 |
EOF
cat > "$TOG/repoB/.claude/observations.md" <<'EOF'
## 열린 것
| 패턴 | 종류 | 횟수 | 마지막 | 근거 |
|---|---|---|---|---|
| 옛표패턴 | 재지시 | 2 | 2026-11-22 | #4 |
EOF

# phases — repoA: blocked 1 · retries 3 1 · retries 2(제외) · completed(제외), repoB: 없음
mkdir -p "$TOG/repoA/phases/ph1"
cat > "$TOG/repoA/phases/ph1/index.json" <<'EOF'
{"phase": "ph1", "steps": [
  {"step": 1, "name": "s-done", "status": "completed"},
  {"step": 2, "name": "s-blocked", "status": "blocked", "blocked_reason": "API 키 필요"},
  {"step": 3, "name": "s-retry3", "status": "error", "retries": 3, "error_message": "테스트 실패 반복"},
  {"step": 4, "name": "s-retry2", "status": "error", "retries": 2, "error_message": "x"}
]}
EOF

# 대화 기록
mkdir -p "$CLAUDE_HARNESS_GAPS_PROJECTS/p1" "$CLAUDE_HARNESS_GAPS_PROJECTS/p2"
LONG=$(python3 -c 'print("가"*600)')
python3 - "$TOG" "$LONG" > "$CLAUDE_HARNESS_GAPS_PROJECTS/p1/s1.jsonl" <<'PY'
import json, sys
tog, long = sys.argv[1], sys.argv[2]
def u(cwd, ts, content, **kw):
    d = {"type": "user", "cwd": cwd, "timestamp": ts, "message": {"role": "user", "content": content}}
    d.update(kw); return json.dumps(d, ensure_ascii=False)
def a(cwd, ts, cmd):
    return json.dumps({"type": "assistant", "cwd": cwd, "timestamp": ts,
        "message": {"role": "assistant", "content": [{"type": "tool_use", "name": "Bash", "input": {"command": cmd}}]}})
A, W, B = tog + "/repoA", tog + "/repoA-wt", tog + "/repoB"
lines = [
    u(A, "2026-11-20T01:00:00.000Z", "A메인말"),
    u(W, "2026-11-21T01:00:00.000Z", [{"type": "text", "text": "A워크트리말"}]),
    u(A, "2026-11-21T02:00:00.000Z", [{"type": "tool_result", "content": "툴결과말"}]),
    u(A, "2026-11-21T03:00:00.000Z", "<command-name>/clear</command-name>"),
    u(A, "2026-11-21T04:00:00.000Z", long),
    u(A, "2026-11-01T01:00:00.000Z", "창밖말"),
    a(A, "2026-11-21T05:00:00.000Z", "git status\necho 두번째줄"),
    a(W, "2026-11-21T06:00:00.000Z", "x" * 500),
    u(B, "2026-11-22T01:00:00.000Z", "B말"),
    u(tog + "/plain", "2026-11-22T01:00:00.000Z", "플레인말"),
    u(tog + "/nowhere", "2026-11-22T01:00:00.000Z", "없는경로말"),
    "{broken json line",
    json.dumps({"type": "user", "timestamp": "2026-11-22T01:00:00Z", "message": {"content": "cwd없음"}}),
    json.dumps({"type": "user", "cwd": A, "timestamp": "not-a-date", "message": {"content": "날짜깨짐"}}),
    json.dumps([1, 2, 3]),
]
print("\n".join(lines))
PY
printf 'garbage\n' > "$CLAUDE_HARNESS_GAPS_PROJECTS/p2/s2.jsonl"

G="$TOG/gather.json"
python3 "$OBS" gather --days 7 > "$G" 2>"$TOG/gather.err"; code=$?
[ "$code" = "0" ] && ! grep -q Traceback "$TOG/gather.err" && ok "gather: 깨진 줄 · 없는 cwd · git 아닌 cwd 에도 traceback 없이 exit 0" || bad "gather exit" "exit=$code err=$(cat "$TOG/gather.err")"

tog_py() { # $1=이름  $2=파이썬 단언(변수 d=JSON, R=레포 dict)
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
R = {r["name"]: r for r in d["repos"]}
exec(sys.argv[2])
' "$G" "$2" 2>"$TOG/assert.err" && ok "$1" || bad "$1" "$(tail -n1 "$TOG/assert.err")"
}
tog_py "gather: 레포 2개(A main+worktree 합침 · B), git 아닌 폴더 제외 · 이름 순" \
  'assert [r["name"] for r in d["repos"]] == ["repoA", "repoB"], [r["name"] for r in d["repos"]]'
tog_py "gather: worktree 의 말도 같은 레포 A 로" 'assert "A워크트리말" in R["repoA"]["user"], R["repoA"]["user"]'
tog_py "gather: 창 밖 줄 제외" 'assert "창밖말" not in json.dumps(d, ensure_ascii=False)'
tog_py "gather: tool_result 제외" 'assert "툴결과말" not in json.dumps(d, ensure_ascii=False)'
tog_py "gather: < 로 시작하는 사람 말 제외" 'assert not any(x.startswith("<") for x in R["repoA"]["user"]), R["repoA"]["user"]'
tog_py "gather: git 아닌 cwd 말은 재료에 없음" 'assert "플레인말" not in json.dumps(d, ensure_ascii=False) and "없는경로말" not in json.dumps(d, ensure_ascii=False)'
tog_py "gather: 사람 말 한 줄 400자로 자름(AC5)" 'assert max(len(x) for x in R["repoA"]["user"]) == 400, [len(x) for x in R["repoA"]["user"]]'
tog_py "gather: Bash 는 첫 줄만 · 200자로 자름(AC5)" \
  'assert "git status" in R["repoA"]["bash"] and not any("두번째줄" in x for x in R["repoA"]["bash"]) and max(len(x) for x in R["repoA"]["bash"]) == 200, R["repoA"]["bash"]'
tog_py "gather: sessions 는 창 안 날짜" 'assert "2026-11-20" in R["repoA"]["sessions"] and "2026-11-01" not in R["repoA"]["sessions"], R["repoA"]["sessions"]'
tog_py "gather: 미위임은 blocked · retries 3 만(AC3)" \
  'u = R["repoA"]["undelegated"]; assert sorted(x["name"] for x in u) == ["s-blocked", "s-retry3"], u; assert all(x["phase"] == "ph1" for x in u); assert any(x["reason"] == "API 키 필요" for x in u) and any(x["reason"] == "테스트 실패 반복" for x in u), u'
tog_py "gather: 미위임 0 이면 빈 배열" 'assert R["repoB"]["undelegated"] == [], R["repoB"]["undelegated"]'
tog_py "gather: observations 는 전역 후보 · 창 안 행만(AC4, worktree 포함)" \
  's = json.dumps(R["repoA"]["observations"], ensure_ascii=False); assert "전역창안패턴" in s and "워크트리전역패턴" in s and "전역창밖패턴" not in s and "고유패턴" not in s and "닫힌패턴" not in s, s'
tog_py "gather: 범위 칸 없는 옛 표는 행 0" 'assert R["repoB"]["observations"] == [], R["repoB"]["observations"]'

# 레포당 상한(AC5): 사람 말 150개
python3 - "$TOG" > "$CLAUDE_HARNESS_GAPS_PROJECTS/p2/s3.jsonl" <<'PY'
import json, sys
for i in range(200):
    print(json.dumps({"type": "user", "cwd": sys.argv[1] + "/repoB", "timestamp": "2026-11-22T02:%02d:%02dZ" % (i // 60, i % 60), "message": {"content": "많은말%d" % i}}, ensure_ascii=False))
PY
python3 "$OBS" gather --days 7 > "$G" 2>/dev/null
tog_py "gather: 사람 말 레포당 최근 150개(AC5)" 'u = R["repoB"]["user"]; assert len(u) == 150 and "많은말199" in u and "많은말0" not in u, len(u)'

# gather 는 아무 파일도 쓰지 않는다
before=$(cd "$TOG" && find . -type f -not -name gather.json -not -name gather.err -not -name assert.err | LC_ALL=C sort | xargs cksum 2>/dev/null | cksum)
python3 "$OBS" gather --days 7 >/dev/null 2>&1
after=$(cd "$TOG" && find . -type f -not -name gather.json -not -name gather.err -not -name assert.err | LC_ALL=C sort | xargs cksum 2>/dev/null | cksum)
[ "$before" = "$after" ] && ok "gather: 픽스처 폴더에 아무 파일도 쓰지 않음" || bad "gather 쓰기" "파일이 바뀜"

unset CLAUDE_HARNESS_GAPS_CONFIG CLAUDE_HARNESS_GAPS_PROJECTS HARNESS_GAPS_NOW
