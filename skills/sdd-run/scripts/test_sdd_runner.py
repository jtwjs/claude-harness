#!/usr/bin/env python3
"""sdd_runner 판정 루프 테스트 — 가짜 claude 실행 파일로 끝에서 끝까지 돌린다.

강의 test_execute.py 는 claude 호출을 mock 으로 바꿔 부품만 보고, 판정 루프(재시도·status 미갱신·3회 실패)는
테스트가 0개였다. 여기서는 index.json·git 을 실제로 바꾸는 가짜 claude 로 그 루프를 본다.

실행: python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py
"""
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

# 검사 상한(verify_busy)이 진짜 ps 를 보지 않게 — 다른 세션 검사가 돌면 judge 마다 최대 600초 기다린다(REVIEW 1회차)
_EMPTY_PS = tempfile.NamedTemporaryFile(prefix="verify-ps-", delete=False)
os.environ["CLAUDE_VERIFY_PS"] = _EMPTY_PS.name

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
    Path(os.environ["FAKE_PROMPTS"], f"{n}.argv").write_text(json.dumps(sys.argv[1:-1]))
    Path(os.environ["FAKE_PROMPTS"], f"{n}.env").write_text(os.environ.get("CLAUDE_CODE_DISABLE_AUTO_MEMORY", "<unset>"))
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
        # 헤드리스 step 안에서 돌면 부모에 러너가 넣은 끄는 변수가 있다 — 물려받으면 auto memory 단언이 빈 검증이 된다(#118 리뷰)
        self.env.pop("CLAUDE_CODE_DISABLE_AUTO_MEMORY", None)

    def phase(self, steps, task="t1", after=None, md=None):
        """md: {step 번호: step 파일 본문} — 없으면 옛 꼴(의도 절 없음) 기본 본문."""
        d = self.repo / "phases" / task
        d.mkdir(parents=True, exist_ok=True)
        (d / "index.json").write_text(json.dumps({"project": "p", "phase": task, "docs": "docs/x",
                                                  "after": after or [], "steps": steps}, indent=2))
        for s in steps:
            (d / f"step{s['step']}.md").write_text((md or {}).get(s["step"])
                                                   or f"# Step {s['step']}: {s['name']}\n\n## 작업\n- 구현\n")
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

    def test_red_test_file_failing_lint_restarts_from_tests(self):
        # #9: RED 테스트 파일이 lint 에 걸리면 고치려면 테스트를 건드려야 하고, 건드리면 되돌려져 재시도로 못 고쳤다
        (self.repo / ".claude/harness.json").write_text(json.dumps(
            {"verify": {"test": "sh check.sh", "lint": "sh lint.sh"}, "tdd": {"enabled": True}}))
        (self.repo / "lint.sh").write_text('rc=0; for f in tests/*; do grep -q BAD "$f" && echo "$f: BAD 금지" && rc=1; done; exit $rc\n')
        git(self.repo, "add", "-A")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "lint")
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        dirty = {"step": 1, "ops": [RED, ["write", "tests/a_note.txt", "BAD"], ["commit", "test: a (red)"],
                                    IMPL, ["commit", "feat: a"], DONE]}
        clean = {"step": 1, "ops": [RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"], DONE]}
        rc = self.run_runner([dirty, clean])
        self.assertEqual(rc, 0, self.out)
        self.assertFalse((self.repo / "tests/a_note.txt").exists(), "테스트 파일 탓 시도는 버린다")
        self.assertIn("a_note.txt", self.step()["attempts"][0]["error"])
        self.assertIn("sdd-discard/t1/step1-try1", git(self.repo, "branch", "--list", "sdd-discard/*").stdout)

    def test_retry_prompt_says_tests_already_committed(self):
        # #9: 재시도 지시문이 '테스트 먼저 쓰라'만 반복해 에이전트가 테스트를 다시 쓰다 되돌림을 맞았다
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        wrong = {"step": 1, "ops": [RED, ["commit", "test: a (red)"], ["write", "src/a.txt", "bye"], ["commit", "feat: a"], DONE]}
        rc = self.run_runner([wrong, {"step": 1, "ops": [IMPL, ["commit", "feat: a 고침"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertIn("테스트 커밋이 남아 있다", self.prompt(1))
        self.assertNotIn("테스트 커밋이 남아 있다", self.prompt(0))

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

    def test_measure_step_passes_without_change(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False, "kind": "measure"}])
        rc = self.run_runner([{"step": 1, "ops": [["status", "completed", {"summary": "`sh check.sh` → rc 0 · 3건 일치"}]]}])
        self.assertEqual(rc, 0, self.out)
        self.assertEqual(self.step()["status"], "completed")
        self.assertIn("측정 전용", self.prompt(0))

    def test_measure_step_requires_measurement_summary(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False, "kind": "measure"}])
        rc = self.run_runner([{"step": 1, "ops": [DONE]}] * 4)
        self.assertEqual(rc, 1, self.out)
        self.assertIn("측정 명령", self.step()["error_message"])

    def test_measure_step_with_tdd_refuses(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True, "kind": "measure"}])
        rc = self.run_runner([])
        self.assertEqual(rc, 1, self.out)
        self.assertIn("measure", self.out)
        self.assertEqual(self.calls_made(), 0)

    def test_verify_fails(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        (self.repo / "tests").mkdir()
        (self.repo / "tests/q.expect").write_text("q")
        git(self.repo, "add", "-A")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "q 테스트")
        rc = self.run_runner([{"step": 1, "ops": [["write", "src/q.txt", "nope"], ["commit", "feat: q"], DONE]}] * 4)
        self.assertEqual(rc, 1, self.out)
        self.assertIn("verify", self.step()["error_message"])

    # ── 판정 4'(ADR-024 T1 · T2) — tdd 가 아닌 step 의 기존 테스트 파일 수정 · 삭제 되돌림 ──────
    def guard_turn(self, steps, prompt=True):
        """기존 테스트 tests/q.expect · tests/r.expect(src 와 짝, verify 통과)를 둔 뒤 start → prompt --base. BASE 를 돌려준다.
        prompt=False 면 start 까지만(나눔 모드 prompt 는 호출하는 테스트가 부른다)."""
        r = self.repo
        (r / "tests").mkdir(exist_ok=True)
        for n in ("q", "r"):
            (r / f"tests/{n}.expect").write_text(n)
            (r / f"src/{n}.txt").write_text(n)
        git(r, "add", "-A")
        git(r, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "기존 테스트 q · r")
        self.phase(steps)
        self.assertEqual(self.session("start", "t1").returncode, 0, self.out)
        base = self.head()
        if prompt:
            self.assertEqual(self.session("prompt", "t1", "--base", base).returncode, 0, self.out)
        return base

    def read(self, rel):
        return (self.repo / rel).read_text()

    def test_tdd_false_test_edit_reverted(self):
        # AC-1: 기존 테스트 한 줄을 고치면 BASE 내용으로 돌아가고 파일 이름이 판정 결과에 보인다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.act([["write", "src/q.txt", "qq"], ["write", "tests/q.expect", "qq"], ["commit", "feat: q 바꿈"], DONE])
        p = self.session("judge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 10, self.out)
        self.assertEqual(self.read("tests/q.expect"), "q", "시작 커밋 내용으로 되돌린다")
        self.assertIn("tests/q.expect", self.out, "되돌린 파일 이름이 판정 출력에 보인다")
        self.assertIn("되돌림", self.step()["last_error"])
        self.assertIn("tests/q.expect", self.step()["last_error"])
        self.assertIn("test: step 1 — 테스트 수정 되돌림", self.log(), "판정 4와 같은 꼴로 되돌림 커밋")
        # 재시도 갈래는 원래 index.json 을 커밋하지 않는다 — phases/ 밖만 본다
        self.assertEqual(git(self.repo, "status", "--porcelain", "--", ".", ":(exclude)phases").stdout.strip(), "",
                         "되돌림은 커밋으로 남는다")

    def test_tdd_false_test_delete_restored(self):
        # AC-2: 기존 테스트를 지우면 복원한다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        (self.repo / "tests/q.expect").unlink()
        self.act([["write", "src/c.txt", "c"], ["commit", "feat: c · q 테스트 지움"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertTrue((self.repo / "tests/q.expect").exists(), "지운 테스트를 복원한다")
        self.assertEqual(self.read("tests/q.expect"), "q")
        self.assertIn("tests/q.expect", self.step()["last_error"])

    def test_tdd_false_new_test_file_kept(self):
        # AC-3: 새 테스트 파일만 더하면 통과하고 새 파일이 남는다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.act([["write", "src/n.txt", "n"], ["write", "tests/n.expect", "n"], ["commit", "feat: n"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.read("tests/n.expect"), "n", "새 테스트 파일은 남는다")
        self.assertIn("completed_at", self.step())
        self.assertNotIn("테스트 수정 되돌림", self.log())

    def test_tdd_false_no_test_change_passes(self):
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.act([["write", "src/c.txt", "c"], ["commit", "feat: c"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertNotIn("테스트 수정 되돌림", self.log())
        self.assertEqual((self.read("tests/q.expect"), self.read("tests/r.expect")), ("q", "r"))

    def test_tdd_false_listed_test_edit_passes(self):
        # T1: 계획 칸(test_edits)에 이유와 함께 적힌 기존 테스트 파일은 고쳐도 받는다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                          "test_edits": {"tests/q.expect": "q 문구가 qq 로 바뀐다"}}])
        self.act([["write", "src/q.txt", "qq"], ["write", "tests/q.expect", "qq"], ["commit", "feat: q 바꿈"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.read("tests/q.expect"), "qq")
        self.assertNotIn("테스트 수정 되돌림", self.log())

    def test_tdd_false_listed_and_unlisted_edit(self):
        # 칸에 적힌 파일만 받는다 — 같이 고친 다른 기존 테스트는 되돌리고 이름에도 그것만 나온다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                          "test_edits": {"tests/q.expect": "q 문구가 qq 로 바뀐다"}}])
        self.act([["write", "src/q.txt", "qq"], ["write", "tests/q.expect", "qq"],
                  ["write", "src/r.txt", "rr"], ["write", "tests/r.expect", "rr"], ["commit", "feat: q · r 바꿈"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/q.expect"), "qq", "칸에 적힌 파일은 그대로")
        self.assertEqual(self.read("tests/r.expect"), "r", "칸에 없는 파일은 되돌린다")
        err = self.step()["last_error"]
        self.assertIn("tests/r.expect", err)
        self.assertNotIn("tests/q.expect", err)

    def test_tdd_false_glob_key_matches_literally(self):
        # T4: 칸 키는 글자 그대로 — glob 으로 넓혀 테스트 전부를 열지 않는다.
        # start 는 glob 키를 거르므로(T8) start 뒤 계획을 고쳐 커밋한 경우로 판정 쪽만 본다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}], prompt=False)
        f = self.repo / "phases/t1/index.json"
        d = json.loads(f.read_text())
        d["steps"][0]["test_edits"] = {"tests/*.expect": "모두"}
        f.write_text(json.dumps(d, indent=2))
        git(self.repo, "add", "-f", str(f))
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "계획: glob 키")
        self.assertEqual(self.session("prompt", "t1", "--base", self.head()).returncode, 0, self.out)
        self.act([["write", "src/q.txt", "qq"], ["write", "tests/q.expect", "qq"], ["commit", "feat: q 바꿈"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/q.expect"), "q")

    def test_measure_step_test_edit_reverted(self):
        # 측정 step 도 tdd: false 다 — 기존 테스트를 고치면 되돌린다(verify 실패가 아니라 되돌림 사유로)
        self.guard_turn([{"step": 1, "name": "m", "status": "pending", "tdd": False, "kind": "measure"}])
        self.act([["write", "tests/q.expect", "zz"], ["commit", "chore: q 측정용"],
                  ["status", "completed", {"summary": "`wc -l x` → 1"}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/q.expect"), "q")
        self.assertIn("되돌림", self.step()["last_error"])
        self.assertIn("tests/q.expect", self.step()["last_error"])

    def test_tdd_false_renamed_test_restored(self):
        # 리뷰 🔴: git diff --name-only 는 기본으로 이름 바꾸기를 감지해 옛 경로를 안 보인다 — 옮긴 테스트가 사라진 채 통과했다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        os.rename(self.repo / "tests/q.expect", self.repo / "tests/q2.expect")
        (self.repo / "src/q2.txt").write_text("q")
        self.act([["commit", "feat: q 이름 바꿈"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/q.expect"), "q", "옛 경로를 복원한다")
        self.assertTrue((self.repo / "tests/q2.expect").exists(), "새 경로는 추가라 남는다")
        self.assertIn("tests/q.expect", self.step()["last_error"])

    def test_tdd_false_moved_out_test_restored(self):
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        (self.repo / "docs").mkdir(exist_ok=True)
        os.rename(self.repo / "tests/q.expect", self.repo / "docs/q.old")
        self.act([["commit", "feat: q 테스트를 문서로 옮김"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/q.expect"), "q", "테스트 밖으로 옮겨도 복원한다")

    def test_tdd_false_listed_rename_passes(self):
        # T1: 이름 바꾸기는 옛 경로를 칸에 적으면 받는다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                          "test_edits": {"tests/q.expect": "q 테스트를 q2 로 옮긴다"}}])
        os.rename(self.repo / "tests/q.expect", self.repo / "tests/q2.expect")
        (self.repo / "src/q2.txt").write_text("q")
        self.act([["commit", "feat: q 이름 바꿈"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertFalse((self.repo / "tests/q.expect").exists())
        self.assertEqual(self.read("tests/q2.expect"), "q")

    def test_tdd_false_space_and_nonascii_paths_reverted(self):
        # 리뷰 🟡: 공백은 split 으로 쪼개지고 비ASCII 는 core.quotePath 로 따옴표가 붙어 되돌리지 못했다
        r = self.repo
        (r / "tests").mkdir(exist_ok=True)
        for n in ("my q", "한글"):
            (r / f"tests/{n}.expect").write_text("v")
            (r / f"src/{n}.txt").write_text("v")
        git(r, "add", "-A")
        git(r, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "공백 · 한글 테스트")
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.act([["write", "tests/my q.expect", "w"], ["write", "src/my q.txt", "w"],
                  ["write", "tests/한글.expect", "w"], ["write", "src/한글.txt", "w"], ["commit", "feat: 바꿈"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/my q.expect"), "v")
        self.assertEqual(self.read("tests/한글.expect"), "v")
        self.assertIn("tests/my q.expect", self.step()["last_error"])
        self.assertIn("tests/한글.expect", self.step()["last_error"])

    def test_tdd_false_self_granted_test_edits_ignored(self):
        # 리뷰 🟡 · T6: 구현이 진행 중 index.json 에 자기 허가를 써 넣어도 BASE 계획에 없으면 되돌린다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}], prompt=False)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "src/q.txt", "qq"], ["write", "tests/q.expect", "qq"], ["commit", "feat: q 바꿈"],
                  ["status", "completed", {"summary": "q", "test_edits": {"tests/q.expect": "내가 허가"}}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/q.expect"), "q", "BASE 계획에 없는 칸은 허가가 아니다")
        self.assertIn("tests/q.expect", self.step()["last_error"])

    def test_tdd_false_error_stop_reverts(self):
        # 리뷰 🟡 · T7: 재시도를 다 써 error 로 멈추면 wip 커밋 + BASE 지움 → 재개 때 새 BASE 로 수정이 씻겼다
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        r = self.repo
        (r / "tests").mkdir(exist_ok=True)
        (r / "tests/q.expect").write_text("q")
        (r / "src/q.txt").write_text("q")
        git(r, "add", "-A")
        git(r, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "기존 테스트 q")
        rc = self.run_runner([{"step": 1, "ops": [["write", "tests/q.expect", "qq"],
                                                  ["status", "error", {"error_message": "못 고침"}]]}],
                             "--max-retries", "0")
        self.assertEqual(rc, 1, self.out)
        s = self.step()
        self.assertEqual(s["status"], "error")
        self.assertNotIn("base", s, "멈추면 BASE 를 지운다(지금 동작 그대로)")
        self.assertEqual(self.read("tests/q.expect"), "q", "BASE 를 지우기 전에 되돌린다")
        self.assertIn("테스트 수정 되돌림", s["error_message"])
        self.assertIn("tests/q.expect", s["error_message"])
        hist = git(r, "log", "-p", "--format=%s", "--", "tests/q.expect").stdout
        self.assertIn("+qq", hist, "고친 내용은 기록에 남는다")

    def test_tdd_false_revert_then_retry_passes(self):
        # T2: 되돌림 → 재시도 지시문에 파일 이름 → 구현만 고치면 통과(되돌림 커밋은 BASE 뒤에 있어도 순변화 0)
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        r = self.repo
        (r / "tests").mkdir(exist_ok=True)
        (r / "tests/q.expect").write_text("q")
        (r / "src/q.txt").write_text("q")
        git(r, "add", "-A")
        git(r, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "기존 테스트 q")
        rc = self.run_runner([
            {"step": 1, "ops": [["write", "src/q.txt", "qq"], ["write", "tests/q.expect", "qq"], ["commit", "feat: q"], DONE]},
            {"step": 1, "ops": [["write", "src/q.txt", "q"], ["write", "src/c.txt", "c"], ["commit", "feat: c"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        s = self.step()
        self.assertEqual(s["status"], "completed")
        self.assertIn("attempts", s, "첫 시도는 되돌림으로 실패한다")
        self.assertIn("tests/q.expect", s["attempts"][0]["error"])
        self.assertIn("tests/q.expect", self.prompt(1), "다음 시도 지시문에 되돌린 파일 이름이 붙는다")
        self.assertEqual(self.read("tests/q.expect"), "q")
        self.assertEqual(self.log().count("테스트 수정 되돌림"), 1, "재시도에서 다시 걸리지 않는다")

    # ── 나눔 모드 tdd:false 시작 커밋(ADR-024 T3) · 지시문 ─────────────────────────────
    def test_impl_prompt_pins_base_when_missing(self):
        base = self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}], prompt=False)
        p = self.session("prompt", "t1", "--role", "impl")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertEqual(self.step().get("base"), base, "BASE 가 없으면 구현 차례 prompt 가 그 순간 HEAD 를 고정한다")

    def test_tdd_false_prompt_states_test_rule(self):
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False},
                         {"step": 2, "name": "d", "status": "pending", "tdd": False,
                          "test_edits": {"tests/q.expect": "q 문구가 qq 로 바뀐다"}}], prompt=False)
        p = self.session("prompt", "t1", "--role", "impl")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("기존 테스트 파일은 고치지 않는다", p.stdout)
        self.assertIn("새 테스트 파일은 더해도 된다", p.stdout)
        p = self.session("prompt", "t1", "--step", "2")
        self.assertIn("tests/q.expect", p.stdout, "칸에 적힌 파일을 지시문에 보인다")
        self.assertIn("q 문구가 qq 로 바뀐다", p.stdout, "이유도 같이 보인다")

    def test_impl_prompt_keeps_given_base(self):
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}], prompt=False)
        given = git(self.repo, "rev-parse", "HEAD~1").stdout.strip()
        self.assertEqual(self.session("prompt", "t1", "--role", "impl", "--base", given).returncode, 0, self.out)
        self.assertEqual(self.step().get("base"), given, "--base 를 주면 그 값")
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.assertEqual(self.step().get("base"), given, "이미 고정된 BASE 는 덮지 않는다")

    def test_impl_tdd_false_judge_reverts_without_base_flag(self):
        # #80 관찰: 구현 세션이 --base 없이 돌면 judge 가 「BASE 필요」로 거절했다 — 러너가 고정하면 판정 4'까지 간다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}], prompt=False)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "src/q.txt", "qq"], ["write", "tests/q.expect", "qq"], ["commit", "feat: q 바꿈"], DONE])
        p = self.session("judge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 10, self.out)
        self.assertEqual(self.read("tests/q.expect"), "q")
        self.assertIn("tests/q.expect", self.step()["last_error"])

    def test_impl_base_repinned_after_blocked_fix(self):
        # blocked(red 없음)는 BASE 를 지운다 → 검증이 테스트를 고쳐 커밋하고 pending 으로 되돌리면
        # 다음 구현 차례가 그 커밋 뒤를 BASE 로 잡아 검증의 수정이 되돌려지지 않는다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False}], prompt=False)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "src/c.txt", "c"], ["status", "blocked", {"blocked_reason": "q 테스트 기대값이 틀렸다"}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 2, self.out)
        self.assertNotIn("base", self.step())
        (self.repo / "tests/q.expect").write_text("qq")                       # 검증 세션이 테스트를 고친다
        git(self.repo, "add", "tests/q.expect")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "test: q 기대값 고침")
        fixed = self.head()
        f = self.repo / "phases/t1/index.json"
        d = json.loads(f.read_text())
        d["steps"][0]["status"] = "pending"
        f.write_text(json.dumps(d, indent=2))
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.assertEqual(self.step().get("base"), fixed, "새 BASE 는 검증의 테스트 커밋 뒤")
        self.act([["write", "src/q.txt", "qq"], ["commit", "feat: q 맞춤"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.read("tests/q.expect"), "qq", "검증의 테스트 수정은 되돌리지 않는다")

    # ── blocked 보고 때 되돌림(ADR-024 T5) ─────────────────────────────────────────
    def blocked_impl(self, steps, ops):
        """기존 테스트 q · r → 구현 차례 prompt → ops + blocked 보고 → judge. judge 결과를 돌려준다."""
        self.guard_turn(steps, prompt=False)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act(ops + [["status", "blocked", {"blocked_reason": "q 테스트 기대값이 틀렸다"}]])
        return self.session("judge", "t1", "--step", "1")

    def test_tdd_false_blocked_test_edit_reverted(self):
        # 테스트를 고친 채 blocked 를 보고하면 wip 커밋 뒤 새 BASE 로 수정이 씻긴다 — 기록 전에 되돌린다
        p = self.blocked_impl([{"step": 1, "name": "c", "status": "pending", "tdd": False}],
                              [["write", "src/c.txt", "c"], ["write", "tests/q.expect", "qq"]])
        self.assertEqual(p.returncode, 2, self.out)
        self.assertEqual(self.read("tests/q.expect"), "q", "BASE 내용으로 되돌린다")
        reason = self.step()["blocked_reason"]
        self.assertTrue(reason.startswith("q 테스트 기대값이 틀렸다"), "구현이 적은 사유는 그대로 앞에")
        self.assertIn("테스트 수정 되돌림", reason)
        self.assertIn("tests/q.expect", reason)
        self.assertIn("테스트 수정 되돌림", self.log(), "되돌림은 커밋으로 남는다")
        hist = git(self.repo, "log", "-p", "--format=%s", "--", "tests/q.expect").stdout
        self.assertIn("+qq", hist, "구현이 고친 내용은 기록에 남아 검증이 재판정 때 본다")
        self.assertEqual(self.step()["status"], "blocked")

    def test_tdd_false_blocked_without_test_edit_unchanged(self):
        p = self.blocked_impl([{"step": 1, "name": "c", "status": "pending", "tdd": False}],
                              [["write", "src/c.txt", "c"]])
        self.assertEqual(p.returncode, 2, self.out)
        self.assertEqual(self.step()["blocked_reason"], "q 테스트 기대값이 틀렸다", "되돌릴 것이 없으면 사유 그대로")
        self.assertNotIn("테스트 수정 되돌림", self.log())

    def test_tdd_false_blocked_listed_edit_kept(self):
        p = self.blocked_impl([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                                "test_edits": {"tests/q.expect": "q 문구가 qq 로 바뀐다"}}],
                              [["write", "tests/q.expect", "qq"]])
        self.assertEqual(p.returncode, 2, self.out)
        self.assertEqual(self.read("tests/q.expect"), "qq", "칸에 적힌 파일은 되돌리지 않는다")
        self.assertEqual(self.step()["blocked_reason"], "q 테스트 기대값이 틀렸다")
        self.assertNotIn("테스트 수정 되돌림", self.log())

    def test_tdd_true_blocked_keeps_test_edit(self):
        # tdd: true(red 있음) blocked 는 그대로 — 씻김은 rejudge D1 · D5 가 막는다
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([RED, ["commit", "test: step 1 — a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "tests/a.expect", "bye"], ["status", "blocked", {"blocked_reason": "a 기대값이 틀렸다"}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 2, self.out)
        self.assertEqual(self.read("tests/a.expect"), "bye")
        self.assertEqual(self.step()["blocked_reason"], "a 기대값이 틀렸다")
        self.assertNotIn("테스트 수정 되돌림", self.log())

    # ── 기록 때 test_edits 를 BASE 계획 값으로 맞춤(#116) ─────────────────────────────
    def committed_step(self, n=1):
        d = json.loads(git(self.repo, "show", "HEAD:phases/t1/index.json").stdout)
        return next(s for s in d["steps"] if s["step"] == n)

    def edit_index(self, fn):
        f = self.repo / "phases/t1/index.json"
        d = json.loads(f.read_text())
        fn(d["steps"])
        f.write_text(json.dumps(d, ensure_ascii=False, indent=2))

    def test_align_blocked_self_edits_not_granted_after_resume(self):
        # AC-1 · 재현 A: blocked 멈춤 커밋에 구현이 쓴 칸이 실려 재개(새 BASE) 뒤 허가가 됐다(rc 0)
        p = self.blocked_impl([{"step": 1, "name": "c", "status": "pending", "tdd": False}],
                              [["write", "src/c.txt", "c"],
                               ["status", "pending", {"test_edits": {"tests/q.expect": "내가 허가"}}]])
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn('step 1 test_edits 되돌림: {"tests/q.expect": "내가 허가"} → 없음', self.out)
        self.assertNotIn("test_edits", self.committed_step(), "멈춤 커밋에 구현이 쓴 칸이 실리지 않는다")
        self.assertNotIn("test_edits", self.step())
        self.edit_index(lambda steps: steps[0].update(status="pending"))   # 사람이 재개
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "src/q.txt", "qq"], ["write", "tests/q.expect", "qq"], ["commit", "feat: q 바꿈"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/q.expect"), "q", "재개 뒤에도 구현이 쓴 칸은 허가가 아니다")
        self.assertIn("tests/q.expect", self.step()["last_error"])

    def test_align_error_stop_drops_self_edits(self):
        # AC-2: 재시도를 다 써 error 로 멈출 때도 멈춤 커밋에 구현이 쓴 칸이 실리지 않는다
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        r = self.repo
        (r / "tests").mkdir(exist_ok=True)
        (r / "tests/q.expect").write_text("q")
        (r / "src/q.txt").write_text("q")
        git(r, "add", "-A")
        git(r, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "기존 테스트 q")
        rc = self.run_runner([{"step": 1, "ops": [["status", "error", {"error_message": "못 고침",
                                                                       "test_edits": {"tests/q.expect": "내가 허가"}}]]}],
                             "--max-retries", "0")
        self.assertEqual(rc, 1, self.out)
        self.assertEqual(self.step()["status"], "error")
        self.assertIn('step 1 test_edits 되돌림: {"tests/q.expect": "내가 허가"} → 없음', self.out)
        self.assertNotIn("test_edits", self.committed_step())

    def test_align_completed_next_step_self_edits_not_granted(self):
        # AC-3 · 재현 B: step 1 구현이 step 2 칸을 써 넣고 완료 → 완료 커밋을 타고 step 2 BASE 의 허가가 됐다(rc 0)
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False},
                         {"step": 2, "name": "d", "status": "pending", "tdd": False}], prompt=False)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "src/c.txt", "c"], ["commit", "feat: c"], DONE])
        self.edit_index(lambda steps: steps[1].update(test_edits={"tests/q.expect": "내가 허가"}))
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertIn('step 2 test_edits 되돌림: {"tests/q.expect": "내가 허가"} → 없음', self.out)
        self.assertNotIn("test_edits", self.committed_step(2), "완료 커밋에 뒤 step 칸이 실리지 않는다")
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "src/q.txt", "qq"], ["write", "tests/q.expect", "qq"], ["commit", "feat: q 바꿈"], DONE], n=2)
        self.assertEqual(self.session("judge", "t1", "--step", "2").returncode, 10, self.out)
        self.assertEqual(self.read("tests/q.expect"), "q")

    def test_align_planned_edits_kept_and_reason_restored(self):
        # AC-4: 계획에 있던 칸은 남고, 구현이 바꾼 이유 글은 계획 글로 돌아간다. 안 바뀐 step 은 줄이 없다
        plan1 = {"tests/q.expect": "q 문구가 qq 로 바뀐다"}
        plan2 = {"tests/r.expect": "r 문구가 rr 로 바뀐다"}
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False, "test_edits": plan1},
                         {"step": 2, "name": "d", "status": "pending", "tdd": False, "test_edits": plan2}], prompt=False)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "src/q.txt", "qq"], ["write", "tests/q.expect", "qq"], ["commit", "feat: q 바꿈"],
                  ["status", "completed", {"summary": "q", "test_edits": {"tests/q.expect": "다른 이유"}}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.read("tests/q.expect"), "qq", "계획 칸 파일은 그대로 허가")
        self.assertEqual(self.committed_step(1)["test_edits"], plan1)
        self.assertEqual(self.committed_step(2)["test_edits"], plan2)
        self.assertIn("step 1 test_edits 되돌림", self.out)
        self.assertNotIn("step 2 test_edits 되돌림", self.out, "안 바뀐 칸은 줄을 내지 않는다")

    def test_align_no_plan_in_base_drops_edits(self):
        # AC-5: BASE 커밋에 index.json 이 없으면 계획 없음 — 판정 4'와 같은 답으로 칸을 빼고 전 값을 한 줄로 남긴다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                          "test_edits": {"tests/q.expect": "q 문구가 qq 로 바뀐다"}}], prompt=False)
        before_plan = git(self.repo, "rev-parse", "HEAD~1").stdout.strip()   # 기존 테스트 커밋 — 계획 커밋 앞
        self.assertNotEqual(git(self.repo, "cat-file", "-e", f"{before_plan}:phases/t1/index.json").returncode, 0)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl", "--base", before_plan).returncode, 0, self.out)
        self.act([["write", "src/c.txt", "c"], ["commit", "feat: c"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertIn('step 1 test_edits 되돌림: {"tests/q.expect": "q 문구가 qq 로 바뀐다"} → 없음', self.out)
        self.assertNotIn("test_edits", self.committed_step())

    def test_align_other_session_later_edit_reverted_with_notice(self):
        # AC-7 · 결정 2에서 감수한 경우: BASE 뒤 다른 세션이 뒤 step 칸을 고쳐 커밋하면 완료 기록이 되돌리고 한 줄을 낸다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False},
                         {"step": 2, "name": "d", "status": "pending", "tdd": False}], prompt=False)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.edit_index(lambda steps: steps[1].update(test_edits={"tests/r.expect": "다른 세션이 더함"}))
        git(self.repo, "add", "phases/t1/index.json")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "chore: 다른 세션이 계획 고침")
        self.act([["write", "src/c.txt", "c"], ["commit", "feat: c"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertIn('step 2 test_edits 되돌림: {"tests/r.expect": "다른 세션이 더함"} → 없음', self.out)
        self.assertNotIn("test_edits", self.committed_step(2), "막는 쪽 실패 — 계획 값으로 돌아간다")

    def test_start_refuses_uncommitted_plan_edits(self):
        # AC-9 · REVIEW 1회차 🟡: 계획을 커밋 안 하고 첫 실행하면 완료 기록이 뒤 step 의 정당한 칸을 지웠다 — 지우기 전에 멈춘다
        r = self.repo
        (r / "tests").mkdir(exist_ok=True)
        (r / "tests/q.expect").write_text("q")
        (r / "src/q.txt").write_text("q")
        git(r, "add", "-A")
        git(r, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "기존 테스트 q")
        d = r / "phases/t1"
        d.mkdir(parents=True)
        (d / "index.json").write_text(json.dumps({"project": "p", "phase": "t1", "docs": "docs/x", "after": [], "steps": [
            {"step": 1, "name": "c", "status": "pending", "tdd": False},
            {"step": 2, "name": "d", "status": "pending", "tdd": False,
             "test_edits": {"tests/q.expect": "q 문구가 qq 로 바뀐다"}}]}, ensure_ascii=False, indent=2))
        for n, name in ((1, "c"), (2, "d")):
            (d / f"step{n}.md").write_text(f"# Step {n}: {name}\n\n## 작업\n- 구현\n")
        before = (git(r, "branch", "--show-current").stdout.strip(), self.index_bytes())
        rc = self.session("start", "t1").returncode
        after = (git(r, "branch", "--show-current").stdout.strip(), self.index_bytes())
        self.assertEqual(rc, 1, self.out)
        self.assertIn("step 2 test_edits 가 커밋된 계획과 다르다 — index.json 을 커밋한 뒤 실행", self.out)
        self.assertEqual(before, after, "브랜치 · index.json 을 바꾸지 않는다")

    def test_start_refuses_uncommitted_edit_on_resume(self):
        # AC-9: 멈춘 뒤 커밋 없이 칸을 더하고 재개하면 조용히 무시되던 것을 멈춘다 — 커밋하면 지나간다
        p = self.blocked_impl([{"step": 1, "name": "c", "status": "pending", "tdd": False}],
                              [["write", "src/c.txt", "c"]])
        self.assertEqual(p.returncode, 2, self.out)
        self.edit_index(lambda steps: steps[0].update(status="pending",
                                                      test_edits={"tests/q.expect": "사람이 더함"}))
        self.assertEqual(self.session("start", "t1").returncode, 1, self.out)
        self.assertIn("step 1 test_edits 가 커밋된 계획과 다르다 — index.json 을 커밋한 뒤 실행", self.out)
        git(self.repo, "add", "phases/t1/index.json")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "chore: 사람이 칸을 더함")
        self.assertEqual(self.session("start", "t1").returncode, 0, self.out)

    def test_align_null_edits_no_notice(self):
        # AC-11 · REVIEW 1회차 🟢: null 칸은 계획에도 칸이 없으면 같은 값 — 「없음 → 없음」 줄을 내지 않는다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False, "test_edits": None}], prompt=False)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "src/c.txt", "c"], ["commit", "feat: c"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertNotIn("test_edits 되돌림", self.out)

    def test_align_renumbered_step_does_not_inherit_edits(self):
        # AC-10 · REVIEW 1회차 🟡: 커밋 없이 step 을 끼워 번호를 바꾸면 번호로만 맞춰 옛 step 2 칸이 새 step 2 로 옮겨 붙었다
        self.guard_turn([{"step": 1, "name": "c", "status": "pending", "tdd": False},
                         {"step": 2, "name": "d", "status": "pending", "tdd": False,
                          "test_edits": {"tests/q.expect": "d 가 q 문구를 바꾼다"}}], prompt=False)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)

        def renumber(steps):
            d = dict(steps[1], step=3)
            steps[1:] = [{"step": 2, "name": "x", "status": "pending", "tdd": False}, d]
        self.edit_index(renumber)
        (self.repo / "phases/t1/step3.md").write_text("# Step 3: d\n\n## 작업\n- 구현\n")
        self.act([["write", "src/c.txt", "c"], ["commit", "feat: c"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        x = self.committed_step(2)
        self.assertEqual(x["name"], "x")
        self.assertNotIn("test_edits", x, "이름이 다른 step 은 계획 칸을 받지 않는다")
        self.assertNotIn("test_edits", self.committed_step(3), "계획에 없는 번호 + 이름 — 막는 쪽으로 뺀다")

    # ── test_edits 칸 꼴 검사(ADR-024 T4) — start 가 첫 step 전에 거른다 ─────────────────
    def start_with(self, steps):
        """phase 를 두고 start. (종료 코드, 앞뒤 (브랜치, index 바이트) 같은가)."""
        self.phase(steps)
        before = (git(self.repo, "branch", "--show-current").stdout.strip(), self.index_bytes())
        rc = self.session("start", "t1").returncode
        after = (git(self.repo, "branch", "--show-current").stdout.strip(), self.index_bytes())
        return rc, before == after

    def test_start_test_edits_empty_reason_refuses(self):
        rc, same = self.start_with([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                                     "test_edits": {"tests/q.expect": "  "}}])
        self.assertEqual(rc, 1, self.out)
        self.assertIn("test_edits", self.out)
        self.assertIn("step 1", self.out, "어느 step 인지 보인다")
        self.assertTrue(same, "거절하면 브랜치 · index 를 바꾸지 않는다")

    def test_start_test_edits_valid_passes(self):
        rc, _ = self.start_with([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                                  "test_edits": {"tests/q.expect": "q 문구가 qq 로 바뀐다"}}])
        self.assertEqual(rc, 0, self.out)

    def test_start_test_edits_not_object_refuses(self):
        rc, same = self.start_with([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                                     "test_edits": ["tests/q.expect"]}])
        self.assertEqual(rc, 1, self.out)
        self.assertIn("test_edits", self.out)
        self.assertTrue(same)
        rc, same = self.start_with([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                                     "test_edits": {"tests/q.expect": 3}}])
        self.assertEqual(rc, 1, "이유는 문자열이어야 한다 — " + self.out)
        self.assertTrue(same)

    def test_start_test_edits_non_test_path_refuses(self):
        rc, same = self.start_with([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                                     "test_edits": {"src/q.txt": "구현 파일"}}])
        self.assertEqual(rc, 1, self.out)
        self.assertIn("src/q.txt", self.out)
        self.assertTrue(same)
        rc, same = self.start_with([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                                     "test_edits": {"phases/t1/tests/x.expect": "phase 기록"}}])
        self.assertEqual(rc, 1, "phases/ 아래는 테스트 파일로 보지 않는다 — " + self.out)
        self.assertTrue(same)

    def test_start_test_edits_glob_key_refuses(self):
        # T8: 글자 그대로 비교라 glob · ./ 키는 아무것도 열지 못한다 — 계획 실수를 첫 step 전에 알린다
        for key in ("tests/*.expect", "tests/q?.expect", "tests/[q].expect", "./tests/q.expect"):
            rc, same = self.start_with([{"step": 1, "name": "c", "status": "pending", "tdd": False,
                                         "test_edits": {key: "이유"}}])
            self.assertEqual(rc, 1, f"{key} — {self.out}")
            self.assertIn(key, self.out)
            self.assertTrue(same)

    def test_start_test_edits_on_tdd_step_refuses(self):
        # 테스트 먼저 step 의 판정 4 는 그대로다(설계서 결정) — 그 step 에 칸을 두면 열 수 없는 문이라 계획 실수다
        rc, same = self.start_with([{"step": 1, "name": "a", "status": "pending", "tdd": True,
                                     "test_edits": {"tests/a.expect": "a 기대값"}}])
        self.assertEqual(rc, 1, self.out)
        self.assertIn("test_edits", self.out)
        self.assertTrue(same)

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

    # ── step 명령($step) — step 마다 영향받은 테스트만, 전체는 phase 마지막·재개·앱 밖 ──────
    def step_cfg(self, single=False):
        """full 명령은 'full', step 명령은 'step {since}' 를 tmp/runs.log 에 적는다. server 전체는 실패한다."""
        log = self.tmp / "runs.log"
        if single:
            cfg = {"verify": {"test": f"echo full >> {log}; sh check.sh",
                              "$step": {"test": f"echo step {{since}} >> {log}; sh check.sh"}}}
        else:
            for d in ("web", "server"):
                (self.repo / d).mkdir(exist_ok=True)
                (self.repo / d / "ok").write_text("x")
            cfg = {"verify": {"web": {"test": "true"},
                              "server": {"test": f"echo full >> {log}; exit 1",
                                         "$step": {"test": f"echo step {{since}} >> {log}"}}}}
        self.set_cfg(cfg)
        return log

    def runs(self, log):
        return log.read_text().split("\n")[:-1] if log.exists() else []

    def test_step_cmd_used_mid_phase_full_on_last(self):
        log = self.step_cfg()
        self.two_steps()
        base = git(self.repo, "rev-parse", "HEAD").stdout.strip()
        rc = self.run_runner([{"step": 1, "ops": [["write", "server/a.txt", "1"], ["commit", "feat: a"], DONE]}]
                             + [{"step": 2, "ops": [["write", "server/b.txt", "1"], ["commit", "feat: b"], DONE]}] * 4)
        self.assertEqual(self.step(1)["status"], "completed", self.out)   # 전체(exit 1) 대신 step 명령
        self.assertEqual(self.runs(log)[0], f"step {base}", "{since} = 그 step 시작 커밋")
        self.assertIn("step 명령: server test", self.out)
        self.assertIn("full", self.runs(log), "마지막 step 은 전체 명령")
        self.assertEqual(rc, 2, "전체만 깨지고 이 step 범위는 통과 → 앞 step 탓 의심, 재시도 없이 사람에게")
        self.assertEqual(self.calls_made(), 2)
        s2 = self.step(2)
        self.assertEqual(s2["status"], "blocked")
        self.assertIn("앞 step", s2["blocked_reason"])
        self.assertIn("server test", s2["blocked_reason"])

    def test_last_step_own_scope_fails_retries(self):
        log = self.tmp / "runs.log"
        (self.repo / "server").mkdir()
        (self.repo / "server/ok").write_text("x")
        self.set_cfg({"verify": {"server": {"test": "exit 1", "$step": {"test": "! test -f bad.txt"}}}})
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [["write", "server/bad.txt", "1"], ["commit", "feat: a"], DONE]}] * 4)
        self.assertEqual(rc, 1, self.out)
        self.assertEqual(self.calls_made(), 4, "이 step 범위에서도 깨지면 그 step 탓 — 지금처럼 재시도")
        self.assertIn("이 step 범위에서도", self.step()["error_message"])

    def test_last_step_without_step_cmd_retries(self):
        self.apps_cfg()
        self.two_steps()
        rc = self.run_runner([{"step": 1, "ops": [["write", "web/a.txt", "1"], ["commit", "feat: a"], DONE]}]
                             + [{"step": 2, "ops": [["write", "web/b.txt", "1"], ["commit", "feat: b"], DONE]}] * 4)
        self.assertEqual(rc, 1, "step 명령이 없으면 누구 탓인지 못 가려 지금처럼 재시도")

    def test_step_cmd_not_run_outside_apps(self):
        log = self.step_cfg()
        self.two_steps()
        self.run_runner([{"step": 1, "ops": [["write", "README.md", "x"], ["write", "server/a.txt", "1"],
                                             ["commit", "feat: a"], DONE]}] * 4)
        self.assertNotIn("step", " ".join(self.runs(log)), "앱 밖 파일이면 step 명령이 아니라 전체")
        self.assertIn("verify 실패: test", self.step(1).get("error_message", ""))

    def test_resumed_step_runs_full(self):
        log = self.step_cfg()
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False, "failed_at": "2026-01-01T00:00:00+0900",
                     "error_message": "원인: x"},
                    {"step": 2, "name": "b", "status": "pending", "tdd": False}])
        self.run_runner([{"step": 1, "ops": [["write", "server/a.txt", "1"], ["commit", "feat: a"], DONE]}] * 4)
        self.assertIn("재개", self.out)
        self.assertNotIn("step", " ".join(self.runs(log)))

    def test_measure_last_step_runs_full_verify(self):
        self.step_cfg()
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False},
                    {"step": 2, "name": "m", "status": "pending", "tdd": False, "kind": "measure"}])
        rc = self.run_runner([{"step": 1, "ops": [["write", "server/a.txt", "1"], ["commit", "feat: a"], DONE]}]
                             + [{"step": 2, "ops": [["status", "completed", {"summary": "`wc -l a` → 1"}]]}] * 4)
        self.assertEqual(rc, 2, self.out)
        self.assertEqual(self.calls_made(), 2, "측정 step 은 코드를 안 바꿨으니 전체 실패는 앞 step 탓 — 재시도 없음")
        self.assertIn("verify 실패: test", self.step(2).get("blocked_reason", ""),
                      "마지막 step 이 측정이어도 phase 전체 verify 는 한 번 돈다")

    def test_red_check_uses_step_cmd(self):
        log = self.step_cfg(single=True)
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True},
                    {"step": 2, "name": "b", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"], DONE]},
                              {"step": 2, "ops": [["write", "src/z.txt", "z"], ["commit", "feat: z"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        runs = self.runs(log)
        self.assertTrue(runs[0].startswith("step ") and runs[1].startswith("step "), runs)   # RED 확인 · judge
        self.assertEqual(runs[-1], "full", "마지막 step 은 전체")

    def test_prompt_shows_step_cmd_with_since(self):
        self.step_cfg()
        self.two_steps()
        base = git(self.repo, "rev-parse", "HEAD").stdout.strip()
        self.run_runner([{"step": 1, "ops": [["write", "server/a.txt", "1"], ["commit", "feat: a"], DONE]},
                         {"step": 2, "ops": [["write", "server/b.txt", "1"], ["commit", "feat: b"], DONE]}])
        self.assertIn(f"step {base}", self.prompt(0), "서브에이전트 자체 확인도 step 명령")
        self.assertIn("echo full", self.prompt(1), "마지막 step 지시문은 전체 명령")

    def test_session_prompt_takes_base(self):
        self.step_cfg()
        self.two_steps()
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--base", "abc123")
        self.assertIn("step abc123", p.stdout)

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

    def test_error_tail_in_last_error_and_retry_prompt(self):
        # #12: 사유가 "verify 실패: test" 한 줄뿐이라 다음 시도가 무엇이 깨졌는지 모른 채 같은 실패를 되풀이했다
        (self.repo / "loud.sh").write_text(textwrap.dedent('''\
            #!/bin/sh
            [ -f src/ok.txt ] && exit 0
            echo "  🔴 early_case — 기대와 다름"
            i=1; while [ $i -le 60 ]; do printf 'row-%03d\\n' $i; i=$((i+1)); done
            echo "끝 줄 표식" >&2
            exit 1
        '''))
        (self.repo / ".claude/harness.json").write_text(json.dumps({"verify": {"test": "sh loud.sh"}}))
        git(self.repo, "add", "-A")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "loud verify")
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [["write", "src/x.txt", "x"], ["commit", "feat: x"], DONE]},
                              {"step": 1, "ops": [["write", "src/ok.txt", "ok"], ["commit", "feat: ok"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        err = self.step()["attempts"][0]["error"]
        self.assertIn("verify 실패: test", err)
        self.assertIn("row-060", err, "출력 끝 줄이 붙는다")
        self.assertIn("끝 줄 표식", err, "stderr 도 붙는다")
        self.assertNotIn("row-001", err, "40줄 밖 일반 줄은 붙지 않는다")
        self.assertIn("early_case", err, "40줄 밖이어도 실패한 테스트 이름 줄은 앞에 모은다")
        self.assertIn(err, self.prompt(1), "다음 지시문 「이전 시도 실패」에 같은 글이 그대로 붙는다")

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

    def test_session_base_pinned_across_retry(self):
        # #11: BASE 를 모델 기억에 맡기면 재시도 때 HEAD 로 다시 잡아 이전 시도의 RED 커밋이 BASE 앞으로 밀린다
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.session("start", "t1")
        base = git(self.repo, "rev-parse", "HEAD").stdout.strip()
        self.session("prompt", "t1", "--base", base)
        self.assertEqual(self.step().get("base"), base, "prompt --base 가 BASE 를 index.json 에 적는다")
        self.act([RED, ["commit", "test: a (red)"], ["write", "src/a.txt", "bye"], ["commit", "feat: a"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        head = git(self.repo, "rev-parse", "HEAD").stdout.strip()
        self.session("prompt", "t1", "--base", head)        # 모델이 재시도에서 HEAD 로 다시 잡아도
        self.assertEqual(self.step().get("base"), base, "재시도에서 고정한 BASE 를 덮지 않는다")
        self.act([IMPL, ["commit", "feat: a 고침"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertNotIn("base", self.step(), "끝난 step 의 BASE 는 지운다")

    # ── --defer-full-test (#13) — 부하 중 전체 test 를 릴리스 전으로 미룬다 ──────────────
    DEFER_MARK = "전체 test 미룸 — 릴리스 전 한 번"

    def test_defer_full_last_step_runs_step_cmd(self):
        log = self.step_cfg()
        self.two_steps()
        rc = self.run_runner([{"step": 1, "ops": [["write", "server/a.txt", "1"], ["commit", "feat: a"], DONE]},
                              {"step": 2, "ops": [["write", "server/b.txt", "1"], ["commit", "feat: b"], DONE]}],
                             "--defer-full-test")
        self.assertEqual(rc, 0, self.out)
        self.assertNotIn("full", self.runs(log), "마지막 step 도 step 명령만")
        self.assertIn("echo step", self.prompt(1), "지시문 검증 명령도 step 명령")
        self.assertNotIn("echo full", self.prompt(1))
        self.assertTrue(self.step(2)["summary"].endswith(self.DEFER_MARK), self.step(2)["summary"])
        self.assertNotIn(self.DEFER_MARK, self.step(1)["summary"], "줄이지 않은 step 에는 붙이지 않는다")

    def test_defer_full_absent_last_step_runs_full(self):
        log = self.step_cfg(single=True)
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertEqual(self.runs(log), ["full"], "옵션이 없으면 지금처럼 마지막 step 은 전체")
        self.assertNotIn(self.DEFER_MARK, self.step()["summary"])

    def test_defer_full_without_step_cmd_runs_full(self):
        log = self.tmp / "runs.log"
        self.set_cfg({"verify": {"test": f"echo full >> {log}; sh check.sh"}})
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}], "--defer-full-test")
        self.assertEqual(rc, 0, self.out)
        self.assertEqual(self.runs(log), ["full"], "$step 이 없으면 줄일 범위가 없어 전체")
        self.assertNotIn(self.DEFER_MARK, self.step()["summary"], "줄이지 않았으면 표시도 없다")

    def test_defer_full_outside_apps_runs_step_cmd(self):
        log = self.step_cfg()
        self.two_steps()
        self.run_runner([{"step": 1, "ops": [["write", "README.md", "x"], ["write", "server/a.txt", "1"],
                                             ["commit", "feat: a"], DONE]}], "--defer-full-test")
        self.assertEqual(self.step(1)["status"], "completed", self.out)
        self.assertNotIn("full", self.runs(log), "앱 밖 파일이어도 step 명령만")
        self.assertIn("step", " ".join(self.runs(log)))
        self.assertTrue(self.step(1)["summary"].endswith(self.DEFER_MARK), self.step(1)["summary"])

    def test_defer_full_resumed_step_runs_step_cmd(self):
        log = self.step_cfg()
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False, "failed_at": "2026-01-01T00:00:00+0900",
                     "error_message": "원인: x"},
                    {"step": 2, "name": "b", "status": "pending", "tdd": False}])
        self.run_runner([{"step": 1, "ops": [["write", "server/a.txt", "1"], ["commit", "feat: a"], DONE]}],
                        "--defer-full-test")
        self.assertEqual(self.step(1)["status"], "completed", self.out)
        self.assertNotIn("full", self.runs(log), "재개 step 도 step 명령만")
        self.assertTrue(self.step(1)["summary"].endswith(self.DEFER_MARK), self.step(1)["summary"])

    def test_defer_full_session_judge(self):
        log = self.step_cfg(single=True)
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        self.session("start", "t1")
        base = git(self.repo, "rev-parse", "HEAD").stdout.strip()
        self.act([IMPL, ["commit", "feat: a"], DONE])
        p = self.session("judge", "t1", "--step", "1", "--base", base, "--defer-full-test")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertEqual(self.runs(log), [f"step {base}"], "judge 도 옵션을 받아 마지막 step 을 step 명령으로")
        self.assertTrue(self.step()["summary"].endswith(self.DEFER_MARK), self.step()["summary"])

    # ── 나눔 모드(ADR-019 A4 · E2 · E12) — 검증 세션이 테스트 · 구현 세션이 구현 ──────────────
    def index_bytes(self):
        return (self.repo / "phases/t1/index.json").read_bytes()

    def head(self):
        return git(self.repo, "rev-parse", "HEAD").stdout.strip()

    def red_turn(self, steps, cfg=None):
        """start → prompt --role test --base HEAD. (BASE, 지시문)"""
        if cfg:
            self.set_cfg(cfg)
        self.phase(steps)
        self.assertEqual(self.session("start", "t1").returncode, 0, self.out)
        base = self.head()
        p = self.session("prompt", "t1", "--role", "test", "--base", base)
        self.assertEqual(p.returncode, 0, self.out)
        return base, p.stdout

    def test_red_judge_test_prompt_writes_tests_only(self):
        _, text = self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.assertIn("실패하는 테스트", text)
        self.assertIn("test: step 1 — a (red)", text)
        self.assertIn("구현 파일을 만들지 않는다", text)
        self.assertNotIn("② 구현한다", text, "검증 차례 지시문은 구현을 시키지 않는다")

    def test_red_judge_pass_records_red(self):
        base, _ = self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([RED, ["commit", "test: step 1 — a (red)"]])
        red = self.head()
        p = self.session("judge", "t1", "--red", "--step", "1")
        self.assertEqual(p.returncode, 0, self.out)
        s = self.step()
        self.assertEqual(s.get("red"), red, "통과하면 테스트 커밋 sha 를 red 에 적는다")
        self.assertEqual(s["status"], "pending", "구현은 아직 — step 은 끝나지 않는다")
        self.assertEqual(s.get("base"), base, "BASE 는 구현 쪽이 그대로 쓴다")
        self.assertIn("chore: update phase index for step 1", self.log())
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "", "index 를 커밋한다")

    def test_red_judge_red_fail_discards_attempt(self):
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([RED, IMPL, ["commit", "test: a 구현과 함께"]])
        p = self.session("judge", "t1", "--red", "--step", "1")
        self.assertEqual(p.returncode, 10, self.out)
        self.assertNotIn("구현과 함께", self.log(), "RED 위반 시도의 커밋은 버린다")
        self.assertIn("sdd-discard/t1/step1-try1", git(self.repo, "branch", "--list", "sdd-discard/*").stdout)
        s = self.step()
        self.assertNotIn("red", s)
        self.assertIn("RED", s["last_error"])
        self.assertEqual(s["retries"], 1)

    def test_red_judge_red_catching_nothing_discards(self):
        self.red_turn([{"step": 1, "name": "b", "status": "pending", "tdd": True}])
        self.act([["write", "tests/b.expect", "x"], ["commit", "test: b (red)"]])   # src/b.txt 가 이미 x — 통과한다
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 10, self.out)
        self.assertIn("아무것도 잡지", self.step()["last_error"])
        self.assertNotIn("red", self.step())

    def test_red_judge_refuses_out_of_turn(self):
        steps = [{"step": 1, "name": "a", "status": "pending", "tdd": True}]
        self.phase(steps)
        self.session("start", "t1")
        before = self.index_bytes()
        p = self.session("prompt", "t1", "--role", "impl")
        self.assertNotEqual(p.returncode, 0, "red 없는 tdd step 은 검증 차례")
        self.assertIn("지금은 검증 차례", self.out)
        self.assertEqual(self.index_bytes(), before, "차례가 아니면 아무것도 바꾸지 않는다")
        # 검증이 red 를 적은 뒤에는 구현 차례 — 검증 쪽 호출을 거부한다
        base = self.head()
        self.session("prompt", "t1", "--role", "test", "--base", base)
        self.act([RED, ["commit", "test: a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        head, before = self.head(), self.index_bytes()
        p = self.session("prompt", "t1", "--role", "test")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("지금은 구현 차례", self.out)
        p = self.session("judge", "t1", "--red", "--step", "1")
        self.assertNotEqual(p.returncode, 0, "judge --red 가 구현 중인 트리를 치지 않는다")
        self.assertIn("지금은 구현 차례", self.out)
        self.assertEqual((self.head(), self.index_bytes()), (head, before))

    def test_red_judge_tdd_false_is_impl_turn(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--role", "test")
        self.assertNotEqual(p.returncode, 0, "쓸 테스트가 없는 step 은 구현 차례")
        self.assertIn("지금은 구현 차례", self.out)
        p = self.session("prompt", "t1", "--role", "impl", "--base", self.head())
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("feat: step 1 — c", p.stdout)

    def test_red_judge_measure_is_test_turn(self):
        self.phase([{"step": 1, "name": "m", "status": "pending", "tdd": False, "kind": "measure"}])
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--role", "impl")
        self.assertNotEqual(p.returncode, 0, "측정 · 대조는 검증 몫")
        self.assertIn("지금은 검증 차례", self.out)
        base = self.head()
        p = self.session("prompt", "t1", "--role", "test", "--base", base)
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("측정 전용", p.stdout, "measure 지시문은 지금 그대로")
        self.act([["status", "completed", {"summary": "`wc -l x` → 1"}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)

    def test_red_judge_impl_skips_step_without_red(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True},
                    {"step": 2, "name": "c", "status": "pending", "tdd": False}])
        self.session("start", "t1")
        before = self.index_bytes()
        p = self.session("prompt", "t1", "--role", "impl")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("지금은 검증 차례", self.out)
        self.assertNotIn("Step 2", p.stdout, "red 없는 step 을 건너뛰어 뒤 step 을 집지 않는다")
        self.assertEqual(self.index_bytes(), before)

    def test_red_judge_impl_judge_skips_red_checks(self):
        log = self.tmp / "runs.log"
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}],
                      cfg={"verify": {"test": f"echo run >> {log}; sh check.sh"}, "tdd": {"enabled": True}})
        self.act([RED, ["commit", "test: a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        self.assertEqual(len(self.runs(log)), 1, "judge --red 는 RED 시점 test 를 한 번")
        p = self.session("prompt", "t1", "--role", "impl")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("테스트는 이미 있다", p.stdout)
        self.assertIn("blocked", p.stdout)
        self.act([IMPL, ["commit", "feat: a"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.step()["status"], "completed")
        self.assertEqual(len(self.runs(log)), 2, "구현 쪽 judge 는 판정 3(RED 시점 test)을 다시 돌지 않는다")

    def test_red_judge_impl_reverts_test_edit_keeps_red(self):
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([RED, ["commit", "test: a (red)"]])
        self.session("judge", "t1", "--red", "--step", "1")
        red = self.step()["red"]
        self.session("prompt", "t1", "--role", "impl")
        self.act([["write", "src/a.txt", "bye"], ["write", "tests/a.expect", "bye"], ["commit", "feat: a (테스트도 고침)"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual((self.repo / "tests/a.expect").read_text(), "hello", "테스트 수정은 되돌린다(판정 4)")
        self.assertIn("테스트 파일", self.step()["last_error"])
        self.assertEqual(self.step()["red"], red, "구현 쪽 재시도는 red 를 지우지 않는다")
        p = self.session("prompt", "t1", "--role", "impl")
        self.assertEqual(p.returncode, 0, "재시도도 구현 차례")
        self.act([IMPL, ["commit", "feat: a 다시"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)

    # ── 판정 4 경로 읽기(#102) — red 뒤 이름 바꾸기 · 공백 · 비ASCII 경로도 되돌린다 ──────────────
    def impl_after_red(self, pre=()):
        """pre: BASE 에 미리 둘 기존 테스트 이름(tests/<이름>.expect · src/<이름>.txt 짝, 내용 v). 나눔 모드 red(tests/a.expect)
        기록 → 구현 차례까지. red sha 를 돌려준다. 비ASCII 경로를 red 커밋에 넣으면 red 확인이 먼저 거절해서(#113) BASE 에 둔다."""
        r = self.repo
        if pre:
            (r / "tests").mkdir(exist_ok=True)
            for n in pre:
                (r / f"tests/{n}.expect").write_text("v")
                (r / f"src/{n}.txt").write_text("v")
            git(r, "add", "-A")
            git(r, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "기존 테스트")
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([RED, ["commit", "test: step 1 — a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        return self.step()["red"]

    def test_red_impl_renamed_test_restored(self):
        # #102: git diff --name-only 기본값은 이름 바꾸기를 감지해 옛 경로를 안 보인다 — 새 경로만 지워져 둘 다 사라졌다
        red = self.impl_after_red()
        os.rename(self.repo / "tests/a.expect", self.repo / "tests/a2.expect")
        self.act([IMPL, ["write", "src/a2.txt", "hello"], ["commit", "feat: a (테스트 이름 바꿈)"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertTrue((self.repo / "tests/a.expect").exists(), "옛 경로를 복원한다")
        self.assertEqual(self.read("tests/a.expect"), "hello", "옛 경로를 red 내용으로 복원한다")
        self.assertFalse((self.repo / "tests/a2.expect").exists(), "red 에 없던 새 경로는 지운다")
        self.assertIn("tests/a.expect", self.step()["last_error"])
        self.assertEqual(self.step()["red"], red, "재시도는 red 를 지우지 않는다")
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, "재시도도 구현 차례\n" + self.out)
        self.act([IMPL, ["commit", "feat: a 다시"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.step()["status"], "completed")

    def test_red_impl_moved_out_test_restored(self):
        # 테스트 밖으로 옮기면 새 경로가 테스트 파일이 아니라 목록이 비어 판정 4를 조용히 지나갔다
        self.impl_after_red()
        (self.repo / "docs").mkdir(exist_ok=True)
        os.rename(self.repo / "tests/a.expect", self.repo / "docs/a.old")
        self.act([IMPL, ["commit", "feat: a (테스트를 문서로 옮김)"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/a.expect"), "hello", "테스트 밖으로 옮겨도 복원한다")
        self.assertIn("tests/a.expect", self.step()["last_error"])

    def test_red_impl_space_path_test_reverted(self):
        # 공백 경로는 split 으로 쪼개져 되돌리지 못하고 이유에 조각(tests/my)만 보였다
        self.impl_after_red(pre=("my q",))
        self.act([IMPL, ["write", "tests/my q.expect", "w"], ["write", "src/my q.txt", "w"], ["commit", "feat: 바꿈"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/my q.expect"), "v", "red 내용으로 되돌린다")
        self.assertIn("tests/my q.expect", self.step()["last_error"])

    def test_red_impl_nonascii_path_test_reverted(self):
        # 비ASCII 경로는 core.quotePath 로 따옴표 · 8진 escape 가 붙어 테스트 파일 판별에서 빠졌다
        self.impl_after_red(pre=("한글",))
        self.act([IMPL, ["write", "tests/한글.expect", "w"], ["write", "src/한글.txt", "w"], ["commit", "feat: 바꿈"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, self.out)
        self.assertEqual(self.read("tests/한글.expect"), "v", "red 내용으로 되돌린다")
        self.assertIn("tests/한글.expect", self.step()["last_error"])
        self.assertNotIn("\\3", self.step()["last_error"], "8진 escape 없이 경로 그대로")

    def test_red_judge_impl_red_blame_blocks_without_discard(self):
        (self.repo / "lint.sh").write_text('rc=0; for f in tests/*; do grep -q BAD "$f" && echo "$f: BAD 금지" && rc=1; done; exit $rc\n')
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}],
                      cfg={"verify": {"test": "sh check.sh", "lint": "sh lint.sh"}, "tdd": {"enabled": True}})
        self.act([RED, ["write", "tests/a_note.txt", "BAD"], ["commit", "test: a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        red = self.step()["red"]
        self.session("prompt", "t1", "--role", "impl")
        self.act([IMPL, ["commit", "feat: a"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 2, self.out)
        s = self.step()
        self.assertEqual(s["status"], "blocked")
        self.assertIn("a_note.txt", s["blocked_reason"])
        self.assertIn("검증", s["blocked_reason"], "검증 세션 재판정으로 넘긴다")
        self.assertEqual(s["red"], red)
        self.assertEqual(git(self.repo, "merge-base", "--is-ancestor", red, "HEAD").returncode, 0,
                         "테스트 커밋을 지우지 않는다 — red 가 고아 커밋이 되지 않게")
        self.assertIn("test: a (red)", self.log())
        self.assertEqual(git(self.repo, "branch", "--list", "sdd-discard/*").stdout.strip(), "", "시도를 버리지 않는다")
        p = self.session("prompt", "t1", "--role", "impl")
        self.assertNotEqual(p.returncode, 0, "blocked 는 검증 재판정 차례")
        self.assertIn("지금은 검증 차례", self.out)

    def test_red_judge_one_shot_mode_unchanged(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--base", self.head())
        self.assertIn("② 구현한다", p.stdout, "옵션 없는 prompt 는 지금 1회 지시문")
        self.act([RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertNotIn("red", self.step(), "1회 모드는 red 를 적지 않는다")

    def test_red_judge_phases_status_accepts_red(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True, "red": "abc123"}])
        p = subprocess.run([sys.executable, str(HERE / "phases_status.py"), "--check", "t1"], cwd=self.repo,
                           capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)

    # ── 계획 칸 · effort (ADR-019 C1 · C2 · C3 · G5) ─────────────────────────────────
    def argv(self, i):
        return json.loads((self.tmp / "prompts" / f"{i}.argv").read_text())

    def test_intent_effort_empty_intent_refuses(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}],
                   md={1: "# Step 1: c\n\n## 의도\n\n   \n## 작업\n- 구현\n"})
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--base", self.head())
        self.assertNotEqual(p.returncode, 0, "의도 절이 비면 지시문을 내지 않는다")
        self.assertNotIn("작업 규칙", p.stdout)
        self.assertIn("의도", self.out)

    def test_intent_effort_missing_intent_warns_only(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--base", self.head())
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("작업 규칙", p.stdout, "옛 phase 는 지시문을 낸다")
        self.assertIn("옛 꼴", p.stderr)

    def test_intent_effort_one_shot_session_is_impl_role(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--base", self.head())
        self.assertIn("▶ effort medium", p.stderr, "세션 안 1회 모드는 구현 역할 값(C7a)")

    def test_intent_effort_role_values(self):
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.assertIn("▶ effort high", self.out, "검증 역할")
        self.act([RED, ["commit", "test: a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        p = self.session("prompt", "t1", "--role", "impl")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("▶ effort medium", p.stderr, "구현 역할")

    def test_intent_effort_headless_passes_effort(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        a = self.argv(0)
        self.assertIn("--effort", a)
        self.assertEqual(a[a.index("--effort") + 1], "high", "헤드리스 run 은 검증 역할 값(C7b)")

    # ── 헤드리스 대화 기록 차단(#75) — claude -p 인자에 --disallowedTools · 지시문 앞 -- ──────────────
    def assert_history_blocked(self, i):
        """가짜 claude i 번째 호출 인자: 차단 규칙 넷이 있고, 지시문은 -- 바로 뒤 마지막 인자 하나로 남는다."""
        a = self.argv(i)   # 지시문(마지막 인자)은 빠진 목록
        self.assertIn("--disallowedTools", a, a)
        start = a.index("--disallowedTools") + 1
        end = next((k for k in range(start, len(a)) if a[k].startswith("--")), len(a))
        # 헤드리스 시험(step 3)에서 거부를 확인한 글자 그대로 — 상수를 import 하면 같은 값끼리 비교가 돼
        # 앞 와일드카드 · /** 가 빠지는 회귀를 못 잡는다(REVIEW 1회차)
        rules = a[start:end]
        self.assertEqual(rules, ["Bash(*.claude/projects*)", "Read(~/.claude/projects/**)",
                                 "Grep(~/.claude/projects/**)", "Glob(~/.claude/projects/**)"])
        self.assertEqual(a[-1], "--", "지시문 바로 앞은 -- — 여러 값 옵션이 지시문을 규칙으로 먹지 않게")
        self.assertLess(start, a.index("--"))
        self.assertTrue(self.prompt(i).startswith("당신은"), "지시문은 마지막 인자 하나 그대로")
        self.assertFalse(any(r.startswith("당신은") for r in rules), "지시문이 차단 목록에 섞이지 않는다")

    # ── 헤드리스 auto memory 끄기(#118) — 메모리 안내가 금지 문구와 부딪치고 메모리 내용이 맥락에 실리는 길 ─────
    def memory_env(self, i):
        return (self.tmp / "prompts" / f"{i}.env").read_text()

    def test_headless_auto_memory_off(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.assertEqual(self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}]), 0, self.out)
        self.assertEqual(self.memory_env(0), "1", "헤드리스 호출 환경에서 auto memory 를 끈다")

    def test_headless_auto_memory_off_over_parent(self):
        self.env["CLAUDE_CODE_DISABLE_AUTO_MEMORY"] = "0"
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.assertEqual(self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}]), 0, self.out)
        self.assertEqual(self.memory_env(0), "1", "부모 환경에 다른 값이 있어도 1 로 덮는다")

    def test_headless_auto_memory_off_on_retry(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        err = {"step": 1, "ops": [["status", "error", {"error_message": "못 함"}]]}
        ok = {"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}
        self.assertEqual(self.run_runner([err, ok]), 0, self.out)
        self.assertEqual([self.memory_env(0), self.memory_env(1)], ["1", "1"], "재시도 호출도 끈다")

    def test_headless_disallow_rules_in_argv(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.assertEqual(self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}]), 0, self.out)
        self.assert_history_blocked(0)
        self.assertIn("--dangerously-skip-permissions", self.argv(0), "권한 건너뛰기는 그대로 — 막는 것은 차단 규칙")

    def test_headless_disallow_with_model(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False, "model": "opus"}])
        self.assertEqual(self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}]), 0, self.out)
        a = self.argv(0)
        self.assertEqual(a[a.index("--model") + 1], "opus")
        self.assert_history_blocked(0)

    def test_headless_disallow_on_retry(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        err = {"step": 1, "ops": [["status", "error", {"error_message": "못 함"}]]}
        ok = {"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}
        self.assertEqual(self.run_runner([err, ok]), 0, self.out)
        self.assertEqual(self.calls_made(), 2)
        self.assert_history_blocked(0)
        self.assert_history_blocked(1)

    def test_intent_effort_override(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}], "--effort", "max")
        self.assertEqual(rc, 0, self.out)
        a = self.argv(0)
        self.assertEqual(a[a.index("--effort") + 1], "max")
        self.phase([{"step": 1, "name": "d", "status": "pending", "tdd": False}], task="t2")
        p = self.session("prompt", "t2", "--role", "impl", "--effort", "low")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("▶ effort low", p.stderr)
        self.assertNotIn("▶ effort medium", p.stderr)

    def test_intent_effort_retry_headers_plain(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": []},
                              {"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertIn("이전 시도 실패", self.prompt(1))
        self.assertNotIn("반드시", self.prompt(1))

    def test_intent_effort_resume_header_plain(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False,
                     "failed_at": "2026-01-01T00:00:00+0900", "error_message": "원인: x"}])
        rc = self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        self.assertIn("멈춘 원인", self.prompt(0))
        self.assertNotIn("반드시", self.prompt(0))

    def test_intent_effort_blocked_conditions(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--base", self.head())
        for c in ("사람만 할 수 있는 일", "테스트가 수용 조건과 다르다", "설계 문서에 없는 결정이 필요하다"):
            self.assertIn(c, p.stdout)

    def test_intent_effort_impl_role_does_not_edit_tests(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--role", "impl")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("테스트는 고치지 않는다 — 막히면", p.stdout)
        self.assertIn("검증 세션이 다시 판정한다", p.stdout)

    # ── 엣지 5축 칸 (ADR-019 G6) ───────────────────────────────────────────────
    AXES = ("빈 값·경계", "비정상 입력", "실패 경로", "상태 전이", "동시성")

    def edge_md(self, cells=None, name="a"):
        """새 꼴 step 파일. cells: {축: 값} — 없는 축은 줄을 안 쓴다. None 이면 엣지 줄 자체가 없다."""
        md = f"# Step 1: {name}\n\n## 의도\n\nAC-1 — 이유 한 줄\n\n## 작업\n- 구현\n\n## Acceptance Criteria\n\n- 테스트 통과\n"
        if cells is not None:
            md += "- 엣지 5축\n" + "".join(f"  - {k}: {v}\n" for k, v in cells.items())
        return md

    def full_cells(self, first="`hello`"):
        return {"빈 값·경계": first, "비정상 입력": "해당 없음", "실패 경로": "해당 없음: 실패할 경로가 없다",
                "상태 전이": "`hello` · `hello`", "동시성": "해당 없음"}

    def tdd_new(self, cells, cfg=None):
        if cfg:
            self.set_cfg(cfg)
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}], md={1: self.edge_md(cells)})
        self.assertEqual(self.session("start", "t1").returncode, 0, self.out)

    def test_edge_axes_missing_cell_refuses(self):
        self.tdd_new(None)
        p = self.session("prompt", "t1", "--base", self.head())
        self.assertNotEqual(p.returncode, 0, "새 꼴 tdd step 에 엣지 칸이 없으면 지시문을 내지 않는다")
        self.assertNotIn("작업 규칙", p.stdout)
        self.assertIn("엣지 5축", self.out)

    def test_edge_axes_one_empty_axis_named(self):
        for bad in ("", "그냥 글"):
            with self.subTest(bad=bad):
                self.setUp()
                cells = self.full_cells()
                cells["상태 전이"] = bad
                self.tdd_new(cells)
                p = self.session("prompt", "t1", "--role", "test", "--base", self.head())
                self.assertNotEqual(p.returncode, 0, self.out)
                self.assertNotIn("작업 규칙", p.stdout)
                self.assertIn("상태 전이", self.out)
                self.assertNotIn("비정상 입력", self.out, "빈 축만 이름을 댄다")

    def test_edge_axes_missing_axis_line_is_empty(self):
        cells = self.full_cells()
        del cells["동시성"]
        self.tdd_new(cells)
        p = self.session("prompt", "t1", "--base", self.head())
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("동시성", self.out)

    def test_edge_axes_full_cells_emit_prompt(self):
        self.tdd_new(self.full_cells())
        p = self.session("prompt", "t1", "--base", self.head())
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("작업 규칙", p.stdout)
        self.assertIn("엣지 5축 칸의 테스트 이름을 그대로", p.stdout, "1회 모드 tdd 규칙에 한 구절")
        self.assertNotIn("옛 꼴", p.stderr)

    def test_edge_axes_test_role_prompt_mentions_names(self):
        self.tdd_new(self.full_cells())
        p = self.session("prompt", "t1", "--role", "test", "--base", self.head())
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("엣지 5축 칸의 테스트 이름을 그대로", p.stdout)

    def test_edge_axes_old_form_warns_only(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--base", self.head())
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("작업 규칙", p.stdout)
        self.assertIn("옛 꼴", p.stderr)

    def test_edge_axes_not_checked_for_tdd_false_or_measure(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False},
                    {"step": 2, "name": "m", "status": "pending", "tdd": False, "kind": "measure"}],
                   md={1: self.edge_md(None, "c"), 2: self.edge_md(None, "m")})
        self.session("start", "t1")
        for n in ("1", "2"):
            p = self.session("prompt", "t1", "--step", n)
            self.assertEqual(p.returncode, 0, self.out)
            self.assertIn("작업 규칙", p.stdout)

    def test_edge_axes_headless_blocks_without_claude(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}], md={1: self.edge_md(None)})
        rc = self.run_runner([{"step": 1, "ops": [RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 2, self.out)
        self.assertEqual(self.calls_made(), 0, "계획 칸이라 claude 를 부르지 않는다")
        s = self.step()
        self.assertEqual(s["status"], "blocked")
        self.assertIn("엣지 5축 칸이 비었다", s["blocked_reason"])
        self.assertIn("동시성", s["blocked_reason"])
        self.assertNotIn("retries", s, "재시도를 태우지 않는다")

    def test_edge_axes_name_missing_in_red_discards_one_shot(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}],
                   md={1: self.edge_md(self.full_cells("`hello` · `edge_empty_name`"))})
        rc = self.run_runner([
            {"step": 1, "ops": [RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"], DONE]},
            {"step": 1, "ops": [RED, ["write", "tests/names.txt", "edge_empty_name"], ["commit", "test: a (red)"],
                                IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 0, self.out)
        err = self.step()["attempts"][0]["error"]
        self.assertIn("엣지 5축", err)
        self.assertIn("edge_empty_name", err)
        self.assertIn("sdd-discard/t1/step1-try1", git(self.repo, "branch", "--list", "sdd-discard/*").stdout,
                      "RED 위반처럼 시도를 버린다")

    def test_edge_axes_name_check_judge_red(self):
        self.tdd_new(self.full_cells("`edge_empty_name`"))
        self.session("prompt", "t1", "--role", "test", "--base", self.head())
        self.act([RED, ["commit", "test: a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 10, self.out)
        self.assertIn("edge_empty_name", self.step()["last_error"])
        self.assertNotIn("red", self.step())
        self.act([RED, ["write", "tests/names.txt", "edge_empty_name"], ["commit", "test: a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        self.assertIn("red", self.step())

    def test_edge_axes_template_placeholder_is_empty(self):
        # 리뷰: 템플릿 자리표시 `<테스트 이름>` 을 그대로 두면 칸이 찬 것으로 보여 재시도 4회를 다 썼다
        cells = self.full_cells()
        cells["실패 경로"] = "`<테스트 이름>`"
        self.tdd_new(cells)
        p = self.session("prompt", "t1", "--base", self.head())
        self.assertNotEqual(p.returncode, 0, self.out)
        self.assertNotIn("작업 규칙", p.stdout)
        self.assertIn("실패 경로", self.out)

    def test_intent_effort_template_intent_refuses(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}],
                   md={1: "# Step 1: c\n\n## 의도\n\n- 채우는 수용 조건: AC-N(, AC-M) — 이유 한 줄\n\n## 작업\n- 구현\n"})
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--base", self.head())
        self.assertNotEqual(p.returncode, 0, "의도 절이 템플릿 그대로면 빈 것과 같다")
        self.assertNotIn("작업 규칙", p.stdout)
        self.assertIn("의도", self.out)

    def test_intent_effort_rejects_unknown_effort(self):
        self.phase([{"step": 1, "name": "c", "status": "pending", "tdd": False}])
        self.session("start", "t1")
        p = self.session("prompt", "t1", "--base", self.head(), "--effort", "hihg")
        self.assertNotEqual(p.returncode, 0, "오타가 헤드리스 claude --effort 실패로 번지지 않게 입구에서 막는다")
        self.assertNotIn("작업 규칙", p.stdout)

    def test_red_judge_test_turn_completed_refused(self):
        # 리뷰: 검증 차례 에이전트가 step 파일 「검증 절차」대로 completed 를 적으면 judge --red 가 다음 step 을 보고
        # 「차례 아님」(3)으로 끝나, 구현 없이 step 이 넘어갔다
        _, text = self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True},
                                 {"step": 2, "name": "b", "status": "pending", "tdd": False}])
        self.assertIn("검증 차례에는 status 를 바꾸지 않는다", text, "지시문 6번이 step 파일 검증 절차보다 앞선다고 적는다")
        self.act([RED, ["commit", "test: step 1 — a (red)"], DONE])
        p = self.session("judge", "t1", "--red", "--step", "1")
        self.assertEqual(p.returncode, 1, self.out)
        self.assertIn("status", self.out)
        self.assertNotIn("red", self.step())

    def test_red_judge_test_turn_blocked_recorded(self):
        # 검증 차례 에이전트가 blocked 를 적으면 1회 모드처럼 기록 · 커밋하고 종료 2(사람). 「차례 아님」(3)이 아니다
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([["status", "blocked", {"blocked_reason": "수용 조건이 모호하다"}]])
        p = self.session("judge", "t1", "--red", "--step", "1")
        self.assertEqual(p.returncode, 2, self.out)
        s = self.step()
        self.assertEqual(s["status"], "blocked")
        self.assertIn("blocked_at", s)
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "", "index 를 커밋한다")

    def test_session_judge_without_any_base_refuses(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        self.assertNotEqual(self.session("judge", "t1", "--step", "1").returncode, 0)

    def test_session_judge_requires_step(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        self.assertNotEqual(self.session("judge", "t1", "--base", "HEAD").returncode, 0)

    # ── 구현 시작 관문 (ADR-023 R1 · R2) ──────────────────────────────────────
    ADR_OPEN = textwrap.dedent('''\
        # ADR
        ## ADR-900 첫 결정
        ### 결정할 것
        | # | 정할 것 | 추천 / 결정 | 주체 |
        |---|---|---|---|
        | R1 | 관문 위치 | start | 사용자(AI 추천 수용) |
        | R2 | 세는 칸 |  |  |
        ### 버린 방법
        | 방법 | 이유 | 주체 |
        |---|---|---|
        | X | 느림 |  |
        ## ADR-901 둘째 결정
        ### 결정할 것 / 결정한 것
        | # | 정할 것 | 추천 / 결정 | 주체 |
        |---|---|---|---|
        | S1 | 진입점 모양 | A |   |
        | S2 | 이름 | gate | 사람 |
    ''')
    ADR_CLOSED = textwrap.dedent('''\
        # ADR
        ## ADR-900 첫 결정
        ### 결정할 것
        | # | 정할 것 | 추천 / 결정 | 주체 |
        |---|---|---|---|
        | R1 | 관문 위치 | start | 사용자(AI 추천 수용) |

        열린 결정 0.
    ''')
    PRD_LABEL = textwrap.dedent('''\
        # PRD
        - **범위**: x
        - **남은 ⚠️** (계획 때 정한다)
          - ⚠️ 관문이 무엇을 세나 → 결정: ADR-900 R1
          - ⚠️ 테스트 모양
            - 하위 메모 ⚠️ 첫 단이 아니라 세지 않는다
        - **수용 조건**
          - AC-1 ⚠️ 남은 ⚠️ 범위 밖이라 세지 않는다
    ''')
    PRD_HEADING = textwrap.dedent('''\
        # PRD
        ## 남은 ⚠️
        - ⚠️ A 정하기
        - ⚠️ B 다음 phase 일 막지 않음: 이번 범위 밖
        ## 다음 절
        - ⚠️ D 범위 밖
    ''')

    def docs(self, path="docs/d", adr=None, prd=None, arch=None):
        d = self.repo / path
        d.mkdir(parents=True, exist_ok=True)
        for name, body in (("ADR.md", adr), ("PRD.md", prd), ("ARCHITECTURE.md", arch)):
            if body is not None:
                (d / name).write_text(body)
        git(self.repo, "add", "-A")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", f"docs {path}")
        return path

    def test_gate_no_docs_passes(self):
        p = self.session("gate", "docs/none")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("ADR · PRD 없음", p.stdout, "문서가 없으면 막지 않는다(AC-2)")
        path = self.docs("docs/arch-only", arch="# ARCHITECTURE\n기존 구조 그대로\n")
        p = self.session("gate", path)
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("ADR · PRD 없음", p.stdout)
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "", "관문은 아무것도 쓰지 않는다")

    def test_gate_all_closed_passes(self):
        path = self.docs(adr=self.ADR_CLOSED, prd="# PRD\n- **범위**: x\n")
        p = self.session("gate", path)
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("열린 「정할 것」 0", p.stdout)

    def test_gate_open_rows_stop_with_list(self):
        path = self.docs(adr=self.ADR_OPEN, prd=self.PRD_LABEL)
        p = self.session("gate", path)
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 3개", p.stdout)
        self.assertIn("  - ADR R2: 세는 칸", p.stdout, "주체 칸이 빈 행")
        self.assertIn("  - ADR S1: 진입점 모양", p.stdout, "주체 칸이 공백뿐인 행 · 둘째 ADR 블록")
        self.assertIn("  - PRD: ⚠️ 테스트 모양", p.stdout)
        self.assertNotIn("R1", p.stdout.replace("ADR-900 R1", ""), "주체가 찬 행은 닫힌 것")
        self.assertNotIn("S2", p.stdout)
        self.assertNotIn("느림", p.stdout, "「결정할 것」 절 밖의 표는 세지 않는다")

    def test_gate_table_without_owner_column_counts_all(self):
        adr = textwrap.dedent('''\
            # ADR
            ## 결정할 것
            | # | 정할 것 | 추천 |
            |---|---|---|
            | Q1 | 하나 | A |
            | Q2 | 둘 | B |
        ''')
        p = self.session("gate", self.docs(adr=adr))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("  - ADR Q1: 하나", p.stdout, "주체 칸이 없으면 모든 행이 열린 것(기본이 멈춤)")
        self.assertIn("  - ADR Q2: 둘", p.stdout)

    def test_gate_prd_marked_lines_excluded(self):
        path = self.docs(prd=self.PRD_LABEL)
        self.assertEqual(self.session("gate", path).returncode, 2, self.out)
        self.docs(prd=self.PRD_LABEL.replace("⚠️ 테스트 모양", "⚠️ 테스트 모양 → 결정: ADR-900 R2"))
        p = self.session("gate", path)
        self.assertEqual(p.returncode, 0, "닫힘 표시를 달면 통과한다\n" + self.out)
        self.docs(prd=self.PRD_LABEL.replace("⚠️ 테스트 모양", "⚠️ 테스트 모양 막지 않음: 구현과 무관"))
        self.assertEqual(self.session("gate", path).returncode, 0, "막지 않음: 표시도 뺀다\n" + self.out)

    def test_gate_prd_heading_and_label_forms(self):
        p = self.session("gate", self.docs("docs/h", prd=self.PRD_HEADING))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 1개", p.stdout)
        self.assertIn("  - PRD: ⚠️ A 정하기", p.stdout, "제목 꼴: 다음 같은 급 제목 전까지")
        self.assertNotIn("B 다음", p.stdout)
        self.assertNotIn("D 범위 밖", p.stdout)
        p = self.session("gate", self.docs("docs/l", prd=self.PRD_LABEL))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 1개", p.stdout, "불렛 라벨 꼴: 첫 단 항목만 · 라벨 범위 밖은 안 센다")
        self.assertNotIn("하위 메모", p.stdout)
        self.assertNotIn("AC-1", p.stdout)

    def test_start_gate_no_docs_key_passes(self):
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        f = self.repo / "phases/t1/index.json"
        d = json.loads(f.read_text())
        d.pop("docs")
        f.write_text(json.dumps(d, indent=2))
        git(self.repo, "add", "-A")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "docs 칸 없음")
        p = self.session("start", "t1")
        self.assertEqual(p.returncode, 0, "docs 칸이 없으면 관문은 막지 않는다(AC-2)\n" + self.out)

    def test_start_gate_open_stops_before_side_effects(self):
        self.set_cfg({"verify": {"test": "sh check.sh"}, "git": {"branchPattern": "feature/{task}"}})
        self.docs("docs/x", adr=self.ADR_OPEN)
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        exclude = self.repo / ".git/info/exclude"
        ex_before = exclude.read_text() if exclude.exists() else ""
        idx_before = (self.repo / "phases/t1/index.json").read_bytes()
        p = self.session("start", "t1")
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 2개", p.stdout)
        self.assertIn("  - ADR R2: 세는 칸", p.stdout)
        self.assertIn("  - ADR S1: 진입점 모양", p.stdout)
        self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip(), "main",
                         "멈추면 브랜치를 옮기지 않는다")
        self.assertEqual(exclude.read_text() if exclude.exists() else "", ex_before, "exclude 를 쓰기 전에 멈춘다")
        self.assertEqual((self.repo / "phases/t1/index.json").read_bytes(), idx_before)

    def test_run_gate_open_never_calls_claude(self):
        self.docs("docs/x", prd=self.PRD_HEADING)
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        rc = self.run_runner([{"step": 1, "ops": [IMPL, ["commit", "feat: a"], DONE]}])
        self.assertEqual(rc, 2, self.out)
        self.assertIn("  - PRD: ⚠️ A 정하기", self.out)
        self.assertEqual(self.calls_made(), 0, "관문이 열렸으면 claude 를 부르지 않는다")

    def test_start_gate_closed_then_passes(self):
        self.docs("docs/x", adr=self.ADR_OPEN, prd=self.PRD_LABEL)
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": False}])
        self.assertEqual(self.session("start", "t1").returncode, 2, self.out)
        self.docs("docs/x", adr=self.ADR_CLOSED,
                  prd=self.PRD_LABEL.replace("⚠️ 테스트 모양", "⚠️ 테스트 모양 → 결정: ADR-900 R1"))
        p = self.session("start", "t1")
        self.assertEqual(p.returncode, 0, "닫으면 통과한다\n" + self.out)

    # ── 재판정 「테스트가 틀렸다」 진입점 (ADR-023 R3) ────────────────────────
    def blocked_after_red(self):
        """나눔 모드: 검증 red(기대 hello) → 구현이 bye 를 쓰고 「테스트가 수용 조건과 다르다」로 blocked. (BASE, 옛 red)"""
        base, _ = self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([RED, ["commit", "test: step 1 — a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        old = self.step()["red"]
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "src/a.txt", "bye"],
                  ["status", "blocked", {"blocked_reason": "테스트가 수용 조건과 다르다 — 기대값은 bye"}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 2, self.out)
        return base, old

    def fix_tests(self, ops, msg="test: step 1 — a 테스트 고침"):
        """검증 세션이 테스트만 고쳐 커밋한다. ops: [("write", 경로, 내용) | ("rm", 경로)]"""
        for op in ops:
            if op[0] == "write":
                (self.repo / op[1]).parent.mkdir(parents=True, exist_ok=True)   # git rm 이 빈 폴더를 지운다
                (self.repo / op[1]).write_text(op[2])
                git(self.repo, "add", "--", op[1])
            else:
                git(self.repo, "rm", "-q", "--", op[1])
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", msg)
        return self.head()

    def wip_sha(self):
        return next(ln.split(" ", 1)[0] for ln in git(self.repo, "log", "--format=%H %s").stdout.splitlines()
                    if " wip: step 1" in ln)

    def assert_unchanged(self, before):
        self.assertEqual((self.head(), self.index_bytes()), before, "거부하면 아무것도 바꾸지 않는다")

    def test_rejudge_moves_red_keeps_impl(self):
        base, old = self.blocked_after_red()
        wip = self.wip_sha()
        fixed = self.fix_tests([("write", "tests/a.expect", "bye")])
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("재판정", p.stdout)
        s = self.step()
        self.assertEqual(s["red"], fixed, "red 는 고친 테스트 커밋으로 옮긴다")
        self.assertEqual(s["status"], "pending")
        self.assertNotIn("blocked_reason", s)
        self.assertNotIn("blocked_at", s)
        self.assertEqual(s["base"], base, "BASE 는 그대로")
        self.assertEqual(len(s["rejudged"]), 1)
        self.assertEqual(s["rejudged"][0]["red_before"], old)
        self.assertIn("at", s["rejudged"][0])
        self.assertEqual(git(self.repo, "merge-base", "--is-ancestor", wip, "HEAD").returncode, 0,
                         "구현 커밋을 지우지 않는다")
        self.assertEqual((self.repo / "src/a.txt").read_text(), "bye")
        self.assertEqual((self.repo / "tests/a.expect").read_text(), "bye")
        self.assertEqual(git(self.repo, "branch", "--list", "sdd-discard/*").stdout.strip(), "", "시도를 버리지 않는다")
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "", "index 를 커밋한다")
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, "다음은 구현 차례\n" + self.out)

    # ── 한글 · 공백 테스트 경로(#113) — 파일 목록을 -z + core.quotePath=false 로 읽는다 ─────────────
    def red_path(self, path):
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([["write", path, "hello"], ["commit", "test: step 1 — a (red)"]])
        return self.session("judge", "t1", "--red", "--step", "1")

    def test_red_judge_nonascii_path_recorded(self):
        # AC-1 · 재현 A: diff-tree 가 한글 경로에 따옴표 · 8진 이스케이프를 붙여 「테스트 커밋이 없다」로 거절했다
        p = self.red_path("tests/한글.expect")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertEqual(self.step()["red"], self.head_before_index())

    def test_red_judge_space_path_recorded(self):
        # AC-2 · 재현 B: 공백 경로가 두 조각으로 쪼개져 「q.expect 가 같이 커밋된 구현」으로 거절했다
        p = self.red_path("tests/my q.expect")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertEqual(self.step()["red"], self.head_before_index())

    def head_before_index(self):
        """red 기록 뒤 HEAD 는 index 커밋 — 그 앞이 테스트 커밋이다."""
        return git(self.repo, "rev-parse", "HEAD~1").stdout.strip()

    def test_rejudge_nonascii_path_bundle_accepted(self):
        # AC-3 · 재현 C: 재판정 묶음의 한글 경로가 「테스트 · phases/ 밖 파일」로 보여 거절했다
        self.blocked_after_red()
        fixed = self.fix_tests([("write", "tests/a.expect", "bye"), ("write", "tests/한글.expect", "bye")])
        self.assertEqual(self.session("rejudge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.step()["red"], fixed)

    def test_rejudge_space_path_bundle_accepted(self):
        # AC-4 · 재현 D
        self.blocked_after_red()
        fixed = self.fix_tests([("write", "tests/a.expect", "bye"), ("write", "tests/my q.expect", "bye")])
        self.assertEqual(self.session("rejudge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.step()["red"], fixed)

    def test_rejudge_nonascii_new_test_put_on_base(self):
        # AC-5 · 재현 E: base_with_tests 가 따옴표 경로를 못 찾아 한글 새 테스트를 BASE 에 안 얹고 「BASE 에서도 통과」로 거절했다
        self.blocked_after_red()
        fixed = self.fix_tests([("rm", "tests/a.expect"), ("write", "tests/한글.expect", "bye")])
        self.assertEqual(self.session("rejudge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.step()["red"], fixed)

    def test_red_blame_nonascii_path_blocks(self):
        # AC-6 · 재현 F: red 테스트 목록이 따옴표 경로라 lint 가 가리킨 한글 red 테스트 파일을 못 찾아 재시도로 태웠다
        (self.repo / "lint.sh").write_text('rc=0; for f in tests/*; do grep -q BAD "$f" && echo "$f: BAD 금지" && rc=1; done; exit $rc\n')
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}],
                      cfg={"verify": {"test": "sh check.sh", "lint": "sh lint.sh"}, "tdd": {"enabled": True}})
        self.act([RED, ["write", "tests/한글_note.txt", "BAD"], ["commit", "test: a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        self.session("prompt", "t1", "--role", "impl")
        self.act([IMPL, ["commit", "feat: a"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 2, self.out)
        s = self.step()
        self.assertEqual(s["status"], "blocked")
        self.assertIn("tests/한글_note.txt", s["blocked_reason"], "경로가 따옴표 · 8진 이스케이프 없이 보인다")

    def test_rejudge_second_block_goes_to_user(self):
        self.blocked_after_red()
        fixed = self.fix_tests([("write", "tests/a.expect", "bye")])
        self.assertEqual(self.session("rejudge", "t1", "--step", "1").returncode, 0, self.out)
        self.session("prompt", "t1", "--role", "impl")
        self.act([["status", "blocked", {"blocked_reason": "여전히 수용 조건과 다르다"}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 2, self.out)
        self.fix_tests([("write", "tests/a.expect", "bye!")], msg="test: step 1 — a 다시 고침")
        before = (self.head(), self.index_bytes())
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 2, "한 번 다시 판정했으면 사용자에게(ADR-019 E3)\n" + self.out)
        self.assertIn("사용자", self.out)
        self.assert_unchanged(before)
        self.assertEqual(self.step()["red"], fixed)

    def test_rejudge_without_test_fix_refused(self):
        self.blocked_after_red()
        before = (self.head(), self.index_bytes())
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 1, self.out)
        self.assertIn("고친 테스트", self.out)
        self.assert_unchanged(before)

    def test_rejudge_fix_with_impl_file_refused(self):
        self.blocked_after_red()
        self.fix_tests([("write", "tests/a.expect", "bye"), ("write", "src/c.txt", "구현도 섞음")])
        before = (self.head(), self.index_bytes())
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 1, "고친 테스트 커밋에 구현 파일이 섞이면 거부\n" + self.out)
        self.assert_unchanged(before)
        self.assertEqual(self.step()["status"], "blocked")

    def test_rejudge_dirty_tree_refused(self):
        self.blocked_after_red()
        self.fix_tests([("write", "tests/a.expect", "bye")])
        (self.repo / "src/b.txt").write_text("커밋 안 함")
        before = (self.head(), self.index_bytes())
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 1, self.out)
        self.assert_unchanged(before)
        self.assertEqual((self.repo / "src/b.txt").read_text(), "커밋 안 함", "작업 트리를 건드리지 않는다")

    def test_rejudge_fix_passing_on_base_refused(self):
        _, old = self.blocked_after_red()
        # 테스트를 약하게 고침: a 기대를 지우고 BASE 에서도 맞는 b 기대(src/b.txt 가 이미 x)로 바꾼다
        self.fix_tests([("rm", "tests/a.expect"), ("write", "tests/b.expect", "x")])
        before = (self.head(), self.index_bytes())
        branch = git(self.repo, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 1, "고친 테스트가 BASE 에서도 통과하면 아무것도 안 잡는다\n" + self.out)
        self.assertIn("아무것도 잡지", self.out)
        self.assert_unchanged(before)
        self.assertEqual(self.step()["red"], old)
        self.assertEqual((self.repo / "src/a.txt").read_text(), "bye", "BASE 확인 뒤 트리를 HEAD 로 돌려 둔다")
        self.assertTrue((self.repo / "tests/b.expect").exists())
        self.assertEqual(git(self.repo, "rev-parse", "--abbrev-ref", "HEAD").stdout.strip(), branch,
                         "BASE 확인이 브랜치를 옮기지 않는다")

    def test_rejudge_out_of_turn_changes_nothing(self):
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        before = (self.head(), self.index_bytes())
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 3, "red 없는 pending(검증이 테스트 쓸 차례)은 재판정 차례가 아니다\n" + self.out)
        self.assert_unchanged(before)
        self.act([RED, ["commit", "test: step 1 — a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        before = (self.head(), self.index_bytes())
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 3, "구현 차례에 재판정이 트리를 치지 않는다\n" + self.out)
        self.assertIn("구현 차례", self.out)
        self.assert_unchanged(before)
        p = self.session("rejudge", "t1", "--step", "2")
        self.assertEqual(p.returncode, 3, "지금 차례인 step 이 아니면 거부\n" + self.out)
        self.assert_unchanged(before)

    # ── #86 F1 · F3: 구현이 바꾼 테스트를 씻지 않는다 · detached HEAD ─────────
    def blocked_with_impl_ops(self, impl_ops):
        """red(a=hello, c=c) → 구현이 impl_ops 를 하고 blocked. (BASE, 옛 red)"""
        base, _ = self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([RED, ["write", "tests/c.expect", "c"], ["commit", "test: step 1 — a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        old = self.step()["red"]
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        for op in impl_ops:
            if op[0] == "rm":
                (self.repo / op[1]).unlink()
        self.act([op for op in impl_ops if op[0] != "rm"]
                 + [["status", "blocked", {"blocked_reason": "a 기대값이 틀렸다 — bye"}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 2, self.out)
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "",
                         "구현 시도는 wip 커밋에 담긴다(거부 이유가 더러운 트리가 아니게)")
        return base, old

    def test_rejudge_impl_deleted_test_refused(self):
        _, old = self.blocked_with_impl_ops([["write", "src/a.txt", "bye"], ["write", "src/c.txt", "c"],
                                             ["rm", "tests/c.expect"]])
        self.assertFalse((self.repo / "tests/c.expect").exists(), "구현이 지운 테스트가 HEAD 에 없다")
        self.fix_tests([("write", "tests/a.expect", "bye")])
        before = (self.head(), self.index_bytes())
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 1, "구현 세션이 지운 테스트를 새 red 로 씻지 않는다\n" + self.out)
        self.assertIn("tests/c.expect", self.out, "바뀐 테스트 파일 목록을 보인다")
        self.assert_unchanged(before)
        self.assertEqual(self.step()["red"], old)
        self.assertEqual(self.step()["status"], "blocked")

    def test_rejudge_impl_edited_test_refused(self):
        _, old = self.blocked_with_impl_ops([["write", "src/a.txt", "bye"], ["write", "src/c.txt", "zzz"],
                                             ["write", "tests/c.expect", "zzz"]])
        self.fix_tests([("write", "tests/a.expect", "bye")])
        before = (self.head(), self.index_bytes())
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 1, "구현 세션이 고친 테스트를 새 red 로 씻지 않는다\n" + self.out)
        self.assertIn("tests/c.expect", self.out)
        self.assert_unchanged(before)
        self.assertEqual(self.step()["red"], old)

    def test_rejudge_impl_test_edit_before_red_ok(self):
        # 경계: 옛 red 커밋의 테스트 변경 · 끝의 테스트만 담은 커밋 묶음(둘)은 구현 구간이 아니다
        self.blocked_with_impl_ops([["write", "src/a.txt", "bye"], ["write", "src/c.txt", "c"]])
        self.fix_tests([("write", "tests/a.expect", "bye")])
        fixed = self.fix_tests([("write", "tests/e.expect", "e")], msg="test: step 1 — e 기대 추가")
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 0, "구현이 테스트를 안 건드렸으면 받는다\n" + self.out)
        self.assertEqual(self.step()["red"], fixed)

    def test_rejudge_detached_head(self):
        _, old = self.blocked_after_red()
        fixed = self.fix_tests([("write", "tests/a.expect", "bye")])
        git(self.repo, "checkout", "-q", "--detach", "HEAD")
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertEqual(self.step()["red"], fixed, "red 는 임시 커밋이 아니라 고친 테스트 커밋")
        self.assertEqual(git(self.repo, "rev-parse", "HEAD~1").stdout.strip(), fixed,
                         "BASE 확인 뒤 시작 sha 로 돌아와 그 위에 index 를 커밋한다")
        self.assertEqual((self.repo / "src/a.txt").read_text(), "bye", "구현 파일이 작업 트리에 남는다")
        self.assertEqual((self.repo / "tests/a.expect").read_text(), "bye")
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "")

    def test_judge_detached_head_returns_to_start(self):
        # D3: RED 확인(red_passes)은 rejudge · judge 공용이다. 세션 하나 모드는 red 커밋 뒤에 구현 커밋이 있어
        # detached 에서 「HEAD」로 돌아가면 red 커밋에 남는다 — 시작 sha 로 돌아가야 한다
        self.phase([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.assertEqual(self.session("start", "t1").returncode, 0, self.out)
        self.session("prompt", "t1", "--base", self.head())
        self.act([RED, ["commit", "test: a (red)"], IMPL, ["commit", "feat: a"], DONE])
        impl = self.head()
        git(self.repo, "checkout", "-q", "--detach", "HEAD")
        p = self.session("judge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertEqual(git(self.repo, "merge-base", "--is-ancestor", impl, "HEAD").returncode, 0,
                         "RED 확인 뒤 구현 커밋 위로 돌아온다")
        self.assertEqual((self.repo / "src/a.txt").read_text(), "hello", "구현 파일이 작업 트리에 남는다")
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "")

    # ── #86 F2: 재판정 뒤 재시도 창 ─────────────────────────────────────────
    def fail_impl(self, n, start=0):
        rcs = []
        for i in range(start, start + n):
            self.session("prompt", "t1", "--role", "impl")
            self.act([["write", "src/a.txt", f"bye{i}"], DONE])
            rcs.append(self.session("judge", "t1", "--step", "1").returncode)
        return rcs

    def rejudged_after_three_fails(self):
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([RED, ["commit", "test: step 1 — a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.fail_impl(3), [10, 10, 10], self.out)
        self.session("prompt", "t1", "--role", "impl")
        self.act([["status", "blocked", {"blocked_reason": "기대값이 틀렸다 — bye"}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 2, self.out)
        self.fix_tests([("write", "tests/a.expect", "bye")])
        self.assertEqual(self.session("rejudge", "t1", "--step", "1").returncode, 0, self.out)

    def test_rejudge_resets_retry_window(self):
        self.rejudged_after_three_fails()
        self.assertEqual(self.fail_impl(1, start=10), [10], "재판정 뒤 첫 실패는 재시도다(한도 초과 error 아님)\n" + self.out)
        self.assertEqual(self.step()["status"], "pending")
        self.assertGreaterEqual(len(self.step()["attempts"]), 4, "attempts 는 이력으로 남는다")

    def test_rejudge_retry_window_still_limits(self):
        self.rejudged_after_three_fails()
        rcs = self.fail_impl(4, start=10)
        self.assertEqual(rcs[:3], [10, 10, 10], self.out)
        self.assertNotEqual(rcs[3], 10, "재판정 뒤에도 한도를 넘으면 멈춘다\n" + self.out)
        self.assertEqual(self.step()["status"], "error")

    def test_rejudge_does_not_set_resumed_at(self):
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([RED, ["commit", "test: step 1 — a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        before = self.step().get("resumed_at")
        self.session("prompt", "t1", "--role", "impl")
        self.act([["write", "src/a.txt", "bye"], ["status", "blocked", {"blocked_reason": "기대값이 틀렸다 — bye"}]])
        self.session("judge", "t1", "--step", "1")
        self.fix_tests([("write", "tests/a.expect", "bye")])
        self.assertEqual(self.session("rejudge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertEqual(self.step().get("resumed_at"), before, "재개 표시를 쓰면 전체 verify 가 켜진다 — 쓰지 않는다")

    def test_rejudge_after_restoring_impl_test_edit_accepted(self):
        # D1 「검증이 되돌리는 테스트 커밋을 올리면 다시 받는다」
        _, old = self.blocked_with_impl_ops([["write", "src/a.txt", "bye"], ["write", "src/c.txt", "c"],
                                             ["rm", "tests/c.expect"]])
        self.fix_tests([("write", "tests/a.expect", "bye"), ("write", "tests/c.expect", "c")])
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 0, "옛 red 내용으로 되돌렸으면 받는다\n" + self.out)
        self.assertEqual((self.repo / "tests/c.expect").read_text(), "c")

    def test_rejudge_impl_only_deleted_test_refused(self):
        # 구현 시도가 테스트만 지우고 막히면 wip 커밋도 「테스트만 담은 커밋」이다 — 끝 묶음에 넣으면 씻긴다
        _, old = self.blocked_with_impl_ops([["rm", "tests/c.expect"]])
        self.fix_tests([("write", "tests/a.expect", "bye")])
        before = (self.head(), self.index_bytes())
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 1, "구현 시도 커밋은 고친 테스트 묶음이 아니다\n" + self.out)
        self.assertIn("tests/c.expect", self.out)
        self.assert_unchanged(before)

    # ── #86 리뷰 1회차: 묶음 경계 · 되돌린 파일 · 라벨 정리 · 재시도 표시 ─────────
    def test_rejudge_impl_committed_test_only_refused(self):
        # D4: 구현 세션이 테스트만 담은 커밋을 직접 올리고 blocked — wip 커밋이 없어도 묶음에 섞이지 않는다
        _, old = self.blocked_with_impl_ops([["rm", "tests/c.expect"], ["commit", "test: c 기대 고침"]])
        self.fix_tests([("write", "tests/a.expect", "bye")])
        before = (self.head(), self.index_bytes())
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 1, "구현 세션 커밋은 고친 테스트 묶음이 아니다\n" + self.out)
        self.assertIn("tests/c.expect", self.out)
        self.assert_unchanged(before)

    def test_blocked_records_blocked_head(self):
        self.blocked_after_red()
        s = self.step()
        self.assertIn("blocked_head", s, "blocked 판정이 묶음 경계 sha 를 남긴다(D4)")
        self.assertEqual(git(self.repo, "merge-base", "--is-ancestor", s["blocked_head"], "HEAD").returncode, 0)
        self.fix_tests([("write", "tests/a.expect", "bye")])
        self.assertEqual(self.session("rejudge", "t1", "--step", "1").returncode, 0, self.out)
        self.assertNotIn("blocked_head", self.step(), "재판정이 blocked 칸과 같이 지운다")

    def test_rejudge_fix_of_runner_reverted_test_accepted(self):
        # D5: 판정 4가 되돌려 구현 구간 순변화가 0 인 테스트는 검증이 고쳐도 받는다(막다른 길 해소)
        self.red_turn([{"step": 1, "name": "a", "status": "pending", "tdd": True}])
        self.act([RED, ["commit", "test: step 1 — a (red)"]])
        self.assertEqual(self.session("judge", "t1", "--red", "--step", "1").returncode, 0, self.out)
        self.session("prompt", "t1", "--role", "impl")
        self.act([["write", "src/a.txt", "bye"], ["write", "tests/a.expect", "bye"], DONE])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 10, "판정 4가 되돌리고 재시도\n" + self.out)
        self.session("prompt", "t1", "--role", "impl")
        self.act([["status", "blocked", {"blocked_reason": "a 기대값이 틀렸다 — bye"}]])
        self.assertEqual(self.session("judge", "t1", "--step", "1").returncode, 2, self.out)
        fixed = self.fix_tests([("write", "tests/a.expect", "bye")])
        p = self.session("rejudge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 0, "러너가 되돌린 파일은 구현이 바꿔 놓은 채 남은 게 아니다\n" + self.out)
        self.assertEqual(self.step()["red"], fixed)

    def test_rejudge_retry_shows_count_since_rejudge(self):
        self.rejudged_after_three_fails()
        self.fail_impl(1, start=10)
        self.assertIn("재시도 1/", self.out, "재판정 뒤 수를 보인다(전체 4/3 아님)")

    def test_gate_label_inline_strips_marks(self):
        for i, prd in enumerate(("# PRD\n- **남은 ⚠️** — 없음\n", "# PRD\n- **남은 ⚠️:** 없음\n")):
            p = self.session("gate", self.docs(path=f"docs/n{i}", prd=prd))
            self.assertEqual(p.returncode, 0, "굵게 안 콜론 · 줄표 뒤 「없음」은 항목 없음\n" + self.out)
        p = self.session("gate", self.docs(path="docs/o", prd="# PRD\n- **남은 ⚠️:** 결제 재시도 미정\n"))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("PRD: 결제 재시도 미정\n", p.stdout, "앞에 ** 가 붙지 않는다")

    def rejudged(self, ops=(("write", "tests/a.expect", "bye"),)):
        """blocked → 검증이 테스트 고침 → rejudge 통과. (BASE, 구현 wip sha, 고친 테스트 sha)"""
        base, _ = self.blocked_after_red()
        wip = self.wip_sha()
        fixed = self.fix_tests(list(ops))
        self.assertEqual(self.session("rejudge", "t1", "--step", "1").returncode, 0, self.out)
        return base, wip, fixed

    def test_rejudged_impl_already_right_completes(self):
        self.rejudged()
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([DONE])   # 구현이 이미 맞다 — 더 고칠 것이 없다
        p = self.session("judge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 0, "rejudge 뒤 판정 5 는 BASE 뒤 구현 변경을 본다\n" + self.out)
        self.assertEqual(self.step()["status"], "completed")

    def test_rejudged_impl_edit_test_reverted(self):
        _, _, fixed = self.rejudged()
        self.session("prompt", "t1", "--role", "impl")
        self.act([["write", "src/a.txt", "zzz"], ["write", "tests/a.expect", "zzz"], ["commit", "feat: a (테스트도 고침)"], DONE])
        p = self.session("judge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 10, self.out)
        self.assertEqual((self.repo / "tests/a.expect").read_text(), "bye", "새 red(고친 테스트) 기준으로 되돌린다(판정 4)")
        self.assertIn("테스트 파일", self.step()["last_error"])
        self.assertEqual(self.step()["red"], fixed)

    def test_rejudge_round_trip_keeps_impl_and_fixed_test(self):
        # 고친 테스트가 c 기대도 더한다 — 구현 세션이 rejudge 뒤에 더 구현해야 끝난다
        _, wip, fixed = self.rejudged((("write", "tests/a.expect", "bye"), ("write", "tests/c.expect", "c")))
        self.assertEqual(self.session("prompt", "t1", "--role", "impl").returncode, 0, self.out)
        self.act([["write", "src/c.txt", "c"], ["commit", "feat: step 1 — c"], DONE])
        p = self.session("judge", "t1", "--step", "1")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertEqual(self.step()["status"], "completed")
        for sha in (wip, fixed):
            self.assertEqual(git(self.repo, "merge-base", "--is-ancestor", sha, "HEAD").returncode, 0,
                             "구현 커밋과 고친 테스트가 둘 다 브랜치에 남는다(AC-3)")
        self.assertEqual((self.repo / "src/a.txt").read_text(), "bye")
        self.assertEqual((self.repo / "tests/a.expect").read_text(), "bye")
        self.assertEqual((self.repo / "src/c.txt").read_text(), "c")
        self.assertEqual(git(self.repo, "branch", "--list", "sdd-discard/*").stdout.strip(), "")
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "", "사람 손 정리 없이 끝난다")

    def test_blocked_test_prompt_mentions_rejudge(self):
        self.blocked_after_red()
        p = self.session("prompt", "t1", "--role", "test")
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("rejudge t1 --step 1", self.out, "테스트가 틀렸을 때의 다음 수")
        self.assertIn("pending", self.out, "구현이 고칠 일일 때의 다음 수")

    def test_gate_prd_none_item_passes(self):
        for prd in ("# PRD\n## 남은 ⚠️\n\n- 없음 (판정 방식은 ADR)\n",
                    "# PRD\n- **남은 ⚠️**\n  - 없음\n"):
            p = self.session("gate", self.docs(prd=prd))
            self.assertEqual(p.returncode, 0, "「없음」 항목은 항목 없음 표시라 세지 않는다(리뷰 1회차)\n" + self.out)

    def test_gate_prd_none_inside_text_still_counts(self):
        p = self.session("gate", self.docs(prd="# PRD\n## 남은 ⚠️\n- ⚠️ 기본값 없음 처리\n- 없음표 정리\n"))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 2개", p.stdout, "「없음」이 본문 가운데 있거나 낱말 일부면 그대로 센다")

    # ── #86 F4: 관문이 못 보던 꼴 · F6 경로 출력 ─────────────────────────────
    def test_gate_heading_without_fe0f_counts(self):
        for prd in ("# PRD\n## 남은 ⚠\n- 결제 재시도 정책 미정\n",
                    "# PRD\n- **남은 ⚠**\n  - 결제 재시도 정책 미정\n"):
            p = self.session("gate", self.docs(prd=prd))
            self.assertEqual(p.returncode, 2, "변이 선택자 없는 ⚠ 도 같은 표시다\n" + self.out)
            self.assertIn("PRD: 결제 재시도 정책 미정", p.stdout)

    def test_gate_escaped_pipe_cell_counts(self):
        head = "# ADR\n### 결정할 것\n\n| # | 정할 것 | 추천 | 주체 |\n|---|---|---|---|\n"
        p = self.session("gate", self.docs(adr=head + "| R1 | `a \\| b` 중 무엇 | A |  |\n"))
        self.assertEqual(p.returncode, 2, "셀 안 \\| 는 칸 나눔이 아니다 — 주체 칸이 비었다\n" + self.out)
        self.assertIn("ADR R1:", p.stdout)
        p = self.session("gate", self.docs(path="docs/e", adr=head + "| R1 | `a \\| b` 중 무엇 | A | 사용자 |\n"))
        self.assertEqual(p.returncode, 0, "주체가 찬 행은 칸이 밀려도 닫힘\n" + self.out)

    def test_gate_label_inline_content_counts(self):
        p = self.session("gate", self.docs(prd="# PRD\n- **남은 ⚠️**: 결제 재시도 정책 미정\n"))
        self.assertEqual(p.returncode, 2, "라벨 줄에 붙여 쓴 내용도 열린 항목\n" + self.out)
        self.assertIn("PRD: 결제 재시도 정책 미정", p.stdout)
        p = self.session("gate", self.docs(path="docs/e", prd="# PRD\n- **남은 ⚠️**: A 미정\n  - B 미정\n"))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 2개", p.stdout, "붙여 쓴 내용 + 아래 항목")
        for i, prd in enumerate(("# PRD\n- **남은 ⚠️**: 없음\n",
                                 "# PRD\n- **남은 ⚠️**: 재시도 정책 → 결정: ADR-1\n",
                                 "# PRD\n- **남은 ⚠️** (닫힘 표시 규칙은 ADR)\n")):
            p = self.session("gate", self.docs(path=f"docs/c{i}", prd=prd))
            self.assertEqual(p.returncode, 0, "「없음」 · 닫힘 표시 규칙은 같다 · 괄호 설명은 내용이 아니다\n" + self.out)

    def test_gate_numbered_and_plus_bullets_count(self):
        p = self.session("gate", self.docs(prd="# PRD\n## 남은 ⚠️\n1. A 미정\n2) B 미정\n+ C 미정\n"))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 3개", p.stdout, "번호 목록 · + 불렛도 첫 단 항목")
        p = self.session("gate", self.docs(path="docs/e", prd="# PRD\n- **남은 ⚠️**\n  1. D 미정\n"))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("PRD: D 미정", p.stdout)

    def test_gate_no_docs_prints_resolved_path(self):
        p = self.session("gate", "docs/typo-2026")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("docs/typo-2026", p.stdout, "문서 없음 · 경로 오타를 가를 수 있게 해석한 폴더를 같이 낸다")


class VerifySlotTest(unittest.TestCase):
    """검사 상한 대기 (ADR-007) — 다른 세션 검사가 상한 이상이면 판정 전에 기다린다."""

    def setUp(self):
        sys.path.insert(0, str(HERE))
        import sdd_runner
        self.r = sdd_runner

    def test_waits_until_not_busy(self):
        seq = iter([3, 2, 0])
        slept = []
        waited = self.r.wait_for_slot(".", interval=1, timeout=60, busy=lambda _: next(seq), sleep=slept.append)
        self.assertEqual(slept, [1, 1])
        self.assertTrue(waited)

    def test_no_wait_when_idle(self):
        slept = []
        self.assertFalse(self.r.wait_for_slot(".", interval=1, timeout=60, busy=lambda _: 0, sleep=slept.append))
        self.assertEqual(slept, [])

    def test_gives_up_after_timeout(self):
        slept = []
        self.r.wait_for_slot(".", interval=5, timeout=12, busy=lambda _: 4, sleep=slept.append)
        self.assertEqual(sum(slept), 15)   # 12초를 넘긴 첫 시점에 그대로 진행


class TestFilePatternTest(unittest.TestCase):
    """테스트 파일 판정(TEST_FILE) — RED 판정이 셸 테스트 자리를 알아봐야 한다(REVIEW R7)."""

    def setUp(self):
        sys.path.insert(0, str(HERE))
        import sdd_runner
        self.pat = sdd_runner.TEST_FILE

    def test_shell_test_files_are_tests(self):
        for f in ("hooks/test.sh", "test.sh", "hooks/tests/sdd-runner-unit.sh"):
            with self.subTest(f=f):
                self.assertIsNotNone(self.pat.search(f))

    def test_other_shell_scripts_are_not_tests(self):
        # 구현 파일이 테스트로 잡히면 「테스트 커밋에 구현 파일 없음」이 거짓으로 통과한다
        for f in ("hooks/tdd-guard.sh", "scripts/release.sh", "hooks/latest.sh"):
            with self.subTest(f=f):
                self.assertIsNone(self.pat.search(f))


class ErrorTailTest(unittest.TestCase):
    """verify 실패 사유에 붙이는 출력 꼬리(#12) — 끝 40줄 · 실패 이름 줄 우선(최대 10) · 4,000자 상한."""

    def setUp(self):
        sys.path.insert(0, str(HERE))
        import sdd_runner
        self.tail = sdd_runner.error_tail

    def test_error_tail_keeps_last_40_lines(self):
        out = "\n".join(f"row-{i:03d}" for i in range(1, 101))
        t = self.tail(out)
        for i in (61, 80, 100):
            self.assertIn(f"row-{i:03d}", t)
        self.assertNotIn("row-060", t)
        self.assertNotIn("row-001", t)

    def test_error_tail_puts_failing_test_lines_first(self):
        fails = ["  🔴 hook a — 깨짐", "FAIL: test_b (x.Y)", "FAILED tests/c.py::d", "  ✗ e 실패", "\t✕ f 실패"]
        out = "\n".join(fails + [f"row-{i:03d}" for i in range(1, 51)])
        t = self.tail(out)
        for f in fails:
            self.assertIn(f.strip(), t)
        self.assertLess(t.index("hook a"), t.index("row-050"), "실패 이름 줄이 꼬리보다 앞")
        self.assertNotIn("row-010", t)

    def test_error_tail_caps_failing_lines_at_10(self):
        out = "\n".join([f"  🔴 case-{i:02d}" for i in range(1, 16)] + [f"row-{i:03d}" for i in range(1, 51)])
        self.assertEqual(self.tail(out).count("🔴"), 10)

    def test_error_tail_cuts_front_over_4000_chars(self):
        out = "\n".join(f"row-{i:03d} " + "x" * 200 for i in range(1, 41)) + "\n마지막 줄"
        t = self.tail(out)
        self.assertLessEqual(len(t), 4000)
        self.assertIn("…(앞 생략)", t)
        self.assertIn("마지막 줄", t, "자르는 쪽은 앞이다")

    def test_error_tail_short_output_untouched(self):
        t = self.tail("one\ntwo")
        self.assertIn("one", t)
        self.assertNotIn("…(앞 생략)", t)
        self.assertEqual(self.tail(""), "")



# ── 동시 실행 묶음(runner-test-time) — 테스트 대부분이 하위 프로세스를 기다려서 스레드로 동시에 돌린다 ──────────
sys.path.insert(0, str(HERE))
from parallel_suite import ParallelSuite, jobs  # noqa: E402


class ParallelSuiteTest(unittest.TestCase):
    """묶음이 결과를 하나도 잃지 않는다 — 실패를 삼켜 전부 통과로 보이는 것이 가장 큰 약화다."""

    def run_suite(self, tests, n):
        result = unittest.TestResult()
        ParallelSuite(tests, n).run(result)
        return result

    def test_failures_errors_skips_carried_over(self):
        # AC-1: 실패 · 에러 · 건너뜀 · 예상한 실패 · 예상 밖 성공이 그 테스트와 함께 옮겨진다 · 중첩 묶음도 펼친다
        class C(unittest.TestCase):
            def test_ok(self):
                pass

            def test_fail(self):
                self.fail("일부러 실패")

            def test_error(self):
                raise RuntimeError("일부러 에러")

            @unittest.skip("건너뛴 이유")
            def test_skip(self):
                pass

            @unittest.expectedFailure
            def test_xfail(self):
                self.fail("예상한 실패")

            @unittest.expectedFailure
            def test_xpass(self):
                pass

        nested = unittest.TestSuite([unittest.TestSuite([C("test_ok"), C("test_fail"), C("test_error")]),
                                     unittest.TestSuite([C("test_skip"), C("test_xfail"), C("test_xpass")])])
        r = self.run_suite(nested, 3)
        names = lambda xs: [x[0]._testMethodName for x in xs]
        self.assertEqual(r.testsRun, 6)
        self.assertEqual(names(r.failures), ["test_fail"])
        self.assertIn("일부러 실패", r.failures[0][1])
        self.assertEqual(names(r.errors), ["test_error"])
        self.assertIn("RuntimeError: 일부러 에러", r.errors[0][1])
        self.assertEqual([(x._testMethodName, why) for x, why in r.skipped], [("test_skip", "건너뛴 이유")])
        self.assertEqual(names(r.expectedFailures), ["test_xfail"])
        self.assertEqual([x._testMethodName for x in r.unexpectedSuccesses], ["test_xpass"])

    def test_any_failure_makes_run_unsuccessful(self):
        # AC-1: 하나라도 실패면 전체가 실패로 보인다 · 다 통과면 통과
        class C(unittest.TestCase):
            def test_ok(self):
                pass

            def test_fail(self):
                self.assertEqual(1, 2)

        bad = self.run_suite([C("test_ok") for _ in range(5)] + [C("test_fail")], 3)
        self.assertEqual(bad.testsRun, 6)
        self.assertFalse(bad.wasSuccessful())
        good = self.run_suite([C("test_ok") for _ in range(6)], 3)
        self.assertEqual(good.testsRun, 6)
        self.assertTrue(good.wasSuccessful())

    def test_runs_tests_concurrently(self):
        # AC-2: jobs 3 이면 세 테스트가 동시에 돌아야 장벽이 풀린다(시간 대신 장벽 — 부하에 흔들리지 않는다)
        import threading
        barrier = threading.Barrier(3, timeout=10)

        class C(unittest.TestCase):
            def test_a(self):
                barrier.wait()
            test_b = test_c = test_a

        r = self.run_suite([C("test_a"), C("test_b"), C("test_c")], 3)
        self.assertEqual((r.testsRun, r.errors, r.failures), (3, [], []), "세 테스트가 동시에 돌지 않았다")

    def test_jobs_one_runs_serially(self):
        # AC-2: jobs 1 이면 동시에 도는 테스트가 1개를 넘지 않는다
        import threading
        import time
        lock, seen = threading.Lock(), {"now": 0, "max": 0}

        class C(unittest.TestCase):
            def test_a(self):
                with lock:
                    seen["now"] += 1
                    seen["max"] = max(seen["max"], seen["now"])
                time.sleep(0.05)
                with lock:
                    seen["now"] -= 1
            test_b = test_c = test_d = test_a

        r = self.run_suite([C("test_a"), C("test_b"), C("test_c"), C("test_d")], 1)
        self.assertEqual(r.testsRun, 4)
        self.assertEqual(seen["max"], 1)

    def test_jobs_env_blank_or_invalid_uses_default(self):
        # AC-3: 환경을 인자로 받는다(테스트가 os.environ 을 바꾸지 않게 — 동시 실행 중 공유 상태)
        default = min(3, os.cpu_count() or 1)
        for v in (None, "", "0", "-2", "abc", "1.5"):
            env = {} if v is None else {"RUNNER_TEST_JOBS": v}
            self.assertEqual(jobs(env), default, repr(v))
        self.assertEqual(jobs({"RUNNER_TEST_JOBS": "1"}), 1)
        self.assertEqual(jobs({"RUNNER_TEST_JOBS": "8"}), 8)


    def test_subtest_failure_carried_over(self):
        # AC-1 · REVIEW 1회차 🟡: subTest 실패도 그 subTest 이름과 함께 옮겨진다
        class C(unittest.TestCase):
            def test_sub(self):
                for i in range(3):
                    with self.subTest(i=i):
                        self.assertNotEqual(i, 1)

        r = self.run_suite([C("test_sub")], 3)
        self.assertEqual(len(r.failures), 1)
        self.assertIn("(i=1)", str(r.failures[0][0]))
        self.assertFalse(r.wasSuccessful())

    def fixture_summary(self, r):
        return (r.testsRun, sorted(str(t) for t, _ in r.failures), sorted(str(t) for t, _ in r.errors),
                sorted(str(t) for t, _ in r.skipped))

    def test_class_fixture_matches_plain_suite(self):
        # AC-1 · REVIEW 1회차 🟡: setUpClass 를 쓰는 클래스는 결과가 일반 묶음과 같다 — 준비 실패가 숨거나 통과로 세지지 않는다
        class Broken(unittest.TestCase):
            @classmethod
            def setUpClass(cls):
                raise RuntimeError("준비 실패")

            def test_a(self):
                pass

            def test_b(self):
                pass

        class Ready(unittest.TestCase):
            @classmethod
            def setUpClass(cls):
                cls.value = 42

            @classmethod
            def tearDownClass(cls):
                del cls.value

            def test_uses_value(self):
                self.assertEqual(self.value, 42)

        class Plain(unittest.TestCase):
            def test_x(self):
                pass

        make = lambda: [Broken("test_a"), Broken("test_b"), Ready("test_uses_value"), Plain("test_x")]
        plain = unittest.TestResult()
        unittest.TestSuite(make()).run(plain)
        par = self.run_suite(make(), 3)
        self.assertEqual(self.fixture_summary(par), self.fixture_summary(plain))
        self.assertTrue(any("setUpClass" in str(t) for t, _ in par.errors), "준비 실패가 보인다")

    def test_module_fixture_matches_plain_suite(self):
        # AC-1 · REVIEW 1회차 🟡: setUpModule 이 있는 모듈의 테스트도 결과가 일반 묶음과 같다
        import types
        mod = types.ModuleType("parallel_suite_fixture_probe")
        state = {}

        def setUpModule():
            state["ready"] = True

        def tearDownModule():
            state.clear()

        mod.setUpModule, mod.tearDownModule = setUpModule, tearDownModule
        sys.modules[mod.__name__] = mod   # 이 클래스는 묶음 밖에서 차례로 돈다(load_tests) — 동시 실행 중 공유 상태가 아니다
        self.addCleanup(sys.modules.pop, mod.__name__, None)

        class M(unittest.TestCase):
            def test_ready(self):
                self.assertTrue(state.get("ready"))

        M.__module__ = mod.__name__
        plain = unittest.TestResult()
        unittest.TestSuite([M("test_ready")]).run(plain)
        par = self.run_suite([M("test_ready")], 3)
        self.assertEqual(self.fixture_summary(par), self.fixture_summary(plain))
        self.assertTrue(par.wasSuccessful(), par.failures + par.errors)

    def test_guard_tests_run_outside_parallel_suite(self):
        # AC-1 · REVIEW 1회차 🟡: 묶음을 검증하는 이 클래스가 묶음 안에서 돌면 실패를 버리는 변이에 같이 눈이 먼다
        loader = unittest.TestLoader()
        loaded = unittest.TestSuite([loader.loadTestsFromTestCase(ParallelSuiteTest),
                                     loader.loadTestsFromTestCase(TestFilePatternTest)])

        def walk(s, inside):
            for x in s:
                if isinstance(x, unittest.TestSuite):
                    yield from walk(x, inside or isinstance(x, ParallelSuite))
                else:
                    yield x, inside

        seen = list(walk(load_tests(loader, loaded, None), False))
        self.assertEqual(len(seen), loaded.countTestCases())
        for x, inside in seen:
            self.assertEqual(inside, not isinstance(x, ParallelSuiteTest), x.id())


def load_tests(loader, tests, pattern):
    """`python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 가 이 묶음으로 돈다. RUNNER_TEST_JOBS=1 이면 차례 실행.
    묶음을 검증하는 ParallelSuiteTest 는 묶음 밖(일반 묶음)에서 먼저 돈다 — 안에서 돌면 실패를 버리는 변이에 같이 눈이 먼다(REVIEW 1회차)."""
    guard, rest = [], []

    def walk(s):
        for x in s:
            if isinstance(x, unittest.TestSuite):
                walk(x)
            else:
                (guard if isinstance(x, ParallelSuiteTest) else rest).append(x)

    walk(tests)
    return unittest.TestSuite([unittest.TestSuite(guard), ParallelSuite(rest, jobs(os.environ))])


if __name__ == "__main__":
    unittest.main()
