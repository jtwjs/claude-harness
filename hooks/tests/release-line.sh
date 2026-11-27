# conductor-context — 하네스 원본 줄에 「릴리스 안 된 머지 n건 …」 · 「릴리스 확인 실패」(#80 AC-1~7 · AC-10). test.sh 가 source 한다.
# 하네스 원본은 임시 git 레포(버전 올림 커밋 기록을 실제로 만든다), 원격 main 은 가짜 gh 의 compare 응답. 진짜 gh 는 부르지 않는다.
printf '\n[release-line] 지휘 현황 — 설치본 뒤 원격 main 머지 · 확인 실패\n'
_rl_d="$TMP/_rl_"; rm -rf "$_rl_d"
mkdir -p "$_rl_d/seat" "$_rl_d/plugin/.claude-plugin" "$_rl_d/plugin45/.claude-plugin" "$_rl_d/pluginempty/.claude-plugin" "$_rl_d/noplugin"
printf '{"name":"claude-harness","version":"0.43.0"}\n' > "$_rl_d/plugin/.claude-plugin/plugin.json"
printf '{"name":"claude-harness","version":"0.45.0"}\n' > "$_rl_d/plugin45/.claude-plugin/plugin.json"
printf '{"name":"claude-harness","version":""}\n' > "$_rl_d/pluginempty/.claude-plugin/plugin.json"
printf '#!/bin/sh\nexit 0\n' > "$_rl_d/ts"; chmod +x "$_rl_d/ts"
# 가짜 gh — 받은 인자를 적고, harness compare 는 mode 파일대로(ok: compare.json · fail: 종료 1 · slow: 10초 잠)
{
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\n' "$_rl_d/gh.log"
  printf 'case "$*" in\n'
  printf '  "issue list"*) echo "[]";;\n'
  printf '  "api repos/acme/harness/compare/"*) case "$(cat "%s")" in fail) exit 1;; slow) exec sleep 10;; *) cat "%s";; esac;;\n' "$_rl_d/mode" "$_rl_d/compare.json"
  printf '  *) echo "{}";;\n'
  printf 'esac\n'
} > "$_rl_d/gh"; chmod +x "$_rl_d/gh"
_rl_git() { git -C "$_rl_d/rl-harness" -c user.email=t@t -c user.name=t "$@"; }
_rl_ver() { printf '{"name":"claude-harness","version":"%s"}\n' "$1" > "$_rl_d/rl-harness/.claude-plugin/plugin.json"; }
# 하네스 원본: 0.42.0 (#1) → 기능 (#2) → 0.43.0 올림 (#3) = 기준점. 로컬 origin/main 은 기준점
mkdir -p "$_rl_d/rl-harness/.claude-plugin" "$_rl_d/rl-harness/.claude" && git -C "$_rl_d/rl-harness" init -q
printf '{"harness":{"version":"0.43.0"}}' > "$_rl_d/rl-harness/.claude/harness.json"
_rl_ver 0.42.0; _rl_git add -A; _rl_git commit -q -m "chore: 0.42.0 (#1)"
echo x > "$_rl_d/rl-harness/x.txt"; _rl_git add -A; _rl_git commit -q -m "feat: x (#2)"
_rl_ver 0.43.0; _rl_git add -A; _rl_git commit -q -m "chore: 0.43.0 (#3)"
_rl_base="$(_rl_git rev-parse HEAD)"
_rl_git remote add origin https://github.com/acme/harness.git
_rl_git update-ref refs/remotes/origin/main "$_rl_base"
# 다른 플러그인 레포: 하네스 원본이 아니다(이름 다름). 템플릿 0.34.0 이라 템플릿 꼬리는 붙는다
mkdir -p "$_rl_d/rl-other/.claude-plugin" "$_rl_d/rl-other/.claude" && git -C "$_rl_d/rl-other" init -q
printf '{"name":"other-plugin","version":"1.0.0"}\n' > "$_rl_d/rl-other/.claude-plugin/plugin.json"
printf '{"harness":{"version":"0.34.0"}}' > "$_rl_d/rl-other/.claude/harness.json"
git -C "$_rl_d/rl-other" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$_rl_d/rl-other" remote add origin https://github.com/acme/other.git
printf '{"seat":"%s","repos":["%s","%s"]}' "$_rl_d/seat" "$_rl_d/rl-harness" "$_rl_d/rl-other" > "$_rl_d/conductor.json"

_rl_json() { # 커밋 메시지들(오래된 것부터) → compare 응답 JSON
  python3 -c 'import json,sys; m=sys.argv[1:]; print(json.dumps({"total_commits":len(m),"commits":[{"sha":"%040d"%i,"commit":{"message":x}} for i,x in enumerate(m)]}))' "$@" > "$_rl_d/compare.json"
}
_rl_run() { # $1 설치본 폴더 · $2 mode · [$3 전체 마감] → $_rl_ctx
  printf '%s' "$2" > "$_rl_d/mode"; : > "$_rl_d/gh.log"
  _rl_ctx="$( (cd "$_rl_d/seat" && printf '{}' | env CLAUDE_CONDUCTOR_CONFIG="$_rl_d/conductor.json" CLAUDE_CONDUCTOR_GH="$_rl_d/gh" \
    CLAUDE_CONDUCTOR_TS="$_rl_d/ts" CLAUDE_PLUGIN_ROOT="$1" CLAUDE_CONDUCTOR_DEADLINE="${3:-25}" bash "$HOOKS/conductor-context.sh" 2>/dev/null) \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])' 2>/dev/null)"
}
_rl_line() { printf '%s\n' "$_rl_ctx" | grep -F -- "- $1 —"; }
_rl_head='- rl-harness — 트랙 손댈 것 없음'
_rl_fail() { # $1 테스트 이름 · $2 설명 — 하네스 원본 줄에 「릴리스 확인 실패」, 「릴리스 안 된 머지」 없음
  _rl_l="$(_rl_line rl-harness)"
  case "$_rl_l" in "$_rl_head · 릴리스 확인 실패"*) printf '%s' "$_rl_l" | grep -qF '릴리스 안 된 머지' && bad "$1" "[$_rl_l]" || ok "$1 — $2";; *) bad "$1" "[$_rl_l] ctx=[$_rl_ctx]";; esac
}

# ── 세기 · 꼴 ──
_rl_json "feat: a (#10)" "fix: b (#11)"
_rl_run "$_rl_d/plugin" ok
[ "$(_rl_line rl-harness)" = "$_rl_head · 릴리스 안 된 머지 2건 #10 · #11 (설치본 0.43.0)" ] \
  && ok "release_counts_with_numbers — 2건 + PR 번호 + 설치본 버전" || bad "release_counts_with_numbers" "[$(_rl_line rl-harness)] ctx=[$_rl_ctx]"
grep -qxF "api repos/acme/harness/compare/$_rl_base...main" "$_rl_d/gh.log" \
  && ok "release — 기준점은 버전이 설치본 버전이 된 커밋 · compare 1회" || bad "release 기준점" "log=[$(cat "$_rl_d/gh.log")] base=$_rl_base"
[ "$(_rl_git rev-list --count "$_rl_base..origin/main")" = "0" ] && [ "$(_rl_line rl-harness)" = "$_rl_head · 릴리스 안 된 머지 2건 #10 · #11 (설치본 0.43.0)" ] \
  && ok "release_remote_ahead_of_local_counted — 로컬 origin/main 은 기준점 그대로여도 원격 2건을 센다" || bad "release_remote_ahead_of_local_counted" "[$(_rl_line rl-harness)]"
[ "$(_rl_git rev-parse refs/remotes/origin/main)" = "$_rl_base" ] && ok "release — 로컬 ref 를 바꾸지 않는다(fetch 안 함)" || bad "release 로컬 ref" "$(_rl_git rev-parse refs/remotes/origin/main)"
! grep -qF 'acme/other/compare' "$_rl_d/gh.log" && [ "$(_rl_line rl-other)" = "- rl-other — 트랙 손댈 것 없음 · 템플릿 0.34.0 → 설치본 0.43.0" ] \
  && ok "release_other_plugin_repo_not_checked — 이름이 다른 플러그인 레포는 원격 조회 · 릴리스 꼬리 없음" || bad "release_other_plugin_repo_not_checked" "[$(_rl_line rl-other)] log=[$(cat "$_rl_d/gh.log")]"

_rl_json
_rl_run "$_rl_d/plugin" ok
[ "$(_rl_line rl-harness)" = "$_rl_head" ] && ok "release_zero_no_suffix — 0건 → 꼬리 없음" || bad "release_zero_no_suffix" "[$(_rl_line rl-harness)]"

_rl_json "a (#10)" "b (#11)" "c (#12)" "d (#13)" "e (#14)"
_rl_run "$_rl_d/plugin" ok
[ "$(_rl_line rl-harness)" = "$_rl_head · 릴리스 안 된 머지 5건 #10 · #11 · #12 · #13 · #14 (설치본 0.43.0)" ] \
  && ok "release_five_numbers_no_overflow — 5개는 다 보이고 「외」 없음" || bad "release_five_numbers_no_overflow" "[$(_rl_line rl-harness)]"

_rl_json "a (#10)" "b (#11)" "c (#12)" "d (#13)" "e (#14)" "f (#15)" "g (#16)"
_rl_run "$_rl_d/plugin" ok
[ "$(_rl_line rl-harness)" = "$_rl_head · 릴리스 안 된 머지 7건 #10 · #11 · #12 · #13 · #14 외 2건 (설치본 0.43.0)" ] \
  && ok "release_overflow_shows_rest — 7건은 오래된 것부터 5개 + 「외 2건」" || bad "release_overflow_shows_rest" "[$(_rl_line rl-harness)]"

_rl_json "feat: a (#55) (#10)" "hotfix pushed directly" "$(printf 'docs: b (#11)\n\n본문 (#99)')"
_rl_run "$_rl_d/plugin" ok
[ "$(_rl_line rl-harness)" = "$_rl_head · 릴리스 안 된 머지 3건 #10 · #11 외 1건 (설치본 0.43.0)" ] \
  && ok "release_commit_without_pr_number_counted — 번호 없는 커밋도 셈 · 번호는 첫 줄 끝 마지막 (#N)" || bad "release_commit_without_pr_number_counted" "[$(_rl_line rl-harness)]"
_rl_json "hotfix pushed directly"
_rl_run "$_rl_d/plugin" ok
[ "$(_rl_line rl-harness)" = "$_rl_head · 릴리스 안 된 머지 1건 (설치본 0.43.0)" ] \
  && ok "release — 번호가 하나도 없으면 「외」 없이 건수만" || bad "release 번호 0개" "[$(_rl_line rl-harness)]"

_rl_json "docs: only docs (#20)"
_rl_run "$_rl_d/plugin" ok
[ "$(_rl_line rl-harness)" = "$_rl_head · 릴리스 안 된 머지 1건 #20 (설치본 0.43.0)" ] \
  && ok "release_docs_only_counted — 문서만 바꾼 머지도 센다" || bad "release_docs_only_counted" "[$(_rl_line rl-harness)]"

# 버전은 올렸는데 release.sh 를 안 돌림: 로컬 origin/main 이 0.44.0 올림 커밋(#4)까지 와도 기준점은 0.43.0 올림 커밋
_rl_ver 0.44.0; _rl_git add -A; _rl_git commit -q -m "chore: 0.44.0 (#4)"
_rl_git update-ref refs/remotes/origin/main "$(_rl_git rev-parse HEAD)"
_rl_json "chore: 0.44.0 (#4)"
_rl_run "$_rl_d/plugin" ok
[ "$(_rl_line rl-harness)" = "$_rl_head · 릴리스 안 된 머지 1건 #4 (설치본 0.43.0)" ] && grep -qxF "api repos/acme/harness/compare/$_rl_base...main" "$_rl_d/gh.log" \
  && ok "release_bump_unreleased_counted — 버전 올림 머지도 센다 · 기준점은 설치본 버전 커밋" || bad "release_bump_unreleased_counted" "[$(_rl_line rl-harness)] log=[$(cat "$_rl_d/gh.log")]"
_rl_git update-ref refs/remotes/origin/main "$_rl_base"

# ── 확인 실패 — 0건처럼 보이지 않는다 ──
_rl_json "feat: a (#10)"
_rl_run "$_rl_d/plugin" fail
_rl_fail release_gh_error_fails "원격 조회 실패 → 「릴리스 확인 실패」"
[ "$(_rl_line rl-other)" = "- rl-other — 트랙 손댈 것 없음 · 템플릿 0.34.0 → 설치본 0.43.0" ] && printf '%s' "$_rl_ctx" | grep -qF '열린 지휘 이슈 (acme/other): 없음' \
  && ok "release_failure_isolated_to_repo — 하네스 원본 실패가 다른 레포 줄 · 이슈 줄을 막지 않는다" || bad "release_failure_isolated_to_repo" "ctx=[$_rl_ctx]"

printf 'not json' > "$_rl_d/compare.json"
_rl_run "$_rl_d/plugin" ok
_rl_fail release_bad_json_fails "compare 응답이 JSON 아님 → 「릴리스 확인 실패」"

_rl_json "feat: a (#10)"
_rl_run "$_rl_d/plugin45" ok
_rl_fail release_base_not_found_fails "기록에 설치본 버전(0.45.0) 커밋이 없음 → 「릴리스 확인 실패」"
! grep -qF '/compare/' "$_rl_d/gh.log" && ok "release — 기준점을 못 찾으면 원격 조회를 하지 않는다" || bad "release 기준점 없음 조회" "log=[$(cat "$_rl_d/gh.log")]"

_rl_run "$_rl_d/pluginempty" ok
_rl_fail release_installed_version_empty_fails "설치본 version 빈 값 → 「릴리스 확인 실패」"

_rl_run "$_rl_d/noplugin" ok
_rl_fail release_installed_unreadable_fails "설치본 plugin.json 없음(이름 모름) → 플러그인 레포 줄에 「릴리스 확인 실패」"

_rl_s=$SECONDS
_rl_run "$_rl_d/plugin" slow 3
_rl_e=$((SECONDS - _rl_s))
[ "$_rl_e" -le 7 ] && ok "release_gh_slow_fails_within_limit — 원격이 10초 걸려도 마감 안에서 끝남(${_rl_e}초)" || bad "release_gh_slow_fails_within_limit 시간" "${_rl_e}초"
_rl_fail release_gh_slow_fails_within_limit "원격 시간 초과 → 「릴리스 확인 실패」"
