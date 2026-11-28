#!/usr/bin/env python3
"""테스트 통과 판정 — `.claude/harness.json` 의 verify test 명령을 돌려 종료 코드로 판정한다(ADR-028).

검증 세션이 테스트 무변경 판정(tests_unchanged.py) 다음에 같은 테스트 커밋 sha 로 부른다.

  python3 tests_pass.py <테스트 커밋 sha>

명령 고르기(ADR-025):
  - `$step.test` 가 있으면 그것을 쓰고 {since} 에 테스트 커밋의 부모를 넣는다(테스트 파일도 바뀐 범위에 든다)
  - 없으면 전체 `test` 를 쓴다
  - 앱별 verify({"<폴더>": {"test": …}})면 앱마다 그 폴더에서 돌린다
종료 코드: 0 전부 통과 · 1 하나라도 실패 · 2 harness.json · test 명령 · 커밋 오류
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


def main(argv) -> int:
    if len(argv) != 1:
        print("사용: tests_pass.py <테스트 커밋 sha>", file=sys.stderr)
        return 2
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if r.returncode:
        print("테스트 통과: git 레포가 아니다", file=sys.stderr)
        return 2
    root = Path(r.stdout.strip())
    cfg_file = root / ".claude/harness.json"
    try:
        verify = json.loads(cfg_file.read_text(encoding="utf-8")).get("verify") or {}
    except (OSError, ValueError) as e:
        print(f"테스트 통과: {cfg_file} 를 읽을 수 없다 — {e}", file=sys.stderr)
        return 2
    cmds = test_cmds(verify)
    if not cmds:
        print("테스트 통과: verify 에 test 명령이 없다 — 판정할 수 없다", file=sys.stderr)
        return 2
    since = None
    if any(s for _, _, s in cmds):
        p = subprocess.run(["git", "rev-parse", "--verify", "-q", f"{argv[0]}^{{commit}}"], capture_output=True, text=True)
        q = subprocess.run(["git", "rev-parse", "--verify", "-q", f"{argv[0]}^"], capture_output=True, text=True)
        if p.returncode:
            print(f"테스트 통과: 커밋을 읽을 수 없다 — {argv[0]}", file=sys.stderr)
            return 2
        since = q.stdout.strip() if q.returncode == 0 else None   # 첫 커밋이면 부모가 없다 → 전체 명령
    failed = []
    for folder, full, step in cmds:
        cmd = step.replace("{since}", shlex.quote(since)) if step and since else full
        print(f"▶ [{folder}] {cmd}", flush=True)
        if subprocess.run(cmd, shell=True, cwd=root / folder).returncode:
            failed.append(folder)
    if failed:
        print(f"테스트 통과: 실패 — {' · '.join(failed)}")
        return 1
    print("테스트 통과: 전부 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
