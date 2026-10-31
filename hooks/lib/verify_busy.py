#!/usr/bin/env python3
"""검사 상한 — 지금 이 머신에서 도는 검사(verify) 프로세스 수를 센다. 잠금 파일은 없다 (ADR-007, 2026-10-31).

검사 명령 = 레포 .claude/harness.json 의 verify 값(단일·앱별, `$` 키 무시) + `pnpm verify` · `npm run verify`.
프로세스 목록은 `ps -Ao command`(테스트는 CLAUDE_VERIFY_PS 파일). 상한 CLAUDE_VERIFY_MAX(기본 2).
세션이 하나면 상한에 닿지 않아 아무 일도 하지 않는다.

Usage:
    verify_busy.py busy <repo_root>            # 상한 이상이면 개수 출력 + exit 0, 아니면 exit 1
    verify_busy.py match <repo_root> <command> # 검사 명령이면 exit 0
"""
import json
import os
import subprocess
import sys
from pathlib import Path

ALWAYS = ["pnpm verify", "npm run verify"]
DEFAULT_MAX = 2


def verify_cmds(repo_root) -> list:
    cmds = list(ALWAYS)
    try:
        v = json.loads((Path(repo_root) / ".claude" / "harness.json").read_text(encoding="utf-8")).get("verify") or {}
    except (OSError, ValueError, AttributeError):
        return cmds
    groups = [m for k, m in v.items() if not k.startswith("$") and isinstance(m, dict)] or [v]
    for g in groups:
        for k, c in g.items():
            if not k.startswith("$") and isinstance(c, str) and c.strip() and c.strip() not in cmds:
                cmds.append(c.strip())
    return cmds


def _ps_lines() -> list:
    fake = os.environ.get("CLAUDE_VERIFY_PS")
    if fake:
        try:
            return Path(fake).read_text(encoding="utf-8").splitlines()
        except OSError:
            return []
    r = subprocess.run(["ps", "-Ao", "command"], capture_output=True, text=True)
    return r.stdout.splitlines()[1:] if r.returncode == 0 else []


def running(cmds) -> int:
    return sum(1 for line in _ps_lines()
               if "verify_busy.py" not in line and any(c in line for c in cmds))


def limit() -> int:
    try:
        n = int(os.environ.get("CLAUDE_VERIFY_MAX", DEFAULT_MAX))
    except ValueError:
        return DEFAULT_MAX
    return n if n >= 1 else DEFAULT_MAX


def busy(repo_root) -> int:
    """상한 이상이면 지금 개수, 아니면 0."""
    n = running(verify_cmds(repo_root))
    return n if n >= limit() else 0


def is_verify(repo_root, command: str) -> bool:
    return any(c in command for c in verify_cmds(repo_root))


def main(argv) -> int:
    if len(argv) == 2 and argv[0] == "busy":
        n = busy(argv[1])
        if n:
            print(n)
            return 0
        return 1
    if len(argv) == 3 and argv[0] == "match":
        return 0 if is_verify(argv[1], argv[2]) else 1
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
