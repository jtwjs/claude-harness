# 템플릿 CI 비밀값 검사 잡(#71) — templates/.github/workflows/ci.yml 의 secret-scan 잡. test.sh 가 source 한다.
# 꼴은 시스템 ruby YAML 로 읽고, 동작은 스텝의 run: 을 꺼내 GitHub Actions 기본 셸(bash -e)로 돌린다.
# 네트워크는 쓰지 않는다: curl · gitleaks 는 가짜다. 실제 gitleaks 실행은 phases/secret-scan step 4(측정)가 맡는다.
# 레포 파일은 건드리지 않는다 — 전부 $TMP 안에서 돈다.
printf '\n[secret-scan] 템플릿 CI 비밀값 검사 잡 — PR 범위 · 버전 · 체크섬 고정\n'
_ss_root="$(cd "$HOOKS/.." && pwd)"
_ss_tpl="$_ss_root/templates/.github/workflows/ci.yml"
_ss_d="$TMP/_ss_"; mkdir -p "$_ss_d/bin"

# YAML 질의: $1=ruby 식(y=문서, j=secret-scan 잡, a=ARGV 나머지) $2=파일 … — 못 읽으면 빈 출력
_ss_q() { # $1 식 $2 파일 [$3…]
  ruby -ryaml -e 'y = YAML.load_file(ARGV.shift); j = (y["jobs"] || {})["secret-scan"] rescue nil; a = ARGV; r = (eval(ARGV.shift) rescue nil); print r.to_s' "$2" "$1" "${@:3}" 2>/dev/null
}
_ss_step_run() { _ss_q '(j["steps"].find { |s| s["name"] == a[0] } || {})["run"]' "$1" "$2"; }   # $1 파일 $2 스텝 이름

# 가짜 curl: -o 다음 인자에 $SS_FIXTURE 를 쓰고, 받은 주소를 $SS_CURL_LOG 에 남긴다. SS_CURL_FAIL=1 이면 22(HTTP 실패)
cat > "$_ss_d/bin/curl" <<'EOF'
#!/bin/bash
out=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in -o) out="$2"; shift 2 ;; -*) shift ;; *) url="$1"; shift ;; esac
done
printf '%s\n' "$url" >> "$SS_CURL_LOG"
[ "${SS_CURL_FAIL:-0}" = "1" ] && exit 22
cp "$SS_FIXTURE" "$out"
EOF
chmod +x "$_ss_d/bin/curl"
# sha256sum 이 없는 macOS 에서는 shasum 으로 대신한다(같은 -c 꼴)
command -v sha256sum >/dev/null 2>&1 || { printf '#!/bin/sh\nexec shasum -a 256 "$@"\n' > "$_ss_d/bin/sha256sum"; chmod +x "$_ss_d/bin/sha256sum"; }
# 내려받기 대신 줄 압축 파일 — 안에 gitleaks 하나
mkdir -p "$_ss_d/pkg" && printf '#!/bin/sh\necho fake\n' > "$_ss_d/pkg/gitleaks" && chmod +x "$_ss_d/pkg/gitleaks"
tar -czf "$_ss_d/fixture.tar.gz" -C "$_ss_d/pkg" gitleaks
_ss_fix_sha="$(shasum -a 256 "$_ss_d/fixture.tar.gz" | cut -d' ' -f1)"

# ① 단일 형태: secret-scan 잡이 verify 옆에 있다 · YAML 로 읽힌다
_ss_jobs="$(ruby -ryaml -e 'print (YAML.load_file(ARGV[0])["jobs"] || {}).keys.join(" ")' "$_ss_tpl" 2>/dev/null)"
case " $_ss_jobs " in *" verify "*) _ss_v=1 ;; *) _ss_v=0 ;; esac
case " $_ss_jobs " in *" secret-scan "*) [ "$_ss_v" = "1" ] ;; *) false ;; esac \
  && ok "ss-single-job — 단일 형태 jobs 에 verify · secret-scan" || bad "ss-single-job" "jobs=[$_ss_jobs]"
[ "$(_ss_q 'j["if"]' "$_ss_tpl")" = "github.event_name == 'pull_request'" ] \
  && ok "ss-pr-only — PR 에서만 돈다(push 는 건너뜀)" || bad "ss-pr-only" "if=[$(_ss_q 'j["if"]' "$_ss_tpl")]"
[ "$(_ss_q 'j["runs-on"]' "$_ss_tpl")" = "ubuntu-latest" ] && [ -z "$(_ss_q 'j["needs"]' "$_ss_tpl")" ] \
  && ok "ss-independent — ubuntu-latest · verify 를 기다리지 않음(needs 없음)" || bad "ss-independent" "runs-on=[$(_ss_q 'j["runs-on"]' "$_ss_tpl")] needs=[$(_ss_q 'j["needs"]' "$_ss_tpl")]"
[ "$(_ss_q '(j["steps"].find { |s| s["uses"].to_s.start_with?("actions/checkout@") } || {}).fetch("with", {})["fetch-depth"]' "$_ss_tpl")" = "0" ] \
  && ok "ss-fetch-depth — checkout fetch-depth 0(기준 커밋이 있어야 범위가 된다)" || bad "ss-fetch-depth" "checkout with=[$(_ss_q '(j["steps"].find { |s| s["uses"].to_s.start_with?("actions/checkout@") } || {})["with"]' "$_ss_tpl")]"
_ss_ver="$(_ss_q 'j["env"]["GITLEAKS_VERSION"]' "$_ss_tpl")"; _ss_sha="$(_ss_q 'j["env"]["GITLEAKS_SHA256"]' "$_ss_tpl")"
[ "$_ss_ver" = "8.30.1" ] && [ "$_ss_sha" = "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb" ] \
  && ok "ss-pinned — GITLEAKS_VERSION 8.30.1 · GITLEAKS_SHA256 = 상류 linux_x64 값" || bad "ss-pinned" "version=[$_ss_ver] sha=[$_ss_sha]"
grep -q '폐기' "$_ss_tpl" && ok "ss-revoke-note — 걸리면 폐기가 먼저라는 주석" || bad "ss-revoke-note" "템플릿에 「폐기」 주석 없음"
! grep -qE 'claude-harness|jtwjs|/Users/' "$_ss_tpl" && ok "ss-no-repo-specific — 템플릿에 이 레포 전용 이름 · 경로 없음" || bad "ss-no-repo-specific" "$(grep -nE 'claude-harness|jtwjs|/Users/' "$_ss_tpl")"

# ② install gitleaks: 주소 · 체크섬 대조 · $RUNNER_TEMP 에 풀기 · 작업 트리 깨끗
_ss_install="$(_ss_step_run "$_ss_tpl" "install gitleaks")"
_ss_inst() { # $1 RUNNER_TEMP $2 sha $3 curl 실패(0|1) → 종료 코드
  mkdir -p "$1" "$1.work" && : > "$_ss_d/curl.log"
  (cd "$1.work" && env PATH="$_ss_d/bin:$PATH" RUNNER_TEMP="$1" GITLEAKS_VERSION="${_ss_ver:-8.30.1}" GITLEAKS_SHA256="$2" \
    SS_CURL_LOG="$_ss_d/curl.log" SS_FIXTURE="$_ss_d/fixture.tar.gz" SS_CURL_FAIL="$3" bash -e -c "$_ss_install" >"$_ss_d/inst.out" 2>&1)
}
if [ -z "$_ss_install" ]; then
  bad "ss-install-ok" "install gitleaks 스텝(run:)이 없다"
  bad "ss-install-sha-mismatch-fails" "install gitleaks 스텝이 없다"
  bad "ss-install-download-fails" "install gitleaks 스텝이 없다"
else
  _ss_inst "$_ss_d/rt-ok" "$_ss_fix_sha" 0; _ss_code=$?
  [ "$_ss_code" = "0" ] && [ -x "$_ss_d/rt-ok/gitleaks" ] && [ -z "$(ls -A "$_ss_d/rt-ok.work")" ] \
    && ok "ss-install-ok — 체크섬 같으면 \$RUNNER_TEMP/gitleaks · 작업 트리 깨끗" || bad "ss-install-ok" "exit=$_ss_code work=[$(ls -A "$_ss_d/rt-ok.work")] out=[$(cat "$_ss_d/inst.out")]"
  [ "$(cat "$_ss_d/curl.log")" = "https://github.com/gitleaks/gitleaks/releases/download/v${_ss_ver}/gitleaks_${_ss_ver}_linux_x64.tar.gz" ] \
    && ok "ss-install-url — 고정 버전의 linux_x64 릴리스 주소" || bad "ss-install-url" "url=[$(cat "$_ss_d/curl.log")]"
  _ss_inst "$_ss_d/rt-bad" "$_ss_sha" 0; _ss_code=$?
  [ "$_ss_code" != "0" ] && [ ! -e "$_ss_d/rt-bad/gitleaks" ] \
    && ok "ss-install-sha-mismatch-fails — 체크섬 다르면 실패 · 풀지 않음" || bad "ss-install-sha-mismatch-fails" "exit=$_ss_code gitleaks 있음=$([ -e "$_ss_d/rt-bad/gitleaks" ] && echo 예 || echo 아니오)"
  _ss_inst "$_ss_d/rt-dl" "$_ss_fix_sha" 1; _ss_code=$?
  [ "$_ss_code" != "0" ] && [ ! -e "$_ss_d/rt-dl/gitleaks" ] \
    && ok "ss-install-download-fails — 내려받기 실패면 잡 실패" || bad "ss-install-download-fails" "exit=$_ss_code"
fi

# ③ gitleaks scan: PR 기준 · 머리 sha 를 env 로 받아 base..head 만 · 값 가림 · 종료 코드 그대로
[ "$(_ss_q '(j["steps"].find { |s| s["name"] == "gitleaks scan" } || {}).fetch("env", {})["BASE_SHA"]' "$_ss_tpl")" = '${{ github.event.pull_request.base.sha }}' ] \
  && [ "$(_ss_q '(j["steps"].find { |s| s["name"] == "gitleaks scan" } || {}).fetch("env", {})["HEAD_SHA"]' "$_ss_tpl")" = '${{ github.event.pull_request.head.sha }}' ] \
  && ok "ss-scan-env — BASE_SHA · HEAD_SHA ← pull_request base · head sha" || bad "ss-scan-env" "env=[$(_ss_q '(j["steps"].find { |s| s["name"] == "gitleaks scan" } || {})["env"]' "$_ss_tpl")]"
_ss_scan="$(_ss_step_run "$_ss_tpl" "gitleaks scan")"
if [ -z "$_ss_scan" ]; then
  bad "ss-scan-range" "gitleaks scan 스텝(run:)이 없다"
  bad "ss-scan-exit-propagates" "gitleaks scan 스텝이 없다"
else
  case "$_ss_scan" in *'${{'*) bad "ss-scan-no-inline-expr" "run: 안에 \${{ }}" ;; *) ok "ss-scan-no-inline-expr — run: 안에 \${{ }} 를 직접 쓰지 않음" ;; esac
  _ss_r="$_ss_d/repo"; mkdir -p "$_ss_r" "$_ss_d/rt-scan"
  (cd "$_ss_r" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base \
    && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m pr)
  _ss_b="$(git -C "$_ss_r" rev-parse HEAD~1)"; _ss_h="$(git -C "$_ss_r" rev-parse HEAD)"
  # 가짜 gitleaks: 인자를 한 줄에 하나씩 남기고 $SS_GL_EXIT 로 끝난다
  printf '#!/bin/sh\nfor a in "$@"; do printf "%%s\\n" "$a"; done > "$SS_GL_ARGS"\nexit "${SS_GL_EXIT:-0}"\n' > "$_ss_d/rt-scan/gitleaks"; chmod +x "$_ss_d/rt-scan/gitleaks"
  _ss_sc() { # $1 가짜 종료 코드 → 종료 코드
    (cd "$_ss_r" && env RUNNER_TEMP="$_ss_d/rt-scan" BASE_SHA="$_ss_b" HEAD_SHA="$_ss_h" SS_GL_ARGS="$_ss_d/gl.args" SS_GL_EXIT="$1" \
      bash -e -c "$_ss_scan" >"$_ss_d/scan.out" 2>&1)
  }
  _ss_sc 0; _ss_code=$?
  _ss_args="$(tr '\n' ' ' < "$_ss_d/gl.args" 2>/dev/null)"
  [ "$_ss_code" = "0" ] && printf '%s' "$_ss_args" | grep -qE "(^| )git( |$)" && printf '%s' "$_ss_args" | grep -qE -- "--log-opts[= ]${_ss_b}\.\.${_ss_h}( |$)" \
    && printf '%s' "$_ss_args" | grep -qE -- "(^| )--redact( |$)" \
    && ok "ss-scan-range — gitleaks git --log-opts=base..head · --redact" || bad "ss-scan-range" "exit=$_ss_code args=[$_ss_args] out=[$(cat "$_ss_d/scan.out")]"
  _ss_sc 1; _ss_code1=$?
  [ "$_ss_code1" != "0" ] && ok "ss-scan-exit-propagates — gitleaks 가 찾으면(1) 잡 실패 · 없으면(0) 통과" || bad "ss-scan-exit-propagates" "가짜 1 → exit=$_ss_code1 · 가짜 0 → exit=$_ss_code"
fi

# ④ harness-init 이 채운 뒤에도 잡이 남는다 — 플레이스홀더를 늘리지 않았고 fill_ci.py 가 잡을 지우지 않는다
_ss_f="$_ss_d/filled"; mkdir -p "$_ss_f/.claude" "$_ss_f/.github/workflows" && cp "$_ss_tpl" "$_ss_f/.github/workflows/ci.yml"
printf '%s' '{"git":{"baseBranch":"main"},"verify":{"test":"make test"}}' > "$_ss_f/.claude/harness.json"
python3 "$_ss_root/skills/harness-init/scripts/fill_ci.py" "$_ss_f/.claude/harness.json" "$_ss_f/.github/workflows/ci.yml" >/dev/null 2>&1; _ss_code=$?
[ "$_ss_code" = "0" ] && [ "$(_ss_q 'j["env"]["GITLEAKS_SHA256"]' "$_ss_f/.github/workflows/ci.yml")" = "$_ss_sha" ] && [ -n "$_ss_sha" ] \
  && ok "ss-after-fill — fill_ci.py exit 0 뒤에도 secret-scan 잡 그대로" || bad "ss-after-fill" "exit=$_ss_code sha=[$(_ss_q 'j["env"]["GITLEAKS_SHA256"]' "$_ss_f/.github/workflows/ci.yml")]"

# ⑤ 앱별 형태(맨 아래 주석 블록): 주석을 벗기면 YAML · 같은 secret-scan 잡 · ci-gate 가 그 결과를 모은다
_ss_app="$_ss_d/app.yml"
awk 'f { if ($0 == "#") print ""; else if (substr($0, 1, 2) == "# ") print substr($0, 3); else print; next } $0 == "# jobs:" { f = 1; print "jobs:" }' "$_ss_tpl" > "$_ss_app"
_ss_ajobs="$(ruby -ryaml -e 'print (YAML.load_file(ARGV[0])["jobs"] || {}).keys.join(" ")' "$_ss_app" 2>/dev/null)"
case " $_ss_ajobs " in *" ci-gate "*) _ss_v=1 ;; *) _ss_v=0 ;; esac
case " $_ss_ajobs " in *" secret-scan "*) [ "$_ss_v" = "1" ] ;; *) false ;; esac \
  && ok "ss-app-job — 앱별 블록을 펼치면 YAML 로 읽히고 secret-scan · ci-gate 가 있다" || bad "ss-app-job" "jobs=[$_ss_ajobs]"
[ "$(ruby -ryaml -e 'a = YAML.load_file(ARGV[0])["jobs"]["secret-scan"]; b = YAML.load_file(ARGV[1])["jobs"]["secret-scan"]; print(!a.nil? && a == b)' "$_ss_app" "$_ss_tpl" 2>/dev/null)" = "true" ] \
  && ok "ss-app-same-as-single — 앱별 secret-scan 잡 = 단일 형태 잡(if · env · 스텝 같음, paths 필터 밖)" || bad "ss-app-same-as-single" "앱별 블록 잡이 없거나 단일 형태와 다르다"
_ss_needs="$(_ss_q 'Array(y["jobs"]["ci-gate"]["needs"]).join(" ")' "$_ss_app")"
_ss_v=1; for _ss_n in changes api web secret-scan; do case " $_ss_needs " in *" $_ss_n "*) ;; *) _ss_v=0 ;; esac; done
[ "$_ss_v" = "1" ] \
  && ok "ss-app-gate-needs — ci-gate needs 에 secret-scan(changes · api · web 그대로)" || bad "ss-app-gate-needs" "needs=[$_ss_needs]"
# ci-gate 판정 줄을 그대로 돌린다: needs 마다 결과를 넣은 JSON 으로 ${{ toJSON(needs) }} 를 바꾼다
_ss_gate_run="$(_ss_q '(y["jobs"]["ci-gate"]["steps"].find { |s| s["run"].to_s.include?("jq") } || {})["run"]' "$_ss_app")"
_ss_gate() { # $1 secret-scan 결과 → 종료 코드 (다른 needs 는 success)
  local js; js="$(python3 -c 'import json,sys; print(json.dumps({n: {"result": sys.argv[1] if n == "secret-scan" else "success"} for n in sys.argv[2:]}))' "$1" $_ss_needs)"
  bash -e -c "${_ss_gate_run//'${{ toJSON(needs) }}'/$js}" >/dev/null 2>&1
}
if [ -z "$_ss_gate_run" ]; then
  bad "ss-app-gate-skipped-ok" "ci-gate jq 판정 줄이 없다"; bad "ss-app-gate-fails-on-scan-failure" "ci-gate jq 판정 줄이 없다"
else
  _ss_gate skipped && ok "ss-app-gate-skipped-ok — push 에서 secret-scan 이 skipped 면 ci-gate 통과" || bad "ss-app-gate-skipped-ok" "skipped 인데 ci-gate 가 막음"
  ! _ss_gate failure && ok "ss-app-gate-fails-on-scan-failure — secret-scan 이 실패하면 ci-gate 가 막는다" || bad "ss-app-gate-fails-on-scan-failure" "secret-scan failure 인데 ci-gate 통과(needs=[$_ss_needs])"
fi

# ⑥ 템플릿 .gitignore 에 .env · 이미 깔린 레포(업그레이드 모드): CI 는 안내 한 줄만, .env 줄은 기존 .gitignore 행(빠진 줄 · diff 승인 뒤)
_ss_gi="$_ss_root/templates/.gitignore.append"
_ss_keep="$(grep -n '아래는 ignore 하지 않는다' "$_ss_gi" | head -1 | cut -d: -f1)"
_ss_env="$(grep -nx '\.env' "$_ss_gi" | head -1 | cut -d: -f1)"
[ -n "$_ss_env" ] && { [ -z "$_ss_keep" ] || [ "$_ss_env" -lt "$_ss_keep" ]; } \
  && ok "ss-gitignore-env-line — .gitignore.append 에 .env 줄(ignore 하지 않는다 블록 밖)" || bad "ss-gitignore-env-line" ".env 줄=[$_ss_env] 「ignore 하지 않는다」 줄=[$_ss_keep]"
_ss_up="$_ss_d/upgrade.md"
awk '/^## 0\./ { f = 1; next } /^## 1\./ { f = 0 } f' "$_ss_root/skills/harness-init/SKILL.md" > "$_ss_up"
_ss_ci_row="$(grep -E '^\| [^|]*\.github/workflows/ci\.yml' "$_ss_up" | head -1)"
case "$_ss_ci_row" in *gitleaks*) _ss_v=1 ;; *) _ss_v=0 ;; esac
case "$_ss_ci_row" in *secret-scan*) ;; *) _ss_v=0 ;; esac
case "$_ss_ci_row" in *'고치지 않'*) ;; *) _ss_v=0 ;; esac
case "$_ss_ci_row" in *'안내'*) ;; *) _ss_v=0 ;; esac
[ "$_ss_v" = "1" ] && ok "ss-upgrade-ci-row — 업그레이드 표 CI 행: 고치지 않음 · gitleaks 없으면 secret-scan 안내 한 줄" || bad "ss-upgrade-ci-row" "행=[$_ss_ci_row]"
grep -qxF '| `.gitignore` | `${CLAUDE_PLUGIN_ROOT}/templates/.gitignore.append`의 줄 중 빠진 것만 |' "$_ss_up" \
  && grep -qF 'CI는 다시 하지 않는다' "$_ss_up" \
  && ok "ss-upgrade-gitignore-row-unchanged — .gitignore 행 그대로(.env 도 빠진 줄 · diff 승인 뒤) · 「CI는 다시 하지 않는다」 그대로" \
  || bad "ss-upgrade-gitignore-row-unchanged" "$(grep -n -e '^| `.gitignore`' -e 'CI는 다시' "$_ss_up")"
