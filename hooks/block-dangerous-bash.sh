#!/usr/bin/env bash
# PreToolUse(Bash) — 같은 폴더 deny-patterns.yaml 의 사고 패턴 차단
# stdin: { tool_input: { command: "..." } }
# exit 2 = 차단 (Claude가 stderr 메시지를 deny 사유로 인식)
set -uo pipefail

# 이 훅만 harness.json 게이팅 없이 항상 켜진다. 그래서 꺼지는 조건은 소리 내서 꺼진다 —
# python3 가 없으면 cmd="" 로 조용히 exit 0 하던 것이 "차단이 켜져 있는 줄" 알게 만들었다 (2026-10-08).
if ! command -v python3 >/dev/null 2>&1; then
  printf '⚠️ block-dangerous-bash: python3 없음 — 위험 명령 차단이 꺼져 있습니다\n' >&2
  exit 0
fi

input=$(cat 2>/dev/null || true)
cmd=$(printf '%s' "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

[ -z "$cmd" ] && exit 0

# 플러그인 hooks/ 안에 정책 데이터가 같이 있다.
# ⚠️ 이 훅만 harness.json 게이팅 없이 항상 동작한다 (하네스 미설치 레포도 보호).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YAML="$SCRIPT_DIR/deny-patterns.yaml"
[ -f "$YAML" ] || exit 0

# python3 로 YAML 파싱 후, 명령에 매칭되는 첫 패턴을 stdout에 (id|title|reason) 한 줄로 출력.
# PyYAML 없이 표준 라이브러리만 사용: 단순 키-값 YAML이라 정규식으로 추출.
matched=$(CMD="$cmd" YAML_PATH="$YAML" python3 <<'PY'
import os, re, sys

cmd = os.environ["CMD"]
text = open(os.environ["YAML_PATH"], encoding="utf-8").read()

# 패턴 블록 분리: 각 entry는 "- id:" 로 시작
entries = re.split(r'(?m)^\s*-\s+id:\s*', text)[1:]

import subprocess

def grep_match(pattern: str, s: str) -> bool:
    # 시스템 grep -E 로 일관성 유지 (shell 스크립트와 동일 엔진)
    r = subprocess.run(
        ["grep", "-qE", pattern],
        input=s, text=True
    )
    return r.returncode == 0

for entry in entries:
    def field(name, default=""):
        m = re.search(rf'(?m)^\s*{name}:\s*(.+?)\s*$', entry)
        return m.group(1).strip().strip('"').strip("'") if m else default

    id_     = entry.splitlines()[0].strip().strip('"').strip("'")
    pattern = field("pattern")
    title   = field("title")
    reason  = field("reason")

    if not pattern:
        continue

    # ignore_quoted: 따옴표 안 문자열을 비우고 매칭 (커밋 메시지·printf 인자 속 "-n" 오탐 방지)
    target = cmd
    if field("ignore_quoted").lower() == "true":
        target = re.sub(r"'[^']*'|\"[^\"]*\"", "''", cmd)

    if not grep_match(pattern, target):
        continue

    # exclude: 매칭되면 이 항목은 차단하지 않는다 (.env.example 같은 템플릿 파일)
    excl = field("exclude")
    if excl and grep_match(excl, target):
        continue

    # match_all 처리 (yaml list)
    ma_block = re.search(r'(?ms)^\s*match_all:\s*\n((?:\s+-\s+.+\n?)+)', entry)
    if ma_block:
        extras = re.findall(r'^\s+-\s+(.+?)\s*$', ma_block.group(1), re.M)
        ok = all(grep_match(p.strip().strip('"').strip("'"), target) for p in extras)
        if not ok:
            continue

    print(f"{id_}|{title}|{reason}")
    sys.exit(0)

sys.exit(0)
PY
)

if [ -n "$matched" ]; then
  title=$(printf '%s' "$matched" | awk -F'|' '{print $2}')
  reason=$(printf '%s' "$matched" | awk -F'|' '{print $3}')
  printf '🚫 차단됨: %s\n   사유: %s\n' "$title" "$reason" >&2
  exit 2
fi

# GitHub 쓰기 계정 — ~/.claude/gh-accounts.txt 에 「owner 계정」 줄이 있으면, 그 owner 레포에 이슈·PR·릴리스를 쓰는 명령은
# 활성 gh 계정이 그 계정일 때만 통과(2026-10-15). 다른 계정이면 에러 없이 그 계정 이름으로 올라간다(jtwjs/claude-harness #1~3·#7 실측).
# 같은 명령 안에 gh auth switch -u <계정> 이 먼저 있으면 통과. 목록 파일이 없으면 아무것도 안 한다.
GH_ACCOUNTS="${CLAUDE_GH_ACCOUNTS:-$HOME/.claude/gh-accounts.txt}"
if [ -f "$GH_ACCOUNTS" ]; then
  unqg=$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
  if printf '%s' "$unqg" | grep -Eq 'gh[[:space:]]+(issue|pr|release)[[:space:]]+(create|comment|edit|close|reopen|review|delete|merge)\b'; then
    owner=$(printf '%s' "$unqg" | grep -Eo '(-R|--repo)[[:space:]=]+[^[:space:]/]+/' | head -1 | sed -E 's/^(-R|--repo)[[:space:]=]+//; s#/$##')
    [ -z "$owner" ] && owner=$(git remote get-url origin 2>/dev/null | sed -E 's#^(https://[^/]+/|git@[^:]+:)##; s#/.*##')
    need=$(awk -v o="$owner" '$1==o{print $2; exit}' "$GH_ACCOUNTS" 2>/dev/null)
    if [ -n "$owner" ] && [ -n "$need" ] && ! printf '%s' "$unqg" | grep -Eq "gh[[:space:]]+auth[[:space:]]+switch[[:space:]].*-u[[:space:]]+$need\b"; then
      active="${CLAUDE_GH_ACTIVE:-$(gh config get -h github.com user 2>/dev/null)}"
      if [ "$active" != "$need" ]; then
        printf '🚫 차단됨: %s 레포는 %s 계정으로 쓴다\n   사유: 지금 gh 활성 계정은 %s — 그대로 두면 그 이름으로 올라간다. gh auth switch -u %s 로 바꾸고(같은 명령 앞에 붙여도 된다) 끝나면 원래 계정으로 되돌린다 (%s)\n' "$owner" "$need" "${active:-알 수 없음}" "$need" "$GH_ACCOUNTS" >&2
        exit 2
      fi
    fi
  fi
fi

# PR 머지는 사람 확인으로 — pr-write 4.6 자동 머지 판정이 dry-run 인 동안(2026-10-13, PR 10건 오판 0 이면 따로 결정).
# 막지(exit 2) 않고 묻는다(ask): 사람이 "머지해"라고 한 머지는 그대로 승인하면 된다. 문장 하나로만 막던 것을 장치로(10-13 리뷰)
unq=$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")
if printf '%s' "$unq" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge\b'; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"PR 머지는 사람 확인 — 자동 머지 판정은 아직 dry-run(pr-write 4.6)"}}\n'
  exit 0
fi

# 운영 DB — 레포의 .claude/harness.json guard.prodDb 가 있을 때만 (2026-10-13). 판별은 lib/prod_db.py:
# harness.json 에 적힌 위치(spring:<프로필> · env:<파일>:<키>)에서 호스트를 디스크로 읽는다. 값은 어디에도 옮기지 않는다.
#   ① 운영 DB 를 가리키는 명령(호스트·그 값을 담은 변수 이름)에 쓰기 SQL·SQL 파일 실행 → 차단. 조회(SELECT)는 허용
#   ② 운영을 가리키는 Spring 프로필(같은 호스트면 자동) · switches(Node) 로 실행 → 차단
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0
prod=$(python3 "$SCRIPT_DIR/lib/prod_db.py" check "$REPO_ROOT" "$cmd" 2>/dev/null); prc=$?
# 판별이 죽으면 막는다(fail-closed). guard.prodDb 가 없는 레포는 설정을 읽자마자 끝나 여기 올 일이 없다 — 10-13 리뷰: 조용히 통과했다
if [ "$prc" -ne 0 ]; then
  printf '🚫 차단됨: 운영 DB 가드 오류\n   사유: lib/prod_db.py 가 종료 코드 %s 로 죽었다 — 판별 못 한 명령은 통과시키지 않는다. harness.json guard.prodDb 와 설정 파일을 확인한다\n' "$prc" >&2
  exit 2
fi
if [ -n "$prod" ]; then
  printf '🚫 차단됨: %s\n   사유: %s\n' "${prod%%|*}" "${prod#*|}" >&2
  exit 2
fi

exit 0
