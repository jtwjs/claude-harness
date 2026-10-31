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


# 셸 내장·한 단어 무해 명령은 세지 않는다 — `true` 가 `… || true` 가 든 모든 셸 줄에 걸린다(2026-10-31 실측: 러너 테스트가 600초 대기)
TRIVIAL = {"true", "false", ":", "exit", "echo", "test", "["}


def _ps_rows() -> list:
    """[(pid, ppid, command)]. CLAUDE_VERIFY_PS 가짜 파일 줄은 `pid ppid command` 이거나 command 만(그러면 각 줄이 따로)."""
    fake = os.environ.get("CLAUDE_VERIFY_PS")
    if fake:
        try:
            lines = Path(fake).read_text(encoding="utf-8").splitlines()
        except OSError:
            return []
    else:
        r = subprocess.run(["ps", "-Ao", "pid=,ppid=,command="], capture_output=True, text=True)
        lines = r.stdout.splitlines() if r.returncode == 0 else []
    rows = []
    for i, line in enumerate(lines):
        parts = line.split(None, 2)
        if len(parts) == 3 and parts[0].isdigit() and parts[1].isdigit():
            rows.append((int(parts[0]), int(parts[1]), parts[2]))
        elif line.strip():
            rows.append((-1 - i, 0, line))
    return rows


def running(cmds) -> int:
    """검사 실행 수. 한 실행은 셸 래퍼 → node pnpm → turbo 처럼 줄이 여럿이라, 부모가 이미 검사인 줄은 세지 않는다."""
    cmds = [c for c in cmds if c.split() and c.split()[0] not in TRIVIAL]
    hits = {pid: ppid for pid, ppid, c in _ps_rows()
            if "verify_busy.py" not in c and any(x in c for x in cmds)}
    return sum(1 for pid, ppid in hits.items() if ppid not in hits)


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
