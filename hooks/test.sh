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
export CLAUDE_SKILL_HINTS_DIR="$TMP/skill-hints"
export CLAUDE_LEARN_REPOS="$TMP/learn-repos.txt"   # learn-setup 이 실제 ~/.claude 목록에 쓰지 않게   # cadence-reminder 가 실제 ~/.claude 에 쓰지 않게
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

ok()   { printf '  ✓ %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  🔴 %s — %s\n' "$1" "$2"; fail=$((fail+1)); }

# ── 케이스 1: 하네스가 없는 레포에서는 전부 조용해야 한다 ────────────────────
# 오탐 1건 = 신뢰 10건 손실. 남의 레포에서 떠드는 훅은 즉시 꺼진다.
printf '\n[1] 하네스 없는 레포 — 전부 exit 0 · 무출력\n'
mkdir -p "$TMP/none/src" && (cd "$TMP/none" && git init -q)
payload='{"tool_input":{"file_path":"'"$TMP"'/none/src/a.ts","command":"npm test"}}'
for h in auto-format tdd-guard todo-warn loop-lock validate-session-end cadence-reminder weekly-readiness-check learn-setup; do
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

# ── 케이스 6: weekly-readiness-check — 자동 채점 · 하락 시만 알림 (2026-10-11) ──
# cadence 축 4(환기만, 94세션에 채점 0)를 대체한다. 테스트는 CLAUDE_READINESS_SYNC 로 채점을 동기 실행한다.
printf '\n[6] readiness — 게이트 · 첫 채점 무출력 · 하락 1회 알림 · git 흔적 0\n'
export CLAUDE_READINESS_SYNC=1
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/weekly-readiness-check.sh" 2>&1)
[ -z "$out" ] && [ ! -d "$TMP/on/.claude/reports" ] && ok "게이트 아래 — 채점 안 함·무출력" || bad "오탐" "커밋 몇 건인데 채점했다 out=[$out]"
(cd "$TMP/on" && for i in $(seq 25); do git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "c$i"; done)
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/weekly-readiness-check.sh" 2>&1)
ls "$TMP/on/.claude/reports"/*/ai-readiness-score.json >/dev/null 2>&1 && ok "게이트 초과 — 채점 리포트 생성" || bad "채점 안 됨" "리포트 없음"
[ -z "$out" ] && ok "첫 채점은 비교 대상이 없어 무출력" || bad "소음" "out=[$out]"
[ -z "$(cd "$TMP/on" && git status --porcelain -- .claude/reports)" ] && ok "리포트는 git 에 안 뜬다(exclude)" || bad "흔적" "reports 가 git status 에 뜬다"
python3 - "$TMP/on/.claude/reports" <<'PY'
import json, os, sys, glob
d = sys.argv[1]; cur = json.load(open(glob.glob(os.path.join(d, "*", "ai-readiness-score.json"))[0]))
old = json.loads(json.dumps(cur)); old["total"] = cur["total"] + 10
k = next(iter(old["categories"])); old["categories"][k]["score"] = cur["categories"][k]["score"] + 10
os.makedirs(os.path.join(d, "2000-01-01"), exist_ok=True); json.dump(old, open(os.path.join(d, "2000-01-01", "ai-readiness-score.json"), "w"))
PY
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/weekly-readiness-check.sh" 2>&1)
echo "$out" | grep -q '떨어졌다' && ok "하락 — 알림" || bad "침묵" "점수가 떨어졌는데 아무 말이 없다 out=[$out]"
echo "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && ok "하락 알림은 유효한 JSON" || bad "JSON" "파싱 실패 out=[$out]"
rf="$CLAUDE_SKILL_HINTS_DIR/$(cd "$TMP/on" && git rev-parse --show-toplevel | tr '/' '-').readiness"
grep -q '^ai-readiness — ' "$rf" 2>/dev/null && ok "하락 — 상태줄 권고 파일" || bad "권고 파일" "없음 [$rf]"
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/weekly-readiness-check.sh" 2>&1)
[ -z "$out" ] && [ -f "$rf" ] && ok "같은 하락은 한 번만 알리고 상태줄은 유지" || bad "반복" "out=[$out]"
# 리포트가 있을 때 분기 — 7일 이상 + 커밋 20건 이상이면 다시 잰다
mkdir -p "$TMP/rd/.claude" && (cd "$TMP/rd" && git init -q && printf '{}' > .claude/harness.json && git add -A \
  && for i in $(seq 22); do git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "c$i"; done)
mkdir -p "$TMP/rd/.claude/reports/2000-01-01" && cp "$(ls "$TMP"/on/.claude/reports/*/ai-readiness-score.json | head -1)" "$TMP/rd/.claude/reports/2000-01-01/"
(cd "$TMP/rd" && printf '{}' | bash "$HOOKS/weekly-readiness-check.sh" >/dev/null 2>&1)
[ -f "$TMP/rd/.claude/reports/$(date +%F)/ai-readiness-score.json" ] && ok "리포트 있음 + 7일·20건 — 다시 채점" || bad "재채점 안 됨" "$(ls "$TMP/rd/.claude/reports")"
# 채점이 실패하면 빈 날짜 폴더를 남기지 않는다 — 가짜 플러그인 루트(실패하는 score.py)로 돌린다
FAKE="$TMP/fakeplugin"; mkdir -p "$FAKE/hooks" "$FAKE/skills/ai-readiness-cartography/scripts"
cp "$HOOKS/weekly-readiness-check.sh" "$FAKE/hooks/"; printf 'import sys; sys.exit(3)\n' > "$FAKE/skills/ai-readiness-cartography/scripts/score.py"
rm -rf "$TMP/rd/.claude/reports/$(date +%F)"
(cd "$TMP/rd" && printf '{}' | bash "$FAKE/hooks/weekly-readiness-check.sh" >/dev/null 2>&1)
[ -d "$TMP/rd/.claude/reports/$(date +%F)" ] && bad "빈 폴더" "채점 실패인데 날짜 폴더가 남았다" || ok "채점 실패 — 빈 날짜 폴더를 지운다"
unset CLAUDE_READINESS_SYNC

# cadence 축 1 — doctor 결과 먼저는 레포마다 하루 한 번
(cd "$TMP/on" && git add CLAUDE.md && git -c user.email=t@t -c user.name=t commit -qm "docs: claude" \
  && for i in 1 2 3; do git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "fix: f$i"; done)
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/cadence-reminder.sh" 2>&1)
echo "$out" | grep -q '오늘 이 레포 첫 세션' && ok "doctor 지시 — 하루 첫 세션" || bad "침묵" "fix 3건인데 지시가 없다 out=[$out]"
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/cadence-reminder.sh" 2>&1)
echo "$out" | grep -q '오늘 이 레포 첫 세션' && bad "반복" "같은 날 두 번째 세션에도 지시" || ok "doctor 지시 — 같은 날 두 번째는 생략"
# 상태줄 권고 칸 — 권고가 있으면 레포 밖 파일에 '이름 — 이유', 없으면 파일을 지운다 (2026-10-10 · 이유 2026-10-11)
hf="$CLAUDE_SKILL_HINTS_DIR/$(cd "$TMP/on" && git rev-parse --show-toplevel | tr '/' '-')"
grep -q '^harness-doctor — fix 3건$' "$hf" 2>/dev/null && ok "권고를 '이름 — 이유'로 남긴다" || bad "권고 파일" "$(cat "$hf" 2>/dev/null) [$hf]"
[ -e "$TMP/on/.claude/skill-hints" ] && bad "레포에 씀" "권고 파일이 레포 안에 생겼다" || ok "권고 파일은 레포 밖"
mkdir -p "$TMP/quiet/.claude" && (cd "$TMP/quiet" && git init -q && printf '{}' > .claude/harness.json && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)
qf="$CLAUDE_SKILL_HINTS_DIR/$(cd "$TMP/quiet" && git rev-parse --show-toplevel | tr '/' '-')"
printf 'harness-doctor\n' > "$qf"   # 지난 세션의 권고가 남아 있다고 치고
(cd "$TMP/quiet" && printf '{}' | bash "$HOOKS/cadence-reminder.sh" >/dev/null 2>&1)
[ -e "$qf" ] && bad "남은 권고" "권고가 없는데 파일이 남았다" || ok "권고가 없으면 칸을 비운다"

# ── 케이스 6-b: learn-setup — 개인 학습 수신함 _learn/ (2026-10-11) ──────────
# 레포에 쓰는 훅이라 경계를 다 건다: 하네스 없는 레포 무동작(케이스 1) · .gitignore 무변경 · 두 번 돌려도 한 줄.
printf '\n[6-b] learn-setup — _learn/ 수신함 · 로컬 제외 · 목록\n'
mkdir -p "$TMP/learn/.claude" && (cd "$TMP/learn" && git init -q && printf '{}' > .claude/harness.json && printf 'node_modules/\n' > .gitignore \
  && git add -A && git -c user.email=t@t -c user.name=t commit -qm init)
out=$(cd "$TMP/learn" && printf '{}' | bash "$HOOKS/learn-setup.sh" 2>&1)
[ -f "$TMP/learn/_learn/inbox.md" ] && ok "수신함 생성" || bad "수신함" "_learn/inbox.md 없음"
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "_learn/inbox.md" in d["hookSpecificOutput"]["additionalContext"]' 2>/dev/null \
  && ok "기록 지시를 additionalContext 로" || bad "지시" "JSON 이 아니거나 지시가 없다 out=[$out]"
echo "$out" | grep -q '_brain/wiki/' && ok "지시가 도메인은 _brain 으로 가른다" || bad "분기" "지시에 _brain 행선지가 없다"
echo "$out" | grep -q '안 옮긴 카드 0장' && ok "새 수신함은 0장(형식 예시는 세지 않는다)" || bad "카운트" "새 수신함인데 0장이 아니다"
(cd "$TMP/learn" && printf '{}' | bash "$HOOKS/learn-setup.sh" >/dev/null 2>&1)
n=$(grep -cxF '_learn/' "$TMP/learn/.git/info/exclude" 2>/dev/null); [ "$n" = "1" ] && ok "exclude 한 줄(두 번 돌려도)" || bad "exclude" "_learn/ 줄 수=$n"
[ -z "$(cd "$TMP/learn" && git status --porcelain)" ] && ok "git status 깨끗 — .gitignore 무변경" || bad "흔적" "$(cd "$TMP/learn" && git status --porcelain | head -3)"
n=$(grep -c . "$CLAUDE_LEARN_REPOS" 2>/dev/null); [ "$n" = "1" ] && ok "레포 목록 등록(중복 없이)" || bad "목록" "줄 수=$n"
printf '## 2026-10-11 · 예시\n- vault: [[x]]\n' >> "$TMP/learn/_learn/inbox.md"; before=$(cat "$TMP/learn/_learn/inbox.md")
(cd "$TMP/learn" && printf '{}' | bash "$HOOKS/learn-setup.sh" >/dev/null 2>&1)
[ "$before" = "$(cat "$TMP/learn/_learn/inbox.md")" ] && ok "있는 수신함은 건드리지 않는다" || bad "덮어씀" "기존 카드가 바뀌었다"
printf '## 2026-10-11 · 빈 카드\n- vault:\n' >> "$TMP/learn/_learn/inbox.md"
out=$(cd "$TMP/learn" && printf '{}' | bash "$HOOKS/learn-setup.sh" 2>&1)
echo "$out" | grep -q '안 옮긴 카드 1장' && ok "옮기지 않은 카드만 센다(vault 칸 빈 것 1장)" || bad "카운트" "1장이 아니다"
# 워크트리 — 수신함·목록은 본 레포 기준(워크트리를 지워도 카드가 남는다)
(cd "$TMP/learn" && git worktree add -q "$TMP/learn-wt" 2>/dev/null)
mkdir -p "$TMP/learn-wt/.claude" && printf '{}' > "$TMP/learn-wt/.claude/harness.json"
out=$(cd "$TMP/learn-wt" && printf '{}' | bash "$HOOKS/learn-setup.sh" 2>&1)
[ ! -e "$TMP/learn-wt/_learn" ] && echo "$out" | grep -q "$TMP/learn/_learn/inbox.md" && ok "워크트리 — 본 레포 수신함을 가리킨다" || bad "워크트리" "워크트리에 _learn 이 생겼거나 경로가 다르다"
grep -qxF "$TMP/learn-wt" "$CLAUDE_LEARN_REPOS" && bad "목록" "워크트리 경로가 목록에 들어갔다" || ok "워크트리 — 목록엔 본 레포만"
(cd "$TMP/learn" && git worktree remove --force "$TMP/learn-wt" 2>/dev/null)
[ -f "$TMP/learn/_learn/inbox.md" ] && ok "워크트리를 지워도 카드가 남는다" || bad "유실" "수신함이 사라졌다"

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

# ── 케이스 11: 앱별 verify — Stop 훅이 root 마다 cd 해서 돌리고 root 이름을 낸다 (0.10.0) ─
printf '\n[11] Stop 훅 — 앱별 verify\n'
mkdir -p "$TMP/multi/.claude" "$TMP/multi/apps/api" "$TMP/multi/apps/web" && (cd "$TMP/multi" && git init -q)
: > "$TMP/multi/apps/api/only-here"   # cd 가 안 되면 test -f 가 실패한다
cat > "$TMP/multi/.claude/harness.json" <<JSON
{ "verify": { "\$comment": "x",
  "apps/api": { "test": "test -f only-here" },
  "apps/web": { "lint": "echo ok", "test": "" } } }
JSON
out=$(cd "$TMP/multi" && printf '{}' | bash "$HOOKS/validate-session-end.sh" 2>/dev/null)
msg=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["systemMessage"])' 2>/dev/null)
echo "$msg" | grep -q '🟢 apps/api test' && ok "root 에서 실행 · 이름 표시 (apps/api test)" || bad "앱별 실행" "msg=[$msg]"
echo "$msg" | grep -q '🟢 apps/web lint' && ok "두 번째 root 도 실행 (apps/web lint)" || bad "앱별 실행" "msg=[$msg]"
echo "$msg" | grep -q 'apps/web: verify.test 가 비어' && ok "빈 test 를 root 별로 보고" || bad "침묵" "msg=[$msg]"
# loop-lock: 중첩 verify 명령을 검증성으로 본다 — 'cd … &&' 로 시작해 2순위 정규식에는 안 걸리는 명령
cat > "$TMP/multi/.claude/harness.json" <<JSON
{ "verify": { "apps/api": { "test": "mytool verify-all" } } }
JSON
llm() { (cd "$TMP/multi" && printf '{"session_id":"m1","tool_input":{"command":"%s"}}' "$1" | bash "$HOOKS/loop-lock.sh" >/dev/null 2>&1); echo $?; }
c='cd apps/api && mytool verify-all'
[ "$(llm "$c")" = "0" ] && [ "$(llm "$c")" = "0" ] && [ "$(llm "$c")" = "2" ] \
  && ok "loop-lock — 중첩 verify 명령 3회째 exit 2" || bad "loop-lock 중첩" "앱별 verify 명령을 추적하지 못했다"

printf '\n──────────────\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
