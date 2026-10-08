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

exit 0
