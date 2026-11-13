#!/usr/bin/env python3
"""가설 게이트 원장 — 쓰기·읽기 (ADR-002·003·004, 줄 형식 정본은 docs/desk-hypothesis-gate-2026-11-12/SDD-SIDE.md).

원장: CLAUDE_HYPOTHESIS_LEDGER(테스트용) 또는 ~/.claude/hypothesis-ledger.jsonl. 추가 전용 — 기존 줄은 고치지 않는다.
이름·프롬프트 원문·코드는 받지 않는다: 허용 칸·값 밖은 거부.

Usage:
    ledger.py append repo=.. task=.. gate=.. diff=<easy|mid|hard|null> area=.. hyp=.. rec=.. acc=.. why=.. rebut=.. skip=..
    ledger.py hit <ref> <right|partial|wrong> <model|finn>
    ledger.py gate-fix <ref> <schema|api|error|delete|security|null>
    ledger.py state [repo task]          # on|off 한 줄. 줄 순서만으로 계산, 파일을 만들지 않음
    ledger.py pending-hits <repo> <task>   # hyp=true 인데 적중 줄이 없는 맡김 줄의 ts
    ledger.py pending-gates <repo> <task>  # 유효한 gate 가 null 인 맡김 줄의 ts

종료 코드: 0 성공 · 2 거부(칸·값·ref) · 1 쓰기 실패. 거부·실패는 stderr 한 줄만(재시도·복구 없음).
읽기 서브커맨드는 원장을 쓰지 않고, 원장이 없거나 깨져도 exit 0.
기준 횟수: CLAUDE_HYPOTHESIS_GATE_CONFIG(테스트용) 또는 ~/.claude/hypothesis-gate.json 의 threshold. 없으면 항상 off.
"""
import datetime
import json
import os
import re
import secrets
import sys
from pathlib import Path

GATES = ("schema", "api", "error", "delete", "security")
DIFFS = ("easy", "mid", "hard")  # 참고용 칸 — 계산(state·pending-*)에는 쓰지 않는다
AREAS = ("FE", "BE", "infra", "domain", "unknown")
HITS = ("right", "partial", "wrong")
BYS = ("model", "finn")
BOOLS = ("hyp", "rec", "acc", "why", "rebut", "skip")
FIELDS = ("repo", "task", "gate", "diff", "area") + BOOLS
_NAME = re.compile(r"^[A-Za-z0-9._-]{1,100}$")


class Reject(Exception):
    pass


def ledger_path() -> Path:
    return Path(os.environ.get("CLAUDE_HYPOTHESIS_LEDGER") or Path.home() / ".claude" / "hypothesis-ledger.jsonl")


def read_lines():
    """원장의 JSON 객체 줄을 순서대로. 없거나 깨진 줄은 건너뛴다."""
    out = []
    try:
        data = ledger_path().read_bytes()
    except OSError:
        return out
    for raw in data.split(b"\n"):
        try:
            d = json.loads(raw.decode("utf-8"))  # UTF-8 아닌 바이트가 든 줄만 건너뛴다
        except ValueError:  # UnicodeDecodeError 포함
            continue
        if isinstance(d, dict):
            out.append(d)
    return out


def _now() -> str:
    # 같은 순간의 줄이 겹치지 않게 마이크로초 + 난수 꼬리. 줄 키·ref 는 이 문자열 통째(불투명)
    return datetime.datetime.now().astimezone().isoformat(timespec="microseconds") + "#" + secrets.token_hex(2)


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
    if kv["diff"] != "null" and kv["diff"] not in DIFFS:
        raise Reject("diff: 허용 밖 값")
    if kv["area"] not in AREAS:
        raise Reject("area: 허용 밖 값")
    entry = {
        "ts": _now(),
        "repo": kv["repo"],
        "task": None if kv["task"] == "null" else kv["task"],
        "gate": _gate(kv["gate"], "gate"),
        "diff": None if kv["diff"] == "null" else kv["diff"],
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


def threshold():
    """기준 횟수(양의 정수). 파일·값이 없거나 이상하면 None → 재요구는 켜지지 않는다(AC6)."""
    p = Path(os.environ.get("CLAUDE_HYPOTHESIS_GATE_CONFIG") or Path.home() / ".claude" / "hypothesis-gate.json")
    try:
        v = json.loads(p.read_text(encoding="utf-8")).get("threshold")
    except (OSError, ValueError, AttributeError):
        return None
    if isinstance(v, int) and not isinstance(v, bool) and v >= 1:
        return v
    return None


def _split(lines):
    """줄 종류를 키로 가른다: ts 가 있으면 맡김 줄, hit 면 적중 줄, ref+gate 면 보정 줄(마지막이 유효)."""
    entries, hits, fixes = [], {}, {}
    for d in lines:
        if "ts" in d and "repo" in d:
            if isinstance(d["ts"], str):
                entries.append(d)
        elif not isinstance(d.get("ref"), str):
            continue
        elif "hit" in d:
            if d["hit"] in HITS:
                hits[d["ref"]] = d["hit"]
        elif "gate" in d and (d["gate"] is None or d["gate"] in GATES):
            fixes[d["ref"]] = d["gate"]
    return entries, hits, fixes


def _eff_gate(d, fixes):
    return fixes[d["ts"]] if d["ts"] in fixes else d.get("gate")


def compute_state(lines, thr) -> bool:
    """재요구 상태(SDD-SIDE 「계산 규칙」). 맡김 줄만, 보정을 적용해 처음부터 다시 센다."""
    if thr is None:
        return False
    entries, _, fixes = _split(lines)
    key, streak, on = None, 0, False
    got_hyp = got_rebut = False
    for d in entries:
        if d.get("task") is None:
            continue  # task=null 은 세지도 끊지도 모으지도 않는다
        k = (d["repo"], d["task"])
        if _eff_gate(d, fixes) is None:
            # gate=null 은 연속 계산에서만 빠진다: 세지도 끊지도 않고, (repo, task) 신호도 아니다.
            # 단 켜진 동안 같은 키면 hyp·rebut 은 꺼짐 조건에 모은다.
            if on and k == key:
                got_hyp = got_hyp or d.get("hyp") is True
                got_rebut = got_rebut or d.get("rebut") is True
                if got_hyp and got_rebut:
                    on, streak, got_hyp, got_rebut = False, 0, False, False
            continue
        if k != key:
            key, streak, got_hyp, got_rebut = k, 0, False, False
        if d.get("rec") is True and d.get("acc") is True and d.get("why") is False:
            streak += 1
        else:
            streak = 0
        if not on:
            if streak >= thr:
                on, got_hyp, got_rebut = True, False, False  # 켜진 뒤의 hyp·rebut 만 모은다
        else:
            got_hyp = got_hyp or d.get("hyp") is True
            got_rebut = got_rebut or d.get("rebut") is True
            if got_hyp and got_rebut:
                on, streak, got_hyp, got_rebut = False, 0, False, False
    return on


def _same(d, repo, task) -> bool:
    return d.get("repo") == repo and d.get("task") == (None if task == "null" else task)


def cmd_read(cmd, args):
    lines = read_lines()
    if cmd == "state":
        print("on" if compute_state(lines, threshold()) else "off")
        return 0
    if len(args) != 2:
        raise Reject(f"사용: {cmd} <repo> <task>")
    entries, hits, fixes = _split(lines)
    for d in entries:
        if not _same(d, args[0], args[1]):
            continue
        if cmd == "pending-hits" and d.get("hyp") is True and d["ts"] not in hits:
            print(d["ts"])
        elif cmd == "pending-gates" and _eff_gate(d, fixes) is None:
            print(d["ts"])
    return 0


def main(argv) -> int:
    if len(argv) < 2:
        print("사용: ledger.py append|hit|gate-fix|state|pending-hits|pending-gates ...", file=sys.stderr)
        return 2
    cmd, args = argv[1], argv[2:]
    if cmd in ("state", "pending-hits", "pending-gates"):
        try:
            return cmd_read(cmd, args)
        except Reject as e:
            print(f"ledger: 거부 — {e}", file=sys.stderr)
            return 2
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
