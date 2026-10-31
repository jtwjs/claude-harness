#!/usr/bin/env python3
"""지휘 설정 — 지휘 자리(seat)와 대상 레포 목록. 읽기만 한다 (ADR-001 · ADR-002, 2026-10-31).

설정: CLAUDE_CONDUCTOR_CONFIG(테스트용) 또는 ~/.claude/conductor.json
    {"seat": "~/wiki", "repos": ["~/orca/bv-admin", ...]}
없거나 깨지면 지휘 기능이 꺼진 것으로 본다 — 모든 호출부가 지금 동작 그대로.

Usage:
    conductor.py is-seat <cwd>    # 지휘 자리면 exit 0
    conductor.py repos            # 대상 레포 경로 한 줄에 하나
"""
import json
import os
import subprocess
import sys
from pathlib import Path


def _path() -> Path:
    return Path(os.environ.get("CLAUDE_CONDUCTOR_CONFIG") or Path.home() / ".claude" / "conductor.json")


def load():
    try:
        cfg = json.loads(_path().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return cfg if isinstance(cfg, dict) else None


def _expand(p) -> Path:
    return Path(os.path.expanduser(str(p)))


def seat():
    cfg = load()
    s = cfg.get("seat") if cfg else None
    return _expand(s).resolve() if isinstance(s, str) and s.strip() else None


def repos() -> list:
    cfg = load()
    rs = cfg.get("repos") if cfg else None
    return [_expand(r) for r in rs if isinstance(r, str) and r.strip()] if isinstance(rs, list) else []


def _toplevel(cwd) -> Path:
    r = subprocess.run(["git", "-C", str(cwd), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    return Path(r.stdout.strip()).resolve() if r.returncode == 0 and r.stdout.strip() else Path(cwd).resolve()


def is_seat(cwd) -> bool:
    s = seat()
    return s is not None and _toplevel(cwd) == s


def main(argv) -> int:
    if len(argv) >= 2 and argv[0] == "is-seat":
        return 0 if is_seat(argv[1]) else 1
    if argv[:1] == ["repos"]:
        for r in repos():
            print(r)
        return 0
    print(__doc__.strip().splitlines()[-2:], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
