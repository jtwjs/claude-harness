#!/usr/bin/env python3
"""지휘 이슈 의존 — conductor §4 의 `gh api graphql` 호출을 감싼다. gh CLI 에는 의존 플래그가 없어 graphql 로만 걸린다.

Usage:
    issues.py block <이슈> <막는 이슈> [--repo R]    #이슈 가 #막는 이슈 에 막힌다(addBlockedBy)
    issues.py unblock <이슈> <막는 이슈> [--repo R]  막힘을 푼다(removeBlockedBy)
    issues.py sub <부모> <자식> [--repo R]           #자식 을 #부모(결정) 의 하위로(addSubIssue)
    issues.py ready [--repo R]                       열린 conductor 이슈를 한 번에 받아 차단이 전부 닫힌 것만.
                                                     decision 은 지휘 원장이라 뺀다. 한 줄에 `#번호 [track:…] 제목`
    --repo 는 OWNER/NAME. 없으면 지금 레포(gh 가 고른다).
    실패(권한 · 기능 미지원)는 gh 오류를 stderr 로 내고 0 아닌 종료 — 부른 쪽이 §4 「실패하면」으로 간다.
    gh 경로는 CLAUDE_CONDUCTOR_GH 로 바꿔 끼운다(테스트. hooks/conductor-context.sh 와 같은 변수).
"""
import argparse
import json
import os
import subprocess
import sys

GH = os.environ.get("CLAUDE_CONDUCTOR_GH") or "gh"

BLOCK = "mutation($i:ID!,$b:ID!){addBlockedBy(input:{issueId:$i,blockingIssueId:$b}){issue{number}}}"
UNBLOCK = "mutation($i:ID!,$b:ID!){removeBlockedBy(input:{issueId:$i,blockingIssueId:$b}){issue{number}}}"
SUB = "mutation($p:ID!,$c:ID!){addSubIssue(input:{issueId:$p,subIssueId:$c}){issue{number}}}"
READY = """query($owner:String!,$name:String!){repository(owner:$owner,name:$name){
  issues(first:100,states:OPEN,labels:["conductor"]){nodes{
    number title labels(first:10){nodes{name}}
    blockedBy(first:20){nodes{number state}}
}}}}"""


class GhError(Exception):
    pass


def gh(*args) -> str:
    try:
        r = subprocess.run([GH, *args], capture_output=True, text=True)
    except OSError as e:
        raise GhError(f"gh 실행 실패: {e}")
    if r.returncode != 0:
        raise GhError(r.stderr.strip() or f"gh 종료 코드 {r.returncode}")
    return r.stdout.strip()


def node_id(num: str, repo) -> str:
    """노드 id 를 받은 뒤의 mutation 은 레포를 묻지 않는다."""
    return gh("issue", "view", num, "--json", "id", "-q", ".id", *(["-R", repo] if repo else []))


def link(query: str, keys: tuple, nums: tuple, repo) -> None:
    ids = [node_id(n, repo) for n in nums]
    args = ["api", "graphql", "-f", f"query={query}"]
    for k, v in zip(keys, ids):
        args += ["-f", f"{k}={v}"]
    gh(*args)


def ready(repo) -> list:
    owner, _, name = (repo or gh("repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner")).partition("/")
    if not owner or not name:
        raise GhError(f"레포는 OWNER/NAME 이어야 한다: {repo}")
    out = gh("api", "graphql", "-f", f"owner={owner}", "-f", f"name={name}", "-f", f"query={READY}")
    try:
        nodes = json.loads(out)["data"]["repository"]["issues"]["nodes"]
    except (ValueError, KeyError, TypeError) as e:
        raise GhError(f"응답 형식이 다르다: {e}")
    lines = []
    for n in nodes:
        labels = [x["name"] for x in n["labels"]["nodes"]]
        if "decision" in labels:
            continue
        if any(b["state"] == "OPEN" for b in n["blockedBy"]["nodes"]):
            continue
        tracks = ",".join(x for x in labels if x.startswith("track:"))
        lines.append(f"#{n['number']} [{tracks}] {n['title']}")
    return lines


def main(argv: list) -> int:
    p = argparse.ArgumentParser(prog="issues.py", description="지휘 이슈 의존 · 지금 진행 가능한 것 (gh api graphql)")
    cmds = p.add_subparsers(dest="cmd", required=True)
    for name, a, b, desc in (("block", "issue", "blocking", "#issue 가 #blocking 에 막힌다"),
                             ("unblock", "issue", "blocking", "#issue 의 #blocking 막힘을 푼다"),
                             ("sub", "parent", "child", "#child 를 #parent 의 하위로")):
        s = cmds.add_parser(name, help=desc)
        s.add_argument(a)
        s.add_argument(b)
        s.add_argument("--repo", help="OWNER/NAME (없으면 지금 레포)")
    s = cmds.add_parser("ready", help="차단이 전부 닫힌 열린 conductor 이슈(decision 제외)")
    s.add_argument("--repo", help="OWNER/NAME (없으면 지금 레포)")
    args = p.parse_args(argv)
    try:
        if args.cmd == "block":
            link(BLOCK, ("i", "b"), (args.issue, args.blocking), args.repo)
            print(f"#{args.issue} 가 #{args.blocking} 에 막힘")
        elif args.cmd == "unblock":
            link(UNBLOCK, ("i", "b"), (args.issue, args.blocking), args.repo)
            print(f"#{args.issue} 의 #{args.blocking} 막힘 풀림")
        elif args.cmd == "sub":
            link(SUB, ("p", "c"), (args.parent, args.child), args.repo)
            print(f"#{args.child} 는 #{args.parent} 의 하위")
        else:
            for line in ready(args.repo):
                print(line)
    except GhError as e:
        print(f"issues.py {args.cmd}: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
