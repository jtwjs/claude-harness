#!/usr/bin/env bash
# Stop — 세션 종료 시 harness.json 의 verify 를 순서대로 실행해 상태만 보고한다.
#
# 🔴 전부 읽기 전용이다. 세션 끝에 파일을 조용히 다시 쓰지 않는다.
#    (포맷 '적용'은 auto-format.sh 가 편집 직후에 한다. 여기서는 검사만.)
#    → verify.format 에는 --check 계열(읽기)만 들어간다. harness-init 이 그렇게 기록한다.
#
# non-blocking: 실패해도 exit 0. 진짜 게이트는 CI 와 feature-builder 자체 점검이다.
# 루프 가드: 같은 변경 상태면 재실행하지 않는다.
# 출력: stdout JSON 의 systemMessage. exit 0 의 stderr 는 디버그 로그에만 남아 아무도 못 본다
#   (2026-10-08 공식 문서 확인 — 그 전까지 이 훅의 🟢/🔴 결과는 한 번도 전달된 적이 없다).
set -uo pipefail
cat >/dev/null 2>&1 || true

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0
CFG="$REPO_ROOT/.claude/harness.json"
[ -f "$CFG" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
cd "$REPO_ROOT" 2>/dev/null || exit 0

# ── 루프 가드 ────────────────────────────────────────────────────────────────
# 해시는 "변경 내용" 기준이다. `git status --porcelain` 을 해시하면 이미 ` M` 인 파일을 더 고쳐도
# 출력이 같아서 첫 Stop 이후 verify 가 전부 건너뛰어진다 (2026-10-08 리뷰).
stamp="$REPO_ROOT/.claude/.last-session-validate"
# untracked 에서 훅 자신의 stamp·리포트는 뺀다 — 넣으면 해시가 자기 자신을 참조해 매번 달라진다.
cur_hash=$({ git diff HEAD 2>/dev/null;
             git ls-files -o --exclude-standard -z -- . ':(exclude).claude/.last-*' ':(exclude).claude/reports' 2>/dev/null \
               | xargs -0 cat 2>/dev/null; } \
           | git hash-object --stdin 2>/dev/null || echo "")
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

emit() { # $1 = 메시지 — stdout JSON systemMessage 로 낸다
  MSG="$1" python3 -c 'import json,os; print(json.dumps({"systemMessage": os.environ["MSG"]}, ensure_ascii=False))'
}

if [ -z "$steps" ]; then
  emit 'ℹ️ harness.json 에 verify 명령이 없습니다 — Stop 검증 skip'
  exit 0
fi

failed=""; report=""
while IFS=$'\t' read -r name cmd; do
  [ -z "$name" ] && continue
  out=$(eval "$cmd" 2>&1 </dev/null); code=$?   # stdin 을 끊는다 — 아래 heredoc 을 verify 명령이 삼키지 않게
  if [ "$code" -ne 0 ]; then
    failed="$failed $name"
    report="${report}🔴 ${name} 실패
$(printf '%s\n' "$out" | tail -n 12)
"
  else
    report="${report}🟢 ${name}
"
  fi
done <<EOF
$steps
EOF

[ -n "$cur_hash" ] && printf '%s' "$cur_hash" >"$stamp" 2>/dev/null || true

# verify.test 가 비어 있으면 그 사실을 말한다 (조용히 죽지 않게)
if ! python3 -c 'import json,sys; cfg=json.load(open(sys.argv[1],encoding="utf-8")); sys.exit(0 if ((cfg.get("verify") or {}).get("test") or "").strip() else 1)' "$CFG" 2>/dev/null; then
  report="${report}⚠️ verify.test 가 비어 있습니다 — 이 레포에는 테스트 실행 경로가 없습니다.
"
fi
[ -n "$failed" ] && report="${report}⚠️ 실패:${failed} (차단 아님 — CI 가 최종 게이트)"

emit "Stop 검증(읽기 전용)
${report}"
exit 0
