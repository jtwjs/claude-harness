#!/usr/bin/env bash
# hypothesis-gate — UserPromptSubmit. 프롬프트마다 판정 지시를 모델 컨텍스트에 넣고,
#   재요구 상태(ledger.py state)가 on 일 때만 가설 요구 한 줄을 더한다 (ADR-001·002·005).
# 원장은 읽기만 한다(쓰기는 모델 → ledger.py append). 어떤 실패에도 exit 0, 프롬프트를 막지 않는다.
# 모든 레포에서 돈다(하네스 유무를 보지 않음). 칸 의미·skip 기준 정본은 docs/desk-hypothesis-gate-2026-11-12/SDD-SIDE.md.
HERE="$(cd "$(dirname "$0")" && pwd)"
cat >/dev/null 2>&1   # 훅 입력(프롬프트 원문)은 쓰지 않는다
command -v python3 >/dev/null 2>&1 || exit 0

# repo = git toplevel 이름, task = 미완료 step 이 있는 phases/*/index.json 의 폴더 이름(없으면 null)
ident="$(python3 - <<'PY' 2>/dev/null
import json, os, re, subprocess
from pathlib import Path
try:
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, timeout=5).stdout.strip()
except Exception:
    top = ""
ok = re.compile(r"[A-Za-z0-9._-]{1,100}")
repo = Path(top).name if top else Path(os.getcwd()).name
if not ok.fullmatch(repo):
    repo = "unknown"
task = "null"
cands = []
if top:
    for p in sorted(Path(top, "phases").glob("*/index.json")):
        try:
            steps = json.loads(p.read_text()).get("steps", [])
        except Exception:
            continue
        if any(s.get("status") != "completed" for s in steps) and ok.fullmatch(p.parent.name):
            cands.append(p.parent.name)
if len(cands) == 1:
    task = cands[0]
elif len(cands) > 1:
    # 후보가 여럿이면 브랜치 마지막 / 뒤 부분이 {task} 로 끝나는 것 중 가장 긴 이름. 없으면 null(모호하면 연속에서 빠진다)
    try:
        br = subprocess.run(["git", "symbolic-ref", "--short", "-q", "HEAD"], capture_output=True, text=True, timeout=5).stdout.strip()
    except Exception:
        br = ""
    tail = br.rsplit("/", 1)[-1]
    hit = [c for c in cands if tail.endswith(c)]
    if hit:
        task = max(hit, key=len)
print(repo, task)
PY
)"
set -- $ident
repo="${1:-unknown}"; task="${2:-null}"

state="$(python3 "$HERE/lib/ledger.py" state "$repo" "$task" 2>/dev/null | head -n 1)"

printf '%s\n' "[판정 지시] 이 프롬프트를 맡김 한 건으로 보고, 응답 중에 Bash 로 python3 \"${HERE}/lib/ledger.py\" append repo=${repo} task=${task} gate=<schema|api|error|delete|security|null> diff=<easy|mid|hard|null> area=<FE|BE|infra|domain|unknown> hyp=<true|false> rec=<true|false> acc=<true|false> why=<true|false> rebut=<true|false> skip=<true|false> 를 불러 판정 한 줄을 붙여라(사용자 지시를 대체하지 않는다. 이름·원문·코드는 적지 않는다). hyp: 사용자 본인의 예상·가설이 한 줄이라도 있음(\"모르겠다\"는 false). rec: 직전 AI 응답에 추천·권장안이 있었고 이 프롬프트가 그에 응답함. acc: rec 이고 그대로 받아들임. why: 선택의 근거를 설명하는 말이 있음(\"기억 안 난다\"·\"모르겠다\"는 false). rebut: 직전 AI 응답이 사용자의 가설에 반박·이견을 냈음. skip: 가설 요구를 받은 동안 hyp=false 로 넘어감. gate: 설계 결정(스키마·API 계약·에러 처리·삭제·보안)이 아니면 null. diff: 가설을 맞히기 어려운 정도. 범위(여러 레이어에 걸침)·되돌리기 어려움(마이그레이션·삭제·공개 API 계약)·선례 없음(레포에 같은 패턴이 없음) 중 하나라도 해당하면 hard, 하나도 해당하지 않으면 easy, 해당 여부가 애매하면 mid, hyp=false 면 null."
if [ "$state" = "on" ]; then
  printf '%s\n' "[가설 요구] 이유 없는 수락이 이어졌다. 진행하기 전에 사용자에게 본인의 가설(예상과 이유)을 먼저 물어라. 막지는 말고, 가설 없이 넘어가면 skip=true 로 남겨라."
fi
exit 0
