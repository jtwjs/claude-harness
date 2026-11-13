#!/usr/bin/env python3
"""가설 게이트 원장 — 쓰기 (ADR-002·003, 줄 형식 정본은 docs/desk-hypothesis-gate-2026-11-12/SDD-SIDE.md).

원장: CLAUDE_HYPOTHESIS_LEDGER(테스트용) 또는 ~/.claude/hypothesis-ledger.jsonl. 추가 전용 — 기존 줄은 고치지 않는다.
이름·프롬프트 원문·코드는 받지 않는다: 허용 칸·값 밖은 거부.

Usage:
    ledger.py append repo=.. task=.. gate=.. area=.. hyp=.. rec=.. acc=.. why=.. rebut=.. skip=..
    ledger.py hit <ref> <right|partial|wrong> <model|finn>
    ledger.py gate-fix <ref> <schema|api|error|delete|security|null>

종료 코드: 0 성공 · 2 거부(칸·값·ref) · 1 쓰기 실패. 거부·실패는 stderr 한 줄만(재시도·복구 없음).
"""
import datetime
import json
import os
import re
import sys
from pathlib import Path

GATES = ("schema", "api", "error", "delete", "security")
AREAS = ("FE", "BE", "infra", "domain", "unknown")
HITS = ("right", "partial", "wrong")
BYS = ("model", "finn")
BOOLS = ("hyp", "rec", "acc", "why", "rebut", "skip")
FIELDS = ("repo", "task", "gate", "area") + BOOLS
_NAME = re.compile(r"^[A-Za-z0-9._-]{1,100}$")


class Reject(Exception):
    pass


def ledger_path() -> Path:
    return Path(os.environ.get("CLAUDE_HYPOTHESIS_LEDGER") or Path.home() / ".claude" / "hypothesis-ledger.jsonl")


def read_lines():
    """원장의 JSON 객체 줄을 순서대로. 없거나 깨진 줄은 건너뛴다."""
    out = []
    try:
        text = ledger_path().read_text(encoding="utf-8")
    except OSError:
        return out
    for raw in text.splitlines():
        try:
            d = json.loads(raw)
        except ValueError:
            continue
        if isinstance(d, dict):
            out.append(d)
    return out


def _now() -> str:
    return datetime.datetime.now().astimezone().isoformat(timespec="milliseconds")


def _write(obj: dict) -> None:
    p = ledger_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "a", encoding="utf-8") as f:
        f.write(json.dumps(obj, ensure_ascii=False) + "\n")


def _gate(v: str, what: str):
    if v == "null":
        return None
    if v in GATES:
        return v
    raise Reject(f"{what}: 허용 밖 값")


def build_entry(pairs):
    kv = {}
    for a in pairs:
        k, sep, v = a.partition("=")
        if not sep or k not in FIELDS:
            raise Reject("허용 밖 칸이거나 key=value 형식이 아님")
        if k in kv:
            raise Reject(f"{k}: 중복")
        kv[k] = v
    missing = [k for k in FIELDS if k not in kv]
    if missing:
        raise Reject("빠진 칸: " + ",".join(missing))
    if not _NAME.match(kv["repo"]):
        raise Reject("repo: 허용 밖 값")
    if kv["task"] != "null" and not _NAME.match(kv["task"]):
        raise Reject("task: 허용 밖 값")
    if kv["area"] not in AREAS:
        raise Reject("area: 허용 밖 값")
    entry = {
        "ts": _now(),
        "repo": kv["repo"],
        "task": None if kv["task"] == "null" else kv["task"],
        "gate": _gate(kv["gate"], "gate"),
        "area": kv["area"],
    }
    for b in BOOLS:
        if kv[b] not in ("true", "false"):
            raise Reject(f"{b}: true|false 만")
        entry[b] = kv[b] == "true"
    return entry


def _has_entry(ref: str, need_hyp: bool) -> bool:
    for d in read_lines():
        if d.get("ts") == ref and "repo" in d and (not need_hyp or d.get("hyp") is True):
            return True
    return False


def main(argv) -> int:
    if len(argv) < 2:
        print("사용: ledger.py append|hit|gate-fix ...", file=sys.stderr)
        return 2
    cmd, args = argv[1], argv[2:]
    try:
        if cmd == "append":
            obj = build_entry(args)
        elif cmd == "hit":
            if len(args) != 3 or args[1] not in HITS or args[2] not in BYS:
                raise Reject("사용: hit <ref> <right|partial|wrong> <model|finn>")
            if not _has_entry(args[0], True):
                raise Reject("ref: hyp=true 인 맡김 줄의 ts 가 아님")
            obj = {"ref": args[0], "hit": args[1], "by": args[2]}
        elif cmd == "gate-fix":
            if len(args) != 2:
                raise Reject("사용: gate-fix <ref> <gate|null>")
            gate = _gate(args[1], "gate")
            if not _has_entry(args[0], False):
                raise Reject("ref: 맡김 줄의 ts 가 아님")
            obj = {"ref": args[0], "gate": gate, "by": "finn"}
        else:
            raise Reject(f"모르는 명령: {cmd}")
    except Reject as e:
        print(f"ledger: 거부 — {e}", file=sys.stderr)
        return 2
    try:
        _write(obj)
    except OSError as e:
        print(f"ledger: 쓰기 실패 — {e.strerror or e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
