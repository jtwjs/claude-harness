# 훅 발화 기록 — 지금 모델에서 그 훅이 아직 일을 하는지 근거를 쌓는다(0.27.0).
# 한 줄 = 시각 \t 레포 \t 훅 \t 결과 \t ms \t 상세. 레포 밖 한 파일에 쌓고(머신 전체) 레포에는 쓰지 않는다.
# 집계는 scripts/hook-usage.sh. 기록 실패는 훅 동작에 영향을 주지 않는다.
HOOK_LOG_FILE="${CLAUDE_HARNESS_HOOK_LOG:-$HOME/.claude/harness-hook-log.tsv}"
hook_now_ms() { python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo 0; }
hook_log() { # $1 훅 · $2 결과 · $3 ms(선택) · $4 상세(선택, 탭·줄바꿈은 공백으로)
  local detail="${4:-}"; detail="${detail//$'\t'/ }"; detail="${detail//$'\n'/ }"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$(basename "${REPO_ROOT:-?}")" "$1" "$2" "${3:-}" "${detail:0:200}" \
    >>"$HOOK_LOG_FILE" 2>/dev/null || true
}
