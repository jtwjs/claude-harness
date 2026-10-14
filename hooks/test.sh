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
export CLAUDE_LEARNING_LEVEL_FILE="$TMP/learning-level.json"   # learn-setup 이 실제 ~/.claude 레벨을 읽지 않게
export CLAUDE_LEARN_REPOS="$TMP/learn-repos.txt"   # learn-setup 이 실제 ~/.claude 목록에 쓰지 않게   # cadence-reminder 가 실제 ~/.claude 에 쓰지 않게
trap 'rm -rf "$TMP"' EXIT
unset CLAUDE_BRAIN_SYNC_AUTO CLAUDE_BRAIN_SYNC_AUTO_SKIP CLAUDE_BRAIN_SYNC_BIN CLAUDE_BRAIN_SYNC_SYNC   # 사용자 settings env 가 새어 들어오면 opt-in 판정이 틀어진다
pass=0; fail=0

ok()   { printf '  ✓ %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  🔴 %s — %s\n' "$1" "$2"; fail=$((fail+1)); }
# 빈 커밋 N건을 최근 3일에 나눠 찍는다 — 활발한 레포 게이트(14일·20건·활동일 3일)를 넘기려면 날짜가 퍼져 있어야 한다
spread_commits() {
  local n="$1" i d
  for i in $(seq "$n"); do
    d="$(python3 -c "import datetime,sys; print((datetime.datetime.now()-datetime.timedelta(days=int(sys.argv[1])%3)).strftime('%Y-%m-%dT%H:%M:%S'))" "$i")"
    GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "c$i"
  done
}

# ── 케이스 1: 하네스가 없는 레포에서는 전부 조용해야 한다 ────────────────────
# 오탐 1건 = 신뢰 10건 손실. 남의 레포에서 떠드는 훅은 즉시 꺼진다.
printf '\n[1] 하네스 없는 레포 — 전부 exit 0 · 무출력\n'
mkdir -p "$TMP/none/src" && (cd "$TMP/none" && git init -q)
payload='{"tool_input":{"file_path":"'"$TMP"'/none/src/a.ts","command":"npm test"}}'
for h in auto-format tdd-guard todo-warn loop-lock validate-session-end cadence-reminder weekly-readiness-check learn-setup brain-sync-auto prod-db-check; do
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
# PR 머지 → 사람 확인(ask). 자동 머지 판정이 dry-run 인 동안 (2026-10-13)
for c in 'gh pr merge 12 --squash --delete-branch' 'gh pr merge --auto --squash'; do
  out=$(cd "$TMP/none" && python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$c" | bash "$HOOKS/block-dangerous-bash.sh" 2>/dev/null)
  echo "$out" | grep -q '"permissionDecision":"ask"' && ok "ask: $c" || bad "머지 무확인" "$c → [$out]"
done
out=$(cd "$TMP/none" && python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' 'git commit -m "gh pr merge 문서"' | bash "$HOOKS/block-dangerous-bash.sh" 2>/dev/null)
[ -z "$out" ] && ok "따옴표 안 gh pr merge 는 그냥 통과" || bad "오탐" "커밋 메시지에서 ask"

# ── 케이스 3: tdd-guard 는 harness.json 만으로 판정한다 ──────────────────────
# ── 케이스 2-c: 운영 DB — harness.json guard.prodDb 가 있을 때만 (2026-10-13) ──
# 이름(PROD)이 아니라 디스크의 설정 파일에서 호스트를 읽어 가른다. harness.json 에는 파일·키 위치만 적고 값은 옮기지 않는다.
# stage 프로필이 운영 DB 를 가리킨 레포가 있었다 → 같은 호스트를 가리키는 프로필은 자동으로 운영 취급.
printf '\n[2-c] 운영 DB — 쓰기 SQL · 운영 프로필·스위치 실행 차단, 조회 허용\n'
R="$TMP/prod/src/main/resources"; mkdir -p "$R" "$TMP/prod/.claude" && (cd "$TMP/prod" && git init -q)
printf 'spring:\n  datasource:\n    url: jdbc:mysql://prod-db.example.com:3306/app\n' > "$R/application-prod.yml"
printf 'spring:\n  datasource:\n    url: jdbc:mysql://prod-db.example.com:3306/app\n' > "$R/application-stage.yml"
printf 'spring:\n  datasource:\n    url: jdbc:mysql://localhost:3306/app\n' > "$R/application-local.yml"
printf 'DEV_X_HOST=dev-db.example.com\nPROD_X_HOST=prod2.example.com\n' > "$TMP/prod/.env"
cat > "$TMP/prod/.claude/harness.json" <<JSON
{ "guard": { "prodDb": { "from": ["spring:prod", "env:.env:PROD_X_HOST"], "switches": ["NODE_ENV=production"] } } }
JSON
bdb() { # $1=dir $2=command → exit code
  python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$2" \
    | (cd "$1" && bash "$HOOKS/block-dangerous-bash.sh" >/dev/null 2>&1); echo $?
}
for c in 'mysql -h prod-db.example.com -e "DELETE FROM users WHERE id=1"' \
         'psql "host=prod2.example.com dbname=app" -c "drop table t"' \
         'mysql -h "$PROD_X_HOST" -e "UPDATE t SET a=1"' \
         'mysql -h prod-db.example.com app < fix.sql' \
         "./gradlew bootRun --args='--spring.profiles.active=stage'" \
         'SPRING_PROFILES_ACTIVE=prod ./gradlew test' \
         'java -Dspring.profiles.active=dev,stage -jar app.jar' \
         'NODE_ENV=production npm run migrate' \
         'psql -h prod-db.example.com -f fix.sql' \
         'cat fix.sql | mysql -h prod-db.example.com app' \
         'mysql -h prod-db.example.com app <<EOF' \
         'mysql -h prod-db.example.com app' \
         'mysql -h PROD-DB.example.com -e "REPLACE INTO t VALUES (1)"' \
         'mysql -h prod-db.example.com -e "CREATE TABLE x (a int)"' \
         'mysql -h prod-db.example.com -e "DEL""ETE FROM t"' \
         'mysql -h prod-db.example.com -e "source fix.sql"' \
         'mysql -h prod-db.example.com -e "SELECT 1; DELETE FROM t"' \
         "mysql -h prod-db.example.com -e \"SELECT * FROM t INTO OUTFILE '/tmp/x'\"" \
         'mysql -h prod-db.example.com -e "SELECT * FROM t FOR UPDATE"' \
         'SPRING_DATASOURCE_URL=jdbc:mysql://prod-db.example.com:3306/app ./gradlew bootRun' \
         'SPRING_PROFILES_INCLUDE=stage ./gradlew bootRun' \
         'NODE_ENV="production" npm run migrate'; do
  [ "$(bdb "$TMP/prod" "$c")" = "2" ] && ok "차단: $c" || bad "운영 DB 통과" "$c"
done
for c in 'mysql -h prod-db.example.com -e "SELECT count(*) FROM users"' \
         'mysql -h prod-db.example.com -e "SELECT * FROM t WHERE n < 3"' \
         'mysql -h localhost -e "DROP TABLE t"' \
         'mysql -h "$DEV_X_HOST" -e "DELETE FROM t"' \
         "./gradlew bootRun --args='--spring.profiles.active=local'" \
         'git commit -m "stage 프로필 설명"' \
         "mysql -h prod-db.example.com -e \"SELECT * FROM logs WHERE action='delete'\"" \
         'mysql -h prod-db.example.com -e "SHOW TABLES"' \
         'mysql -h prod-db.example.com -e "SELECT 1" | head -5' \
         'git commit -m "drop spring.profiles.active=prod default"' \
         'grep -rn "NODE_ENV=production" src' \
         'grep -rn PROD_X_HOST src'; do
  [ "$(bdb "$TMP/prod" "$c")" = "0" ] && ok "허용: $c" || bad "오탐" "$c"
done
[ "$(bdb "$TMP/none" 'mysql -h prod-db.example.com -e "DELETE FROM users"')" = "0" ] \
  && ok "guard 없는 레포 — 판별 근거가 없어 통과" || bad "오탐" "guard 없는 레포에서 막았다"
# yml 이 값 대신 \${VAR} 를 쓰고 값은 .env 에 있는 Spring 레포
R2="$TMP/prod2/server/src/main/resources"; mkdir -p "$R2" "$TMP/prod2/.claude" && (cd "$TMP/prod2" && git init -q)
printf 'spring:\n  datasource:\n    url: ${SPRING_DATASOURCE_URL}\n' > "$R2/application-prod.yml"
printf 'SPRING_DATASOURCE_URL=jdbc:postgresql://pg-prod.example.com:5432/x\n' > "$TMP/prod2/server/.env"
echo '{ "guard": { "prodDb": { "from": ["spring:prod"] } } }' > "$TMP/prod2/.claude/harness.json"
[ "$(bdb "$TMP/prod2" 'psql -h pg-prod.example.com -c "delete from t"')" = "2" ] \
  && ok "yml 의 \${VAR} 를 .env 에서 풀어 차단" || bad "env 주입 통과" "SPRING_DATASOURCE_URL 을 못 풀었다"
# jdbc-url(Hikari)·앞에 외부 API url 이 있는 yml — 외부 url 을 운영 DB 로 잡지 않는다
printf 'api:\n  url: https://api.example.org/v1\nspring:\n  datasource:\n    hikari:\n      jdbc-url: jdbc:mysql://hk-prod.example.com/x\n' > "$R2/application-prod.yml"
[ "$(bdb "$TMP/prod2" 'mysql -h hk-prod.example.com -e "DELETE FROM t"')" = "2" ] \
  && ok "jdbc-url 을 읽어 차단" || bad "jdbc-url 통과" "hikari jdbc-url 을 못 읽었다"
[ "$(bdb "$TMP/prod2" 'curl -X DELETE https://api.example.org/v1/x')" = "0" ] \
  && ok "외부 API url 은 운영 DB 로 안 본다" || bad "오탐" "외부 API url 을 운영 DB 로 잡았다"
# 판별 스크립트가 죽으면 막는다(fail-closed) — 10-13 리뷰: 조용히 통과했다
cp "$TMP/prod2/.claude/harness.json" "$TMP/prod2/hj.bak"
echo '{ "guard": { "prodDb": { "from": 123 } } }' > "$TMP/prod2/.claude/harness.json"
[ "$(bdb "$TMP/prod2" 'ls')" = "2" ] && ok "가드 오류 → 차단" || bad "fail-open" "prod_db.py 가 죽었는데 통과했다"
out=$(cd "$TMP/prod2" && printf '{}' | bash "$HOOKS/prod-db-check.sh" 2>/dev/null)
echo "$out" | grep -q '죽음' && ok "세션 시작 — 가드 오류를 알린다" || bad "조용히 꺼짐" "out=[$out]"
mv "$TMP/prod2/hj.bak" "$TMP/prod2/.claude/harness.json"
# 세션 시작 — 못 읽으면 소리 내서 꺼짐을 알린다. 값은 출력하지 않는다
ss() { (cd "$1" && printf '{}' | bash "$HOOKS/prod-db-check.sh" 2>/dev/null); }
[ -z "$(ss "$TMP/prod")" ] && ok "세션 시작 — 다 읽히면 무출력" || bad "소음" "$(ss "$TMP/prod")"
echo '{ "guard": { "prodDb": { "from": ["spring:nope", "env:.env:NOPE"] } } }' > "$TMP/prod2/.claude/harness.json"
out=$(ss "$TMP/prod2")
echo "$out" | grep -q '꺼짐' && ok "세션 시작 — 못 읽으면 '꺼짐' 알림" || bad "조용히 꺼짐" "out=[$out]"
echo "$out" | grep -q 'example.com' && bad "값 노출" "알림에 호스트가 찍혔다" || ok "알림에 호스트 값 없음"
[ -z "$(ss "$TMP/none")" ] && ok "guard 없는 레포 — 세션 시작 무출력" || bad "소음" "guard 없는 레포에서 떠든다"

# ── 케이스 2-d: phases_status — 상태 값 4개 · after 선행 점검 (2026-10-13) ──
printf '\n[2-d] phases_status — 허용 밖 상태 · 선행 미완료면 exit 1\n'
PS="$HOOKS/../skills/harness-run/scripts/phases_status.py"
mkdir -p "$TMP/ph/phases/be-a" "$TMP/ph/phases/fe-a" "$TMP/ph/phases/old" && (cd "$TMP/ph" && git init -q)
echo '{"phase":"be-a","docs":"docs/x","after":[],"steps":[{"step":1,"status":"completed"}]}' > "$TMP/ph/phases/be-a/index.json"
echo '{"phase":"fe-a","docs":"docs/x","after":["be-a"],"steps":[{"step":1,"status":"pending"}]}' > "$TMP/ph/phases/fe-a/index.json"
echo '{"phase":"old","steps":[{"step":1,"status":"done"}]}' > "$TMP/ph/phases/old/index.json"
(cd "$TMP/ph" && python3 "$PS" --check fe-a >/dev/null) && ok "선행 completed — 점검 통과" || bad "점검" "선행이 끝났는데 막았다"
(cd "$TMP/ph" && python3 "$PS" --check old >/dev/null) && bad "done 통과" "허용 밖 상태를 못 잡았다" || ok "status 'done' — exit 1"
echo '{"phase":"be-a","docs":"docs/x","after":[],"steps":[{"step":1,"status":"error"}]}' > "$TMP/ph/phases/be-a/index.json"
(cd "$TMP/ph" && python3 "$PS" --check fe-a >/dev/null) && bad "선행 미완료 통과" "be-a 가 error 인데 fe-a 를 허용했다" || ok "선행 미완료 — exit 1"
out=$(cd "$TMP/ph" && python3 "$PS")
printf '%s' "$out" | grep -A2 '^docs/x' | head -3 | sed -n 2p | grep -q 'be-a' && ok "현황 — docs 로 묶고 선행이 먼저" || bad "현황 순서" "$out"

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
# 커밋 25건이 하루에 몰리면 활발한 레포가 아니다(활동일 3일 미만) — 채점하지 않는다
mkdir -p "$TMP/burst/.claude" && (cd "$TMP/burst" && git init -q && printf '{}' > .claude/harness.json && git add -A \
  && for i in $(seq 25); do git -c user.email=t@t -c user.name=t commit -q --allow-empty -m "c$i"; done)
(cd "$TMP/burst" && printf '{}' | bash "$HOOKS/weekly-readiness-check.sh" >/dev/null 2>&1)
[ ! -d "$TMP/burst/.claude/reports" ] && ok "커밋이 하루에 몰림 — 채점 안 함" || bad "오탐" "활동일 1일인데 채점했다"
(cd "$TMP/on" && spread_commits 25)
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
  && spread_commits 22)
mkdir -p "$TMP/rd/.claude/reports/2000-01-01" && cp "$(ls "$TMP"/on/.claude/reports/*/ai-readiness-score.json | head -1)" "$TMP/rd/.claude/reports/2000-01-01/"
(cd "$TMP/rd" && printf '{}' | bash "$HOOKS/weekly-readiness-check.sh" >/dev/null 2>&1)
[ -f "$TMP/rd/.claude/reports/$(date +%F)/ai-readiness-score.json" ] && ok "리포트 있음 + 14일 지남·활발한 레포 — 다시 채점" || bad "재채점 안 됨" "$(ls "$TMP/rd/.claude/reports")"
# 마지막 채점이 14일 안이면 활발해도 다시 재지 않는다
recent="$(python3 -c "import datetime; print(datetime.date.today()-datetime.timedelta(days=5))")"
rm -rf "$TMP/rd/.claude/reports/$(date +%F)" && mkdir -p "$TMP/rd/.claude/reports/$recent" \
  && cp "$TMP/rd/.claude/reports/2000-01-01/ai-readiness-score.json" "$TMP/rd/.claude/reports/$recent/"
(cd "$TMP/rd" && printf '{}' | bash "$HOOKS/weekly-readiness-check.sh" >/dev/null 2>&1)
[ ! -d "$TMP/rd/.claude/reports/$(date +%F)" ] && ok "마지막 채점 5일 전 — 14일 전이라 다시 안 잰다" || bad "조기 재채점" "14일 안인데 다시 쟀다"
rm -rf "$TMP/rd/.claude/reports/$recent"
# 채점이 실패하면 빈 날짜 폴더를 남기지 않는다 — 가짜 플러그인 루트(실패하는 score.py)로 돌린다
FAKE="$TMP/fakeplugin"; mkdir -p "$FAKE/hooks" "$FAKE/skills/ai-readiness-cartography/scripts"
cp "$HOOKS/weekly-readiness-check.sh" "$FAKE/hooks/"; cp -R "$HOOKS/lib" "$FAKE/hooks/"; printf 'import sys; sys.exit(3)\n' > "$FAKE/skills/ai-readiness-cartography/scripts/score.py"
rm -rf "$TMP/rd/.claude/reports/$(date +%F)"
(cd "$TMP/rd" && printf '{}' | bash "$FAKE/hooks/weekly-readiness-check.sh" >/dev/null 2>&1)
[ -d "$TMP/rd/.claude/reports/$(date +%F)" ] && bad "빈 폴더" "채점 실패인데 날짜 폴더가 남았다" || ok "채점 실패 — 빈 날짜 폴더를 지운다"
# 비동기 경로 — SYNC 없이 돌리면 채점을 기다리지 않고 바로 끝난다(세션 시작을 막지 않는다)
unset CLAUDE_READINESS_SYNC
rm -rf "$TMP/rd/.claude/reports/$(date +%F)"
s=$(python3 -c 'import time;print(time.time())'); (cd "$TMP/rd" && printf '{}' | bash "$FAKE/hooks/weekly-readiness-check.sh" >/dev/null 2>&1)
e=$(python3 -c "import time;print(time.time()-$s)")
python3 -c "import sys; sys.exit(0 if $e < 3 else 1)" && ok "비동기 — 훅은 바로 끝난다(${e%.*}s)" || bad "막힘" "훅이 ${e}s 걸렸다"

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
# ── 케이스 6-c: brain-sync-auto — opt-in · 경로 · 활발한 레포 · _brain/wiki 변경 (2026-10-12) ──
printf '\n[6-c] brain-sync-auto — 조건을 다 넘을 때만 띄운다\n'
export CLAUDE_BRAIN_SYNC_SYNC=1
export CLAUDE_BRAIN_SYNC_LOG_DIR="$TMP"   # 실제 /tmp 에 테스트 로그를 남기지 않는다
FAKECL="$TMP/fake-claude"; printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s/claude-calls"\n' "$TMP" > "$FAKECL"; chmod +x "$FAKECL"
export CLAUDE_BRAIN_SYNC_BIN="$FAKECL"
calls() { wc -l < "$TMP/claude-calls" 2>/dev/null | tr -d ' ' || echo 0; }
bs() { (cd "$TMP/bs" && printf '{}' | bash "$HOOKS/brain-sync-auto.sh" 2>&1); }
mkdir -p "$TMP/vault/2_LLMWiki/wiki/projects" "$TMP/bs/.claude" "$TMP/bs/_brain/wiki"
printf '{"brainSync":{"wikiPath":"%s","targetFolder":"2_LLMWiki/wiki/projects/bs"}}' "$TMP/vault" > "$TMP/bs/.claude/harness.json"
(cd "$TMP/bs" && git init -q && echo a > _brain/wiki/a.md && git add -A && spread_commits 22)
out=$(bs); [ -z "$out" ] && [ "$(calls)" = "0" ] && ok "opt-in 안 함 — 안 띄움·무출력" || bad "opt-in" "calls=$(calls) out=[$out]"
export CLAUDE_BRAIN_SYNC_AUTO=1
out=$(bs); [ -z "$out" ] && [ "$(calls)" = "1" ] && ok "첫 실행 — 띄움·무출력" || bad "첫 실행" "calls=$(calls) out=[$out]"
grep -q -- "brain-sync auto.*--add-dir $(cd "$TMP/vault" && pwd -P)" "$TMP/claude-calls" 2>/dev/null && ok "auto 인자 + vault --add-dir" || bad "인자" "$(cat "$TMP/claude-calls")"
rm -f "$CLAUDE_SKILL_HINTS_DIR"/*brain-sync-run
bs >/dev/null; [ "$(calls)" = "1" ] && ok "_brain/wiki 변경 없음 — 안 띄움" || bad "변경 없음" "calls=$(calls)"
(cd "$TMP/bs" && echo b > src.txt && git add -A && git -c user.email=t@t -c user.name=t commit -qm "code only")
bs >/dev/null; [ "$(calls)" = "1" ] && ok "코드만 바뀜 — 안 띄움" || bad "코드만" "calls=$(calls)"
(cd "$TMP/bs" && echo b >> _brain/wiki/a.md && git add -A && git -c user.email=t@t -c user.name=t commit -qm "brain")
bs >/dev/null; [ "$(calls)" = "2" ] && ok "_brain/wiki 바뀜 — 띄움" || bad "변경 감지" "calls=$(calls)"
(cd "$TMP/bs" && echo c >> _brain/wiki/a.md && git add -A && git -c user.email=t@t -c user.name=t commit -qm "brain2")
bs >/dev/null; [ "$(calls)" = "2" ] && ok "같은 날 두 번째 — 안 띄움" || bad "중복" "calls=$(calls)"
rm -f "$CLAUDE_SKILL_HINTS_DIR"/*brain-sync-run
CLAUDE_BRAIN_SYNC_AUTO_SKIP="x:bs" bs >/dev/null; [ "$(calls)" = "2" ] && ok "SKIP 목록 — 안 띄움" || bad "SKIP" "calls=$(calls)"
printf '{"brainSync":{"wikiPath":"%s","targetFolder":"wiki/projects/bs"}}' "$TMP/vault" > "$TMP/bs/.claude/harness.json"
bs >/dev/null; [ "$(calls)" = "2" ] && ok "옛 폴더 구조(부모 없음) — 안 띄움" || bad "경로 확인" "calls=$(calls)"
printf '{"brainSync":{"wikiPath":"%s","targetFolder":"2_LLMWiki/wiki/projects/bs"}}' "$TMP/vault" > "$TMP/bs/.claude/harness.json"
mkdir -p "$TMP/bsq/.claude" "$TMP/bsq/_brain/wiki" && cp "$TMP/bs/.claude/harness.json" "$TMP/bsq/.claude/" \
  && (cd "$TMP/bsq" && git init -q && echo a > _brain/wiki/a.md && git add -A && git -c user.email=t@t -c user.name=t commit -qm one)
(cd "$TMP/bsq" && printf '{}' | bash "$HOOKS/brain-sync-auto.sh" >/dev/null 2>&1); [ "$(calls)" = "2" ] && ok "비활성 레포 — 안 띄움" || bad "활발 게이트" "calls=$(calls)"
unset CLAUDE_BRAIN_SYNC_SYNC CLAUDE_BRAIN_SYNC_AUTO CLAUDE_BRAIN_SYNC_BIN CLAUDE_BRAIN_SYNC_LOG_DIR

printf '\n[6-b] learn-setup — _learn/ 수신함 · 로컬 제외 · 목록\n'
mkdir -p "$TMP/learn/.claude" && (cd "$TMP/learn" && git init -q && printf '{}' > .claude/harness.json && printf 'node_modules/\n' > .gitignore \
  && git add -A && git -c user.email=t@t -c user.name=t commit -qm init)
out=$(cd "$TMP/learn" && printf '{}' | bash "$HOOKS/learn-setup.sh" 2>&1)
[ -f "$TMP/learn/_learn/inbox.md" ] && ok "수신함 생성" || bad "수신함" "_learn/inbox.md 없음"
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "_learn/inbox.md" in d["hookSpecificOutput"]["additionalContext"]' 2>/dev/null \
  && ok "기록 지시를 additionalContext 로" || bad "지시" "JSON 이 아니거나 지시가 없다 out=[$out]"
echo "$out" | grep -q '_brain/wiki/' && ok "지시가 도메인은 _brain 으로 가른다" || bad "분기" "지시에 _brain 행선지가 없다"
echo "$out" | grep -q '안 옮긴 카드 0장' && ok "새 수신함은 0장(형식 예시는 세지 않는다)" || bad "카운트" "새 수신함인데 0장이 아니다"
echo "$out" | grep -q '학습 레벨: FE beginner · BE beginner · 인프라 beginner · 도메인 beginner' && ok "레벨 파일 없음 — 전부 beginner" || bad "레벨 기본값" "beginner 문구가 없다"
echo "$out" | grep -q 'docs/learning-level.md' && ok "레벨 형식 정본 경로를 넣는다" || bad "레벨 정본" "docs/learning-level.md 경로가 없다"
echo "$out" | grep -q '종류: 도메인' && ok "도메인 카드를 _learn 에 허용" || bad "도메인 카드" "지시에 종류: 도메인 이 없다"
printf '{"levels":{"fe":"intermediate","be":"advanced","infra":"이상한값"}}' > "$CLAUDE_LEARNING_LEVEL_FILE"
out=$(cd "$TMP/learn" && printf '{}' | bash "$HOOKS/learn-setup.sh" 2>&1)
echo "$out" | grep -q '학습 레벨: FE intermediate · BE advanced · 인프라 beginner · 도메인 beginner' && ok "레벨 파일 — 값 반영·빠진/틀린 값은 beginner" || bad "레벨 반영" "$(echo "$out" | grep -o '학습 레벨: [^(]*')"
echo "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && ok "레벨 넣어도 JSON 유효" || bad "레벨 JSON" "출력이 JSON 이 아니다"
printf 'not json' > "$CLAUDE_LEARNING_LEVEL_FILE"
out=$(cd "$TMP/learn" && printf '{}' | bash "$HOOKS/learn-setup.sh" 2>&1)
echo "$out" | grep -q '학습 레벨: FE beginner · BE beginner' && ok "깨진 레벨 파일 — beginner로" || bad "깨진 파일" "beginner이 아니다"
rm -f "$CLAUDE_LEARNING_LEVEL_FILE"
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
# 실패한 명령은 PostToolUseFailure 로만 온다(10-13 실측) → 두 이벤트 모두에 걸려 있어야 실패 반복도 센다
python3 -c 'import json,sys; h=json.load(open(sys.argv[1]))["hooks"]; sys.exit(0 if all(any("loop-lock" in x["command"] for e in h.get(k,[]) if e.get("matcher")=="Bash" for x in e["hooks"]) for k in ("PostToolUse","PostToolUseFailure")) else 1)' "$HOOKS/hooks.json" \
  && ok "loop-lock 이 PostToolUse·PostToolUseFailure 둘 다에 등록" || bad "실패 반복 미추적" "PostToolUseFailure 에 loop-lock 이 없다"
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

# 코드 상태가 같을 때만 센다 (2026-10-13) — 코드를 고치고 다시 돌리는 건 정상 수정 루프라 리셋한다.
# 성공·실패는 구분하지 않는다: PostToolUse 는 성공한 도구 호출에만 돈다는 것이 문서 예시로 보이는 동작이라 실패를 셀 수 없다.
rm -f "$TMP/on/.claude/.last-loop-lock"
[ "$(ll s4 'pnpm test')" = "0" ] && [ "$(ll s4 'pnpm test')" = "0" ] || bad "준비" "같은 상태 2회가 막혔다"
printf 'edit\n' >> "$TMP/on/loop-edit.ts"
[ "$(ll s4 'pnpm test')" = "0" ] && ok "코드가 바뀌면 리셋 — 고친 뒤 3번째 실행은 통과" || bad "수정 루프 차단" "코드가 바뀌었는데 막았다"
[ "$(ll s4 'pnpm test')" = "0" ] && [ "$(ll s4 'pnpm test')" = "2" ] \
  && ok "같은 코드로 3번째 — exit 2" || bad "무의미 반복" "코드가 그대로인데 3번째를 안 막았다"
printf 'edit2\n' >> "$TMP/on/loop-edit.ts"
[ "$(ll s4 'pnpm test')" = "0" ] && ok "추적 안 되는 파일 내용이 바뀌어도 리셋" || bad "untracked 변경" "새 파일 내용 변경을 못 봤다"
rm -f "$TMP/on/loop-edit.ts" "$TMP/on/.claude/.last-loop-lock"

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


# ── 케이스 10: 문서 정합 — 지운·바꾼 스킬 이름과 옛 결정 경로가 지시문에 남지 않는다 (2026-10-11) ──
# 규칙을 한 곳만 바꾸고 둘레(sdd·훅 지시문)에 옛 규칙이 남던 것을 리뷰가 두 번 잡았다.
printf '\n[10] 문서 정합\n'
ROOT="$(cd "$HOOKS/.." && pwd)"
left=$(grep -rnE '`(grilling|why-logictree|brain-intake|find-skills|harness-new)`|claude-harness:brain-recall|decisions/<기능>' \
  "$ROOT/skills" "$ROOT/agents" "$ROOT/hooks" "$ROOT/templates" 2>/dev/null | grep -v '/hooks/test.sh:' | grep -vE '삭제|당시 기준|합쳤다|합침|원형|2026-10-11 \|')   # 업그레이드 이름표 행(| 날짜 |)은 옛 이름이 정상
[ -z "$left" ] && ok "지운 스킬·옛 결정 경로 참조 0" || bad "남은 참조" "$(echo "$left" | head -3)"
# 설계 3장 → REFLECT 정리 (0.12.4): why-plan 은 _brain 에 직접 쓰지 않고, sdd REFLECT 가 세 장을 보고 옮긴다.
direct=$(grep -nE '`why-plan`이 `?decisions|why-plan`?이 남긴다|→ `_brain/wiki/decisions/<주제>.md` · `_learn`' \
  "$ROOT/skills" "$ROOT/templates" -r 2>/dev/null)
grep -q '`_brain` 정리' "$ROOT/skills/sdd/SKILL.md" && grep -q 'ARCHITECTURE.md\*\* — PRD 확정 직후' "$ROOT/skills/why-plan/SKILL.md" && [ -z "$direct" ] \
  && ok "why-plan 은 세 장 · _brain 은 REFLECT 정리" || bad "설계 3장 흐름" "${direct:-sdd REFLECT 정리 또는 why-plan ARCHITECTURE 단계 없음}"

printf '\n──────────────\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
