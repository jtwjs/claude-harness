# harness-gaps append --known · weekly.sh 가 재료 레포 이름을 넘김 — PRD AC6(재료에 있던 레포 이름만). test.sh 가 source 한다.
printf '\n[harness-gaps-known] append --known\n'
KOBS="$HOOKS/../skills/harness-gaps/scripts/gaps.py"
KWK="$HOOKS/../skills/harness-gaps/scripts/weekly.sh"
TOK="$TMP/tok"
rm -rf "$TOK"; mkdir -p "$TOK/tmp"
export CLAUDE_HARNESS_GAPS_CONFIG="$TOK/harness-gaps.json"
export CLAUDE_HARNESS_GAPS_PROJECTS="$TOK/projects"
export HARNESS_GAPS_NOW="2026-11-23T12:00:00+09:00"
export HARNESS_GAPS_CLAUDE="$TOK/fake-claude"

mkdir -p "$TOK/vault/.obsidian" "$TOK/vault/ledger"
LEDK="$TOK/vault/ledger/index.md"
cat > "$LEDK" <<'EOF'
# 원장

| ID | 패턴 | 유형 | 대상 | 프로젝트 | 횟수 | 처음 | 마지막 | 방향 | 상태 | 연결 |
|---|---|---|---|---|---|---|---|---|---|---|

끝.
EOF
cp "$LEDK" "$TOK/ledger.orig"
printf '{"ledger": "%s"}' "$LEDK" > "$CLAUDE_HARNESS_GAPS_CONFIG"

tok_cand() { # $1=패턴  $2..=레포 이름
  python3 -c '
import json, sys
print(json.dumps([{"pattern": sys.argv[1], "kind": "재지시", "repos": sys.argv[2:], "count": 2,
  "first": "2026-11-20", "last": "2026-11-21", "direction": "direct", "evidence": ["e"]}], ensure_ascii=False))
' "$@"
}

# ── --known a,b: [a,c] 거부 · stderr 한 줄 ──
tok_cand "모르는레포 후보" a c > "$TOK/ac.json"
out=$(python3 "$KOBS" append --known a,b "$TOK/ac.json" 2>"$TOK/err"); code=$?
[ "$code" = "0" ] && cmp -s "$LEDK" "$TOK/ledger.orig" && grep -q '레포 이름이 재료에 없음: c' "$TOK/err" \
  && [ "$(grep -c . "$TOK/err" | tr -d ' ')" = "1" ] && ! grep -q Traceback "$TOK/err" \
  && ok "append --known a,b: repos [a,c] 거부 · 원장 무변경 · stderr '레포 이름이 재료에 없음: c'" \
  || bad "--known 거부" "exit=$code out=[$out] err=$(cat "$TOK/err")"

# ── --known a,b: [a,b] 씀 ──
tok_cand "아는레포 후보" a b > "$TOK/ab.json"
out=$(python3 "$KOBS" append --known a,b "$TOK/ab.json" 2>"$TOK/err"); code=$?
[ "$code" = "0" ] && grep -q '^| F-001 | 아는레포 후보 |' "$LEDK" \
  && ok "append --known a,b: repos [a,b] 씀 → F-001" || bad "--known 통과" "exit=$code out=[$out] err=$(cat "$TOK/err")"

# ── --known 없음: [a,c] 도 씀(하위 호환) ──
out=$(python3 "$KOBS" append "$TOK/ac.json" 2>"$TOK/err"); code=$?
[ "$code" = "0" ] && grep -q '^| F-002 | 모르는레포 후보 |' "$LEDK" \
  && ok "append(--known 없음): repos [a,c] 도 씀(하위 호환)" || bad "하위 호환" "exit=$code out=[$out] err=$(cat "$TOK/err")"

# ── weekly.sh: 재료에 없는 레포 이름이 섞인 후보만 빠짐 ──
cat > "$TOK/fake-claude" <<EOF
#!/bin/sh
cat > /dev/null
cat "$TOK/reply"
EOF
chmod +x "$TOK/fake-claude"
gqk() { git -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
mkdir -p "$TOK/repoK1" "$TOK/repoK2" "$TOK/projects/p1"
(cd "$TOK/repoK1" && gqk init -q && gqk commit -q --allow-empty -m init)
(cd "$TOK/repoK2" && gqk init -q && gqk commit -q --allow-empty -m init)
python3 - "$TOK" > "$TOK/projects/p1/s.jsonl" <<'PY'
import json, sys
t = sys.argv[1]
for cwd, ts in [(t + "/repoK1", "2026-11-20T01:00:00Z"), (t + "/repoK2", "2026-11-21T01:00:00Z")]:
    print(json.dumps({"type": "user", "cwd": cwd, "timestamp": ts, "message": {"content": "말"}}, ensure_ascii=False))
PY
python3 -c '
import json
base = {"kind": "재지시", "count": 2, "first": "2026-11-20", "last": "2026-11-21", "direction": "direct", "evidence": ["e"]}
cands = [dict(base, pattern="실재 레포 후보", repos=["repoK1", "repoK2"]),
         dict(base, pattern="지어낸 레포 후보", repos=["repoK1", "repoGhost"])]
print(json.dumps({"type": "result", "is_error": False, "result": json.dumps(cands, ensure_ascii=False)}, ensure_ascii=False))
' > "$TOK/reply"
cp "$LEDK" "$TOK/led1"
out=$(TMPDIR="$TOK/tmp" bash "$KWK" 2>"$TOK/err"); code=$?
[ "$code" = "0" ] && grep -q '^| F-003 | 실재 레포 후보 |' "$LEDK" && ! grep -q '지어낸 레포 후보' "$LEDK" \
  && grep -q '레포 이름이 재료에 없음: repoGhost' "$TOK/err" \
  && ok "weekly: 재료에 없는 레포 이름이 섞인 후보만 빠지고 나머지는 씀" \
  || bad "weekly --known" "exit=$code out=[$out] err=$(cat "$TOK/err")"

# dry-run 에도 같은 거름
out=$(TMPDIR="$TOK/tmp" bash "$KWK" --dry-run 2>"$TOK/err"); code=$?
[ "$code" = "0" ] && printf '%s' "$out" | grep -q '| 실재 레포 후보 |' && ! printf '%s' "$out" | grep -q '지어낸 레포 후보' \
  && ok "weekly --dry-run: 재료에 없는 레포 후보는 stdout 에도 없음" \
  || bad "weekly --dry-run --known" "exit=$code out=[$out] err=$(cat "$TOK/err")"

rm -f "$CLAUDE_HARNESS_GAPS_CONFIG"
unset CLAUDE_HARNESS_GAPS_CONFIG CLAUDE_HARNESS_GAPS_PROJECTS HARNESS_GAPS_NOW HARNESS_GAPS_CLAUDE
