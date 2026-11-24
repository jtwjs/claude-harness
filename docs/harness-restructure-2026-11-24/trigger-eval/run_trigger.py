#!/usr/bin/env python3
"""설치된 claude-harness 스킬의 발동 정확도를 잰다.

skill-creator `scripts/run_eval.py` 방식을 따르되, 임시 명령 파일을 만들지 않고
설치본 스킬(`claude-harness:<name>`)이 첫 도구 호출로 불리는지를 본다.
- 첫 tool_use 가 Skill 이고 이름 끝이 <name> 이면 발동, 그 밖(다른 도구 · 다른 스킬 · 글만)은 미발동
- 훅 끔(--settings disableAllHooks) · 세션 저장 안 함 · dontAsk 권한 · 첫 도구 블록에서 바로 끊는다
"""
import argparse
import json
import os
import select
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed


def run_one(query, cwd, model, timeout):
    cmd = ["claude", "-p", query, "--output-format", "stream-json", "--verbose",
           "--include-partial-messages", "--no-session-persistence",
           "--settings", '{"disableAllHooks": true}', "--permission-mode", "dontAsk"]
    if model:
        cmd += ["--model", model]
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    # 훅이 혹시 돌아도 개인 원장에 쓰지 않게
    env["CLAUDE_HYPOTHESIS_LEDGER"] = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ledger-sink.jsonl")
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, cwd=cwd, env=env)
    buf, tool, acc = "", None, ""
    start = time.time()
    try:
        while time.time() - start < timeout:
            if p.poll() is not None:
                rest = p.stdout.read()
                if rest:
                    buf += rest.decode("utf-8", "replace")
            else:
                r, _, _ = select.select([p.stdout], [], [], 1.0)
                if not r:
                    continue
                chunk = os.read(p.stdout.fileno(), 65536)
                if not chunk:
                    break
                buf += chunk.decode("utf-8", "replace")
            while "\n" in buf:
                line, buf = buf.split("\n", 1)
                try:
                    ev = json.loads(line)
                except Exception:
                    continue
                if ev.get("type") == "stream_event":
                    se = ev.get("event", {})
                    t = se.get("type")
                    if t == "content_block_start" and se.get("content_block", {}).get("type") == "tool_use":
                        tool = se["content_block"].get("name", "")
                        if tool != "Skill":
                            return tool, None
                    elif t == "content_block_delta" and tool == "Skill":
                        acc += se.get("delta", {}).get("partial_json", "")
                    elif t == "content_block_stop" and tool == "Skill":
                        try:
                            return "Skill", json.loads(acc).get("skill", "")
                        except Exception:
                            return "Skill", acc[:80]
                    elif t == "message_stop" and tool is None:
                        return "none", None
                elif ev.get("type") == "result":
                    if ev.get("is_error"):
                        return f"error:{ev.get('subtype', '')}", None
                    return (tool or "none"), None
            if p.poll() is not None and "\n" not in buf:
                break
        return "timeout", None
    finally:
        if p.poll() is None:
            p.kill()
            p.wait()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--evals", required=True)
    ap.add_argument("--cwd", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--timeout", type=int, default=90)
    ap.add_argument("--model", default=None)
    ap.add_argument("--only", default=None, help="쉼표로 스킬 이름 제한")
    a = ap.parse_args()
    evals = json.load(open(a.evals))
    jobs = []
    for skill, items in evals.items():
        if a.only and skill not in a.only.split(","):
            continue
        for i, it in enumerate(items):
            for r in range(a.runs):
                jobs.append((skill, i, r, it["query"], it["should_trigger"]))
    rows = []
    with ThreadPoolExecutor(max_workers=a.workers) as ex:
        futs = {ex.submit(run_one, q, a.cwd, a.model, a.timeout): (s, i, r, q, st) for s, i, r, q, st in jobs}
        for n, f in enumerate(as_completed(futs), 1):
            s, i, r, q, st = futs[f]
            try:
                tool, sk = f.result()
            except Exception as e:
                tool, sk = f"error:{e}", None
            hit = tool == "Skill" and (sk or "").split(":")[-1] == s
            rows.append({"skill": s, "idx": i, "run": r, "should_trigger": st, "triggered": hit,
                         "first_tool": tool, "skill_called": sk, "query": q})
            print(f"[{n}/{len(jobs)}] {s}#{i} r{r} want={st} got={hit} ({tool} {sk or ''})", file=sys.stderr, flush=True)
            with open(a.out, "w") as fh:
                json.dump(rows, fh, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
