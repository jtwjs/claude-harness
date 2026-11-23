# task-observer weekly.sh — PRD AC1·AC10·AC11·AC12·AC13. test.sh 가 source 한다.
printf '\n[task-observer-weekly] weekly.sh\n'
WK="$HOOKS/../skills/task-observer/scripts/weekly.sh"
WPROMPT="$HOOKS/../skills/task-observer/references/weekly-prompt.md"
TOW="$TMP/tow"
rm -rf "$TOW"; mkdir -p "$TOW/tmp"
export CLAUDE_TASK_OBSERVER_CONFIG="$TOW/task-observer.json"
export CLAUDE_TASK_OBSERVER_PROJECTS="$TOW/projects"
export TASK_OBSERVER_NOW="2026-11-23T12:00:00+09:00"
export TASK_OBSERVER_CLAUDE="$TOW/fake-claude"

# 가짜 claude — 인자(한 줄에 [값])와 stdin 을 남기고, reply 파일 내용을 내고 rc 파일 값으로 끝난다
cat > "$TOW/fake-claude" <<EOF
#!/bin/sh
: > "$TOW/args"
for a in "\$@"; do printf '[%s]\n' "\$a" >> "$TOW/args"; done
cat > "$TOW/stdin"
cat "$TOW/reply"
exit \$(cat "$TOW/rc" 2>/dev/null || echo 0)
EOF
chmod +x "$TOW/fake-claude"
tow_reset() { rm -f "$TOW/args" "$TOW/stdin"; echo 0 > "$TOW/rc"; }

# 픽스처: git 레포 2개 · 대화 기록(두 레포) · 가짜 원장
gq() { git -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
mkdir -p "$TOW/repoA" "$TOW/repoB"
(cd "$TOW/repoA" && gq init -q && gq commit -q --allow-empty -m init)
(cd "$TOW/repoB" && gq init -q && gq commit -q --allow-empty -m init)
mkdir -p "$TOW/projects/p1" "$TOW/one/p1"
python3 - "$TOW" > "$TOW/projects/p1/s.jsonl" <<'PY'
import json, sys
t = sys.argv[1]
for cwd, ts, text in [(t + "/repoA", "2026-11-20T01:00:00Z", "주간재료A말"), (t + "/repoB", "2026-11-21T01:00:00Z", "주간재료B말")]:
    print(json.dumps({"type": "user", "cwd": cwd, "timestamp": ts, "message": {"content": text}}, ensure_ascii=False))
PY
grep -F 'repoA' "$TOW/projects/p1/s.jsonl" > "$TOW/one/p1/s.jsonl"

mkdir -p "$TOW/vault/.obsidian" "$TOW/vault/ledger"
LEDW="$TOW/vault/ledger/index.md"
MONW="$TOW/vault/ledger/2026-11.md"
cat > "$LEDW" <<'EOF'
# 원장

| ID | 패턴 | 유형 | 대상 | 프로젝트 | 횟수 | 처음 | 마지막 | 방향 | 상태 | 연결 |
|---|---|---|---|---|---|---|---|---|---|---|
| F-002 | 옛 패턴 | 재지시 | 레포(x) | ⚠️ | 1 | 2026-10-01 | 2026-10-01 | direct | 열림 | [[2026-10]] |

끝.
EOF
cp "$LEDW" "$TOW/ledger.orig"

CANDJ='[{"pattern": "주간 후보 패턴", "kind": "재지시", "repos": ["repoA", "repoB"], "count": 2, "first": "2026-11-20", "last": "2026-11-21", "direction": "direct", "evidence": ["repoA 2026-11-20 세션", "repoB 2026-11-21 세션"]}]'
tow_reply() { # $1 = result 문자열(모델 출력)  $2 = is_error(true|false)
  python3 -c 'import json,sys; print(json.dumps({"type": "result", "is_error": sys.argv[2] == "true", "result": sys.argv[1]}, ensure_ascii=False))' "$1" "${2:-false}" > "$TOW/reply"
}
LASTRE='^task-observer weekly: 후보 [0-9]+ · 쓴 행 [0-9]+ · 소요 [0-9]+s$'

# ── 파일 존재 · 실행 가능 ──
[ -x "$WK" ] && ok "weekly.sh 실행 가능" || bad "weekly.sh" "없음 또는 실행 불가"
[ -s "$WPROMPT" ] && ok "references/weekly-prompt.md 있음" || bad "weekly-prompt.md" "없음"

# ── AC1 설정 없음 → claude 안 부름 · '원장 설정 없음' · exit 0 ──
rm -f "$CLAUDE_TASK_OBSERVER_CONFIG"; tow_reset; tow_reply "$CANDJ"
out=$(TMPDIR="$TOW/tmp" bash "$WK" 2>&1); code=$?
[ "$code" = "0" ] && printf '%s' "$out" | grep -q '원장 설정 없음' && [ ! -e "$TOW/args" ] \
  && ok "weekly: 설정 없음 → 가짜 claude 안 불림 · '원장 설정 없음' · exit 0(AC1)" || bad "설정 없음" "exit=$code out=[$out]"

printf '{"ledger": "%s"}' "$LEDW" > "$CLAUDE_TASK_OBSERVER_CONFIG"

# ── 레포 1곳 → 안 불림 · '후보 없음' ──
tow_reset
out=$(CLAUDE_TASK_OBSERVER_PROJECTS="$TOW/one" TMPDIR="$TOW/tmp" bash "$WK" 2>&1); code=$?
[ "$code" = "0" ] && printf '%s' "$out" | grep -q '후보 없음' && [ ! -e "$TOW/args" ] && cmp -s "$LEDW" "$TOW/ledger.orig" \
  && ok "weekly: 레포 1곳 → claude 안 불림 · '후보 없음' · exit 0" || bad "레포 1곳" "exit=$code out=[$out]"

# ── 정상 결과 → 원장에 후보 행 ──
tow_reset; tow_reply "$CANDJ"
out=$(TMPDIR="$TOW/tmp" bash "$WK" 2>"$TOW/err"); code=$?
[ "$code" = "0" ] && grep -q '^| F-003 | 주간 후보 패턴 | 재지시 | 레포(repoA, repoB) |' "$LEDW" && grep -F '| F-003 |' "$LEDW" | grep -qF '| 후보 |' \
  && ok "weekly: 정상 결과 → 원장에 F-003 후보 행" || bad "정상 결과" "exit=$code out=[$out] err=$(cat "$TOW/err")"
[ -f "$MONW" ] && grep -q '→ F-003' "$MONW" && ok "weekly: 월별 파일에 근거 항목" || bad "월별" "$(cat "$MONW" 2>/dev/null)"
last=$(printf '%s\n' "$out" | tail -n1)
printf '%s' "$last" | grep -Eq "$LASTRE" && printf '%s' "$last" | grep -q '후보 1 · 쓴 행 1' \
  && ok "weekly: 마지막 줄 'task-observer weekly: 후보 n · 쓴 행 m · 소요 Ns'" || bad "마지막 줄" "[$last]"

# ── AC11 인자 ──
[ -f "$TOW/args" ] && grep -qx '\[-p\]' "$TOW/args" && grep -A1 -x '\[--tools\]' "$TOW/args" | sed -n 2p | grep -qx '\[\]' \
  && grep -qx '\[--no-session-persistence\]' "$TOW/args" && grep -A1 -x '\[--output-format\]' "$TOW/args" | sed -n 2p | grep -qx '\[json\]' \
  && ok "weekly: claude -p --tools \"\" --no-session-persistence --output-format json(AC11)" || bad "인자" "$(cat "$TOW/args" 2>/dev/null)"

# ── stdin = 지시문 + 재료 ──
python3 -c '
import sys
s = open(sys.argv[1], encoding="utf-8").read(); p = open(sys.argv[2], encoding="utf-8").read().strip()
assert p and p in s, "지시문 없음"
assert "주간재료A말" in s and "주간재료B말" in s and "\"repos\"" in s, "재료 없음"
' "$TOW/stdin" "$WPROMPT" 2>/dev/null && ok "weekly: stdin 에 지시문과 재료 JSON" || bad "stdin" "$(head -c 300 "$TOW/stdin" 2>/dev/null)"

# ── 임시 폴더 정리 ──
[ -z "$(ls -A "$TOW/tmp" 2>/dev/null)" ] && ok "weekly: 재료 · 결과 임시 파일을 지움" || bad "임시 파일 남음" "$(ls -A "$TOW/tmp")"

# ── 펜스로 감싼 결과도 파싱 ──
cp "$LEDW" "$TOW/led1"; tow_reset
tow_reply "$(printf '후보는 아래와 같다.\n```json\n%s\n```\n' "$(printf '%s' "$CANDJ" | sed 's/주간 후보 패턴/펜스 후보 패턴/')")"
out=$(TMPDIR="$TOW/tmp" bash "$WK" 2>"$TOW/err"); code=$?
[ "$code" = "0" ] && grep -q '^| F-004 | 펜스 후보 패턴 |' "$LEDW" \
  && ok "weekly: 코드 펜스로 감싼 결과도 파싱 → F-004" || bad "펜스" "exit=$code out=[$out] err=$(cat "$TOW/err")"

# ── 빈 배열 → '후보 없음' · exit 0 · 무변경 ──
cp "$LEDW" "$TOW/led2"; tow_reset; tow_reply '[]'
out=$(TMPDIR="$TOW/tmp" bash "$WK" 2>&1); code=$?
[ "$code" = "0" ] && printf '%s' "$out" | grep -q '후보 없음' && cmp -s "$LEDW" "$TOW/led2" \
  && ok "weekly: 결과 [] → '후보 없음' · exit 0 · 원장 무변경" || bad "빈 배열" "exit=$code out=[$out]"

# ── AC12 실패 결과 → exit 1 · 원장 무변경 ──
tow_fail() { # $1=이름
  out=$(TMPDIR="$TOW/tmp" bash "$WK" 2>&1); code=$?
  [ "$code" = "1" ] && cmp -s "$LEDW" "$TOW/led2" && ! printf '%s' "$out" | grep -q Traceback \
    && ok "weekly: $1 → exit 1 · 원장 무변경(AC12)" || bad "$1" "exit=$code out=[$out]"
}
tow_reset; tow_reply "$CANDJ"; echo 3 > "$TOW/rc"; tow_fail "claude 비0 종료"
tow_reset; tow_reply "$CANDJ" true; tow_fail "is_error"
tow_reset; tow_reply "후보를 찾지 못했습니다"; tow_fail "결과에 JSON 없음"
tow_reset; tow_reply '{"pattern": "x"}'; tow_fail "결과가 배열 아님"
tow_reset; printf 'not json at all\n' > "$TOW/reply"; tow_fail "claude 출력이 JSON 아님"

# ── AC10 --dry-run → 원장 · 월별 무변경, 행은 stdout ──
cp "$MONW" "$TOW/mon2" 2>/dev/null; tow_reset; tow_reply "$CANDJ"
out=$(TMPDIR="$TOW/tmp" bash "$WK" --dry-run 2>&1); code=$?
[ "$code" = "0" ] && cmp -s "$LEDW" "$TOW/led2" && cmp -s "$MONW" "$TOW/mon2" && printf '%s' "$out" | grep -q '| F-005 | 주간 후보 패턴 |' \
  && printf '%s\n' "$out" | tail -n1 | grep -Eq "$LASTRE" \
  && ok "weekly --dry-run: 원장 · 월별 무변경 · 쓸 행을 stdout(AC10)" || bad "dry-run" "exit=$code out=[$out]"

# ── --days 를 gather 에 넘김: 1일이면 창 안 레포 0 → claude 안 부름 ──
tow_reset
out=$(TMPDIR="$TOW/tmp" bash "$WK" --days 1 2>&1); code=$?
[ "$code" = "0" ] && printf '%s' "$out" | grep -q '후보 없음' && [ ! -e "$TOW/args" ] \
  && ok "weekly --days 1: 창이 좁아 레포 0 → claude 안 부름" || bad "--days" "exit=$code out=[$out]"

# ── AC13 공개 레포: 원장 경로 · 볼트 폴더 이름 하드코딩 0 ──
P1="1_My""Brain"; P2="brain/""friction"
hits=$(grep -rIlE "$P1|$P2" "$HOOKS/../skills/task-observer" "$HOOKS"/tests/task-observer-*.sh 2>/dev/null)
[ -z "$hits" ] && ok "AC13: skills/task-observer · tests 에 볼트 경로 grep 0" || bad "AC13 하드코딩" "$hits"

rm -f "$CLAUDE_TASK_OBSERVER_CONFIG"
unset CLAUDE_TASK_OBSERVER_CONFIG CLAUDE_TASK_OBSERVER_PROJECTS TASK_OBSERVER_NOW TASK_OBSERVER_CLAUDE
