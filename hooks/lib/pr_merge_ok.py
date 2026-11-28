#!/usr/bin/env python3
"""gh pr merge 를 확인 없이 통과시켜도 되는지 본다(ADR-026 D5).

세 조건을 모두 채우면 exit 0, 아니면 exit 1 + 이유 한 줄(stdout).
  1. 규칙 파일(CLAUDE.md · .claude/rules/**) 변경 0
  2. PR 본문 Risk Score 30 이하
  3. CI 체크 전부 통과
PR 을 못 읽음 · Risk 값을 못 찾음 · 시간 초과 · 머지 명령이 하나가 아님도 exit 1 이다(모르면 묻는 쪽).
조건은 사용자가 고른 이 셋뿐이다. 넓히거나 줄이지 않는다.

쓰는 법: pr_merge_ok.py <명령 원문>   (시간 상한: CLAUDE_PR_MERGE_TIMEOUT 초, 기본 10)
"""
import json
import os
import re
import shlex
import subprocess
import sys

RISK_MAX = 30
RULE_FILE = re.compile(r"(^|/)CLAUDE\.md$|(^|/)\.claude/rules/")
RISK = re.compile(r"Risk Score:\s*(\d+)\s*/\s*100")
VALUE_OPTS = {"-R", "--repo", "-t", "--subject", "-b", "--body", "-F", "--body-file", "--match-head-commit", "-A", "--author-email"}


def no(reason):
    print(reason)
    sys.exit(1)


def target(cmd):
    """머지 명령 하나에서 (PR 지정, 레포). 명령이 하나가 아니거나 못 읽으면 None."""
    try:
        toks = shlex.split(cmd)
    except ValueError:
        return None
    starts = [i for i in range(len(toks) - 2) if toks[i:i + 3] == ["gh", "pr", "merge"]]
    if len(starts) != 1:
        return None
    sel, repo, i = None, None, starts[0] + 3
    while i < len(toks) and toks[i] not in ("&&", "||", ";", "|"):
        t = toks[i]
        if t in VALUE_OPTS:
            if t in ("-R", "--repo") and i + 1 < len(toks):
                repo = toks[i + 1]
            i += 2
            continue
        if t.startswith("--repo="):
            repo = t.split("=", 1)[1]
        elif not t.startswith("-") and sel is None:
            sel = t
        i += 1
    return sel, repo


def main():
    if len(sys.argv) != 2:
        no("쓰는 법: pr_merge_ok.py <명령>")
    got = target(sys.argv[1])
    if got is None:
        no("머지 명령이 하나가 아니거나 읽을 수 없다")
    sel, repo = got
    args = ["gh", "pr", "view"] + ([sel] if sel else []) + (["-R", repo] if repo else [])
    args += ["--json", "body,files,changedFiles,statusCheckRollup"]
    try:
        timeout = float(os.environ.get("CLAUDE_PR_MERGE_TIMEOUT", "10"))
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except (subprocess.TimeoutExpired, ValueError, OSError):
        no("PR 을 읽다 시간이 넘었거나 gh 를 부르지 못했다")
    if r.returncode != 0:
        no("PR 을 읽지 못했다")
    try:
        pr = json.loads(r.stdout)
    except ValueError:
        no("PR 응답을 읽지 못했다")
    files = [f.get("path", "") for f in pr.get("files") or []]
    if len(files) != pr.get("changedFiles"):
        no("바뀐 파일 목록을 다 받지 못했다")
    rules = [f for f in files if RULE_FILE.search(f)]
    if rules:
        no(f"규칙 파일이 바뀌었다: {', '.join(rules[:3])}")
    m = RISK.search(pr.get("body") or "")
    if not m:
        no("PR 본문에서 Risk Score 를 찾지 못했다")
    if int(m.group(1)) > RISK_MAX:
        no(f"Risk Score {m.group(1)} > {RISK_MAX}")
    checks = pr.get("statusCheckRollup") or []
    if not checks:
        no("CI 체크가 없다")
    for c in checks:
        result = c.get("conclusion") if c.get("__typename") == "CheckRun" else c.get("state")
        if result != "SUCCESS":
            no(f"CI 체크가 다 통과하지 않았다: {c.get('name') or c.get('context') or '?'} {result or c.get('status') or '?'}")
    sys.exit(0)


if __name__ == "__main__":
    main()
