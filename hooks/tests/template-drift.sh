# conductor-context — 지휘 현황 레포 줄에 「템플릿 X → 설치본 Y」(#80 AC-8). test.sh 가 source 한다.
# 설치본은 가짜 플러그인 폴더(CLAUDE_PLUGIN_ROOT), 지휘 설정 · gh · tracks_status 는 바꿔 끼운다. 진짜 gh 는 부르지 않는다.
printf '\n[template-drift] 지휘 현황 — 레포 템플릿 ≠ 설치본이면 그 레포 줄에 한 꼬리\n'
_td_d="$TMP/_td_"; rm -rf "$_td_d"
mkdir -p "$_td_d/seat" "$_td_d/plugin/.claude-plugin" "$_td_d/noplugin"
printf '{"name":"claude-harness","version":"0.43.0"}\n' > "$_td_d/plugin/.claude-plugin/plugin.json"
printf '#!/bin/sh\nexit 0\n' > "$_td_d/ts"; chmod +x "$_td_d/ts"          # 트랙 줄: 「트랙 손댈 것 없음」
printf '#!/bin/sh\necho "[]"\n' > "$_td_d/gh"; chmod +x "$_td_d/gh"        # 열린 지휘 이슈: 없음
for _td_r in rt-desk rt-same rt-empty rt-broken rt-nocfg; do
  mkdir -p "$_td_d/$_td_r" && (cd "$_td_d/$_td_r" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)
done
mkdir -p "$_td_d/rt-desk/.claude" "$_td_d/rt-same/.claude" "$_td_d/rt-empty/.claude" "$_td_d/rt-broken/.claude"
printf '{"harness":{"version":"0.34.0"}}' > "$_td_d/rt-desk/.claude/harness.json"
printf '{"harness":{"version":"0.43.0"}}' > "$_td_d/rt-same/.claude/harness.json"
printf '{"harness":{"version":""}}' > "$_td_d/rt-empty/.claude/harness.json"
printf '{"harness":{"version":"0.30.0"' > "$_td_d/rt-broken/.claude/harness.json"
printf '{"seat":"%s","repos":["%s","%s","%s","%s","%s"]}' "$_td_d/seat" \
  "$_td_d/rt-desk" "$_td_d/rt-same" "$_td_d/rt-empty" "$_td_d/rt-broken" "$_td_d/rt-nocfg" > "$_td_d/conductor.json"
_td_run() { # $1 설치본 폴더 → additionalContext
  (cd "$_td_d/seat" && printf '{}' | env CLAUDE_CONDUCTOR_CONFIG="$_td_d/conductor.json" CLAUDE_CONDUCTOR_GH="$_td_d/gh" \
    CLAUDE_CONDUCTOR_TS="$_td_d/ts" CLAUDE_PLUGIN_ROOT="$1" bash "$HOOKS/conductor-context.sh" 2>/dev/null) \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null
}
_td_line() { printf '%s\n' "$_td_ctx" | grep -F -- "- $1 —"; }   # $1 레포 이름 → 그 레포 줄

_td_ctx="$(_td_run "$_td_d/plugin")"
[ "$(_td_line rt-desk)" = "- rt-desk — 트랙 손댈 것 없음 · 템플릿 0.34.0 → 설치본 0.43.0" ] \
  && ok "template_differs_suffix — 다름 → 그 레포 줄 끝에 「템플릿 0.34.0 → 설치본 0.43.0」" || bad "template_differs_suffix" "[$(_td_line rt-desk)] ctx=[$_td_ctx]"
[ "$(_td_line rt-same)" = "- rt-same — 트랙 손댈 것 없음" ] \
  && ok "template_same_no_suffix — 같음 → 꼬리 없음" || bad "template_same_no_suffix" "[$(_td_line rt-same)]"
[ "$(_td_line rt-empty)" = "- rt-empty — 트랙 손댈 것 없음" ] \
  && ok "template_empty_version_no_suffix — harness.version 빈 값 → 꼬리 없음" || bad "template_empty_version_no_suffix" "[$(_td_line rt-empty)]"
[ "$(_td_line rt-broken)" = "- rt-broken — 트랙 손댈 것 없음" ] \
  && ok "template_broken_json_no_suffix — harness.json 깨짐 → 꼬리 없음 · 훅은 계속" || bad "template_broken_json_no_suffix" "[$(_td_line rt-broken)]"
[ "$(_td_line rt-nocfg)" = "- rt-nocfg — 트랙 손댈 것 없음" ] \
  && ok "template_no_harness_config_no_suffix — 하네스 설정 없음 → 꼬리 없음" || bad "template_no_harness_config_no_suffix" "[$(_td_line rt-nocfg)]"
[ "$(printf '%s\n' "$_td_ctx" | grep -c '템플릿 ')" = "1" ] \
  && ok "template — 꼬리는 다른 레포 하나에만" || bad "template 꼬리 수" "ctx=[$_td_ctx]"

# 설치본 버전을 못 읽으면 비교하지 않는다(레포 세션 알림과 같은 규칙) — 현황은 그래도 나온다
_td_ctx="$(_td_run "$_td_d/noplugin")"
[ "$(_td_line rt-desk)" = "- rt-desk — 트랙 손댈 것 없음" ] && ! printf '%s' "$_td_ctx" | grep -qF '템플릿 ' \
  && ok "template_installed_unreadable_skips — 설치본 plugin.json 없음 → 템플릿 꼬리 없음 · 현황은 나옴" || bad "template_installed_unreadable_skips" "ctx=[$_td_ctx]"
