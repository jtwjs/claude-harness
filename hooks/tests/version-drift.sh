# cadence-reminder — 레포 harness.version 이 설치본 plugin.json 버전과 다르면 세션 시작에 한 줄(ADR-018 B-10). test.sh 가 source 한다.
# 설치본 버전은 가짜 플러그인 루트(CLAUDE_PLUGIN_ROOT)로 통제한다. HOME · 기록 · 상태줄 폴더는 임시 폴더.
printf '\n[version-drift] 레포 harness.version ≠ 설치본 — 한 줄 · 같음/없음/빈 값은 0줄\n'
_vd_d="$TMP/_vd_"; rm -rf "$_vd_d"
mkdir -p "$_vd_d/home" "$_vd_d/plugin/.claude-plugin" "$_vd_d/repo/.claude" "$_vd_d/nocfg"
printf '{"name":"claude-harness","version":"0.41.0"}\n' > "$_vd_d/plugin/.claude-plugin/plugin.json"
(cd "$_vd_d/repo" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)
(cd "$_vd_d/nocfg" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)
_vd_run() { # $1 경우 · $2 폴더 → 출력은 $_vd_d/<경우>.out, 기록은 <경우>.tsv
  (cd "$2" && printf '{}' | env HOME="$_vd_d/home" CLAUDE_PLUGIN_ROOT="$_vd_d/plugin" \
    CLAUDE_HARNESS_HOOK_LOG="$_vd_d/$1.tsv" CLAUDE_SKILL_HINTS_DIR="$_vd_d/hints" GIT_CEILING_DIRECTORIES="$_vd_d" \
    bash "$HOOKS/cadence-reminder.sh" >"$_vd_d/$1.out" 2>&1)
}
_vd_result() { awk -F'\t' '{print $4}' "$_vd_d/$1.tsv" 2>/dev/null | tr '\n' ' ' | sed 's/ $//'; }
_vd_line='하네스 0.37.0 → 0.41.0, /harness-init 업그레이드 모드'

# 다름 → 한 줄
printf '{"harness":{"version":"0.37.0"}}' > "$_vd_d/repo/.claude/harness.json"
_vd_run diff "$_vd_d/repo"
_vd_n=$(awk 'END{print NR}' "$_vd_d/diff.out")
if [ "$_vd_n" = "1" ] && grep -qF "$_vd_line" "$_vd_d/diff.out"; then ok "다름 — 한 줄 「${_vd_line}」"; else bad "다름" "${_vd_n}줄 [$(cat "$_vd_d/diff.out")]"; fi
_vd_ctx=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hookSpecificOutput"]["additionalContext"])' "$_vd_d/diff.out" 2>/dev/null)
printf '%s' "$_vd_ctx" | grep -qF "$_vd_line" && ok "다름 — 유효한 JSON additionalContext 에 들어간다" || bad "다름 JSON" "$(cat "$_vd_d/diff.out")"
[ "$(_vd_result diff)" = "drift" ] && ok "다름 — 기록 결과 drift 한 줄" || bad "다름 기록" "[$(_vd_result diff)]"

# 같음 → 0줄
printf '{"harness":{"version":"0.41.0"}}' > "$_vd_d/repo/.claude/harness.json"
_vd_run same "$_vd_d/repo"
[ ! -s "$_vd_d/same.out" ] && ok "같음 — 0줄" || bad "같음" "[$(cat "$_vd_d/same.out")]"
[ "$(_vd_result same)" = "clean" ] && ok "같음 — 기록 결과 clean 그대로" || bad "같음 기록" "[$(_vd_result same)]"

# harness.json 없음 → 0줄
_vd_run none "$_vd_d/nocfg"
[ ! -s "$_vd_d/none.out" ] && ok "harness.json 없음 — 0줄" || bad "없음" "[$(cat "$_vd_d/none.out")]"

# harness.version 빈 값 · 키 없음 → 0줄(비교할 값이 없다 — harness-doctor §0 몫)
printf '{"harness":{"version":""}}' > "$_vd_d/repo/.claude/harness.json"
_vd_run empty "$_vd_d/repo"
[ ! -s "$_vd_d/empty.out" ] && ok "harness.version 빈 값 — 0줄" || bad "빈 값" "[$(cat "$_vd_d/empty.out")]"
printf '{}' > "$_vd_d/repo/.claude/harness.json"
_vd_run nokey "$_vd_d/repo"
[ ! -s "$_vd_d/nokey.out" ] && ok "harness.version 키 없음 — 0줄" || bad "키 없음" "[$(cat "$_vd_d/nokey.out")]"

# 다름 + 기존 권고(CLAUDE.md 비대) → 둘 다 한 줄 출력 안에, 결과 이름은 기존 warn
printf '{"harness":{"version":"0.37.0"}}' > "$_vd_d/repo/.claude/harness.json"
seq 90 > "$_vd_d/repo/CLAUDE.md"
_vd_run both "$_vd_d/repo"
_vd_n=$(awk 'END{print NR}' "$_vd_d/both.out")
if [ "$_vd_n" = "1" ] && grep -qF "$_vd_line" "$_vd_d/both.out" && grep -qF '줄(목표 ~40)' "$_vd_d/both.out"; then ok "다름 + 기존 권고 — 한 줄 출력에 둘 다"; else bad "둘 다" "${_vd_n}줄 [$(cat "$_vd_d/both.out")]"; fi
[ "$(_vd_result both)" = "warn" ] && ok "다름 + 기존 권고 — 기록 결과 warn 그대로" || bad "둘 다 기록" "[$(_vd_result both)]"
rm -f "$_vd_d/repo/CLAUDE.md"

# 실제 이벤트는 SessionStart — 세션마다 한 번(매 프롬프트가 아니다)
python3 -c 'import json,sys; h=json.load(open(sys.argv[1]))["hooks"]; on=[k for k,v in h.items() for e in v for x in e["hooks"] if "cadence-reminder" in x["command"]]; sys.exit(0 if on==["SessionStart"] else 1)' "$HOOKS/hooks.json" \
  && ok "cadence-reminder 는 SessionStart 에만 걸려 있다" || bad "이벤트" "SessionStart 단독이 아니다"
