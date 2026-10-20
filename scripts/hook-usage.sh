#!/usr/bin/env bash
# 훅 발화 집계 — hooks/lib/hook-log.sh 가 쌓은 기록을 훅·결과별로 센다(0.27.0).
# 덜어낼지 판단할 근거: loop-lock 이 실제로 막았나 · todo-warn 이 경고를 냈나 · validate-session-end 가
# 실패를 잡았나와 그 대기 시간 합. 판단은 사람이 한다 — 이 스크립트는 숫자만 낸다.
# 사용: bash scripts/hook-usage.sh [일수=14]
set -uo pipefail
DAYS="${1:-14}"
LOG="${CLAUDE_HARNESS_HOOK_LOG:-$HOME/.claude/harness-hook-log.tsv}"
[ -f "$LOG" ] || { echo "기록 없음: $LOG (0.27.0 이후 하네스 레포 세션에서 쌓인다)"; exit 0; }
python3 - "$LOG" "$DAYS" <<'PY'
import sys, datetime, collections
log, days = sys.argv[1], int(sys.argv[2])
cut = (datetime.datetime.now() - datetime.timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%S")
n = collections.Counter(); ms = collections.Counter(); repos = collections.defaultdict(set); first = None
for line in open(log, encoding="utf-8", errors="replace"):
    f = line.rstrip("\n").split("\t")
    if len(f) < 4 or f[0] < cut:
        continue
    first = first or f[0]
    n[(f[2], f[3])] += 1; repos[f[2]].add(f[1])
    if len(f) > 4 and f[4].isdigit():
        ms[(f[2], f[3])] += int(f[4])
print(f"최근 {days}일 (첫 기록 {first or '없음'})")
print(f"{'훅':<22}{'결과':<9}{'건수':>6}{'합계 초':>9}{'평균 초':>8}  레포")
for (h, o), c in sorted(n.items()):
    t = ms[(h, o)] / 1000
    print(f"{h:<22}{o:<9}{c:>6}{t:>9.0f}{t / c:>8.1f}  {len(repos[h])}")
PY
