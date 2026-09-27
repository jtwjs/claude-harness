#!/usr/bin/env bash
# 훅 회귀 테스트 — 기계가 판정할 수 있는 것만 본다.
#
# 왜 2케이스뿐인가: "리뷰 품질이 좋아졌나" 같은 것은 사람이 봐야 하고,
# 게이트가 될 수 없다. 여기 있는 것은 전부 exit code 로 갈리는 것들이다.
#
# 사용: bash hooks/test.sh
set -uo pipefail

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

ok()   { printf '  ✓ %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  🔴 %s — %s\n' "$1" "$2"; fail=$((fail+1)); }

# ── 케이스 1: 하네스가 없는 레포에서는 전부 조용해야 한다 ────────────────────
# 오탐 1건 = 신뢰 10건 손실. 남의 레포에서 떠드는 훅은 즉시 꺼진다.
printf '\n[1] 하네스 없는 레포 — 전부 exit 0 · 무출력\n'
mkdir -p "$TMP/none/src" && (cd "$TMP/none" && git init -q)
payload='{"tool_input":{"file_path":"'"$TMP"'/none/src/a.ts","command":"npm test"}}'
for h in auto-format tdd-guard todo-warn loop-lock validate-session-end cadence-reminder weekly-readiness-check; do
  out=$(cd "$TMP/none" && printf '%s' "$payload" | bash "$HOOKS/$h.sh" 2>&1); code=$?
  if [ "$code" = "0" ] && [ -z "$out" ]; then ok "$h"; else bad "$h" "exit=$code out=[$out]"; fi
done

# ── 케이스 2: 위험 명령은 하네스가 없어도 막아야 한다 ────────────────────────
# block-dangerous-bash 만 게이팅 예외다 — 이 훅이 조용하면 존재 이유가 없다.
printf '\n[2] 위험 명령 차단 — exit 2 (하네스 없어도)\n'
for cmd in 'rm -rf /' 'rm -rf ~'; do
  out=$(cd "$TMP/none" && printf '{"tool_input":{"command":"%s"}}' "$cmd" | bash "$HOOKS/block-dangerous-bash.sh" 2>&1); code=$?
  if [ "$code" = "2" ]; then ok "차단: $cmd"; else bad "차단 실패: $cmd" "exit=$code"; fi
done
# 정상 명령은 통과해야 한다 (오탐 확인)
out=$(cd "$TMP/none" && printf '{"tool_input":{"command":"git status"}}' | bash "$HOOKS/block-dangerous-bash.sh" 2>&1); code=$?
if [ "$code" = "0" ] && [ -z "$out" ]; then ok "정상 명령 통과: git status"; else bad "오탐" "git status 가 막혔다 (exit=$code)"; fi

# ── 케이스 3: tdd-guard 는 harness.json 만으로 판정한다 ──────────────────────
printf '\n[3] tdd-guard — include/exclude 판정\n'
mkdir -p "$TMP/on/.claude" "$TMP/on/src/features" && (cd "$TMP/on" && git init -q)
cat > "$TMP/on/.claude/harness.json" <<JSON
{ "tdd": { "enabled": true, "include": ["src/features/**"], "exclude": ["**/index.ts"] } }
JSON
: > "$TMP/on/src/features/a.ts"; : > "$TMP/on/src/features/index.ts"
check_tdd() { # $1=file  $2=expect(deny|pass)
  out=$(cd "$TMP/on" && printf '{"tool_input":{"file_path":"%s"}}' "$TMP/on/$1" | bash "$HOOKS/tdd-guard.sh" 2>&1)
  if [ "$2" = "deny" ]; then
    echo "$out" | grep -q '"permissionDecision": *"deny"' && ok "차단: $1" || bad "차단 실패: $1" "out=[$out]"
  else
    [ -z "$out" ] && ok "통과: $1" || bad "오탐: $1" "out=[$out]"
  fi
}
check_tdd "src/features/a.ts"     deny   # 짝 테스트 없음
check_tdd "src/features/index.ts" pass   # exclude
check_tdd "src/other/b.ts"        pass   # include 범위 밖

# ── 케이스 4: Stop 훅은 읽기 전용이어야 한다 ────────────────────────────────
printf '\n[4] Stop 훅 — 작업트리를 건드리지 않는다\n'
cat > "$TMP/on/.claude/harness.json" <<JSON
{ "verify": { "lint": "echo ok", "test": "" } }
JSON
(cd "$TMP/on" && git add -A >/dev/null 2>&1 && git -c user.email=t@t -c user.name=t commit -qm i >/dev/null 2>&1)
# stamp(.claude/.last-*)는 gitignore 대상이라 쓰기로 치지 않는다.
# 막으려는 것은 "세션 끝에 소스를 조용히 다시 쓰는 것"이다.
snap() { (cd "$TMP/on" && git status --porcelain | grep -v '\.claude/\.last-' | git hash-object --stdin); }
before=$(snap)
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/validate-session-end.sh" 2>&1)
after=$(snap)
[ "$before" = "$after" ] && ok "소스 무변화 (stamp 제외)" || bad "쓰기 발생" "Stop 훅이 소스를 고쳤다"
# stamp 는 반드시 프로젝트 안에 생겨야 한다 (플러그인에 생기면 레포 간 오염)
[ -f "$TMP/on/.claude/.last-session-validate" ] && ok "stamp 가 프로젝트 .claude/ 안에" || bad "stamp 위치" "프로젝트 밖에 생겼다"
echo "$out" | grep -q "verify.test 가 비어" && ok "빈 verify.test 를 보고한다" || bad "침묵" "test 가 비었는데 아무 말이 없다"

# ── 케이스 5: cadence 축 3(CLAUDE.md 비대) — 임계 아래는 조용, 위는 말한다 ───
# 임계 검사는 조용히 안 터져도 아무도 모른다(§15-4 "무출력 실패"). 그래서 양쪽을 다 건다.
printf '\n[5] cadence 축 3 — CLAUDE.md 비대 임계\n'
printf '# tiny\n' > "$TMP/on/CLAUDE.md"
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/cadence-reminder.sh" 2>&1)
echo "$out" | grep -q 'claude-md-improver' && bad "오탐" "작은 CLAUDE.md 에 떠들었다" || ok "임계 아래 — 조용"
python3 -c "print('x\n'*100, end='')" > "$TMP/on/CLAUDE.md"
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/cadence-reminder.sh" 2>&1)
echo "$out" | grep -q 'claude-md-improver' && ok "임계 초과 — 환기" || bad "침묵" "101줄인데 아무 말이 없다 out=[$out]"

# ── 케이스 6: cadence 축 4(readiness 채점 공백) — 커밋 수 게이트 ────────────
printf '\n[6] cadence 축 4 — readiness 채점 공백\n'
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/cadence-reminder.sh" 2>&1)
echo "$out" | grep -q 'ai-readiness-cartography' && bad "오탐" "커밋 1건인데 떠들었다" || ok "게이트 아래 — 조용"
(cd "$TMP/on" && for i in $(seq 25); do git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "c$i"; done)
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/cadence-reminder.sh" 2>&1)
echo "$out" | grep -q 'ai-readiness-cartography' && ok "게이트 초과 — 환기" || bad "침묵" "커밋 26건인데 아무 말이 없다 out=[$out]"
# 채점을 실행해선 안 된다 — Stop 훅은 읽기 전용이다(케이스 4와 같은 계약)
[ -d "$TMP/on/.claude/reports" ] && bad "쓰기 발생" "환기 훅이 채점까지 돌렸다" || ok "채점은 실행하지 않는다"

printf '\n──────────────\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
