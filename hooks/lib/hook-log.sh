# 훅 발화 기록 — 지금 모델에서 그 훅이 아직 일을 하는지 근거를 쌓는다(0.27.0).
# 한 줄 = 시각 \t 레포 \t 훅 \t 결과 \t ms \t 상세. 레포 밖 한 파일에 쌓고(머신 전체) 레포에는 쓰지 않는다.
# 집계는 scripts/hook-usage.sh. 기록 실패는 훅 동작에 영향을 주지 않는다.
HOOK_LOG_FILE="${CLAUDE_HARNESS_HOOK_LOG:-$HOME/.claude/harness-hook-log.tsv}"
hook_now_ms() { python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo 0; }
hook_log() { # $1 훅 · $2 결과 · $3 ms(선택) · $4 상세(선택, 탭·줄바꿈은 공백으로)
  local detail="${4:-}" repo="${REPO_ROOT:-?}"; detail="${detail//$'\t'/ }"; detail="${detail//$'\n'/ }"
  # 레포 이름은 basename 대신 치환으로 — 이제 모든 Bash 호출마다 기록해서 프로세스 하나(약 3ms)도 아낀다
  # 리다이렉트 실패(기록 폴더 없음)도 숨기려고 묶음 밖에서 stderr 를 버린다 — `>>f 2>/dev/null` 은 >> 가 먼저라 못 숨긴다
  { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "${repo##*/}" "$1" "$2" "${3:-}" "${detail:0:200}" \
    >>"$HOOK_LOG_FILE"; } 2>/dev/null || true
}
# 끝나는 모든 경로에서 정확히 한 줄(ADR-016 D11). 훅 맨 위에서 부르고, 경로마다 HOOK_RESULT(필요하면 HOOK_MS · HOOK_DETAIL)를
# 정한 뒤 exit 한다. 쓰는 곳이 EXIT trap 하나뿐이라 두 줄이 될 수 없고, 결과를 못 정한 채 끝나도 unknown 으로 남는다.
hook_log_on_exit() { # $1 훅
  HOOK_NAME="$1"; HOOK_RESULT=""; HOOK_MS=""; HOOK_DETAIL=""
  trap 'hook_log "$HOOK_NAME" "${HOOK_RESULT:-unknown}" "$HOOK_MS" "$HOOK_DETAIL"' EXIT
}
