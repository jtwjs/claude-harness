#!/usr/bin/env python3
"""gh pr merge 를 확인 없이 통과시켜도 되는지 본다(ADR-026 D5).

세 조건을 모두 채우면 exit 0, 아니면 exit 1 + 이유 한 줄(stdout).
  1. 규칙 파일(CLAUDE.md · .claude/rules/**) 변경 0 — 이름 바꾸기의 옛 경로도 본다
  2. PR 본문 Risk Score 30 이하 — 템플릿 머리 줄(`## ⚠️ Risk Score: N/100`)이 코드 블록 밖에 정확히 하나
  3. CI 체크 전부 통과
모르면 묻는 쪽(exit 1)이다: 어떤 PR 이 머지될지 명령만으로 확실하지 않음(단순한 `gh pr merge <번호> …` 하나가 아님) ·
`--match-head-commit <7~40자 소문자 16진수>` 가 없거나 PR 머리 커밋(headRefOid)의 앞부분과 다름 · `--auto` ·
PR 을 못 읽음 · Risk 줄을 못 찾음 · 바뀐 파일을 다 못 받음 · 시간 초과.
조건은 사용자가 고른 이 셋뿐이다. 넓히거나 줄이지 않는다.

쓰는 법: pr_merge_ok.py <명령 원문>   (시간 상한: CLAUDE_PR_MERGE_TIMEOUT 초, 기본 10 — gh 호출마다)
"""
import json
import os
import re
import shlex
import subprocess
import sys

RISK_MAX = 30
RULE_FILE = re.compile(r"(^|/)CLAUDE\.md$|(^|/)\.claude/rules/")
RISK = re.compile(r"^## ⚠️ Risk Score: (\d+)/100\b", re.M)
FENCE = re.compile(r"^```.*?^```", re.M | re.S)
# 명령이 하나인지 흐리게 만드는 글자: 연결자 · 줄바꿈 · 치환 · 재지정
NOT_SIMPLE = re.compile(r"[;&|\n`<>]|\$\(")
FLAGS = {"-s", "--squash", "-m", "--merge", "-r", "--rebase", "-d", "--delete-branch", "--admin", "--disable-auto"}
# --auto 는 모르는 옵션으로 떨어진다 — 지금 본 CI 가 아니라 나중 상태로 머지된다(트랙이 정함, ADR-026 D1)
VALUE_FLAGS = {"-R", "--repo", "-t", "--subject", "-b", "--body", "-F", "--body-file", "--match-head-commit", "-A", "--author-email"}


def no(reason):
    print(reason)
    sys.exit(1)


def target(cmd):
    """`gh pr merge <번호> [아는 옵션]` 하나일 때만 (번호, 레포 또는 None, 머리 커밋 또는 None). 아니면 None."""
    if NOT_SIMPLE.search(cmd):
        return None
    try:
        toks = shlex.split(cmd)
    except ValueError:
        return None
    if toks[:3] != ["gh", "pr", "merge"]:   # 앞에 환경 변수 · 경로 · cd 가 붙으면 아니다
        return None
    num, repo, head, i = None, None, None, 3
    while i < len(toks):
        t = toks[i]
        if t in VALUE_FLAGS:
            if i + 1 >= len(toks):
                return None
            if t in ("-R", "--repo"):
                repo = toks[i + 1]
            if t == "--match-head-commit":
                head = toks[i + 1]
            i += 2
            continue
        if t in FLAGS:
            i += 1
            continue
        if t.isdigit() and num is None:
            num = t
            i += 1
            continue
        return None   # 모르는 옵션(-sR · -R=x · --repo=x 등) · 번호가 아닌 지정(브랜치 · URL) · 두 번째 지정
    if num is None:
        return None
    return num, repo, head


def gh(args):
    timeout = float(os.environ.get("CLAUDE_PR_MERGE_TIMEOUT", "10"))
    r = subprocess.run(["gh"] + args, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        no("PR 을 읽지 못했다")
    return r.stdout


def main():
    if len(sys.argv) != 2:
        no("쓰는 법: pr_merge_ok.py <명령>")
    got = target(sys.argv[1])
    if got is None:
        no("단순한 gh pr merge <번호> 명령 하나가 아니다")
    num, repo, head = got
    # 확인한 커밋과 머지될 커밋이 같다고 명령이 말해야 한다 — 읽은 뒤 새 커밋이 올라오면 gh 가 머지를 거절한다(트랙이 정함, ADR-026 D1)
    if not head or not re.fullmatch(r"[0-9a-f]{7,40}", head):
        no("--match-head-commit <7자 이상 커밋> 이 없다")
    try:
        view = gh(["pr", "view", num] + (["-R", repo] if repo else []) + ["--json", "headRefOid,body,changedFiles,statusCheckRollup"])
        # 이름 바꾸기의 옛 경로는 REST 파일 목록에만 있다(previous_filename)
        rows = gh(["api", f"repos/{repo or '{owner}/{repo}'}/pulls/{num}/files", "--paginate",
                   "--jq", '.[] | [.filename, (.previous_filename // "")] | @tsv'])
    except (subprocess.TimeoutExpired, ValueError, OSError):
        no("PR 을 읽다 시간이 넘었거나 gh 를 부르지 못했다")
    try:
        pr = json.loads(view)
    except ValueError:
        no("PR 응답을 읽지 못했다")
    if not str(pr.get("headRefOid") or "").startswith(head):
        no("--match-head-commit 이 PR 머리 커밋과 다르다")
    paths = [p for ln in rows.splitlines() if ln for p in ln.split("\t") if p]
    if len([ln for ln in rows.splitlines() if ln]) != pr.get("changedFiles"):
        no("바뀐 파일 목록을 다 받지 못했다")
    rules = sorted({p for p in paths if RULE_FILE.search(p)})
    if rules:
        no(f"규칙 파일이 바뀌었다: {', '.join(rules[:3])}")
    risks = RISK.findall(FENCE.sub("", pr.get("body") or ""))
    if len(risks) != 1:
        no("PR 본문에서 Risk Score 머리 줄을 하나로 찾지 못했다")
    if int(risks[0]) > RISK_MAX:
        no(f"Risk Score {risks[0]} > {RISK_MAX}")
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
