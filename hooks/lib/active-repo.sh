#!/usr/bin/env bash
# 활발한 레포 판정 — readiness 채점과 brain-sync 자동 이관이 같이 쓴다 (2026-10-12).
#
# 기준: 최근 ACTIVE_DAYS(14)일 HEAD 의 머지 제외 커밋이 ACTIVE_MIN_COMMITS(20)건 이상이고,
#       커밋이 있었던 날이 ACTIVE_MIN_DAYS(3)일 이상.
# 왜 날짜 수도 보나: 하루에 몰아친 일괄 리팩터·봇 커밋은 "계속 일하는 레포"가 아니다.
#
# 사용: source "$SCRIPT_DIR/lib/active-repo.sh"; active_repo [dir] && …   (0 = 활발)

active_repo() {
  local dir="${1:-.}" since="${ACTIVE_DAYS:-14} days ago" n d
  n=$(git -C "$dir" rev-list --count --no-merges --since="$since" HEAD 2>/dev/null || echo 0)
  d=$(git -C "$dir" log --no-merges --since="$since" --format=%cd --date=short HEAD 2>/dev/null | sort -u | wc -l | tr -d ' ')
  [ "${n:-0}" -ge "${ACTIVE_MIN_COMMITS:-20}" ] && [ "${d:-0}" -ge "${ACTIVE_MIN_DAYS:-3}" ]
}
