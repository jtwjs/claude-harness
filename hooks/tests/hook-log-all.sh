# 나머지 훅 8개도 끝나는 모든 경로에서 발화 기록을 정확히 한 줄 남긴다(ADR-018 B-4 · B-11). test.sh 가 source 한다.
# 형식은 hook-log-exits.sh 와 같다 — 호출마다 기록 파일을 따로 줘서 그 호출이 남긴 줄만 센다.
# HOME 도 임시 폴더로 둔다: 실제 ~/.claude(기록 · 원장 · 계정 목록)를 읽거나 쓰지 않게.
# 막은 경우는 결과 이름으로 가른다 — blocked(막음) · ask(사람 확인) · warn(알림) · 그 밖은 건너뜀/통과.
printf '\n[hook-log-all] 훅 8개 — 끝나는 경로마다 기록 한 줄\n'
_ha_d="$TMP/_ha_"; rm -rf "$_ha_d"
mkdir -p "$_ha_d/home" "$_ha_d/plain" "$_ha_d/nocfg" "$_ha_d/repo/.claude" "$_ha_d/repo/src" "$_ha_d/bin" "$_ha_d/fake"
(cd "$_ha_d/nocfg" && git init -q)
(cd "$_ha_d/repo" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)
_ha_cfg() { printf '%s' "$1" > "$_ha_d/repo/.claude/harness.json"; }
_ha_cfg '{}'
for _ha_c in git cat dirname date basename; do ln -sf "$(command -v "$_ha_c")" "$_ha_d/bin/$_ha_c"; done   # python3 만 없는 PATH
_ha_run() { # $1 경우 · $2 폴더 · $3 훅 파일 · $4 stdin → 종료 코드. 기록은 $_ha_d/<경우>.tsv 에만. 추가 env 는 HA_ENV 로
  (cd "$2" && printf '%s' "$4" | env HOME="$_ha_d/home" CLAUDE_HARNESS_HOOK_LOG="$_ha_d/$1.tsv" \
    GIT_CEILING_DIRECTORIES="$_ha_d" ${HA_ENV:-} bash "$HOOKS/$3" >"$_ha_d/$1.out" 2>&1); echo $?
}
_ha_nopy() { # $1 경우 · $2 폴더 · $3 훅 파일 — python3 없는 PATH
  (cd "$2" && printf '{}' | HOME="$_ha_d/home" PATH="$_ha_d/bin" CLAUDE_HARNESS_HOOK_LOG="$_ha_d/$1.tsv" "$BASH" "$HOOKS/$3" >/dev/null 2>&1); echo $?
}
_ha_one() { # $1 경우 · $2 훅 이름 · $3 결과 — 그 호출의 기록이 정확히 한 줄이고 훅 · 결과가 맞나
  local f="$_ha_d/$1.tsv" n got
  n=$(cat "$f" 2>/dev/null | awk 'END{print NR}')
  got=$(awk -F'\t' '{printf "%s %s|", $3, $4}' "$f" 2>/dev/null)
  if [ "$n" = "1" ] && [ "$got" = "$2 $3|" ]; then ok "$2 $1 → $3 한 줄"; else bad "$2 $1" "기록 ${n}줄 [$got] (기대: $3 한 줄)"; fi
}
_ha_code() { [ "$1" = "$2" ] && ok "$3 — exit $2 그대로" || bad "$3" "exit=$1 (기대 $2)"; }

# ── auto-format (PostToolUse[Write|Edit]) — prettier · ktlint 는 가짜로(환경에 따라 결과가 갈리지 않게) ──
_ha_fp() { printf '{"tool_input":{"file_path":"%s"}}' "$1"; }
mkdir -p "$_ha_d/repo/node_modules"; : > "$_ha_d/repo/node_modules/x.ts"; : > "$_ha_d/repo/src/a.ts"; : > "$_ha_d/repo/src/a.txt"; : > "$_ha_d/repo/src/a.kt"
_ha_run af-norepo "$_ha_d/plain" auto-format.sh "$(_ha_fp "$_ha_d/plain/a.ts")" >/dev/null; _ha_one af-norepo auto-format norepo
_ha_run af-nocfg "$_ha_d/nocfg" auto-format.sh "$(_ha_fp "$_ha_d/nocfg/a.ts")" >/dev/null; _ha_one af-nocfg auto-format nocfg
_ha_run af-noinput "$_ha_d/repo" auto-format.sh '{}' >/dev/null; _ha_one af-noinput auto-format noinput
_ha_run af-nofile "$_ha_d/repo" auto-format.sh "$(_ha_fp "$_ha_d/repo/src/none.ts")" >/dev/null; _ha_one af-nofile auto-format nofile
_ha_run af-excluded "$_ha_d/repo" auto-format.sh "$(_ha_fp "$_ha_d/repo/node_modules/x.ts")" >/dev/null; _ha_one af-excluded auto-format excluded
_ha_run af-ignore "$_ha_d/repo" auto-format.sh "$(_ha_fp "$_ha_d/repo/src/a.txt")" >/dev/null; _ha_one af-ignore auto-format ignore
printf '#!/bin/sh\nexit 0\n' > "$_ha_d/fake/npx"; printf '#!/bin/sh\nexit 0\n' > "$_ha_d/fake/ktlint"; chmod +x "$_ha_d/fake/npx" "$_ha_d/fake/ktlint"
HA_ENV="PATH=$_ha_d/fake:$PATH" _ha_run af-formatted "$_ha_d/repo" auto-format.sh "$(_ha_fp "$_ha_d/repo/src/a.ts")" >/dev/null; _ha_one af-formatted auto-format formatted
HA_ENV="PATH=$_ha_d/fake:$PATH" _ha_run af-kt "$_ha_d/repo" auto-format.sh "$(_ha_fp "$_ha_d/repo/src/a.kt")" >/dev/null; _ha_one af-kt auto-format formatted
printf '#!/bin/sh\nexit 1\n' > "$_ha_d/fake/npx"
HA_ENV="PATH=$_ha_d/fake:$PATH" _ha_run af-nofmt "$_ha_d/repo" auto-format.sh "$(_ha_fp "$_ha_d/repo/src/a.ts")" >/dev/null; _ha_one af-nofmt auto-format nofmt
rm -rf "$_ha_d/repo/node_modules" "$_ha_d/repo/src/a.txt" "$_ha_d/repo/src/a.kt"

# ── block-dangerous-bash (PreToolUse[Bash]) — 동작은 그대로, 기록만 ──
_ha_cmd() { python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$1"; }
_ha_code "$(_ha_nopy bd-nopython "$_ha_d/plain" block-dangerous-bash.sh)" 0 "block-dangerous-bash nopython"; _ha_one bd-nopython block-dangerous-bash nopython
_ha_run bd-noinput "$_ha_d/plain" block-dangerous-bash.sh '{}' >/dev/null; _ha_one bd-noinput block-dangerous-bash noinput
_ha_c=$(_ha_run bd-deny "$_ha_d/plain" block-dangerous-bash.sh "$(_ha_cmd 'rm -rf /')"); _ha_one bd-deny block-dangerous-bash blocked
_ha_code "$_ha_c" 2 "block-dangerous-bash deny"
grep -q '차단됨' "$_ha_d/bd-deny.out" && ok "block-dangerous-bash deny — 차단 메시지 그대로" || bad "block-dangerous-bash deny" "메시지 없음"
_ha_c=$(_ha_run bd-ask "$_ha_d/plain" block-dangerous-bash.sh "$(_ha_cmd 'gh pr merge 1 --squash')"); _ha_one bd-ask block-dangerous-bash ask
_ha_code "$_ha_c" 0 "block-dangerous-bash ask"
grep -q '"permissionDecision":"ask"' "$_ha_d/bd-ask.out" && ok "block-dangerous-bash ask — 확인 요청 그대로" || bad "block-dangerous-bash ask" "ask 출력 없음"
printf 'jtwjs jtwjs\n' > "$_ha_d/gh-accounts.txt"
_ha_c=$(HA_ENV="CLAUDE_GH_ACCOUNTS=$_ha_d/gh-accounts.txt CLAUDE_GH_ACTIVE=other" _ha_run bd-account "$_ha_d/plain" block-dangerous-bash.sh "$(_ha_cmd 'gh issue create -R jtwjs/x --title t')")
_ha_one bd-account block-dangerous-bash blocked; _ha_code "$_ha_c" 2 "block-dangerous-bash gh 계정"
_ha_run bd-norepo "$_ha_d/plain" block-dangerous-bash.sh "$(_ha_cmd 'git status')" >/dev/null; _ha_one bd-norepo block-dangerous-bash pass
_ha_run bd-nocfg "$_ha_d/nocfg" block-dangerous-bash.sh "$(_ha_cmd 'git status')" >/dev/null; _ha_one bd-nocfg block-dangerous-bash pass
_ha_run bd-pass "$_ha_d/repo" block-dangerous-bash.sh "$(_ha_cmd 'git status')" >/dev/null; _ha_one bd-pass block-dangerous-bash pass
_ha_cfg '{"guard":{"prodDb":{"from":[],"switches":["NODE_ENV=production"]}}}'
_ha_c=$(_ha_run bd-prod "$_ha_d/repo" block-dangerous-bash.sh "$(_ha_cmd 'NODE_ENV=production npm run migrate')"); _ha_one bd-prod block-dangerous-bash blocked
_ha_code "$_ha_c" 2 "block-dangerous-bash 운영 DB"
_ha_cfg '{}'

# ── tdd-guard (PreToolUse[Write|Edit]) ──
_ha_tw() { python3 -c 'import json,sys; print(json.dumps({"tool_input":{"file_path":sys.argv[1],"content":"function f() {}"}}))' "$1"; }
_ha_run tg-norepo "$_ha_d/plain" tdd-guard.sh "$(_ha_tw "$_ha_d/plain/a.ts")" >/dev/null; _ha_one tg-norepo tdd-guard norepo
_ha_run tg-nocfg "$_ha_d/nocfg" tdd-guard.sh "$(_ha_tw "$_ha_d/nocfg/a.ts")" >/dev/null; _ha_one tg-nocfg tdd-guard nocfg
_ha_code "$(_ha_nopy tg-nopython "$_ha_d/repo" tdd-guard.sh)" 0 "tdd-guard nopython"; _ha_one tg-nopython tdd-guard nopython
_ha_run tg-noinput "$_ha_d/repo" tdd-guard.sh '' >/dev/null; _ha_one tg-noinput tdd-guard noinput
_ha_run tg-badinput "$_ha_d/repo" tdd-guard.sh 'not json' >/dev/null; _ha_one tg-badinput tdd-guard badinput
_ha_run tg-off "$_ha_d/repo" tdd-guard.sh "$(_ha_tw "$_ha_d/repo/src/a.ts")" >/dev/null; _ha_one tg-off tdd-guard off
_ha_cfg '{"tdd":{"enabled":true,"include":["src/*"]}}'
_ha_run tg-ignore "$_ha_d/repo" tdd-guard.sh "$(_ha_tw "$_ha_d/repo/lib.ts")" >/dev/null; _ha_one tg-ignore tdd-guard ignore
: > "$_ha_d/repo/src/b.test.ts"
_ha_run tg-paired "$_ha_d/repo" tdd-guard.sh "$(_ha_tw "$_ha_d/repo/src/b.ts")" >/dev/null; _ha_one tg-paired tdd-guard paired
_ha_c=$(_ha_run tg-blocked "$_ha_d/repo" tdd-guard.sh "$(_ha_tw "$_ha_d/repo/src/c.ts")"); _ha_one tg-blocked tdd-guard blocked
_ha_code "$_ha_c" 0 "tdd-guard blocked"
grep -q '"permissionDecision": "deny"' "$_ha_d/tg-blocked.out" && ok "tdd-guard blocked — deny 출력 그대로" || bad "tdd-guard blocked" "[$(cat "$_ha_d/tg-blocked.out")]"
rm -f "$_ha_d/repo/src/b.test.ts"; _ha_cfg '{}'

# ── prod-db-check (SessionStart) ──
_ha_code "$(_ha_nopy pc-nopython "$_ha_d/repo" prod-db-check.sh)" 0 "prod-db-check nopython"; _ha_one pc-nopython prod-db-check nopython
_ha_run pc-norepo "$_ha_d/plain" prod-db-check.sh '{}' >/dev/null; _ha_one pc-norepo prod-db-check norepo
_ha_run pc-nocfg "$_ha_d/nocfg" prod-db-check.sh '{}' >/dev/null; _ha_one pc-nocfg prod-db-check nocfg
_ha_run pc-clean "$_ha_d/repo" prod-db-check.sh '{}' >/dev/null; _ha_one pc-clean prod-db-check clean
_ha_cfg '{"guard":{"prodDb":{"from":["spring:nope"]}}}'
_ha_run pc-warn "$_ha_d/repo" prod-db-check.sh '{}' >/dev/null; _ha_one pc-warn prod-db-check warn
_ha_cfg '{}'

# ── cadence-reminder (SessionStart) ──
_ha_run cr-norepo "$_ha_d/plain" cadence-reminder.sh '{}' >/dev/null; _ha_one cr-norepo cadence-reminder norepo
_ha_run cr-nocfg "$_ha_d/nocfg" cadence-reminder.sh '{}' >/dev/null; _ha_one cr-nocfg cadence-reminder nocfg
_ha_run cr-clean "$_ha_d/repo" cadence-reminder.sh '{}' >/dev/null; _ha_one cr-clean cadence-reminder clean
seq 90 > "$_ha_d/repo/CLAUDE.md"   # 비대 축(80줄 초과)
_ha_run cr-warn "$_ha_d/repo" cadence-reminder.sh '{}' >/dev/null; _ha_one cr-warn cadence-reminder warn
rm -f "$_ha_d/repo/CLAUDE.md"

# ── weekly-readiness-check (SessionStart) ──
_ha_run wr-norepo "$_ha_d/plain" weekly-readiness-check.sh '{}' >/dev/null; _ha_one wr-norepo weekly-readiness-check norepo
_ha_run wr-nocfg "$_ha_d/nocfg" weekly-readiness-check.sh '{}' >/dev/null; _ha_one wr-nocfg weekly-readiness-check nocfg
_ha_code "$(_ha_nopy wr-nopython "$_ha_d/repo" weekly-readiness-check.sh)" 0 "weekly-readiness-check nopython"; _ha_one wr-nopython weekly-readiness-check nopython
_ha_run wr-clean "$_ha_d/repo" weekly-readiness-check.sh '{}' >/dev/null; _ha_one wr-clean weekly-readiness-check clean
mkdir -p "$_ha_d/repo/.claude/reports/2026-01-01" "$_ha_d/repo/.claude/reports/2026-01-02"
echo '{"total":80,"categories":{"a":{"name":"A","score":10}}}' > "$_ha_d/repo/.claude/reports/2026-01-01/ai-readiness-score.json"
echo '{"total":70,"categories":{"a":{"name":"A","score":5}}}' > "$_ha_d/repo/.claude/reports/2026-01-02/ai-readiness-score.json"
_ha_run wr-warn "$_ha_d/repo" weekly-readiness-check.sh '{}' >/dev/null; _ha_one wr-warn weekly-readiness-check warn
rm -rf "$_ha_d/repo/.claude/reports"
mkdir -p "$_ha_d/active/.claude" && echo '{}' > "$_ha_d/active/.claude/harness.json" && (cd "$_ha_d/active" && git init -q && spread_commits 21)
HA_ENV="CLAUDE_READINESS_SYNC=1" _ha_run wr-scoring "$_ha_d/active" weekly-readiness-check.sh '{}' >/dev/null; _ha_one wr-scoring weekly-readiness-check scoring

# ── conductor-context (SessionStart) ──
_ha_code "$(_ha_nopy cc-nopython "$_ha_d/plain" conductor-context.sh)" 0 "conductor-context nopython"; _ha_one cc-nopython conductor-context nopython
HA_ENV="CLAUDE_CONDUCTOR_CONFIG=$_ha_d/none.json" _ha_run cc-noseat "$_ha_d/repo" conductor-context.sh '{}' >/dev/null; _ha_one cc-noseat conductor-context noseat
printf '{"seat":"%s","repos":[]}' "$_ha_d/nocfg" > "$_ha_d/conductor.json"
HA_ENV="CLAUDE_CONDUCTOR_CONFIG=$_ha_d/conductor.json" _ha_run cc-shown "$_ha_d/nocfg" conductor-context.sh '{}' >/dev/null; _ha_one cc-shown conductor-context shown
grep -q '지휘 현황' "$_ha_d/cc-shown.out" && ok "conductor-context shown — 현황 출력 그대로" || bad "conductor-context shown" "[$(cat "$_ha_d/cc-shown.out")]"

# ── hypothesis-gate (UserPromptSubmit) — 원장 쓰기 실패를 한 줄로(B-11) ──
_ha_ge="CLAUDE_HYPOTHESIS_LEDGER=$_ha_d/ledger.jsonl CLAUDE_HYPOTHESIS_GATE_CONFIG=$_ha_d/gate.json"
_ha_code "$(_ha_nopy hg-nopython "$_ha_d/repo" hypothesis-gate.sh)" 0 "hypothesis-gate nopython"; _ha_one hg-nopython hypothesis-gate nopython
HA_ENV="$_ha_ge" _ha_run hg-off "$_ha_d/repo" hypothesis-gate.sh '{"prompt":"x"}' >/dev/null; _ha_one hg-off hypothesis-gate off
mkdir -p "$_ha_d/repo/phases/t"; echo '{"steps":[{"step":1,"status":"pending"}]}' > "$_ha_d/repo/phases/t/index.json"
printf '{"threshold": 3}' > "$_ha_d/gate.json"
for _ha_i in 1 2 3; do
  printf '{"ts":"h%s","repo":"repo","task":"t","gate":"api","area":"BE","hyp":false,"rec":true,"acc":true,"why":false,"rebut":false,"skip":false}\n' "$_ha_i" >> "$_ha_d/ledger.jsonl"
done
HA_ENV="$_ha_ge" _ha_run hg-on "$_ha_d/repo" hypothesis-gate.sh '{"prompt":"x"}' >/dev/null; _ha_one hg-on hypothesis-gate on
rm -rf "$_ha_d/repo/phases"
: > "$_ha_d/afile"   # 원장 상위 경로가 파일 → 원장을 만들 수 없다
_ha_c=$(HA_ENV="CLAUDE_HYPOTHESIS_LEDGER=$_ha_d/afile/ledger.jsonl CLAUDE_HYPOTHESIS_GATE_CONFIG=$_ha_d/gate.json" _ha_run hg-unwritable "$_ha_d/repo" hypothesis-gate.sh '{"prompt":"x"}')
_ha_one hg-unwritable hypothesis-gate ledgerfail; _ha_code "$_ha_c" 0 "hypothesis-gate ledgerfail(원장 못 씀)"
grep -q '\[판정 지시\]' "$_ha_d/hg-unwritable.out" && ok "hypothesis-gate ledgerfail — 판정 지시는 그대로" || bad "hypothesis-gate ledgerfail" "판정 지시 없음"
# 옛 설치 폴더에서 lib/ledger.py 가 사라진 경우 — 훅이 안내하는 append 경로가 없다
mkdir -p "$_ha_d/old/hooks/lib"; cp "$HOOKS/hypothesis-gate.sh" "$_ha_d/old/hooks/"; cp "$HOOKS/lib/hook-log.sh" "$_ha_d/old/hooks/lib/"
_ha_c=$(cd "$_ha_d/repo" && printf '{}' | env HOME="$_ha_d/home" CLAUDE_HARNESS_HOOK_LOG="$_ha_d/hg-noledger.tsv" $_ha_ge bash "$_ha_d/old/hooks/hypothesis-gate.sh" >/dev/null 2>&1; echo $?)
_ha_one hg-noledger hypothesis-gate ledgerfail; _ha_code "$_ha_c" 0 "hypothesis-gate ledgerfail(ledger.py 없음)"
rm -rf "$_ha_d"
