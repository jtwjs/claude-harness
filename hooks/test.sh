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

# ── 케이스 2-b: deny 패턴 경계 — `.*` 가 &&·;·| 를 넘어가던 오탐 (2026-10-08) ─
# 명령은 JSON 으로 감싸 넘긴다 (따옴표가 섞여 printf 포맷으로 못 쓴다).
printf '\n[2-b] deny 패턴 — 한 명령 안에서만 매칭 · 따옴표 안 무시 · exclude\n'
check_deny() { # $1=expect(0|2)  $2=command
  out=$(cd "$TMP/none" && printf '%s' "$2" | python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.stdin.read()}}))' \
        | bash "$HOOKS/block-dangerous-bash.sh" 2>&1); code=$?
  if [ "$code" = "$1" ]; then ok "exit $1: $2"; else bad "exit $code (기대 $1)" "$2"; fi
}
check_deny 0 'git commit -m "x" && git log | head -n 5'      # -n 이 다른 명령에 있다
check_deny 0 'git commit -m "fix" ; sed -n 1p a'             # ; 뒤
check_deny 0 'git commit -m "use -n flag later"'             # 메시지 문자열 안
check_deny 0 'cat .env.example'                              # exclude
check_deny 0 'git push origin feature/x'
check_deny 2 'git commit -n -m x'
check_deny 2 'git commit --no-verify -m x'
check_deny 2 'git commit -m "x" -n'
check_deny 2 'cat .env'
check_deny 2 'git push -f origin main'

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

# ── 케이스 3-b: tdd-guard — Kotlin src/main ↔ src/test 짝 ─────────────────
printf '\n[3-b] tdd-guard — Kotlin 짝 판정\n'
cat > "$TMP/on/.claude/harness.json" <<JSON
{ "tdd": { "enabled": true, "include": ["src/main/kotlin/**"], "exclude": ["**/dto/**"] } }
JSON
K="src/main/kotlin/app/order"; mkdir -p "$TMP/on/$K/dto" "$TMP/on/src/test/kotlin/app/order"
: > "$TMP/on/$K/OrderService.kt"; : > "$TMP/on/$K/PayService.kt"; : > "$TMP/on/$K/dto/OrderRes.kt"
: > "$TMP/on/src/test/kotlin/app/order/PayServiceTest.kt"
check_tdd "$K/OrderService.kt"   deny   # 짝 없음
check_tdd "$K/PayService.kt"     pass   # src/test/.../PayServiceTest.kt 있음
check_tdd "$K/dto/OrderRes.kt"   pass   # exclude
check_tdd "src/test/kotlin/app/order/PayServiceTest.kt" pass   # 테스트 파일 자체
out=$(cd "$TMP/on" && printf '{"tool_input":{"file_path":"%s"}}' "$TMP/on/$K/OrderService.kt" | bash "$HOOKS/tdd-guard.sh" 2>&1)
echo "$out" | grep -q 'src/test/kotlin/app/order/OrderServiceTest.kt' && ok "기대 경로를 src/test 로 안내" || bad "안내 경로" "out=[$out]"

# ── 케이스 3-c: auto-format — .kt 는 ktlint 없으면 조용히 통과 ──────────────
printf '\n[3-c] auto-format — Kotlin\n'
printf 'fun a( ) = 1\n' > "$TMP/on/$K/Fmt.kt"
out=$(cd "$TMP/on" && printf '{"tool_input":{"file_path":"%s"}}' "$TMP/on/$K/Fmt.kt" | PATH="/usr/bin:/bin" bash "$HOOKS/auto-format.sh" 2>&1); code=$?
[ "$code" = "0" ] && [ -z "$out" ] && ok "ktlint 없음 — exit 0 · 무출력" || bad "ktlint 없음" "exit=$code out=[$out]"

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
# 채점을 실행해선 안 된다 — 환기 훅(SessionStart)은 읽기 전용이다(케이스 4 Stop 훅과 같은 계약)
[ -d "$TMP/on/.claude/reports" ] && bad "쓰기 발생" "환기 훅이 채점까지 돌렸다" || ok "채점은 실행하지 않는다"

# ── 케이스 7: loop-lock — 3회 연속 exit 2 · 세션이 바뀌면 리셋 · 비검증 명령 미추적 (2026-10-08) ─
printf '\n[7] loop-lock — 반복 차단 · 세션 리셋 · 추적 범위\n'
cat > "$TMP/on/.claude/harness.json" <<JSON
{ "verify": { "test": "pnpm test" } }
JSON
rm -f "$TMP/on/.claude/.last-loop-lock"
ll() { # $1=session $2=command → exit code
  (cd "$TMP/on" && printf '{"session_id":"%s","tool_input":{"command":"%s"}}' "$1" "$2" | bash "$HOOKS/loop-lock.sh" >/dev/null 2>&1); echo $?
}
[ "$(ll s1 'pnpm test')" = "0" ] && [ "$(ll s1 'pnpm test')" = "0" ] && [ "$(ll s1 'pnpm test')" = "2" ] \
  && ok "같은 세션 3회째 exit 2" || bad "반복 차단" "3회째가 exit 2 가 아니다"
[ "$(ll s2 'pnpm test')" = "0" ] && ok "세션이 바뀌면 count 리셋" || bad "세션 리셋" "다른 세션 첫 호출이 차단됐다"
rm -f "$TMP/on/.claude/.last-loop-lock"
ll s3 'ls build/' >/dev/null; [ ! -f "$TMP/on/.claude/.last-loop-lock" ] && ok "ls build/ 는 추적하지 않는다" || bad "오탐 추적" "ls build/ 가 stamp 를 만들었다"

# ── 케이스 8: todo-warn — stdout JSON 으로 낸다 (stderr 는 아무도 못 본다) ─────
printf '\n[8] todo-warn — stdout JSON\n'
printf 'x\n// TODO later\n' > "$TMP/on/t.ts"
(cd "$TMP/on" && git add t.ts >/dev/null 2>&1)
out=$(cd "$TMP/on" && printf '{"tool_input":{"command":"git commit -m x"}}' | bash "$HOOKS/todo-warn.sh" 2>/dev/null)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "TODO" in d["hookSpecificOutput"]["additionalContext"] and d["systemMessage"]' 2>/dev/null \
  && ok "additionalContext + systemMessage" || bad "JSON" "out=[$out]"
(cd "$TMP/on" && git reset -q t.ts && rm -f t.ts)

# ── 케이스 9: validate-session-end — 결과를 stdout JSON systemMessage 로 ─────
printf '\n[9] Stop 훅 — stdout JSON systemMessage\n'
cat > "$TMP/on/.claude/harness.json" <<JSON
{ "verify": { "lint": "echo ok", "test": "" } }
JSON
rm -f "$TMP/on/.claude/.last-session-validate"
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/validate-session-end.sh" 2>/dev/null)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); m=d["systemMessage"]; assert "🟢 lint" in m and "verify.test" in m' 2>/dev/null \
  && ok "systemMessage 에 🟢 lint · 빈 verify.test" || bad "JSON" "out=[$out]"

# ── 케이스 10: deny — force push 위치 · +refspec · rm -rf 플래그 순서 (2026-10-08) ─
printf '\n[10] deny 패턴 — force push · rm -rf 변형\n'
check_deny 2 'git push -f origin main'
check_deny 2 'git push --force-with-lease origin develop'
check_deny 2 'git push origin +main'
check_deny 2 'git push -f origin HEAD:main'
check_deny 0 'git push -f origin feature/main-fix'
check_deny 0 'git push origin main'
check_deny 2 'rm -fr ~'
check_deny 2 'rm -r -f /'
check_deny 2 'rm -rf "$HOME"'
check_deny 2 'rm -rf ~/'
check_deny 0 'rm -rf ./build'
check_deny 0 'rm -rf /tmp/x'

printf '\n──────────────\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
