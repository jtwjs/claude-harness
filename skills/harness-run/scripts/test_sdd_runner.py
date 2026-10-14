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

    def test_hook_stamps_not_committed(self):
        # 실가동(10-13)에서 .gitignore 없는 레포의 훅 기록 파일이 feat 커밋으로 하나 더 묶였다
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        rc = self.run_runner([{"step": 1, "ops": [RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"],
                                                  ["write", ".claude/.last-loop-lock", "x"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertNotIn("feat: step 1", self.log())
        self.assertEqual(git(self.repo, "ls-files", ".claude/.last-loop-lock").stdout.strip(), "")

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

    def test_red_violation_recovers_on_retry(self):
        # 리뷰(10-13): 재시도에도 기준이 같아 1회차의 잘못된 RED 커밋이 계속 판정 대상이었다 → 위반 시도는 버리고 다시
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        rc = self.run_runner([{"step": 1, "ops": [RED, IMPL, ["commit", "feat: a 테스트와 함께"], DONE]},
                              {"step": 1, "ops": [RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertNotIn("테스트와 함께", self.log(), "위반한 시도의 커밋은 브랜치에서 빠진다")
        self.assertIn("sdd-discard/t1/step1-try1", git(self.repo, "branch", "--list", "sdd-discard/*").stdout,
                      "버린 시도는 백업 브랜치로 남는다")
        self.assertEqual(len(self.step()["attempts"]), 1)

    def test_red_check_leaves_shared_stash_alone(self):
        # 10-15 실측: stash 목록은 worktree 끼리 공유 — RED 확인 중 다른 worktree 가 stash 를 넣으면 남의 것을 꺼냈다
        wt = self.tmp / "wt2"
        git(self.repo, "worktree", "add", "-q", "-b", "other", str(wt))
        (self.repo / "src/b.txt").write_text("mine")
        git(self.repo, "stash", "push", "-q", "-m", "mine", "--", "src/b.txt")   # 판정 전부터 있던 stash
        (wt / "src/b.txt").write_text("theirs")
        # 테스트가 도는 사이 다른 worktree 세션이 stash 를 넣는다
        self.set_cfg({"verify": {"test": f"sh check.sh; rc=$?; git -C {wt} stash push -q -m theirs -- src/b.txt; exit $rc"},
                      "tdd": {"enabled": True}})
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        rc = self.run_runner([{"step": 1, "ops": [RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertEqual(self.step()["status"], "completed", "진행 중 index.json 내용이 보존된다")
        stashes = git(self.repo, "stash", "list", "--format=%s").stdout
        self.assertIn("mine", stashes)
        self.assertIn("theirs", stashes, "다른 worktree 의 stash 를 꺼내지 않는다")
        self.assertEqual(len(stashes.splitlines()), 2, stashes)
        self.assertEqual((self.repo / "src/b.txt").read_text(), "x")
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "")

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

    def set_cfg(self, cfg):
        (self.repo / ".claude/harness.json").write_text(json.dumps(cfg))
        git(self.repo, "add", "-A")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "cfg")

    def test_branch_pattern(self):
        # #4 — 레포 브랜치 규칙을 따른다
        self.set_cfg({"verify": {"test": "sh check.sh"}, "git": {"branchPattern": "feature/{task}"}})
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip(), "feature/t1")

    def test_branch_pattern_keeps_matching_branch(self):
        # 트랙 worktree 처럼 이미 규칙에 맞는 다른 이름의 브랜치면 새로 만들지 않는다
        self.set_cfg({"verify": {"test": "sh check.sh"}, "git": {"branchPattern": "feature/{task}"}})
        git(self.repo, "checkout", "-q", "-b", "feature/be-reviews")
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip(), "feature/be-reviews")
        self.assertIn("그대로 쓴다", self.out)

    def test_branch_pattern_without_task_refuses(self):
        self.set_cfg({"verify": {"test": "sh check.sh"}, "git": {"branchPattern": "feature/x"}})
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [DONE]}])
        self.assertEqual(rc, 1, self.out)
        self.assertEqual(self.calls_made(), 0)

    # ── #5 판정 6 범위 — 앱별 verify ─────────────────────────────────────────
    def apps_cfg(self, affects=None):
        (self.repo / "web").mkdir(exist_ok=True)
        (self.repo / "server").mkdir(exist_ok=True)
        (self.repo / "web/ok").write_text("x")
        (self.repo / "server/ok").write_text("x")
        cfg = {"verify": {"web": {"lint": "test -f ok"}, "server": {"test": "exit 1"}}}
        if affects:
            cfg["verifyAffects"] = affects
        self.set_cfg(cfg)

    def two_steps(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False},
                    {"step": 2, "name": "b", "status": "pending", "tdd": False}])

    def test_scope_only_changed_app(self):
        self.apps_cfg()
        self.two_steps()
        rc = self.run_runner([{"step": 1, "ops": [["write", "web/a.txt", "1"], ["commit", "feat: a"], DONE]},
                             ] + [{"step": 2, "ops": [["write", "web/b.txt", "1"], ["commit", "feat: b"], DONE]}] * 4)
        self.assertEqual(self.step(1)["status"], "completed", self.out)   # server(실패하는 명령)를 안 돌렸다
        self.assertIn("건너뜀: server", self.out)
        self.assertIn("verify 실패: test", self.step(2).get("error_message", ""), "마지막 step 은 전부 돌려 server 실패를 잡는다")

    def test_scope_affects(self):
        self.apps_cfg({"web/api/*": ["server"]})
        self.two_steps()
        self.run_runner([{"step": 1, "ops": [["write", "web/api/x.ts", "1"], ["commit", "feat: a"], DONE]}] * 4)
        self.assertIn("verify 실패: test", self.step(1).get("error_message", ""), "영향 표에 걸리면 server 도 돈다")

    def test_scope_outside_apps_runs_all(self):
        self.apps_cfg()
        self.two_steps()
        self.run_runner([{"step": 1, "ops": [["write", "package.json", "{}"], ["commit", "feat: a"], DONE]}] * 4)
        self.assertIn("verify 실패: test", self.step(1).get("error_message", ""), "앱 밖 파일이면 전부")

    def test_tdd_without_verify_test_refuses(self):
        (self.repo / ".claude/harness.json").write_text(json.dumps({"verify": {"lint": "true"}}))
        git(self.repo, "add", "-A")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "lint만")
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        rc = self.run_runner([{"step": 1, "ops": [DONE]}])
        self.assertEqual(rc, 1, self.out)
        self.assertEqual(self.calls_made(), 0)
        self.assertIn("verify.test", self.out)

    def test_blocked_survives_exit_error(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "exit": 1, "ops": [["status", "blocked", {"blocked_reason": "키"}]]}])
        self.assertEqual(rc, 2, self.out)
        self.assertEqual(self.calls_made(), 1)

    def test_attempts_history_kept_after_pass(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": []},
                              {"step": 1, "ops": [["write", "src/c.txt", "y"], ["commit", "feat: c"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        a = self.step()["attempts"]
        self.assertEqual(len(a), 1)
        self.assertIn("status", a[0]["error"])

    # ── 멈춘 뒤 재개 ────────────────────────────────────────────────────────
    def test_resume_after_stop(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        bad = {"step": 1, "ops": [["write", "src/half.txt", "wip"], ["status", "error", {"error_message": "모름"}]]}
        good = {"step": 1, "ops": [["write", "src/c.txt", "y"], ["commit", "feat: c"], DONE]}
        calls = [bad] * 4 + [good]
        self.assertEqual(self.run_runner(calls), 1, self.out)
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "",
                         "멈출 때 남은 코드도 커밋한다(재개 때 start 가 거부하지 않게)")
        # 사람이 원인을 적고 pending 으로 되돌린다 — retries 는 그대로
        f = self.repo / "phases/t1/index.json"
        d = json.loads(f.read_text())
        d["steps"][0].update(status="pending", error_message="원인: 설정 파일 경로가 틀림")
        f.write_text(json.dumps(d))
        rc = self.run_runner(calls)
        self.assertEqual(rc, 0, self.out)
        self.assertIn("설정 파일 경로가 틀림", self.prompt(4), "사람이 적은 원인이 지시문에 들어간다")
        self.assertEqual(self.step()["retries"], 3)

    # ── 세션 경로 (start → prompt → 서브에이전트 → judge) ────────────────────
    def session(self, *args):
        p = subprocess.run([sys.executable, str(RUNNER), *args], cwd=self.repo, env=self.env,
                           capture_output=True, text=True)
        self.out = p.stdout + p.stderr
        return p

    def act(self, ops, n=1):
        """서브에이전트 흉내 — 가짜 claude 의 동작을 그대로 쓴다."""
        (self.tmp / "scenario.json").write_text(json.dumps([{"step": n, "ops": ops}] * 99))
        subprocess.run([str(self.tmp / "claude"), "-p", "x"], cwd=self.repo, env=self.env, capture_output=True)

    def test_session_judge_targets_given_step(self):
        # 리뷰(10-13): judge 가 '첫 pending' 을 골라 방금 끝난 step 이 아니라 다음 step 을 판정했다
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True},
                    {"step": 2, "name": "c", "status": "pending", "tdd": False}])
        self.assertEqual(self.session("start", "t1").returncode, 0, self.out)
        p = self.session("prompt", "t1")
        self.assertIn("step 1", p.stderr)
        base = git(self.repo, "rev-parse", "HEAD").stdout.strip()
        self.act([RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1", "--base", base).returncode, 0, self.out)
        self.assertIn("completed_at", self.step(1))
        self.assertIn("started_at", self.step(1))
        self.assertNotIn("retries", self.step(2))
        self.assertIn("chore: update phase index for step 1", self.log())

    def test_session_judge_last_step_is_checked(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        self.session("start", "t1")
        base = git(self.repo, "rev-parse", "HEAD").stdout.strip()
        self.act([DONE])                                  # 변경 없이 completed 만 보고
        self.assertEqual(self.session("judge", "t1", "--step", "1", "--base", base).returncode, 10, self.out)
        self.assertIn("변경 없음", self.step()["last_error"])

    def test_session_judge_requires_step(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        self.assertNotEqual(self.session("judge", "t1", "--base", "HEAD").returncode, 0)


if __name__ == "__main__":
    unittest.main()
