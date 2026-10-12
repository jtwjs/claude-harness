#!/usr/bin/env python3
"""sdd_runner 판정 루프 테스트 — 가짜 claude 실행 파일로 끝에서 끝까지 돌린다.

강의 test_execute.py 는 claude 호출을 mock 으로 바꿔 부품만 보고, 판정 루프(재시도·status 미갱신·3회 실패)는
테스트가 0개였다. 여기서는 index.json·git 을 실제로 바꾸는 가짜 claude 로 그 루프를 본다.

실행: python3 -m unittest skills/harness-run/scripts/test_sdd_runner.py
"""
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
RUNNER = HERE / "sdd_runner.py"

# 가짜 claude: FAKE_SCENARIO(json 배열)에서 호출 순서대로 동작 하나를 꺼내 실행한다.
#   ops: [["write", 경로, 내용], ["commit", 메시지], ["status", 상태, {추가 필드}], ["sleep", 초]]
#   is_error / exit: JSON 결과와 종료 코드
FAKE = textwrap.dedent('''\
    #!/usr/bin/env python3
    import json, os, subprocess, sys, time
    from pathlib import Path
    state = Path(os.environ["FAKE_STATE"])
    n = int(state.read_text()) if state.exists() else 0
    state.write_text(str(n + 1))
    Path(os.environ["FAKE_PROMPTS"], f"{n}.txt").write_text(sys.argv[-1])
    calls = json.loads(Path(os.environ["FAKE_SCENARIO"]).read_text())
    call = calls[n] if n < len(calls) else {"ops": []}
    task = os.environ["FAKE_TASK"]
    for op in call.get("ops", []):
        if op[0] == "write":
            p = Path(op[1]); p.parent.mkdir(parents=True, exist_ok=True); p.write_text(op[2])
        elif op[0] == "commit":
            subprocess.run(["git", "add", "-A", "--", ".", ":(exclude)phases"], check=True)
            if subprocess.run(["git", "diff", "--cached", "--quiet"]).returncode != 0:   # 재시도에서 같은 내용이면 건너뛴다
                subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", op[1]], check=True)
        elif op[0] == "status":
            f = Path("phases", task, "index.json"); d = json.loads(f.read_text())
            for s in d["steps"]:
                if s["step"] == call["step"]:
                    s["status"] = op[1]; s.update(op[2] if len(op) > 2 else {})
            f.write_text(json.dumps(d, ensure_ascii=False, indent=2))
        elif op[0] == "sleep":
            time.sleep(op[1])
    print(json.dumps({"type": "result", "is_error": call.get("is_error", False), "result": "fake",
                      "usage": {"input_tokens": 10, "output_tokens": 5}, "num_turns": 1}))
    sys.exit(call.get("exit", 0))
''')

# verify.test: tests/*.expect 마다 src/<이름>.txt 내용이 같아야 통과
CHECK = textwrap.dedent('''\
    #!/bin/sh
    rc=0
    for e in tests/*.expect; do
      [ -f "$e" ] || continue
      n=$(basename "$e" .expect)
      [ "$(cat "src/$n.txt" 2>/dev/null)" = "$(cat "$e")" ] || rc=1
    done
    exit $rc
''')

RED = ["write", "tests/a.expect", "hello"]
IMPL = ["write", "src/a.txt", "hello"]
DONE = ["status", "completed", {"summary": "a 구현"}]


def git(cwd, *args):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


class RunnerCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        r = self.repo
        git(r, "init", "-q", "-b", "main")
        (r / ".claude").mkdir()
        (r / ".claude/harness.json").write_text(json.dumps(
            {"verify": {"test": "sh check.sh"}, "tdd": {"enabled": True}}))
        (r / "check.sh").write_text(CHECK)
        (r / "CLAUDE.md").write_text("# 프로젝트 규칙\n")
        (r / "src").mkdir()
        (r / "src/b.txt").write_text("x")
        git(r, "add", "-A")
        git(r, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "init")
        fake = self.tmp / "claude"
        fake.write_text(FAKE)
        fake.chmod(0o755)
        (self.tmp / "prompts").mkdir()
        self.env = dict(os.environ, SDD_RUNNER_CLAUDE=str(fake), FAKE_STATE=str(self.tmp / "n"),
                        FAKE_PROMPTS=str(self.tmp / "prompts"), FAKE_SCENARIO=str(self.tmp / "scenario.json"),
                        FAKE_TASK="t1")

    def phase(self, steps, task="t1", after=None):
        d = self.repo / "phases" / task
        d.mkdir(parents=True, exist_ok=True)
        (d / "index.json").write_text(json.dumps({"project": "p", "phase": task, "docs": "docs/x",
                                                  "after": after or [], "steps": steps}, indent=2))
        for s in steps:
            (d / f"step{s['step']}.md").write_text(f"# Step {s['step']}: {s['name']}\n\n## 작업\n- 구현\n")
        git(self.repo, "add", "-A")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", f"plan {task}")

    def run_runner(self, calls, *extra, task="t1"):
        (self.tmp / "scenario.json").write_text(json.dumps(calls))
        p = subprocess.run([sys.executable, str(RUNNER), "run", task, "--timeout", "5", *extra],
                           cwd=self.repo, env=self.env, capture_output=True, text=True)
        self.out = p.stdout + p.stderr
        return p.returncode

    def step(self, n=1, task="t1"):
        d = json.loads((self.repo / "phases" / task / "index.json").read_text())
        return next(s for s in d["steps"] if s["step"] == n)

    def calls_made(self):
        f = self.tmp / "n"
        return int(f.read_text()) if f.exists() else 0

    def prompt(self, i):
        return (self.tmp / "prompts" / f"{i}.txt").read_text()

    def log(self):
        return git(self.repo, "log", "--format=%s").stdout

    # ── 통과 ────────────────────────────────────────────────────────────────
    def test_pass_first_try(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        rc = self.run_runner([{"step": 1, "ops": [RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        s = self.step()
        self.assertEqual(s["status"], "completed")
        self.assertEqual(s.get("retries", 0), 0)
        for k in ("started_at", "completed_at", "usage"):
            self.assertIn(k, s)
        self.assertTrue((self.repo / "phases/t1/step1-output.json").exists())
        self.assertIn("chore: update phase index for step 1", self.log())
        self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip(), "feat-t1")
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "", "작업 트리가 깨끗해야 한다")

    def test_tdd_false_step(self):
        self.phase([{"step": 1, "name": "b", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [["write", "src/c.txt", "y"], ["commit", "feat: c"], DONE]}])
        self.assertEqual(rc, 0, self.out)

    # ── 재시도 ──────────────────────────────────────────────────────────────
    def test_pending_then_pass(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        rc = self.run_runner([{"step": 1, "ops": []},
                              {"step": 1, "ops": [RED, ["commit", "test: a"], IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertEqual(self.step()["retries"], 1)
        self.assertIn("status", self.prompt(1))           # 직전 실패 사유가 다음 프롬프트에
        self.assertIn("이전 시도 실패", self.prompt(1))

    def test_retries_exhausted(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        err = {"step": 1, "ops": [["status", "error", {"error_message": "못 함"}]]}
        rc = self.run_runner([err] * 6)
        self.assertEqual(rc, 1, self.out)
        self.assertEqual(self.calls_made(), 4)             # 첫 시도 + 재시도 3
        s = self.step()
        self.assertEqual((s["status"], s["retries"]), ("error", 3))
        self.assertIn("failed_at", s)

    def test_blocked_stops(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True},
                    {"step": 2, "name": "b", "status": "pending", "tdd": True}])
        rc = self.run_runner([{"step": 1, "ops": [["status", "blocked", {"blocked_reason": "API 키"}]]}])
        self.assertEqual(rc, 2, self.out)
        self.assertEqual(self.calls_made(), 1)
        self.assertIn("blocked_at", self.step())
        self.assertEqual(self.step(2)["status"], "pending")

    # ── 판정 0: 실행 결과 ────────────────────────────────────────────────────
    def test_is_error_counts_as_failure(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        ok = {"step": 1, "ops": [RED, ["commit", "test: a"], IMPL, ["commit", "feat: a"], DONE]}
        rc = self.run_runner([dict(ok, is_error=True), {"step": 1, "ops": [DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertEqual(self.step()["retries"], 1)
        self.assertIn("실행 실패", self.prompt(1))

    def test_timeout_counts_as_failure(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [["sleep", 3]]},
                              {"step": 1, "ops": [["write", "src/c.txt", "y"], ["commit", "feat: c"], DONE]}],
                             "--timeout", "1")
        self.assertEqual(rc, 0, self.out)
        self.assertIn("타임아웃", self.prompt(1))

    # ── 판정 2~4: RED ───────────────────────────────────────────────────────
    def test_red_missing(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        rc = self.run_runner([{"step": 1, "ops": [RED, IMPL, ["commit", "feat: a 테스트와 함께"], DONE]}] * 4)
        self.assertEqual(rc, 1, self.out)
        self.assertIn("RED", self.step()["error_message"])

    def test_red_catches_nothing(self):
        self.phase([{"step": 1, "name": "b", "status": "pending", "tdd": True}])
        rc = self.run_runner([{"step": 1, "ops": [["write", "tests/b.expect", "x"], ["commit", "test: b"],
                                                  ["write", "src/z.txt", "1"], ["commit", "feat: z"], DONE]}] * 4)
        self.assertEqual(rc, 1, self.out)
        self.assertIn("아무것도 잡지", self.step()["error_message"])
        self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip(), "feat-t1",
                         "RED 확인 뒤 원래 브랜치로 돌아와야 한다")

    def test_test_file_modified_after_red(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        bad = {"step": 1, "ops": [["write", "tests/a.expect", "hello"], ["commit", "test: a"],
                                  ["write", "src/a.txt", "bye"], ["write", "tests/a.expect", "bye"],
                                  ["commit", "feat: a (테스트도 고침)"], DONE]}
        rc = self.run_runner([bad, {"step": 1, "ops": [IMPL, ["commit", "feat: a 다시"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertEqual((self.repo / "tests/a.expect").read_text(), "hello", "테스트 수정은 되돌린다")
        self.assertIn("테스트 파일", self.prompt(1))

    # ── 판정 5·6 ────────────────────────────────────────────────────────────
    def test_completed_without_change(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [DONE]}] * 4)
        self.assertEqual(rc, 1, self.out)
        self.assertIn("변경 없음", self.step()["error_message"])

    def test_verify_fails(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        (self.repo / "tests").mkdir()
        (self.repo / "tests/q.expect").write_text("q")
        git(self.repo, "add", "-A")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "q 테스트")
        rc = self.run_runner([{"step": 1, "ops": [["write", "src/q.txt", "nope"], ["commit", "feat: q"], DONE]}] * 4)
        self.assertEqual(rc, 1, self.out)
        self.assertIn("verify", self.step()["error_message"])

    # ── 시작 전 점검 ────────────────────────────────────────────────────────
    def test_after_not_done_refuses(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}], task="be")
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}], task="t1", after=["be"])
        rc = self.run_runner([{"step": 1, "ops": [DONE]}])
        self.assertEqual(rc, 1, self.out)
        self.assertEqual(self.calls_made(), 0)

    def test_dirty_tree_refuses(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        (self.repo / "src/b.txt").write_text("dirty")
        rc = self.run_runner([{"step": 1, "ops": [DONE]}])
        self.assertEqual(rc, 1, self.out)
        self.assertEqual(self.calls_made(), 0)

    def test_two_steps_carry_summary(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False},
                    {"step": 2, "name": "c", "status": "pending", "tdd": False}])
        rc = self.run_runner([
            {"step": 1, "ops": [["write", "src/a.txt", "1"], ["commit", "feat: a"], DONE]},
            {"step": 2, "ops": [["write", "src/c.txt", "2"], ["commit", "feat: c"], ["status", "completed", {"summary": "c"}]]}])
        self.assertEqual(rc, 0, self.out)
        self.assertIn("a 구현", self.prompt(1))           # 완료 step 의 summary 가 다음 step 프롬프트에


if __name__ == "__main__":
    unittest.main()
