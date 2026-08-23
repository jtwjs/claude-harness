#!/usr/bin/env bash
# Stop — 세션 종료 시 harness.json 의 verify 를 순서대로 실행해 상태만 보고한다.
#
# 🔴 전부 읽기 전용이다. 세션 끝에 파일을 조용히 다시 쓰지 않는다.
#    (포맷 '적용'은 auto-format.sh 가 편집 직후에 한다. 여기서는 검사만.)
#    → verify.format 에는 --check 계열(읽기)만 들어간다. harness-init 이 그렇게 기록한다.
#
# non-blocking: 실패해도 exit 0. 진짜 게이트는 CI 와 feature-builder 자체 점검이다.
# 루프 가드: 같은 변경 상태면 재실행하지 않는다.
set -uo pipefail
cat >/dev/null 2>&1 || true

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0
CFG="$REPO_ROOT/.claude/harness.json"
[ -f "$CFG" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
cd "$REPO_ROOT" 2>/dev/null || exit 0

# ── 루프 가드 ────────────────────────────────────────────────────────────────
stamp="$REPO_ROOT/.claude/.last-session-validate"
cur_hash=$(git status --porcelain 2>/dev/null | git hash-object --stdin 2>/dev/null || echo "")
if [ -n "$cur_hash" ] && [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$cur_hash" ]; then
  exit 0
fi

# ── verify 추출 (없는 키는 skip — 거짓말하지 않는다) ─────────────────────────
steps=$(python3 - "$CFG" <<'PY'
import json, sys
try:
    cfg = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(0)
v = cfg.get("verify") or {}
for k in ("format", "lint", "typecheck", "test"):
    c = (v.get(k) or "").strip()
    if c:
        print(f"{k}\t{c}")
PY
)

if [ -z "$steps" ]; then
  printf 'ℹ️  harness.json 에 verify 명령이 없습니다 — skip\n' >&2
  exit 0
fi

failed=""
while IFS=$'\t' read -r name cmd; do
  [ -z "$name" ] && continue
  out=$(eval "$cmd" 2>&1); code=$?
  if [ "$code" -ne 0 ]; then
    failed="$failed $name"
    printf '\n🔴 %s 실패\n' "$name" >&2
    printf '%s\n' "$out" | tail -n 25 >&2
  else
    printf '🟢 %s\n' "$name" >&2
  fi
done <<EOF
$steps
EOF

[ -n "$cur_hash" ] && printf '%s' "$cur_hash" >"$stamp" 2>/dev/null || true

# verify.test 가 비어 있으면 그 사실을 말한다 (조용히 죽지 않게)
python3 - "$CFG" <<'PY' >&2
import json, sys
try:
    cfg = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(0)
if not ((cfg.get("verify") or {}).get("test") or "").strip():
    print("⚠️  verify.test 가 비어 있습니다 — 이 레포에는 테스트 실행 경로가 없습니다.")
PY

[ -n "$failed" ] && printf '\n⚠️  실패:%s (차단 아님 — CI 가 최종 게이트)\n' "$failed" >&2
exit 0
