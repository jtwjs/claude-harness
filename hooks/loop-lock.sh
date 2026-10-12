#!/usr/bin/env bash
# Loop Lock — PostToolUse[Bash]
# 코드가 그대로인 채 같은 검증성 명령(test/typecheck/build/lint)이 N회 연속 반복되면 의미 없는 반복으로 보고
# 모델에 stop 신호(exit 2 = stderr 를 차단 피드백으로 전달). 무한 루프·토큰 낭비 방지.
# 다른 명령이 끼면 카운터 리셋. 검증성 명령이 아니면 무시.
#
# 2026-10-08:
#   - stamp 에 session_id 를 같이 적는다. 이전 세션 끝에 2회 돌린 명령이 다음 세션 첫 호출에서
#     바로 차단되던 stale 문제. 세션이 다르면 count 는 1 부터.
#   - "검증성 명령" 판정을 harness.json 의 verify.* 값과의 일치를 1순위로 바꿨다. 옛 정규식
#     `\b(build|lint)\b` 는 `ls build/`·`cat build.gradle` 까지 추적했다.
set -uo pipefail

THRESHOLD=3

input=$(cat 2>/dev/null || true)
read -r cmd session < <(printf '%s' "$input" | python3 -c '
import json, sys
d = json.load(sys.stdin)
cmd = d.get("tool_input", {}).get("command", "").replace("\n", " ")
print(cmd.replace(" ", "\x1f") or "-", d.get("session_id", "") or "-")
' 2>/dev/null || echo "- -")
cmd=${cmd//$'\x1f'/ }
[ "$cmd" = "-" ] && exit 0

# 🔴 stamp 는 반드시 프로젝트 루트에 둔다.
# 플러그인 디렉토리에 두면 모든 프로젝트가 카운터를 공유해 다른 레포에서 오탐한다.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0
CFG="$REPO_ROOT/.claude/harness.json"
[ -f "$CFG" ] || exit 0
stamp="$REPO_ROOT/.claude/.last-loop-lock"  # .claude/.last-* 는 .gitignore 처리

# 검증성(루프 위험) 명령만 추적.
#   1순위: harness.json verify.* 에 적힌 명령 문자열이 들어 있다.
#          앱별 verify({"apps/api": {"test": …}})는 한 겹 평탄화해서 본다 (0.10.0 — 평탄화 전에는
#          중첩 dict 에서 .strip() 이 터져 앱별 레포의 verify 명령을 하나도 추적하지 못했다).
#   2순위: 러너 이름으로 시작하고 test/lint/typecheck/build/check 를 품는다 (verify 가 비어 있는 레포).
is_verify=$(CMD="$cmd" python3 - "$CFG" <<'PY'
import json, os, re, sys
cmd = os.environ["CMD"]
try:
    v = (json.load(open(sys.argv[1], encoding="utf-8")).get("verify") or {})
except Exception:
    v = {}
flat = []
for k, c in v.items():
    if k.startswith("$"):
        continue
    if isinstance(c, dict):
        flat += [x for kk, x in c.items() if not kk.startswith("$")]
    else:
        flat.append(c)
for c in flat:
    c = c.strip() if isinstance(c, str) else ""
    if c and c in cmd:
        print("1"); sys.exit(0)
if re.search(r"^\s*(pnpm|npm|yarn|npx|bun|turbo|vitest|jest|tsc|eslint|gradle|\./gradlew|mvn|\./mvnw)\b[^|;&]*\b(test|lint|typecheck|build|check)\b", cmd):
    print("1"); sys.exit(0)
print("0")
PY
)
if [ "$is_verify" != "1" ]; then
  rm -f "$stamp" 2>/dev/null || true
  exit 0
fi

# 판단 단위 = 명령 + 그 시점 코드 상태 (2026-10-13). 코드가 그대로인데 같은 검증을 다시 돌리는 것만 의미 없는 반복이다.
# 코드를 고치고 다시 돌리는 건 정상 수정 루프라 리셋한다(그 루프의 상한은 harness-run 의 retries 3).
# 성공·실패는 가르지 않는다 — PostToolUse 는 성공한 도구 호출에만 도는 것으로 보여(문서 예시: 실패한 npm test 는
# PostToolUseFailure) 실패만 세는 방식은 이 이벤트로 만들 수 없다.
# 상태 = tracked 변경(git diff HEAD) + untracked 파일 내용. .claude/.last-* 같은 훅 흔적은 뺀다.
state=$(cd "$REPO_ROOT" && python3 - <<'PY' 2>/dev/null
import hashlib, subprocess
h = hashlib.sha1()
h.update(subprocess.run(["git", "diff", "HEAD", "--", ".", ":(exclude).claude/.last-*", ":(exclude).claude/reports"],
                        capture_output=True).stdout)
files = subprocess.run(["git", "ls-files", "-o", "--exclude-standard", "-z"], capture_output=True).stdout.split(b"\0")
for f in sorted(x for x in files if x and not x.startswith(b".claude/.last-") and not x.startswith(b".claude/reports")):
    h.update(f)
    try:
        h.update(open(f.decode(), "rb").read())
    except OSError:
        pass
print(h.hexdigest())
PY
)
hash=$(printf '%s\n%s' "$cmd" "$state" | git hash-object --stdin 2>/dev/null || printf '%s\n%s' "$cmd" "$state" | cksum | awk '{print $1}')

prev_hash=""; prev_count=0; prev_session=""
if [ -f "$stamp" ]; then
  prev_hash=$(sed -n '1p' "$stamp" 2>/dev/null || echo "")
  prev_count=$(sed -n '2p' "$stamp" 2>/dev/null || echo "0")
  prev_session=$(sed -n '3p' "$stamp" 2>/dev/null || echo "")
fi

if [ "$hash" = "$prev_hash" ] && [ "$session" = "$prev_session" ]; then
  count=$((prev_count + 1))
else
  count=1
fi
printf '%s\n%s\n%s\n' "$hash" "$count" "$session" >"$stamp" 2>/dev/null || true

if [ "$count" -ge "$THRESHOLD" ]; then
  printf '🔁 LOOP LOCK: 코드가 그대로인 채 같은 검증 명령을 %s회 연속 실행했습니다. 다시 돌려도 결과가 같습니다.\n   접근을 바꾸거나(가설 재검토·다른 파일 확인) 사람에게 상황을 보고하세요. 같은 명령 반복 금지.\n' "$count" >&2
  exit 2
fi
exit 0
