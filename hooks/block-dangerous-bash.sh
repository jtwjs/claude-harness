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

# 운영 DB — 레포의 .claude/harness.json guard.prodDb 가 있을 때만 (2026-10-13).
# 이름(PROD)으로는 못 가른다: stage 프로필이 운영 DB 를 가리킨 레포가 있었다. 그래서 레포가 적은 호스트·프로필로 가른다.
#   ① 명령에 운영 호스트가 있고 쓰기 SQL 이 있거나, SQL 을 파일로 넘긴다(내용을 볼 수 없다) → 차단. 조회(SELECT)는 허용
#   ② 운영을 가리키는 프로필로 앱·마이그레이션·테스트를 띄운다 → 차단. 연결만 되면 SQL 없이도 운영 데이터가 바뀐다
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
CFG="$REPO_ROOT/.claude/harness.json"
[ -f "$CFG" ] || exit 0
prod=$(CMD="$cmd" python3 - "$CFG" <<'PY'
import json, os, re, sys
cmd = os.environ["CMD"]
try:
    g = (json.load(open(sys.argv[1], encoding="utf-8")).get("guard") or {}).get("prodDb") or {}
except Exception:
    sys.exit(0)
hosts = [h for h in g.get("hosts", []) if isinstance(h, str) and h]
profiles = {p for p in g.get("profiles", []) if isinstance(p, str) and p}
if any(h in cmd for h in hosts):
    if re.search(r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE)\b", cmd, re.I):
        print("운영 DB 쓰기|운영 호스트에 쓰기 SQL 이 있다. 조회(SELECT)만 허용한다. 고쳐야 하면 사람이 직접 실행한다"); sys.exit(0)
    bare = re.sub(r"'[^']*'|\"[^\"]*\"", "''", cmd)   # 따옴표 안의 < 는 SQL 비교 연산자다
    if re.search(r"(^|[^<])<[^<(]|\bsource\b|\\\.", bare):
        print("운영 DB 에 SQL 파일 실행|파일 내용을 볼 수 없어 쓰기인지 가를 수 없다. 조회면 -e/-c 로 SELECT 를 직접 쓴다"); sys.exit(0)
if profiles:
    for m in re.finditer(r"(?:spring[._]profiles[._]active|SPRING_PROFILES_ACTIVE)\s*[=\s]\s*['\"]?([\w,-]+)", cmd):
        hit = profiles & {p.strip() for p in m.group(1).split(",")}
        if hit:
            print(f"운영 프로필로 실행 ({', '.join(sorted(hit))})|이 레포의 harness.json 이 운영 DB 를 가리킨다고 적은 프로필이다. 앱이 뜨면 SQL 없이도 운영 데이터가 바뀐다. 필요하면 사람이 터미널에서 직접 실행한다"); sys.exit(0)
PY
)
if [ -n "$prod" ]; then
  printf '🚫 차단됨: %s\n   사유: %s\n' "${prod%%|*}" "${prod#*|}" >&2
  exit 2
fi

exit 0
