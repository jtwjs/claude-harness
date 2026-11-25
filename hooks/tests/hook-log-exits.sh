# 훅 3개(validate-session-end · loop-lock · todo-warn)는 끝나는 모든 경로에서 발화 기록을 정확히 한 줄 남긴다(ADR-016 D11). test.sh 가 source 한다.
# 기록 0줄이 「안 돌았다」인지 「기록 못 했다」인지 가르려는 것 — 일찍 끝나는 분기(레포 밖 · 설정 없음 · 입력 없음)도 센다.
# 호출마다 기록 파일을 따로 줘서 그 호출이 남긴 줄만 센다($TMP/hook-log.tsv 를 보는 다른 케이스와 섞지 않는다).
printf '\n[hook-log-exits] 훅 3개 — 끝나는 경로마다 기록 한 줄\n'
_hx_d="$TMP/_hx_"; rm -rf "$_hx_d"; mkdir -p "$_hx_d/plain" "$_hx_d/nocfg" "$_hx_d/repo/.claude" "$_hx_d/bin"
(cd "$_hx_d/nocfg" && git init -q)
(cd "$_hx_d/repo" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)
_hx_cfg() { printf '%s' "$1" > "$_hx_d/repo/.claude/harness.json"; }
_hx_run() { # $1 경우 · $2 폴더 · $3 훅 파일 · $4 stdin → 종료 코드. 기록은 $_hx_d/<경우>.tsv 에만
  (cd "$2" && printf '%s' "$4" | CLAUDE_HARNESS_HOOK_LOG="$_hx_d/$1.tsv" CLAUDE_VERIFY_PS="$_hx_d/ps.txt" \
    GIT_CEILING_DIRECTORIES="$_hx_d" bash "$HOOKS/$3" >/dev/null 2>&1); echo $?
}
_hx_one() { # $1 경우 · $2 훅 이름 · $3 결과 — 그 호출의 기록이 정확히 한 줄이고 훅 · 결과가 맞나
  local f="$_hx_d/$1.tsv" n got
  n=$(cat "$f" 2>/dev/null | awk 'END{print NR}')
  got=$(awk -F'\t' '{printf "%s %s|", $3, $4}' "$f" 2>/dev/null)
  if [ "$n" = "1" ] && [ "$got" = "$2 $3|" ]; then ok "$2 $1 → $3 한 줄"; else bad "$2 $1" "기록 ${n}줄 [$got] (기대: $3 한 줄)"; fi
}

# ── validate-session-end (Stop) ──
_hx_run vse-norepo "$_hx_d/plain" validate-session-end.sh '{}' >/dev/null; _hx_one vse-norepo validate-session-end norepo
_hx_run vse-nocfg "$_hx_d/nocfg" validate-session-end.sh '{}' >/dev/null; _hx_one vse-nocfg validate-session-end nocfg
_hx_cfg '{"verify":{"lint":"true"}}'
for _hx_c in git cat dirname date basename; do ln -sf "$(command -v "$_hx_c")" "$_hx_d/bin/$_hx_c"; done   # python3 만 없는 PATH
(cd "$_hx_d/repo" && printf '{}' | PATH="$_hx_d/bin" CLAUDE_HARNESS_HOOK_LOG="$_hx_d/vse-nopython.tsv" "$BASH" "$HOOKS/validate-session-end.sh" >/dev/null 2>&1)
_hx_one vse-nopython validate-session-end nopython
_hx_cfg '{"verify":{"test":"pnpm test"}}'   # 돌릴 명령 없음(test 는 Stop 에서 안 돈다)
_hx_run vse-noverify "$_hx_d/repo" validate-session-end.sh '{}' >/dev/null; _hx_one vse-noverify validate-session-end noverify
_hx_run vse-same "$_hx_d/repo" validate-session-end.sh '{}' >/dev/null; _hx_one vse-same validate-session-end same
_hx_cfg '{"verify":{"lint":"true"}}'
_hx_run vse-ok "$_hx_d/repo" validate-session-end.sh '{}' >/dev/null; _hx_one vse-ok validate-session-end ok
_hx_cfg '{"verify":{"lint":"false"}}'
_hx_run vse-fail "$_hx_d/repo" validate-session-end.sh '{}' >/dev/null; _hx_one vse-fail validate-session-end fail
_hx_cfg '{"verify":{"lint":"echo busy"}}'
printf 'sh -c pnpm verify\nsh -c pnpm verify\n' > "$_hx_d/ps.txt"
_hx_run vse-busy "$_hx_d/repo" validate-session-end.sh '{}' >/dev/null; _hx_one vse-busy validate-session-end busy
rm -f "$_hx_d/ps.txt"
_hx_cfg '{"verify":{"apps/a":{"lint":"true"}}}'   # 바뀐 파일이 .claude/ 뿐 → 앱 전부 건너뜀
_hx_run vse-skip "$_hx_d/repo" validate-session-end.sh '{}' >/dev/null; _hx_one vse-skip validate-session-end skip

# ── loop-lock (PostToolUse[Bash]) ──
_hx_cfg '{"verify":{"test":"pnpm test"}}'
_hx_run ll-noinput "$_hx_d/repo" loop-lock.sh '{}' >/dev/null; _hx_one ll-noinput loop-lock noinput
_hx_run ll-norepo "$_hx_d/plain" loop-lock.sh '{"session_id":"hx","tool_input":{"command":"pnpm test"}}' >/dev/null; _hx_one ll-norepo loop-lock norepo
_hx_run ll-nocfg "$_hx_d/nocfg" loop-lock.sh '{"session_id":"hx","tool_input":{"command":"pnpm test"}}' >/dev/null; _hx_one ll-nocfg loop-lock nocfg
_hx_run ll-ignore "$_hx_d/repo" loop-lock.sh '{"session_id":"hx","tool_input":{"command":"ls"}}' >/dev/null; _hx_one ll-ignore loop-lock ignore
_hx_run ll-seen1 "$_hx_d/repo" loop-lock.sh '{"session_id":"hx","tool_input":{"command":"pnpm test"}}' >/dev/null; _hx_one ll-seen1 loop-lock seen
_hx_run ll-seen2 "$_hx_d/repo" loop-lock.sh '{"session_id":"hx","tool_input":{"command":"pnpm test"}}' >/dev/null; _hx_one ll-seen2 loop-lock seen
_hx_code=$(_hx_run ll-blocked "$_hx_d/repo" loop-lock.sh '{"session_id":"hx","tool_input":{"command":"pnpm test"}}'); _hx_one ll-blocked loop-lock blocked
[ "$_hx_code" = "2" ] && ok "loop-lock blocked — exit 2 그대로" || bad "loop-lock blocked" "exit=$_hx_code (기대 2)"

# ── todo-warn (PreToolUse[Bash]) ──
_hx_run tw-norepo "$_hx_d/plain" todo-warn.sh '{"tool_input":{"command":"git commit -m x"}}' >/dev/null; _hx_one tw-norepo todo-warn norepo
_hx_run tw-nocfg "$_hx_d/nocfg" todo-warn.sh '{"tool_input":{"command":"git commit -m x"}}' >/dev/null; _hx_one tw-nocfg todo-warn nocfg
_hx_run tw-noinput "$_hx_d/repo" todo-warn.sh '{}' >/dev/null; _hx_one tw-noinput todo-warn noinput
_hx_run tw-ignore "$_hx_d/repo" todo-warn.sh '{"tool_input":{"command":"ls"}}' >/dev/null; _hx_one tw-ignore todo-warn ignore
_hx_run tw-clean "$_hx_d/repo" todo-warn.sh '{"tool_input":{"command":"git commit -m x"}}' >/dev/null; _hx_one tw-clean todo-warn clean
printf '// TODO hx\n' > "$_hx_d/repo/hx.ts"; (cd "$_hx_d/repo" && git add hx.ts)
_hx_run tw-warn "$_hx_d/repo" todo-warn.sh '{"tool_input":{"command":"git commit -m x"}}' >/dev/null; _hx_one tw-warn todo-warn warn
rm -rf "$_hx_d"
