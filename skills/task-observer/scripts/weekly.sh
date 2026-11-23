#!/usr/bin/env bash
# task-observer 주 1회 헤드리스 — gather → claude -p(4종 판정 · 2곳 이상 묶기) → append.
# 정본: docs/observer-global-ledger-2026-11-23/ARCHITECTURE.md 「weekly.sh」
# 사용: weekly.sh [--dry-run] [--days N]
# 종료: 0 성공(후보 없음 · 설정 없음 포함) · 1 claude 실패 · 결과 파싱 실패 · 쓰기 실패 · 2 인자
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS="$DIR/observer.py"
PROMPT="$DIR/../references/weekly-prompt.md"
CLAUDE="${TASK_OBSERVER_CLAUDE:-claude}"

DRY=0; DAYS=7
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --days) shift; DAYS="${1:-}" ;;
    *) echo "사용: weekly.sh [--dry-run] [--days N]" >&2; exit 2 ;;
  esac
  shift
done
case "$DAYS" in ''|*[!0-9]*) echo "task-observer: --days 는 양의 정수" >&2; exit 2 ;; esac

START=$(date +%s)
summary() { # $1=후보 수  $2=쓴 행 수
  echo "task-observer weekly: 후보 ${1} · 쓴 행 ${2} · 소요 $(( $(date +%s) - START ))s"
}

# AC1 설정 없으면 claude 를 부르지 않는다(구독 사용량을 쓰지 않음). dry-run 은 계속
LEDGER=$(python3 "$OBS" config)
if [ -z "$LEDGER" ] && [ "$DRY" = "0" ]; then
  echo "원장 설정 없음"
  exit 0
fi

if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "⚠️ ANTHROPIC_API_KEY 가 설정돼 있다 — claude -p 가 구독이 아니라 API 과금으로 돈다" >&2
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/task-observer.XXXXXX") || { echo "task-observer: 임시 폴더를 못 만듦" >&2; exit 1; }
trap 'rm -rf "$WORK"' EXIT

python3 "$OBS" gather --days "$DAYS" > "$WORK/material.json" || { echo "task-observer: gather 실패" >&2; exit 1; }
NREPO=$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1])).get("repos") or []))' "$WORK/material.json" 2>/dev/null || echo 0)
if [ "$NREPO" -lt 2 ]; then
  echo "후보 없음"   # 레포 2곳 미만이면 묶을 수 없다
  summary 0 0
  exit 0
fi

{ cat "$PROMPT"; echo; cat "$WORK/material.json"; } > "$WORK/input.md"
"$CLAUDE" -p --tools "" --no-session-persistence --output-format json < "$WORK/input.md" > "$WORK/out.json" 2>"$WORK/err"
RC=$?

# .result 에서 후보 배열 추출(코드 펜스 벗김). 실패면 사유 한 줄을 stderr 에 내고 exit 1
python3 - "$WORK/out.json" "$RC" "$WORK/err" > "$WORK/cand.json" <<'PY'
import json, re, sys
out, rc, err = sys.argv[1], int(sys.argv[2]), sys.argv[3]
def fail(why):
    print("task-observer: claude 실패 — %s" % why, file=sys.stderr)
    sys.exit(1)
text = open(out, encoding="utf-8", errors="replace").read().strip()
try:
    res = json.loads(text.splitlines()[-1]) if text else {}
except ValueError:
    res = {}
res = res if isinstance(res, dict) else {}
if rc != 0:
    detail = res.get("result") or open(err, encoding="utf-8", errors="replace").read()
    fail("종료 코드 %d — %s" % (rc, " ".join(str(detail).split())[:200]))
if not res:
    fail("결과 JSON 없음")
if res.get("is_error"):
    fail("is_error — %s" % " ".join(str(res.get("result", "")).split())[:200])
body = res.get("result")
if not isinstance(body, str):
    fail("result 칸 없음")
m = re.search(r"```(?:json)?\s*(.*?)```", body, re.S)
cand_text = m.group(1).strip() if m else body.strip()
try:
    cands = json.loads(cand_text)
except ValueError:
    i, j = cand_text.find("["), cand_text.rfind("]")
    try:
        cands = json.loads(cand_text[i:j + 1]) if i != -1 and j > i else None
    except ValueError:
        cands = None
if cands is None:
    fail("결과에서 JSON 을 찾지 못함")
if not isinstance(cands, list):
    fail("결과가 배열이 아님")
print(json.dumps(cands, ensure_ascii=False))
PY
[ $? -eq 0 ] || exit 1

NCAND=$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$WORK/cand.json")
if [ "$NCAND" = "0" ]; then
  echo "후보 없음"
  summary 0 0
  exit 0
fi

# 재료에 있던 레포 이름만 받는다 — 모델이 지어낸 이름으로 「2곳 이상」이 가짜로 차지 않게
KNOWN=$(python3 -c 'import json,sys; print(",".join(r.get("name","") for r in json.load(open(sys.argv[1])).get("repos") or []))' "$WORK/material.json")
if [ "$DRY" = "1" ]; then
  python3 "$OBS" append --dry-run --known "$KNOWN" "$WORK/cand.json"; ARC=$?
  WROTE=0
else
  python3 "$OBS" append --known "$KNOWN" "$WORK/cand.json" > "$WORK/append.out"; ARC=$?
  cat "$WORK/append.out"
  WROTE=$(grep -c '^| F-' "$WORK/append.out" | tr -d ' ')
fi
[ "$ARC" -eq 0 ] || { echo "task-observer: append 실패(exit ${ARC})" >&2; exit 1; }
summary "$NCAND" "$WROTE"
