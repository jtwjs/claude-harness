#!/usr/bin/env python3
"""테스트 통과 판정 — `.claude/harness.json` 의 verify test 명령을 돌려 종료 코드로 판정한다(ADR-028).

검증 세션이 테스트 무변경 판정(tests_unchanged.py) 다음에 부른다.

  python3 tests_pass.py

명령 고르기(ADR-025):
  - `$step.test` 가 있으면 그것을 쓰고 {since} 에 브랜치 시작점(`git merge-base HEAD origin/<git.baseBranch>`,
    origin 이 없으면 로컬 브랜치)을 넣는다. 테스트 커밋이 여럿이어도 전부 범위에 든다
  - `$step.test` 가 없거나 브랜치 시작점을 못 찾으면 전체 `test` 를 쓴다
  - 앱별 verify({"<폴더>": {"test": …}})면 앱마다 그 폴더에서 돌린다
종료 코드: 0 전부 통과 · 1 하나라도 실패 · 2 harness.json · test 명령 · 인자 오류
"""
import json
import shlex
import subprocess
import sys
from pathlib import Path


def test_cmds(verify: dict) -> list:
    """[(폴더, test 명령, $step test 명령 또는 None)] — 단일 앱과 앱별 둘 다."""
    def pick(m):
        step = m.get("$step")
        s = step.get("test") if isinstance(step, dict) else None
        return m.get("test"), (s if isinstance(s, str) and s.strip() else None)

    out = []
    t, s = pick(verify)
    if isinstance(t, str) and t.strip():
        out.append((".", t, s))
    for k, v in verify.items():
        if not k.startswith("$") and isinstance(v, dict):
            t, s = pick(v)
            if isinstance(t, str) and t.strip():
                out.append((k, t, s))
    return out


def branch_start(base):
    """브랜치 시작점 sha, 못 찾으면 None."""
    for ref in (f"origin/{base}", base) if base else ():
        r = subprocess.run(["git", "merge-base", "HEAD", ref], capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
    return None


def main(argv) -> int:
    if argv:
        print("사용: tests_pass.py (인자 없음)", file=sys.stderr)
        return 2
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if r.returncode:
        print("테스트 통과: git 레포가 아니다", file=sys.stderr)
        return 2
    root = Path(r.stdout.strip())
    cfg_file = root / ".claude/harness.json"
    try:
        cfg = json.loads(cfg_file.read_text(encoding="utf-8"))
        verify = cfg.get("verify") or {}
    except (OSError, ValueError, AttributeError) as e:
        print(f"테스트 통과: {cfg_file} 를 읽을 수 없다 — {e}", file=sys.stderr)
        return 2
    cmds = test_cmds(verify)
    if not cmds:
        print("테스트 통과: verify 에 test 명령이 없다 — 판정할 수 없다", file=sys.stderr)
        return 2
    since = branch_start((cfg.get("git") or {}).get("baseBranch")) if any(s for _, _, s in cmds) else None
    failed = []
    for folder, full, step in cmds:
        cmd = step.replace("{since}", shlex.quote(since)) if step and since else full
        print(f"▶ [{folder}] {cmd}", flush=True)
        if not (root / folder).is_dir() or subprocess.run(cmd, shell=True, cwd=root / folder).returncode:
            failed.append(folder)
    if failed:
        print(f"테스트 통과: 실패 — {' · '.join(failed)}")
        return 1
    print("테스트 통과: 전부 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
