# task-observer observer.py append — PRD AC1·AC6·AC7·AC8·AC9·AC10. test.sh 가 source 한다.
printf '\n[task-observer-append] append\n'
OBS="$HOOKS/../skills/task-observer/scripts/observer.py"
TOA="$TMP/toa"
rm -rf "$TOA"; mkdir -p "$TOA"
export CLAUDE_TASK_OBSERVER_CONFIG="$TOA/task-observer.json"
export CLAUDE_TASK_OBSERVER_PROJECTS="$TOA/projects"
export TASK_OBSERVER_NOW="2026-11-23T12:00:00+09:00"

# 가짜 볼트: .obsidian 이 있는 조상 + 원장 폴더
mkdir -p "$TOA/vault/.obsidian" "$TOA/vault/notes/ledger"
LED="$TOA/vault/notes/ledger/index.md"
MON="$TOA/vault/notes/ledger/2026-11.md"
cat > "$LED" <<'EOF'
---
type: brain-note
---
# 불편 원장

머리 문단.

| ID | 패턴 | 유형 | 대상 | 프로젝트 | 횟수 | 처음 | 마지막 | 방향 | 상태 | 연결 |
|---|---|---|---|---|---|---|---|---|---|---|
| F-003 | 옛 패턴 | 재지시 | 레포(x) | ⚠️ | 1 | 2026-10-01 | 2026-10-01 | direct | 열림 | [[2026-10]] |
| F-004 | 옛 패턴2 | 불발 | 레포(y) | ⚠️ | 2 | 2026-10-02 | 2026-10-03 | plan | 버림 | [[2026-10]] |

표 아래 문단 — 바이트 그대로.
EOF
cp "$LED" "$TOA/ledger.orig"

# 후보: 유효 2(첫째는 칸 안 | 포함) · 거부 5
CAND="$TOA/cand.json"
python3 - > "$CAND" <<'PY'
import json
ok1 = {"pattern": "a|b 를 매번 다시 말함", "kind": "재지시", "repos": ["repoA", "repoB"], "count": 3,
       "first": "2026-11-18", "last": "2026-11-22", "direction": "direct",
       "evidence": ["repoA 2026-11-18", "repoB 2026-11-22"]}
ok2 = {"pattern": "같은 배포 절차 반복", "kind": "반복 절차", "repos": ["repoB", "repoC"],
       "direction": "plan", "evidence": ["repoC phases/ph1"]}
bad = [
    dict(ok1, pattern="유형밖", kind="잡담"),
    dict(ok1, pattern="한레포", repos=["repoA"]),
    dict(ok1, pattern="같은레포두번", repos=["repoA", "repoA"]),
    dict(ok1, pattern="방향밖", direction="someday"),
    dict(ok1, pattern="여러\n줄"),
]
print(json.dumps([ok1] + bad + [ok2], ensure_ascii=False))
PY

toa_same() { cmp -s "$1" "$2"; }

# ── AC1 설정 없음 → 무쓰기 exit 0 ──
rm -f "$CLAUDE_TASK_OBSERVER_CONFIG"
out=$(python3 "$OBS" append "$CAND" 2>/dev/null); code=$?
[ "$code" = "0" ] && printf '%s' "$out" | grep -q '원장 설정 없음' && toa_same "$LED" "$TOA/ledger.orig" && [ ! -e "$MON" ] \
  && ok "append: 설정 없음 → '원장 설정 없음' · 무쓰기 · exit 0" || bad "설정 없음" "exit=$code out=[$out]"

# ── AC10 --dry-run 설정 없음 → F-001 부터 stdout ──
out=$(python3 "$OBS" append --dry-run "$CAND" 2>/dev/null); code=$?
[ "$code" = "0" ] && printf '%s' "$out" | grep -q '| F-001 |' && [ ! -e "$MON" ] \
  && ok "append --dry-run: 설정 없어도 돌고 F-001 부터" || bad "dry-run 설정 없음" "exit=$code out=[$out]"

printf '{"ledger": "%s"}' "$LED" > "$CLAUDE_TASK_OBSERVER_CONFIG"

# ── AC10 --dry-run → 둘 다 무변경 · stdout 에 행 ──
out=$(python3 "$OBS" append --dry-run "$CAND" 2>/dev/null); code=$?
[ "$code" = "0" ] && printf '%s' "$out" | grep -q '| F-005 |' && printf '%s' "$out" | grep -q '| F-006 |' \
  && printf '%s' "$out" | grep -q '→ F-005' && toa_same "$LED" "$TOA/ledger.orig" && [ ! -e "$MON" ] \
  && ok "append --dry-run: 원장 · 월별 무변경 · stdout 에 행과 항목" || bad "dry-run" "exit=$code out=[$out]"

# ── 실제 쓰기 ──
python3 "$OBS" append "$CAND" >"$TOA/out" 2>"$TOA/err"; code=$?
[ "$code" = "0" ] && ok "append: exit 0" || bad "append exit" "exit=$code err=$(cat "$TOA/err")"
nerr=$(grep -c . "$TOA/err" | tr -d ' ')
[ "$nerr" = "5" ] && ! grep -q Traceback "$TOA/err" && ok "append: 어긋난 후보 5개 각각 stderr 한 줄(AC6)" || bad "stderr" "줄=$nerr $(cat "$TOA/err")"

toa_py() { # $1=이름  $2=파이썬 단언(L=원장 텍스트, O=원래 원장, M=월별 텍스트 또는 None, rows=새 행 칸 목록)
  python3 -c '
import re, sys, os
L = open(sys.argv[1], encoding="utf-8").read()
O = open(sys.argv[2], encoding="utf-8").read()
M = open(sys.argv[3], encoding="utf-8").read() if os.path.exists(sys.argv[3]) else None
def cells(line):
    s = line.strip()[1:-1]
    return [c.strip() for c in re.split(r"(?<!\\)\|", s)]
rows = [cells(l) for l in L.splitlines() if re.match(r"^\| F-\d+ \|", l) and l not in O.splitlines()]
exec(sys.argv[4])
' "$LED" "$TOA/ledger.orig" "$MON" "$2" 2>"$TOA/assert.err" && ok "$1" || bad "$1" "$(tail -n1 "$TOA/assert.err")"
}
toa_py "append: 유효 2개만 씀 · 거부된 패턴 없음(AC6)" \
  'assert len(rows) == 2, rows; s = L; assert all(x not in s for x in ["유형밖", "한레포", "같은레포두번", "방향밖", "여러"]), s'
toa_py "append: F-004 다음 F-005 · F-006 순서(AC7)" 'assert [r[0] for r in rows] == ["F-005", "F-006"], rows'
toa_py "append: 11칸 · 상태 후보(AC8)" 'assert len(rows) == 2 and all(len(r) == 11 and r[9] == "후보" for r in rows), rows'
toa_py "append: 칸 안 | 이스케이프(AC8)" 'assert rows[0][1] == "a\\|b 를 매번 다시 말함", rows[0]'
toa_py "append: 대상 레포(a, b) · 프로젝트 ⚠️ · 방향" \
  'assert rows[0][2] == "재지시" and rows[0][3] == "레포(repoA, repoB)" and rows[0][4] == "⚠️" and rows[0][8] == "direct", rows[0]'
toa_py "append: count 없으면 레포 수 · 날짜 없으면 실행 날짜" \
  'assert rows[0][5:8] == ["3", "2026-11-18", "2026-11-22"], rows[0]; assert rows[1][5:8] == ["2", "2026-11-23", "2026-11-23"], rows[1]'
toa_py "append: .obsidian 조상 기준 상대 경로 링크" 'assert rows[0][10] == "[[notes/ledger/2026-11\\|2026-11]]", rows[0][10]'
toa_py "append: 표 마지막 행 바로 뒤 삽입 · 기존 바이트 그대로(AC8)" '
anchor = O.index("| F-004 |"); cut = O.index("\n", anchor) + 1
assert L.startswith(O[:cut]), "앞부분 바뀜"
assert L.endswith(O[cut:]), "뒷부분 바뀜"
mid = L[cut:len(L) - len(O[cut:])]
assert mid.count("\n") == 2 and mid.startswith("| F-005 |") and "| F-006 |" in mid, repr(mid)'
toa_py "append: 월별 파일 frontmatter 와 생성(AC9)" '
assert M is not None
assert M.startswith("---\n") and "type: brain-note" in M and "kind/friction" in M and "# 불편 원문 2026-11" in M, M'
toa_py "append: 월별 항목 — 제목 · 근거 · 칸(AC9)" '
assert "## 2026-11-23 · a|b 를 매번 다시 말함 → F-005" in M, M
assert "## 2026-11-23 · 같은 배포 절차 반복 → F-006" in M, M
assert "> 근거(task-observer 헤드리스): repoA 2026-11-18 · repoB 2026-11-22" in M, M
assert "- 유형: 반복 절차" in M and "- 대상: 레포(repoB, repoC)" in M and "- 방향: plan" in M and "- 비용: ⚠️" in M, M
assert M.index("→ F-005") < M.index("→ F-006")'

# ── 월별 파일 있으면 맨 아래 append · 다음 ID F-007 ──
cp "$MON" "$TOA/mon.orig" 2>/dev/null
python3 - > "$TOA/cand2.json" <<'PY'
import json
print(json.dumps([{"pattern": "셋째 패턴", "kind": "재교정", "repos": ["r1", "r2"], "direction": "investigate", "evidence": ["r1 2026-11-20"]}], ensure_ascii=False))
PY
python3 "$OBS" append "$TOA/cand2.json" >/dev/null 2>&1; code=$?
python3 -c '
import sys
M = open(sys.argv[1], encoding="utf-8").read(); O = open(sys.argv[2], encoding="utf-8").read()
assert M.startswith(O) and "→ F-007" in M[len(O):] and M.count("# 불편 원문") == 1, M
' "$MON" "$TOA/mon.orig" 2>/dev/null && [ "$code" = "0" ] && grep -q '^| F-007 | 셋째 패턴 |' "$LED" \
  && ok "append: 월별 파일 있으면 맨 아래에 붙임 · 다음 ID F-007" || bad "월별 append" "exit=$code"

# ── 모두 거부 → 후보 없음 · exit 0 · 무변경 ──
cp "$LED" "$TOA/led2"; cp "$MON" "$TOA/mon2" 2>/dev/null
printf '[{"pattern": "x", "kind": "잡담", "repos": ["a", "b"], "direction": "direct"}]' > "$TOA/cand3.json"
out=$(python3 "$OBS" append "$TOA/cand3.json" 2>/dev/null); code=$?
[ "$code" = "0" ] && printf '%s' "$out" | grep -q '후보 없음' && toa_same "$LED" "$TOA/led2" && toa_same "$MON" "$TOA/mon2" \
  && ok "append: 남은 후보 0 → '후보 없음' · exit 0 · 무변경" || bad "후보 없음" "exit=$code out=[$out]"

# ── .obsidian 없는 원장 → [[YYYY-MM]] · 빈 표면 F-001 ──
mkdir -p "$TOA/plain/ledger"
PL="$TOA/plain/ledger/index.md"
printf '# 원장\n\n| ID | 패턴 | 유형 | 대상 | 프로젝트 | 횟수 | 처음 | 마지막 | 방향 | 상태 | 연결 |\n|---|---|---|---|---|---|---|---|---|---|---|\n\n끝.\n' > "$PL"
printf '{"ledger": "%s"}' "$PL" > "$CLAUDE_TASK_OBSERVER_CONFIG"
python3 "$OBS" append "$TOA/cand2.json" >/dev/null 2>&1; code=$?
[ "$code" = "0" ] && grep -qF '| F-001 | 셋째 패턴 |' "$PL" && grep -F '| F-001 |' "$PL" | grep -qF '| [[2026-11]] |' \
  && grep -q '^끝\.$' "$PL" && [ -f "$TOA/plain/ledger/2026-11.md" ] \
  && ok "append: .obsidian 없으면 [[YYYY-MM]] · 행 없으면 F-001" || bad "obsidian 없음" "exit=$code $(cat "$PL")"

# ── 표 없는 원장 → exit 2 · 원장 · 월별 둘 다 무변경 ──
mkdir -p "$TOA/notable"
NL="$TOA/notable/index.md"
printf '# 원장\n\n표가 없다.\n' > "$NL"; cp "$NL" "$TOA/nl.orig"
printf '{"ledger": "%s"}' "$NL" > "$CLAUDE_TASK_OBSERVER_CONFIG"
python3 "$OBS" append "$CAND" >/dev/null 2>"$TOA/err2"; code=$?
[ "$code" = "2" ] && toa_same "$NL" "$TOA/nl.orig" && [ ! -e "$TOA/notable/2026-11.md" ] && ! grep -q Traceback "$TOA/err2" \
  && ok "append: 표 없는 원장 → exit 2 · 둘 다 무변경" || bad "표 없음" "exit=$code err=$(cat "$TOA/err2")"

rm -f "$CLAUDE_TASK_OBSERVER_CONFIG"
unset CLAUDE_TASK_OBSERVER_CONFIG CLAUDE_TASK_OBSERVER_PROJECTS TASK_OBSERVER_NOW
