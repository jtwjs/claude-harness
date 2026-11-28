#!/usr/bin/env bash
# 훅 회귀 테스트 — 기계가 판정할 수 있는 것만 본다.
#
# 왜 2케이스뿐인가: "리뷰 품질이 좋아졌나" 같은 것은 사람이 봐야 하고,
# 게이트가 될 수 없다. 여기 있는 것은 전부 exit code 로 갈리는 것들이다.
#
# 사용: bash hooks/test.sh                 # 전부
#       bash hooks/test.sh --since <커밋>  # 그 커밋 뒤 바뀐 파일에 걸린 묶음만(표 hooks/test-map.tsv, ADR-025)
set -uo pipefail

HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
export CLAUDE_SKILL_HINTS_DIR="$TMP/skill-hints"
export CLAUDE_HARNESS_HOOK_LOG="$TMP/hook-log.tsv"   # 훅 발화 기록이 실제 ~/.claude 에 쌓이지 않게
export CLAUDE_GH_ACCOUNTS="$TMP/gh-accounts.txt"   # block-dangerous-bash 가 실제 계정 목록을 읽지 않게
export CLAUDE_LEARN_SKIP="$TMP/learn-skip.txt"   # learn-setup 이 실제 제외 목록을 읽지 않게
export CLAUDE_LEARNING_LEVEL_FILE="$TMP/learning-level.json"   # learn-setup 이 실제 ~/.claude 레벨을 읽지 않게
export CLAUDE_CONDUCTOR_CONFIG="$TMP/conductor.json"   # 지휘 설정 — 실제 ~/.claude/conductor.json 을 읽지 않게 (기본은 없음)
export CLAUDE_VERIFY_PS="$TMP/ps.txt"   # 검사 상한 — 실제 ps 대신 이 파일 (기본은 없음 = 0개)
unset CLAUDE_VERIFY_MAX   # 사용자 settings.json env(예: 3)가 기본값 2 전제 테스트를 흔들지 않게 (2026-11-01)
export CLAUDE_LEARN_REPOS="$TMP/learn-repos.txt"   # learn-setup 이 실제 ~/.claude 목록에 쓰지 않게   # cadence-reminder 가 실제 ~/.claude 에 쓰지 않게
trap 'rm -rf "$TMP"' EXIT
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

ROOT="$(cd "$HOOKS/.." && pwd)"
# deny 패턴 검사 — 본문(2-b · 10)과 tests/rm-recursive-force.sh 가 같이 쓴다. 본문을 건너뛰는 부분 실행에서도 있게 여기 둔다
check_deny() { # $1=expect(0|2)  $2=command
  [ -d "$TMP/none/.git" ] || { mkdir -p "$TMP/none/src" && (cd "$TMP/none" && git init -q); }
  out=$(cd "$TMP/none" && printf '%s' "$2" | python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.stdin.read()}}))' \
        | bash "$HOOKS/block-dangerous-bash.sh" 2>&1); code=$?
  if [ "$code" = "$1" ]; then ok "exit $1: $2"; else bad "exit $code (기대 $1)" "$2"; fi
}

# ── 무엇을 돌릴지 ──────────────────────────────────────────────────────────────
# 묶음 셋: 본문(이 파일의 번호 케이스) · 러너 단위(tests/sdd-runner-unit.sh) · tests/*.sh 파일 하나하나. 기본은 전부다.
# HOOK_TEST_PART(CI 두 잡): runner = 러너 단위만 · hooks = 러너 단위를 뺀 나머지 전부. 두 값의 통과 수 합 = 기본 실행의 통과 수
# --since <커밋>(로컬 부분 실행, ADR-025): 고르기는 hooks/lib/test_pick.py 가 hooks/test-map.tsv 로 한다.
#   표에 없는 파일 · 묶음이 비는 파일 · 바뀐 파일 0개 · 읽을 수 없는 커밋이면 전부 돈다(놓치는 쪽으로 실패하지 않게)
HOOK_TEST_PART="${HOOK_TEST_PART:-}"
case "$HOOK_TEST_PART" in
  ''|hooks|runner) ;;
  *) printf 'HOOK_TEST_PART 는 hooks · runner 중 하나다 (받은 값: %s)\n' "$HOOK_TEST_PART" >&2; exit 2 ;;
esac
SINCE=""
case "${1:-}" in
  '') ;;
  --since) [ -n "${2:-}" ] || { printf -- '--since 뒤에 커밋이 없다\n' >&2; exit 2; }; SINCE="$2" ;;
  *) printf '모르는 인자: %s (쓸 수 있는 것: --since <커밋>)\n' "$1" >&2; exit 2 ;;
esac
if [ -n "$SINCE" ] && [ -n "$HOOK_TEST_PART" ]; then printf -- '--since 와 HOOK_TEST_PART 는 같이 쓰지 않는다\n' >&2; exit 2; fi
RUN_MAIN=1; RUN_RUNNER=1; RUN_TESTS="*"   # RUN_TESTS: * = tests/*.sh 전부, 아니면 고른 파일 이름을 공백으로 잇는다
case "$HOOK_TEST_PART" in
  runner) RUN_MAIN=0; RUN_TESTS="" ;;
  hooks) RUN_RUNNER=0 ;;
esac
if [ -n "$SINCE" ]; then
  _pick=$(cd "$ROOT" && python3 "$HOOKS/lib/test_pick.py" "$SINCE" "$HOOKS/test-map.tsv" "$HOOKS/tests")
  _why=$(printf '%s\n' "$_pick" | head -1 | cut -f2-)
  if [ "$(printf '%s\n' "$_pick" | head -1 | cut -f1)" = pick ]; then
    _sel=$(printf '%s\n' "$_pick" | tail -n +2)
    printf '%s\n' "$_sel" | grep -qx main || RUN_MAIN=0
    printf '%s\n' "$_sel" | grep -qx runner || RUN_RUNNER=0
    RUN_TESTS=$(printf '%s\n' "$_sel" | sed -n 's#^tests/##p' | tr '\n' ' ')
    printf '[부분 실행] --since %s · %s → %s\n' "$SINCE" "$_why" "$(printf '%s\n' "$_sel" | tr '\n' ' ')"
  else
    printf '[부분 실행] --since %s · 전부 돈다 — %s\n' "$SINCE" "${_why:-고르기 실패}"
  fi
fi

if [ "$RUN_MAIN" = 1 ]; then

# ── 케이스 1: 하네스가 없는 레포에서는 전부 조용해야 한다 ────────────────────
# 오탐 1건 = 신뢰 10건 손실. 남의 레포에서 떠드는 훅은 즉시 꺼진다.
printf '\n[1] 하네스 없는 레포 — 전부 exit 0 · 무출력\n'
mkdir -p "$TMP/none/src" && (cd "$TMP/none" && git init -q)
payload='{"tool_input":{"file_path":"'"$TMP"'/none/src/a.ts","command":"npm test"}}'
for h in auto-format tdd-guard todo-warn loop-lock validate-session-end cadence-reminder weekly-readiness-check prod-db-check; do
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
# push-no-verify — 인자 위치와 상관없이 막고, dry-run -n 은 통과 (ADR-021 I3)
for c in 'git push --no-verify' 'git push origin x --no-verify' 'git push --no-verify origin x' 'git push origin --no-verify x'; do check_deny 2 "$c"; done
for c in 'git push -n' 'git push origin x -n' 'git commit -m "git push --no-verify 금지 문서"' 'git push origin feature/no-verify-docs' 'git push origin x && echo --no-verify'; do check_deny 0 "$c"; done
# secret-file-read — 읽기 낱말은 명령 자리에서만 본다. 따옴표 본문 · --head 옵션 속 .env 글자는 통과 (#103)
for c in 'cat ".env"' 'head -5 .env.local' 'cat x | tail .env' 'echo hi && cat .env' 'X=$(cat .env)' "cat 'secrets/.env'" \
         'less ~/.ssh/id_rsa' 'cd app && cat .env' 'sudo cat .env' 'time cat .env' 'ls | xargs cat .env' 'env FOO=1 cat .env' \
         'nohup cat .env' 'sudo -u x cat .env' 'cd app && git status && cat .env' 'a | b | cat .env' 'echo a; echo b; cat .env' \
         'echo "$(cat .env)"' 'echo "`cat .env`"' 'FOO=1 cat .env' 'LC_ALL=C cat .env' '/bin/cat .env' '\cat .env' '{ cat .env; }' \
         "$(printf 'echo hi\ncat .env')"; do check_deny 2 "$c"; done
for c in 'orca orchestration ask --question "cat .env 가 막힌다"' 'gh pr create --head feature/x --title "fix: .env 오탐"' \
         'orca orchestration ask --question "막힘; cat .env 가 걸림"' "gh pr create --title 'x; cat .env 문서'" \
         'git log --oneline | head -5' 'env | head -5' 'git commit -m "time; xargs cat .env 문서"' \
         'xargs grep cat .env' 'gh pr create --title "use $(date) and cat .env"' 'echo ${X} cat .env' \
         'git log --format=%H | head -3'; do check_deny 0 "$c"; done
# PR 머지 — 훅이 PR 을 한 번 읽어 세 조건(규칙 파일 변경 0 · Risk Score 30 이하 · CI 체크 전부 통과)을 모두 채우면 확인 없이 통과,
# 하나라도 못 채우거나 PR 을 못 읽으면(읽기 실패 · Risk 없음 · 시간 초과) 사람 확인(ask) (ADR-026 D5 — 2026-10-13 dry-run 확인을 대체)
# 어떤 PR 이 머지될지 명령만으로 확실하지 않으면(단순한 `gh pr merge <번호> …` 하나가 아님) 묻는다. 통과해도 뒤 검사는 끝까지 돈다
_pm_d="$TMP/_pm_"; mkdir -p "$_pm_d/bin"
cat > "$_pm_d/bin/gh" <<'FAKEGH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PM_LOG"
[ -n "${PM_SLEEP:-}" ] && sleep "$PM_SLEEP"
[ -n "${PM_FAIL:-}" ] && { echo "no pr" >&2; exit 1; }
case "$1 $2" in
  "pr view") cat "$PM_JSON" ;;
  api*) cat "$PM_FILES" ;;
esac
FAKEGH
chmod +x "$_pm_d/bin/gh"
_pm_json() { # $1 본문 Risk 부분 · $2 바뀐 파일(쉼표, 「새>옛」이면 이름 바꾸기) · $3 체크 결론(쉼표, ctx: 접두는 StatusContext, 빈 값이면 체크 없음) · $4 changedFiles(빈 값이면 파일 수)
  python3 - "$1" "$2" "$3" "${4:-}" "$_pm_d/pr.json" "$_pm_d/files.tsv" <<'PMPY'
import json, sys
risk, files, checks, cf, out, ftsv = sys.argv[1], [f for f in sys.argv[2].split(",") if f], [c for c in sys.argv[3].split(",") if c], sys.argv[4], sys.argv[5], sys.argv[6]
roll = []
for i, c in enumerate(checks):
    if c.startswith("ctx:"):
        roll.append({"__typename": "StatusContext", "context": f"s{i}", "state": c[4:]})
    else:
        roll.append({"__typename": "CheckRun", "name": f"c{i}", "status": "IN_PROGRESS" if c == "PENDING" else "COMPLETED",
                     "conclusion": "" if c == "PENDING" else c})
open(out, "w").write(json.dumps({"body": f"## Summary\n- x\n\n{risk}\n\n본문", "changedFiles": int(cf) if cf else len(files), "statusCheckRollup": roll}))
open(ftsv, "w").write("".join(f.replace(">", "\t") + ("" if ">" in f else "\t") + "\n" for f in files))
PMPY
}
_pm_run() { # $1 명령 → 훅 출력
  (cd "$TMP/none" && python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' "$1" \
    | env PATH="$_pm_d/bin:$PATH" PM_LOG="$_pm_d/gh.log" PM_JSON="$_pm_d/pr.json" PM_FILES="$_pm_d/files.tsv" CLAUDE_GH_ACCOUNTS="$_pm_d/none.txt" \
      bash "$HOOKS/block-dangerous-bash.sh" 2>/dev/null)
}
_pm_ask() { # $1 이름 · $2 명령
  out=$(_pm_run "$2"); echo "$out" | grep -q '"permissionDecision":"ask"' && ok "ask: $1" || bad "머지 무확인" "$1 → [$out]"
}
_pm_pass() { # $1 이름 · $2 명령
  out=$(_pm_run "$2"); [ -z "$out" ] && ok "통과: $1" || bad "조건 통과인데 확인" "$1 → [$out]"
}
_pm_R='## ⚠️ Risk Score: 21/100 (낮음)'
_pm_json "$_pm_R" 'hooks/a.sh,docs/b.md' 'SUCCESS,ctx:SUCCESS'
: > "$_pm_d/gh.log"
_pm_pass "세 조건 통과(체크 둘 · 상태 하나)" 'gh pr merge 12 -R o/r --squash --match-head-commit abc'
grep -qx 'pr view 12 -R o/r --json body,changedFiles,statusCheckRollup' "$_pm_d/gh.log" \
  && grep -q '^api repos/o/r/pulls/12/files --paginate' "$_pm_d/gh.log" && ok "그 PR 번호 · 레포로 본문 · 파일 목록을 읽는다" || bad "읽기 인자" "[$(cat "$_pm_d/gh.log")]"
_pm_json '## ⚠️ Risk Score: 30/100 (낮음)' 'a.sh' 'SUCCESS'; _pm_pass "Risk 30(경계)" 'gh pr merge 12 --squash'
# 조건 하나씩 못 채움
_pm_json "$_pm_R" 'hooks/a.sh,.claude/rules/x.md' 'SUCCESS'; _pm_ask "rules 파일이 바뀐 PR" 'gh pr merge 12 --squash'
_pm_json "$_pm_R" 'apps/web/.claude/rules/a.md' 'SUCCESS'; _pm_ask "하위 폴더 rules 파일" 'gh pr merge 12 --squash'
_pm_json "$_pm_R" 'web/CLAUDE.md' 'SUCCESS'; _pm_ask "CLAUDE.md 가 바뀐 PR" 'gh pr merge 12 --squash'
_pm_json "$_pm_R" 'docs/x.md>.claude/rules/x.md' 'SUCCESS'; _pm_ask "rules 파일을 이름 바꿔 옮긴 PR(옛 경로)" 'gh pr merge 12 --squash'
_pm_json "$_pm_R" 'a.sh' 'SUCCESS' 150; _pm_ask "바뀐 파일 목록을 다 못 받음" 'gh pr merge 12 --squash'
_pm_json '## ⚠️ Risk Score: 31/100 (보통)' 'a.sh' 'SUCCESS'; _pm_ask "Risk 31" 'gh pr merge 12 --squash'
_pm_json '' 'a.sh' 'SUCCESS'; _pm_ask "Risk 값 없음" 'gh pr merge 12 --squash'
_pm_json '> 예: `Risk Score: 10/100`
## ⚠️ Risk Score: 75/100 (높음)' 'a.sh' 'SUCCESS'; _pm_ask "인용 속 가짜 Risk 뒤 진짜 75" 'gh pr merge 12 --squash'
_pm_json '```
## ⚠️ Risk Score: 5/100
```
## ⚠️ Risk Score: 80/100 (높음)' 'a.sh' 'SUCCESS'; _pm_ask "코드 블록 속 가짜 Risk 뒤 진짜 80" 'gh pr merge 12 --squash'
_pm_json "$_pm_R" 'a.sh' 'SUCCESS,FAILURE'; _pm_ask "CI 하나 실패" 'gh pr merge 12 --squash'
_pm_json "$_pm_R" 'a.sh' 'SUCCESS,ctx:FAILURE'; _pm_ask "상태(StatusContext) 하나 실패" 'gh pr merge 12 --squash'
_pm_json "$_pm_R" 'a.sh' 'SUCCESS,PENDING'; _pm_ask "CI 아직 도는 중" 'gh pr merge 12 --squash'
_pm_json "$_pm_R" 'a.sh' ''; _pm_ask "CI 체크 없음" 'gh pr merge 12 --squash'
# 읽기 실패 · 시간 초과
_pm_json "$_pm_R" 'a.sh' 'SUCCESS'
out=$(PM_FAIL=1 _pm_run 'gh pr merge 12 --squash'); echo "$out" | grep -q '"permissionDecision":"ask"' && ok "ask: PR 을 못 읽음" || bad "읽기 실패 무확인" "[$out]"
s=$(python3 -c 'import time;print(time.time())')
out=$(PM_SLEEP=5 CLAUDE_PR_MERGE_TIMEOUT=1 _pm_run 'gh pr merge 12 --squash'); e=$(python3 -c "import time;print(time.time()-$s)")
echo "$out" | grep -q '"permissionDecision":"ask"' && python3 -c "import sys; sys.exit(0 if $e < 4 else 1)" && ok "ask: 읽기 시간 초과(1초 뒤 묻는다)" || bad "시간 초과" "${e}s [$out]"
# 조건은 채웠지만 어떤 PR 이 머지될지 명령만으로 확실하지 않음 — 묻는다(뒤에 붙은 위험 명령도 사람이 본다)
for c in 'gh pr merge --squash' 'gh pr merge feature/x --squash' 'gh pr merge 12 --squash && gh pr merge 13 --squash' \
         'gh pr merge 12 --squash;gh pr merge 13 --squash' 'gh pr merge 12 --squash $(gh pr merge 13)' \
         'gh pr merge 12 --squash && mysql -h prod-db -e "DELETE FROM users"' 'cd /other/repo && gh pr merge 12 --squash' \
         'GH_REPO=other/repo gh pr merge 12 --squash' '/opt/homebrew/bin/gh pr merge 12' 'gh pr merge 12 -Rother/repo --squash' \
         'gh pr merge 12 -R=other/repo' 'gh pr merge 12 -sR other/repo'; do
  _pm_ask "단순한 머지 하나가 아님: $c" "$c"
done
out=$(cd "$TMP/none" && python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.argv[1]}}))' 'git commit -m "gh pr merge 문서"' | bash "$HOOKS/block-dangerous-bash.sh" 2>/dev/null)
[ -z "$out" ] && ok "따옴표 안 gh pr merge 는 그냥 통과" || bad "오탐" "커밋 메시지에서 ask"

# GitHub 쓰기 계정 — 목록에 있는 owner 레포에 쓰는 명령은 그 계정일 때만 (2026-10-15)
printf '\n[2-e] gh 쓰기 계정 — owner 별 계정이 아니면 차단\n'
check_deny 0 'gh issue create -R jtwjs/x --title t'          # 목록 파일 없음 → 아무것도 안 함
printf 'jtwjs jtwjs\n' > "$CLAUDE_GH_ACCOUNTS"
export CLAUDE_GH_ACTIVE=jtw-219
check_deny 2 'gh issue create -R jtwjs/claude-harness --title "t" --body-file b'
check_deny 2 'gh pr comment 3 --repo jtwjs/x --body "hi"'
check_deny 0 'gh auth switch -u jtwjs && gh issue create -R jtwjs/x --title t'
check_deny 0 'gh issue create -R sellermill/x --title t'     # 목록에 없는 owner
check_deny 0 'gh issue list -R jtwjs/x'                       # 읽기
check_deny 0 'git commit -m "gh issue create -R jtwjs/x"'     # 따옴표 안
mkdir -p "$TMP/ghrepo" && (cd "$TMP/ghrepo" && git init -q && git remote add origin https://github.com/jtwjs/r.git)
out=$(cd "$TMP/ghrepo" && printf '{"tool_input":{"command":"gh issue create --title t"}}' | bash "$HOOKS/block-dangerous-bash.sh" 2>&1); code=$?
[ "$code" = "2" ] && ok "-R 없으면 origin owner 로 판정" || bad "origin 판정" "exit=$code"
CLAUDE_GH_ACTIVE=jtwjs check_deny 0 'gh issue create -R jtwjs/x --title t'
unset CLAUDE_GH_ACTIVE; rm -f "$CLAUDE_GH_ACCOUNTS"

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
PS="$HOOKS/../skills/sdd-run/scripts/phases_status.py"
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
# --retro: 겹쳐 실행된 step 은 자기 started→completed 로 · retries 없으면 attempts 수 · done 은 완료 · obsolete 제외 · +0900 형식
cat > "$TMP/ph/phases/old/index.json" <<'JSON'
{"steps":[
 {"step":1,"name":"a","status":"completed","started_at":"2026-10-16T18:23:15+0900","completed_at":"2026-10-16T18:40:00+0900","retries":1},
 {"step":2,"name":"b","status":"done","started_at":"2026-10-16T18:32:14+0900","completed_at":"2026-10-16T18:41:55+0900","attempts":[{"at":"x","error":"y"},{"at":"x","error":"y"}]},
 {"step":3,"name":"c","status":"error"},
 {"step":4,"name":"d","status":"obsolete","retries":9}]}
JSON
out=$(cd "$TMP/ph" && python3 "$PS" --retro old)
printf '%s' "$out" | grep -q '^step 3 · 완료 2 · 재시도 3 · error/blocked 1 · 소요 26m$' && ok "--retro 합계 줄(겹친 실행·attempts·done·obsolete)" || bad "--retro 합계" "$out"
printf '%s' "$out" | grep -qF '| 3 | c | error | 0 | - |' && ok "--retro 시각 없는 step 은 -" || bad "--retro 빈 소요" "$out"

# ── 케이스 2-g: conductor tracks_status — 브랜치로 트랙 매칭 · 막힌 트랙이 맨 위 (2026-10-18) ──
printf '\n[2-g] tracks_status — 브랜치 매칭 · ⛔ 먼저\n'
TS="$HOOKS/../skills/conductor/scripts/tracks_status.py"
mkdir -p "$TMP/tr/.claude/references" && (cd "$TMP/tr" && git init -q -b main && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)
printf '| 트랙 | 소유 |\n|---|---|\n| `admin` | a |\n| `renderer` | r |\n' > "$TMP/tr/.claude/references/tracks.md"
(cd "$TMP/tr" && git worktree add -q "$TMP/tr-siren" -b feature/admin-x && git worktree add -q "$TMP/tr-rd" -b feature/renderer-y) 2>/dev/null
mkdir -p "$TMP/tr-siren/phases/admin-x" "$TMP/tr-rd/phases/renderer-y"
echo '{"steps":[{"step":1,"name":"s1","status":"completed"},{"step":2,"name":"boom","status":"error"}]}' > "$TMP/tr-siren/phases/admin-x/index.json"
echo '{"steps":[{"step":1,"name":"s1","status":"pending"}]}' > "$TMP/tr-rd/phases/renderer-y/index.json"
out=$(cd "$TMP/tr" && python3 "$TS" --no-gh)
printf '%s' "$out" | sed -n 3p | grep -qF '| ⛔ | admin | tr-siren | feature/admin-x | ⛔ admin-x 1/2 boom |' && ok "막힌 트랙이 첫 행 · 폴더명과 다른 트랙을 브랜치로 매칭" || bad "tracks_status" "$out"
printf '%s' "$out" | grep -qF '| … | renderer | tr-rd | feature/renderer-y | ◆ renderer-y 0/1 ▶ s1 |' && ok "진행 중 트랙 표시" || bad "tracks_status 진행" "$out"
out=$(cd "$TMP/tr" && python3 "$TS" --compact)
[ "$out" = "트랙 ⛔admin 진행1" ] && ok "--compact 한 줄(막힌 트랙 이름 · 나머지는 수 · 기준 worktree 제외)" || bad "tracks_status --compact" "$out"
echo a > "$TMP/tr-siren/shared.txt"; echo b > "$TMP/tr-rd/shared.txt"; echo c > "$TMP/tr/shared.txt"
out=$(cd "$TMP/tr" && python3 "$TS" --no-gh)
printf '%s' "$out" | grep -qF -- '- `shared.txt` — tr-rd, tr-siren' && ! printf '%s' "$out" | grep -qF -- '- `phases' && ok "겹침: 두 트랙이 같이 바꾸는 파일만(기준 worktree·다른 phase 폴더 제외)" || bad "tracks_status 겹침" "$out"
out=$(cd "$TMP/tr" && python3 "$TS" --compact)
[ "$out" = "트랙 ⛔admin 진행1 겹침1" ] && ok "--compact 에 겹침 수" || bad "tracks_status --compact 겹침" "$out"
# 2026-10-31 ADR-006: compact 는 손댈 것만 · 끝난 worktree 는 표 아래 「지울 worktree」 · 지휘 자리면 대상 레포 전부
mkdir -p "$TMP/tr2/.claude/references" && (cd "$TMP/tr2" && git init -q -b main && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)
printf '| 트랙 | 소유 |\n|---|---|\n| `api` | a |\n| `web` | w |\n' > "$TMP/tr2/.claude/references/tracks.md"
(cd "$TMP/tr2" && git worktree add -q "$TMP/tr2-api" -b feature/api-a && git worktree add -q "$TMP/tr2-web" -b feature/web-b) 2>/dev/null
for w in api:api-a web:web-b; do d="$TMP/tr2-${w%%:*}/phases/${w#*:}"; mkdir -p "$d"; echo '{"steps":[{"step":1,"name":"s1","status":"completed"}]}' > "$d/index.json"; echo x > "$TMP/tr2-${w%%:*}/same.txt"; done
out=$(cd "$TMP/tr2" && python3 "$TS" --compact)
[ -z "$out" ] && ok "--compact: 끝난 worktree 만이면 빈 출력(끝N 없음 · 끝난 것끼리 겹침 안 셈)" || bad "tracks_status --compact 끝만" "$out"
out=$(cd "$TMP/tr2" && python3 "$TS" --no-gh)
printf '%s' "$out" | grep -qF '지울 worktree' && printf '%s' "$out" | grep -qF -- '- tr2-api' && ! printf '%s' "$out" | grep -qF '| ✓ |' && ! printf '%s' "$out" | grep -qF '`same.txt`' && ok "전체 표: 끝난 worktree 는 「지울 worktree」로 따로 · 겹침 안 셈" || bad "tracks_status 지울 worktree" "$out"
(cd "$TMP/tr2" && git checkout -q -b docs/x)
out=$(cd "$TMP/tr2" && python3 "$TS" --no-gh)
! printf '%s' "$out" | grep -qF -- '- tr2 (' && ok "본 트리는 기준 브랜치가 아니어도 「지울 worktree」에 안 넣는다(worktree remove 불가)" || bad "본 트리 지울 목록" "$out"
(cd "$TMP/tr2" && git checkout -q main)
mkdir -p "$TMP/seat2" && (cd "$TMP/seat2" && git init -q)
printf '{"seat":"%s","repos":["%s","%s","%s"]}' "$TMP/seat2" "$TMP/tr" "$TMP/tr2" "$TMP/nope-x" > "$CLAUDE_CONDUCTOR_CONFIG"
out=$(cd "$TMP/seat2" && python3 "$TS" --compact)
[ "$out" = "tr ⛔admin 진행1 겹침1 · nope-x (경로 없음)" ] && ok "지휘 자리 --compact: 레포별 조각 · 빈 레포 생략 · 없는 경로" || bad "tracks_status 지휘 compact" "$out"
out=$(cd "$TMP/seat2" && python3 "$TS" --no-gh)
printf '%s' "$out" | grep -qF '## tr' && printf '%s' "$out" | grep -qF '## tr2' && printf '%s' "$out" | grep -qF 'nope-x (경로 없음)' && printf '%s' "$out" | grep -qF 'admin-x 1/2 boom' && ok "지휘 자리 전체 표: 레포마다 절" || bad "tracks_status 지휘 표" "$out"
out=$(cd "$TMP/tr" && python3 "$TS" --compact)
[ "$out" = "트랙 ⛔admin 진행1 겹침1" ] && ok "지휘 설정이 있어도 레포 안에서는 지금 동작" || bad "tracks_status 레포 안" "$out"
rm -f "$CLAUDE_CONDUCTOR_CONFIG"

# ── 케이스 2-h: daily-hub — 사람 요청만 · 헤드리스 제외 · 심볼릭 링크 중복 제거 · 오늘 학습 카드 (2026-10-18) ──
printf '\n[2-h] daily_hub — 세션·학습 카드 집계\n'
DH="$HOOKS/../scripts/daily-hub/daily_hub.py"; H="$TMP/dh"
mkdir -p "$H/.claude/projects/-w" "$H/repo/_learn" && (cd "$H/repo" && git init -q)
ln -s "$H/.claude/projects/-w" "$H/.claude/projects/-w-link"
u() { printf '{"type":"user","promptSource":"typed","entrypoint":"%s","timestamp":"%s","cwd":"%s","message":{"role":"user","content":"%s"}}\n' "$1" "$2" "$H/repo" "$3"; }
{ printf '{"type":"custom-title","customTitle":"repo-fe"}\n'; u cli 2026-10-17T23:30:00Z "첫 요청"; u cli 2026-10-18T05:00:00Z "마지막 요청"; u cli 2026-10-16T01:00:00Z "다른 날"; } > "$H/.claude/projects/-w/a.jsonl"
u sdk-cli 2026-10-18T01:00:00Z "/routine evening" > "$H/.claude/projects/-w/b.jsonl"
printf '%s\n' "$H/repo" > "$H/.claude/learn-repos.txt"
mkdir -p "$H/repo/docs/retro" && printf '## 2026-10-18 — 오늘 기능\n- 숫자: step 1\n' > "$H/repo/docs/retro/2026-10-18-today.md"
printf '## YYYY-MM-DD · 템플릿\n## 2026-10-18 · 오늘 카드\n- 종류: 기술 · 출처: 빈틈 3곳\n- 상태: 설명 들음\n## 2026-10-17 · 어제 카드\n- 종류: 기술 · 출처: AI 설명\n' > "$H/repo/_learn/inbox.md"
out=$(python3 "$DH" 2026-10-18 --home "$H" --out "$H/out")
[ "$out" = "오늘 세션 1 · 프로젝트 1 · 새 학습 1 — 자세히: $H/out/2026-10-18.html" ] && ok "세션 1(헤드리스·링크 중복 제외) · 학습 1(오늘만)" || bad "daily_hub 집계" "$out"
grep -q '08:30~14:00' "$H/out/2026-10-18.html" && grep -q 'repo-fe' "$H/out/2026-10-18.html" && grep -q '빈틈 3곳' "$H/out/2026-10-18.html" && ok "KST 시간대 · 세션 이름 · 빈틈 3곳 표시" || bad "daily_hub HTML" "$(grep -o '[0-9][0-9]:[0-9][0-9]~[0-9:]*' "$H/out/2026-10-18.html")"
grep -q '회고: 2026-10-18 — 오늘 기능' "$H/out/2026-10-18.html" && ok "회고는 retro/ 의 날짜 파일에서 읽는다" || bad "daily_hub 회고" "$(grep -o '회고:[^<]*' "$H/out/2026-10-18.html")"

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
echo "$out" | grep -q '줄(목표 ~40)' && bad "오탐" "작은 CLAUDE.md 에 떠들었다" || ok "임계 아래 — 조용"
python3 -c "print('x\n'*100, end='')" > "$TMP/on/CLAUDE.md"
# 축 3 도 하루 첫 세션 기록(doctor-date)을 쓴다 — 아래 축 1 하루 한 번 케이스와 기록이 섞이지 않게 폴더를 나눈다
out=$(cd "$TMP/on" && printf '{}' | CLAUDE_SKILL_HINTS_DIR="$TMP/hints-case5" bash "$HOOKS/cadence-reminder.sh" 2>&1)
echo "$out" | grep -q '줄(목표 ~40)' && echo "$out" | grep -qF 'harness-doctor/SKILL.md 의 §5 · §9' && ok "임계 초과 — harness-doctor §5 · §9 로 환기" || bad "침묵" "101줄인데 doctor 환기가 없다 out=[$out]"

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
FAKE="$TMP/fakeplugin"; mkdir -p "$FAKE/hooks" "$FAKE/skills/harness-score/scripts"
cp "$HOOKS/weekly-readiness-check.sh" "$FAKE/hooks/"; cp -R "$HOOKS/lib" "$FAKE/hooks/"; printf 'import sys; sys.exit(3)\n' > "$FAKE/skills/harness-score/scripts/score.py"
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

# 발화 기록 (0.27.0) — 덜어낼지 판단할 근거. 막은 건 blocked, 센 건 seen 으로 남는다
grep -q $'\tloop-lock\tblocked\t' "$TMP/hook-log.tsv" 2>/dev/null && grep -q $'\tloop-lock\tseen\t' "$TMP/hook-log.tsv" \
  && ok "loop-lock 발화 기록 — blocked·seen" || bad "발화 기록" "hook-log.tsv 에 loop-lock 줄이 없다"

# ── 케이스 8: todo-warn — stdout JSON 으로 낸다 (stderr 는 아무도 못 본다) ─────
printf '\n[8] todo-warn — stdout JSON\n'
printf 'x\n// TODO later\n' > "$TMP/on/t.ts"
(cd "$TMP/on" && git add t.ts >/dev/null 2>&1)
out=$(cd "$TMP/on" && printf '{"tool_input":{"command":"git commit -m x"}}' | bash "$HOOKS/todo-warn.sh" 2>/dev/null)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "TODO" in d["hookSpecificOutput"]["additionalContext"] and d["systemMessage"]' 2>/dev/null \
  && ok "additionalContext + systemMessage" || bad "JSON" "out=[$out]"
(cd "$TMP/on" && git reset -q t.ts && rm -f t.ts)
grep -q $'\ttodo-warn\twarn\t' "$TMP/hook-log.tsv" 2>/dev/null && ok "todo-warn 발화 기록 — warn" || bad "발화 기록" "todo-warn warn 줄이 없다"

# ── 케이스 9: validate-session-end — 결과를 stdout JSON systemMessage 로 ─────
printf '\n[9] Stop 훅 — stdout JSON systemMessage\n'
cat > "$TMP/on/.claude/harness.json" <<JSON
{ "verify": { "lint": "echo ok", "test": "" } }
JSON
rm -f "$TMP/on/.claude/.last-session-validate"
out=$(cd "$TMP/on" && printf '{}' | bash "$HOOKS/validate-session-end.sh" 2>/dev/null)
echo "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); m=d["systemMessage"]; assert "🟢 lint" in m and "verify.test" in m' 2>/dev/null \
  && ok "systemMessage 에 🟢 lint · 빈 verify.test" || bad "JSON" "out=[$out]"
awk -F'\t' '$3=="validate-session-end" && $4=="ok" && $5 ~ /^[0-9]+$/' "$TMP/hook-log.tsv" 2>/dev/null | grep -q . \
  && ok "validate-session-end 발화 기록 — ok · ms" || bad "발화 기록" "validate-session-end ok·ms 줄이 없다"

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
check_deny 2 'rm -rf ./build'   # 하위 경로도 막는다(#120 rm-recursive-force). 나머지 꼴은 tests/rm-recursive-force.sh
check_deny 0 'rm -r ./build'    # -f 없는 rm -r 은 통과(#120 결정 1 B)

# ── 케이스 11: 앱별 verify — Stop 훅이 root 마다 cd 해서 돌리고 root 이름을 낸다 (0.10.0) ─
printf '\n[11] Stop 훅 — 앱별 verify\n'
mkdir -p "$TMP/multi/.claude" "$TMP/multi/apps/api" "$TMP/multi/apps/web" && (cd "$TMP/multi" && git init -q)
: > "$TMP/multi/apps/api/only-here"   # cd 가 안 되면 test -f 가 실패한다
: > "$TMP/multi/apps/web/changed"
cat > "$TMP/multi/.claude/harness.json" <<JSON
{ "verify": { "\$comment": "x",
  "apps/api": { "lint": "test -f only-here", "test": "exit 1" },
  "apps/web": { "lint": "echo ok", "test": "" } } }
JSON
out=$(cd "$TMP/multi" && printf '{}' | bash "$HOOKS/validate-session-end.sh" 2>/dev/null)
msg=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["systemMessage"])' 2>/dev/null)
echo "$msg" | grep -q '🟢 apps/api lint' && ok "root 에서 실행 · 이름 표시 (apps/api lint)" || bad "앱별 실행" "msg=[$msg]"
echo "$msg" | grep -q '🟢 apps/web lint' && ok "두 번째 root 도 실행 (apps/web lint)" || bad "앱별 실행" "msg=[$msg]"
echo "$msg" | grep -q 'apps/web: verify.test 가 비어' && ok "빈 test 를 root 별로 보고" || bad "침묵" "msg=[$msg]"
! echo "$msg" | grep -q 'apps/api test' && echo "$msg" | grep -q 'test 는 Stop 에서 돌리지 않는다' && ok "test 는 Stop 에서 안 돈다(부하 — 0.31.1)" || bad "Stop test" "msg=[$msg]"
# 바뀐 앱만 (0.31.1): web 만 바뀌면 api 는 건너뛴다. 기록(*.md)은 앱 밖이어도 전부로 넓히지 않는다
(cd "$TMP/multi" && git add -A >/dev/null 2>&1 && git -c user.email=t@t -c user.name=t commit -qm i >/dev/null 2>&1)
echo x > "$TMP/multi/apps/web/changed"; echo n > "$TMP/multi/NOTE.md"
out=$(cd "$TMP/multi" && printf '{}' | bash "$HOOKS/validate-session-end.sh" 2>/dev/null)
msg=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["systemMessage"])' 2>/dev/null)
echo "$msg" | grep -q '🟢 apps/web lint' && ! echo "$msg" | grep -q 'apps/api lint' && echo "$msg" | grep -q '건너뜀(바뀐 파일 없음): apps/api' && ok "바뀐 앱만 · *.md 는 무시" || bad "바뀐 앱만" "msg=[$msg]"
echo y > "$TMP/multi/root.config.js"
out=$(cd "$TMP/multi" && printf '{}' | bash "$HOOKS/validate-session-end.sh" 2>/dev/null)
msg=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["systemMessage"])' 2>/dev/null)
echo "$msg" | grep -q '🟢 apps/api lint' && echo "$msg" | grep -q '🟢 apps/web lint' && ok "앱 밖 코드 파일이면 전부" || bad "앱 밖 코드" "msg=[$msg]"
rm -f "$TMP/multi/root.config.js" "$TMP/multi/NOTE.md"; echo z > "$TMP/multi/apps/api/only-here"
# step 명령(0.25.0): SDD_RUNNER_SINCE 가 있으면 $step 의 같은 키, {since} 치환
cat > "$TMP/multi/.claude/harness.json" <<JSON
{ "verify": { "apps/api": { "lint": "exit 1", "\$step": { "lint": "test {since} = abc1" } } } }
JSON
rm -f "$TMP/multi/.claude/.last-session-validate"
out=$(cd "$TMP/multi" && printf '{}' | SDD_RUNNER_SINCE=abc1 bash "$HOOKS/validate-session-end.sh" 2>/dev/null)
msg=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["systemMessage"])' 2>/dev/null)
echo "$msg" | grep -q '🟢 apps/api lint' && ok "러너 step 안이면 \$step 명령 · {since} 치환" || bad "step 명령" "msg=[$msg]"
rm -f "$TMP/multi/.claude/.last-session-validate"
out=$(cd "$TMP/multi" && printf '{}' | env -u SDD_RUNNER_SINCE bash "$HOOKS/validate-session-end.sh" 2>/dev/null)
msg=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["systemMessage"])' 2>/dev/null)
echo "$msg" | grep -q '🔴 apps/api lint' && ok "러너 밖이면 전체 명령" || bad "전체 명령" "msg=[$msg]"
# loop-lock: 중첩 verify 명령을 검증성으로 본다 — 'cd … &&' 로 시작해 2순위 정규식에는 안 걸리는 명령
cat > "$TMP/multi/.claude/harness.json" <<JSON
{ "verify": { "apps/api": { "test": "mytool verify-all" } } }
JSON
llm() { (cd "$TMP/multi" && printf '{"session_id":"m1","tool_input":{"command":"%s"}}' "$1" | bash "$HOOKS/loop-lock.sh" >/dev/null 2>&1); echo $?; }
c='cd apps/api && mytool verify-all'
[ "$(llm "$c")" = "0" ] && [ "$(llm "$c")" = "0" ] && [ "$(llm "$c")" = "2" ] \
  && ok "loop-lock — 중첩 verify 명령 3회째 exit 2" || bad "loop-lock 중첩" "앱별 verify 명령을 추적하지 못했다"

# 케이스 10 문서 정합은 tests/doc-consistency.sh 로 옮겼다(ADR-025 — 문서만 바뀐 부분 실행이 본문을 돌지 않게)

# ── 케이스 7-a: 지휘 설정 — 자리 판정 · 대상 레포 (2026-10-31 single-conductor) ──
printf '\n[7-a] conductor.py — 설정 없음·깨짐은 꺼짐 · 자리 판정 · 레포 목록\n'
CL="$HOOKS/lib/conductor.py"
mkdir -p "$TMP/seat/sub" && (cd "$TMP/seat" && git init -q)
python3 "$CL" is-seat "$TMP/seat" >/dev/null 2>&1 && bad "설정 없음" "is-seat 0" || ok "설정 없으면 지휘 자리 아님"
echo '{bad' > "$CLAUDE_CONDUCTOR_CONFIG"
python3 "$CL" is-seat "$TMP/seat" >/dev/null 2>&1 && bad "깨진 설정" "is-seat 0" || ok "깨진 설정은 꺼짐"
printf '{"seat":"%s","repos":["%s","~/nowhere-x"]}' "$TMP/seat" "$TMP/tr" > "$CLAUDE_CONDUCTOR_CONFIG"
python3 "$CL" is-seat "$TMP/seat" && ok "seat 폴더는 지휘 자리" || bad "is-seat" "seat 폴더 exit 1"
python3 "$CL" is-seat "$TMP/seat/sub" && ok "하위 폴더도 git toplevel 이 seat 면 지휘 자리" || bad "is-seat 하위" "exit 1"
python3 "$CL" is-seat "$TMP/tr" && bad "is-seat 다른 레포" "exit 0" || ok "다른 레포는 지휘 자리 아님"
out=$(python3 "$CL" repos)
[ "$out" = "$TMP/tr
$HOME/nowhere-x" ] && ok "repos — 순서 유지 · ~ 펼침" || bad "repos" "$out"
rm -f "$CLAUDE_CONDUCTOR_CONFIG"

# ── 케이스 7-b: 검사 상한 — 지금 도는 검사 프로세스 수 (ADR-007) ──
printf '\n[7-b] verify_busy.py — 가짜 ps 로 개수 · 상한 · 명령 판정\n'
VB="$HOOKS/lib/verify_busy.py"
mkdir -p "$TMP/vb/.claude" && printf '{"verify":{"lint":"pnpm lint","test":"pnpm test"}}' > "$TMP/vb/.claude/harness.json"
mkdir -p "$TMP/vb-apps/.claude" && printf '{"verify":{"$comment":"x","web":{"lint":"pnpm lint:web","$step":{"test":"pnpm t"}}}}' > "$TMP/vb-apps/.claude/harness.json"
: > "$CLAUDE_VERIFY_PS"
python3 "$VB" busy "$TMP/vb" >/dev/null && bad "0개" "busy" || ok "검사 0개 → 한가함"
printf 'node /x/pnpm lint\nvim notes\n' > "$CLAUDE_VERIFY_PS"
python3 "$VB" busy "$TMP/vb" >/dev/null && bad "1개" "busy" || ok "검사 1개 → 한가함(상한 2)"
printf 'node /x/pnpm lint\nsh -c pnpm verify\npython3 /h/verify_busy.py busy pnpm lint\n' > "$CLAUDE_VERIFY_PS"
out=$(python3 "$VB" busy "$TMP/vb") && [ "$out" = "2" ] && ok "검사 2개 → 바쁨 · 개수 출력 · 자기 자신 줄은 뺌" || bad "2개" "out=$out"
CLAUDE_VERIFY_MAX=3 python3 "$VB" busy "$TMP/vb" >/dev/null && bad "MAX=3" "busy" || ok "CLAUDE_VERIFY_MAX=3 이면 2개는 한가함"
CLAUDE_VERIFY_MAX=abc python3 "$VB" busy "$TMP/vb" >/dev/null && ok "잘못된 MAX 는 기본 2" || bad "MAX=abc" "한가함"
python3 "$VB" match "$TMP/vb" 'pnpm lint' && ok "match — harness.json verify 값" || bad "match lint" "exit 1"
python3 "$VB" match "$TMP/vb" 'cd x && pnpm verify' && ok "match — pnpm verify" || bad "match verify" "exit 1"
python3 "$VB" match "$TMP/vb" 'git status' && bad "match 오탐" "git status" || ok "match — 검사 아닌 명령은 아님"
python3 "$VB" match "$TMP/vb-apps" 'pnpm lint:web' && ok "match — 앱별 verify · \$ 키 무시" || bad "match 앱별" "exit 1"
# REVIEW 1회차(2026-10-31): 한 실행이 zsh → pnpm → turbo → pnpm run ×2 로 떠도 1개 · 명령 자리에서만 · TRIVIAL 은 match 에서도 제외
printf '100 1 zsh -c pnpm verify\n101 100 node /x/pnpm verify\n102 101 /x/turbo run verify\n103 102 node /x/pnpm run verify\n104 102 node /x/pnpm run verify\n' > "$CLAUDE_VERIFY_PS"
out=$(CLAUDE_VERIFY_MAX=1 python3 "$VB" busy "$TMP/vb") && [ "$out" = "1" ] && ok "한 실행의 프로세스 트리(중간 turbo 포함)는 1개" || bad "트리 1개" "out=$out"
printf 'rg pnpm test docs\nvim pnpm lint.md\n' > "$CLAUDE_VERIFY_PS"
CLAUDE_VERIFY_MAX=1 python3 "$VB" busy "$TMP/vb" >/dev/null && bad "명령 자리" "검색·편집 줄을 검사로 셈" || ok "명령 자리가 아닌 줄(rg·vim 인자)은 안 셈"
: > "$CLAUDE_VERIFY_PS"
mkdir -p "$TMP/vb-true/.claude" && printf '{"verify":{"test":"true"}}' > "$TMP/vb-true/.claude/harness.json"
python3 "$VB" match "$TMP/vb-true" 'ls || true' && bad "match TRIVIAL" "ls || true 를 검사로" || ok "match — verify 값 true 는 검사로 안 봄"
python3 "$VB" match "$TMP/vb" 'echo pnpm verify' && bad "match 자리" "echo 인자를 검사로" || ok "match — 명령 자리 아닌 pnpm verify 는 아님"
mkdir -p "$TMP/vb-gr/.claude" && printf '{"verify":{"test":"./gradlew test"}}' > "$TMP/vb-gr/.claude/harness.json"
printf '200 1 /bin/sh ./gradlew test\n300 1 /bin/sh ./gradlew test\n' > "$CLAUDE_VERIFY_PS"
out=$(python3 "$VB" busy "$TMP/vb-gr") && [ "$out" = "2" ] && ok "./gradlew test 는 공백 뒤도 명령 자리(REVIEW 2회차 회귀)" || bad "gradlew" "out=$out"
: > "$CLAUDE_VERIFY_PS"
python3 "$VB" match "$TMP/vb-apps" 'pnpm t' && bad "match \$step" "exit 0" || ok "match — \$step 은 세지 않음"
python3 "$VB" match "$TMP/none" 'npm run verify' && ok "harness.json 없어도 npm run verify" || bad "match 없음" "exit 1"
: > "$CLAUDE_VERIFY_PS"

# ── 케이스 7-c: 지휘 자리 — -R 강제 · 명령 머리의 대상 레포로 운영 DB 판정 (ADR-003·004) ──
printf '\n[7-c] block-dangerous-bash — 지휘 자리 -R · cd/git -C 대상 레포\n'
printf '{"seat":"%s","repos":["%s"]}' "$TMP/seat" "$TMP/prod" > "$CLAUDE_CONDUCTOR_CONFIG"
[ "$(bdb "$TMP/seat" 'gh issue comment 3 --body hi')" = 2 ] && ok "지휘 자리에서 -R 없는 gh 쓰기 → 차단" || bad "지휘 -R 없음" "통과"
[ "$(bdb "$TMP/seat" 'gh pr create --title t')" = 2 ] && ok "지휘 자리 -R 없는 gh pr create → 차단" || bad "지휘 pr" "통과"
[ "$(bdb "$TMP/seat" 'gh issue comment 3 -R sellermill/x --body hi')" = 0 ] && ok "지휘 자리 + -R → 통과(계정 목록 없음)" || bad "지휘 -R 있음" "차단"
[ "$(bdb "$TMP/seat" 'gh issue list --label conductor')" = 0 ] && ok "지휘 자리 gh 읽기는 -R 없어도 통과" || bad "지휘 읽기" "차단"
[ "$(bdb "$TMP/none" 'gh issue comment 3 --body hi')" = 0 ] && ok "지휘 자리 아니면 지금 동작" || bad "지휘 아님" "차단"
[ "$(bdb "$TMP/seat" "cd $TMP/prod && mysql -h prod-db.example.com -e \"DELETE FROM users\"")" = 2 ] && ok "cd <레포> && → 그 레포 prodDb 로 차단" || bad "cd 대상" "통과"
[ "$(bdb "$TMP/seat" "git -C $TMP/prod log; mysql -h prod-db.example.com -e \"DELETE FROM u\"")" = 2 ] && ok "git -C <레포> 머리 → 그 레포 prodDb" || bad "git -C 대상" "통과"
[ "$(bdb "$TMP/seat" "cd $TMP/prod && mysql -h prod-db.example.com -e \"SELECT 1\"")" = 0 ] && ok "대상 레포 조회는 통과" || bad "cd 조회" "차단"
[ "$(bdb "$TMP/seat" "cd $TMP/no-such && mysql -h prod-db.example.com -e \"DELETE FROM u\"")" = 0 ] && ok "없는 경로면 cwd(하네스 없음) 기준" || bad "없는 경로" "차단"
# REVIEW 1회차: -R 범위(ADR-003 개정) · 머리 레포에 하네스가 없으면 cwd 로
[ "$(bdb "$TMP/seat" 'gh label create x --color 000000')" = 2 ] && ok "지휘 자리 -R 없는 gh label create → 차단" || bad "label create" "통과"
[ "$(bdb "$TMP/seat" 'gh pr ready 3')" = 2 ] && ok "지휘 자리 -R 없는 gh pr ready → 차단" || bad "pr ready" "통과"
[ "$(bdb "$TMP/seat" 'gh issue create -R sellermill/x --title t && gh issue comment 5 --body x')" = 2 ] && ok "&& 뒤 조각에 -R 없으면 차단" || bad "조각마다" "통과"
[ "$(bdb "$TMP/seat" 'gh label list')" = 0 ] && ok "gh label list(읽기)는 통과" || bad "label list" "차단"
[ "$(bdb "$TMP/seat" "$(printf 'gh issue create \\\n  -R sellermill/x --title t')")" = 0 ] && ok "\\ 줄 이어 쓴 gh 명령의 -R 을 본다(REVIEW 2회차 회귀)" || bad "줄 이어 쓰기" "차단"
[ "$(bdb "$TMP/prod" "git -C $TMP/seat log; mysql -h prod-db.example.com -e \"DELETE FROM u\"")" = 2 ] && ok "머리 레포에 하네스 없으면 cwd 레포 prodDb 로 차단" || bad "cwd 되돌림" "통과"
rm -f "$CLAUDE_CONDUCTOR_CONFIG"

# ── 케이스 7-d: 검사 상한 — 모델이 직접 친 verify 명령 (ADR-007) ──
printf '\n[7-d] block-dangerous-bash — 검사 상한 넘으면 직접 친 verify 차단\n'
printf 'node /x/pnpm lint\nsh -c pnpm verify\n' > "$CLAUDE_VERIFY_PS"
out=$(cd "$TMP/vb" && printf '{"tool_input":{"command":"pnpm verify"}}' | bash "$HOOKS/block-dangerous-bash.sh" 2>&1); code=$?
[ "$code" = 2 ] && printf '%s' "$out" | grep -q '30초 뒤 다시' && ok "상한(2) 이상 + pnpm verify → 차단 · 다시 안내" || bad "상한 차단" "exit=$code $out"
[ "$(bdb "$TMP/vb" 'pnpm lint')" = 2 ] && ok "harness.json verify 값도 차단" || bad "verify 값" "통과"
[ "$(bdb "$TMP/vb" 'git status')" = 0 ] && ok "검사 아닌 명령은 통과" || bad "검사 아님" "차단"
[ "$(CLAUDE_VERIFY_MAX=5 bdb "$TMP/vb" 'pnpm verify')" = 0 ] && ok "CLAUDE_VERIFY_MAX=5 면 통과" || bad "MAX=5" "차단"
printf 'node /x/pnpm lint\n' > "$CLAUDE_VERIFY_PS"
[ "$(bdb "$TMP/vb" 'pnpm verify')" = 0 ] && ok "1개 돌 때는 통과(세션 하나는 안 막힘)" || bad "1개" "차단"
: > "$CLAUDE_VERIFY_PS"

# ── 케이스 7-e: 검사 상한 — Stop 훅은 붐비면 건너뛴다 (ADR-007) ──
printf '\n[7-e] Stop 훅 — 검사 상한 이상이면 건너뜀 · stamp 안 남김\n'
mkdir -p "$TMP/st/.claude" && (cd "$TMP/st" && git init -q)
printf '{"verify":{"lint":"touch %s/st-ran","test":""}}' "$TMP" > "$TMP/st/.claude/harness.json"
printf 'sh -c pnpm verify\nnode pnpm verify\n' > "$CLAUDE_VERIFY_PS"
out=$(cd "$TMP/st" && printf '{}' | bash "$HOOKS/validate-session-end.sh" 2>&1)
printf '%s' "$out" | grep -q '⏸ 다른 세션 검사 2개 중 — 건너뜀' && ok "붐비면 건너뜀 메시지" || bad "건너뜀 메시지" "$out"
[ ! -f "$TMP/st-ran" ] && ok "검사 명령을 돌리지 않음" || bad "건너뜀" "verify 가 돌았다"
[ ! -f "$TMP/st/.claude/.last-session-validate" ] && ok "stamp 를 남기지 않음(다음 Stop 에서 다시)" || bad "stamp" "남았다"
printf 'node pnpm verify\n' > "$CLAUDE_VERIFY_PS"
(cd "$TMP/st" && printf '{}' | bash "$HOOKS/validate-session-end.sh" >/dev/null 2>&1)
[ -f "$TMP/st-ran" ] && ok "1개면 지금처럼 검사" || bad "1개" "verify 가 안 돌았다"
: > "$CLAUDE_VERIFY_PS"

# ── 케이스 7-f: conductor-context — 지휘 자리에서만 대상 레포 현황 (ADR-005) ──
printf '\n[7-f] conductor-context — 지휘 자리 SessionStart 현황\n'
CC="$HOOKS/conductor-context.sh"
git -C "$TMP/tr" remote add origin https://github.com/acme/tr.git 2>/dev/null
git -C "$TMP/tr2" remote add origin git@github.com:acme/bad-x.git 2>/dev/null
cat > "$TMP/fake-gh" <<'SH'
#!/bin/sh
case "$*" in *"-R acme/bad-x"*) exit 1;; *"-R acme/tr "*) echo '[{"number":12,"title":"결정 A"}]';; *) echo '[]';; esac
SH
chmod +x "$TMP/fake-gh"; export CLAUDE_CONDUCTOR_GH="$TMP/fake-gh"
out=$(cd "$TMP/tr" && printf '{}' | bash "$CC" 2>&1)
[ -z "$out" ] && ok "지휘 설정 없음 → 무출력" || bad "설정 없음" "$out"
printf '{"seat":"%s","repos":["%s","%s","%s"]}' "$TMP/seat2" "$TMP/tr" "$TMP/tr2" "$TMP/nope-x" > "$CLAUDE_CONDUCTOR_CONFIG"
out=$(cd "$TMP/tr" && printf '{}' | bash "$CC" 2>&1)
[ -z "$out" ] && ok "지휘 자리 아님(대상 레포 안) → 무출력" || bad "지휘 아님" "$out"
out=$(cd "$TMP/seat2" && printf '{}' | bash "$CC" 2>&1)
ctx=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null)
[ -n "$ctx" ] && ok "JSON 형식 유효 · additionalContext" || bad "JSON" "$out"
printf '%s' "$ctx" | grep -qF '트랙 ⛔admin 진행1 겹침1' && printf '%s' "$ctx" | grep -qF '#12 결정 A' && ok "레포별 트랙 한 줄 + 열린 지휘 이슈" || bad "레포 줄" "$ctx"
printf '%s' "$ctx" | grep -qF '(조회 실패)' && ok "gh 실패 → (조회 실패)" || bad "gh 실패" "$ctx"
printf '%s' "$ctx" | grep -qF 'nope-x (경로 없음)' && ok "없는 경로 → (경로 없음)" || bad "경로 없음" "$ctx"
grep -q 'conductor-context.sh' "$HOOKS/hooks.json" && ok "hooks.json SessionStart 에 등록" || bad "등록" "없음"
printf '#!/bin/sh\nexit 3\n' > "$TMP/fake-ts"; chmod +x "$TMP/fake-ts"
ctx=$(cd "$TMP/seat2" && printf '{}' | CLAUDE_CONDUCTOR_TS="$TMP/fake-ts" bash "$CC" 2>&1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null)
printf '%s' "$ctx" | grep -qF 'tr — (조회 실패)' && ! printf '%s' "$ctx" | grep -qF '손댈 것 없음' && ok "tracks_status 실패는 (조회 실패) — 「손댈 것 없음」 아님" || bad "트랙 실패" "$ctx"
ctx=$(cd "$TMP/seat2" && printf '{}' | CLAUDE_CONDUCTOR_DEADLINE=0 bash "$CC" 2>&1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null)
printf '%s' "$ctx" | grep -qF 'tr (시간 초과 — 건너뜀)' && ok "마감을 넘으면 남은 레포는 건너뜀 · 현황은 그래도 나온다" || bad "마감" "$ctx"
rm -f "$CLAUDE_CONDUCTOR_CONFIG"; unset CLAUDE_CONDUCTOR_GH

fi   # RUN_MAIN

# ── hooks/tests/*.sh — 이 파일의 ok·bad·TMP·HOOKS·ROOT·check_deny 를 그대로 쓰는 케이스 묶음(source) ──
# 왜 따로: 러너(sdd_runner.py)의 테스트 파일 판정이 hooks/test.sh 를 못 알아봐서, 새 케이스는 tests/ 아래에 둔다(2026-11-13).
# 새 파일을 더하면 hooks/test-map.tsv 에서 그 파일이 어느 줄로 골리는지 본다(ADR-025)
for _f in "$HOOKS"/tests/*.sh; do
  _n="${_f##*/}"
  if [ "$_n" = sdd-runner-unit.sh ]; then
    if [ "$RUN_RUNNER" = 1 ]; then . "$_f"; else printf '\n[sdd-runner-unit] 건너뜀 (%s)\n' "${HOOK_TEST_PART:+HOOK_TEST_PART=$HOOK_TEST_PART}${SINCE:+--since}"; fi
    continue
  fi
  [ "$RUN_TESTS" = "*" ] || case " $RUN_TESTS " in *" $_n "*) ;; *) continue ;; esac
  [ -f "$_f" ] && . "$_f"
done

printf '\n──────────────\n통과 %s · 실패 %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
