#!/usr/bin/env python3
"""SDD 러너 — phases/{task}/ 의 pending step 을 하나씩 구현하고 git 기록으로 판정한다.

강의 harness_framework 의 execute.py 뼈대(step 당 claude -p 1번 · 직전 에러를 붙여 재시도 · 시간 기록 · 원문 로그 ·
타임아웃)에 우리 하네스가 실측으로 얻은 검사를 더했다. 강의는 에이전트가 index.json 에 스스로 적은 status 만 믿는다.
여기서는 그 status 에 더해 실행 결과(is_error·종료 코드)와 git 기록(RED 커밋 순서·RED 가 실제로 실패하나·테스트
파일 수정·변경 유무·verify)을 러너가 직접 본다. 판정 표의 정본은 docs/sdd-runner.md.

세션 안 harness-run 과 같은 규칙을 쓴다 — 두 러너가 이 파일의 prompt·judge 를 같이 부른다.

  sdd_runner.py run TASK [--timeout 1800] [--max-retries 3]   헤드리스: claude -p 로 끝까지
  sdd_runner.py start TASK                                    시작 전 점검 + 브랜치 (세션 안)
  sdd_runner.py prompt TASK                                   다음 pending step 의 지시문 출력 (세션 안)
  sdd_runner.py judge TASK --base SHA [--max-retries 3]       방금 끝난 step 판정·기록 (세션 안)

종료 코드: 0 완료 · 1 실패로 멈춤 · 2 blocked(사람 필요) · 10 재시도(judge 만)
claude 실행 파일은 SDD_RUNNER_CLAUDE 로 바꿀 수 있다(테스트용 가짜).
"""
import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from string import Template

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import phases_status  # noqa: E402

TZ = timezone(timedelta(hours=9))
VALID = {"pending", "completed", "error", "blocked"}
# 테스트 파일 판별 — tdd-guard 의 짝 테스트 자리와 같은 계열(TS *.test/*.spec · __tests__ · tests/ · JVM *Test.kt · py test_*)
TEST_FILE = re.compile(r"(\.(test|spec)\.[^/]+$|(^|/)__tests__/|(^|/)tests?/|(^|/)src/test/|Tests?\.(kt|java)$|(^|/)test_[^/]+\.py$|_test\.(py|go)$)")
OUTPUT_GLOB = "phases/*/step*-output.json"


def stamp() -> str:
    return datetime.now(TZ).strftime("%Y-%m-%dT%H:%M:%S%z")


class Fail(Exception):
    """판정 실패 — 재시도 대상."""


class Runner:
    def __init__(self, task: str, max_retries: int = 3, timeout: int = 1800):
        r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit("git 레포가 아니다")
        self.root = Path(r.stdout.strip())
        self.task = task
        self.dir = self.root / "phases" / task
        self.index_file = self.dir / "index.json"
        self.max_retries = max_retries
        self.timeout = timeout
        cfg_file = self.root / ".claude/harness.json"
        self.cfg = json.loads(cfg_file.read_text(encoding="utf-8")) if cfg_file.exists() else {}

    # ── 공용 ───────────────────────────────────────────────────────────────
    def git(self, *args, check=False) -> subprocess.CompletedProcess:
        r = subprocess.run(["git", *args], cwd=self.root, capture_output=True, text=True)
        if check and r.returncode != 0:
            raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
        return r

    def read(self) -> dict:
        return json.loads(self.index_file.read_text(encoding="utf-8"))

    def write(self, idx: dict):
        self.index_file.write_text(json.dumps(idx, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    def find(self, idx: dict, n: int) -> dict:
        return next(s for s in idx["steps"] if s["step"] == n)

    def next_pending(self):
        return next((s for s in self.read()["steps"] if s.get("status") == "pending"), None)

    def verify_cmds(self, only=None) -> list:
        """[(root, 이름, 명령)] — 단일 앱({"test": …})과 앱별({"apps/api": {"test": …}}) 둘 다."""
        out = []
        for k, v in (self.cfg.get("verify") or {}).items():
            if k.startswith("$"):
                continue
            if isinstance(v, dict):
                out += [(k, kk, c) for kk, c in v.items() if not kk.startswith("$") and isinstance(c, str) and c.strip()]
            elif isinstance(v, str) and v.strip():
                out.append((".", k, v))
        return [c for c in out if only is None or c[1] == only]

    def run_cmd(self, root: str, cmd: str) -> bool:
        return subprocess.run(cmd, shell=True, cwd=self.root / root, capture_output=True).returncode == 0

    def commit(self, msg: str, paths=None):
        if paths:
            self.git("add", "-f", "--", *paths)
        else:  # 진행 중인 index.json 은 메타데이터 커밋만 담는다
            self.git("add", "-A", "--", ".", f":(exclude)phases/{self.task}")
        if self.git("diff", "--cached", "--quiet").returncode != 0:
            self.git("commit", "-q", "-m", msg, "-m", f"phase: {self.task}", check=True)

    def commit_index(self, n: int):
        self.commit(f"chore: update phase index for step {n}", [str(self.index_file.relative_to(self.root))])

    # ── 시작 전 ────────────────────────────────────────────────────────────
    def start(self) -> int:
        if not self.index_file.exists():
            print(f"{self.index_file} 이 없다")
            return 1
        phases = phases_status.load(self.root / "phases")
        probs = phases_status.problems_of(self.task, phases[self.task], phases)
        if probs:
            print(f"{self.task} 을(를) 돌리지 않는다:\n" + "\n".join(f"  - {p}" for p in probs))
            return 1
        for s in self.read()["steps"]:
            if s.get("status") in ("error", "blocked"):
                why = s.get("error_message") or s.get("blocked_reason") or ""
                print(f"step {s['step']} 이 {s['status']} 다 — 원인을 고치고 pending 으로 되돌린 뒤 다시 실행: {why}")
                return 2 if s["status"] == "blocked" else 1
        exclude = Path(self.git("rev-parse", "--git-path", "info/exclude").stdout.strip())
        exclude = exclude if exclude.is_absolute() else self.root / exclude
        if OUTPUT_GLOB not in (exclude.read_text() if exclude.exists() else ""):
            exclude.parent.mkdir(parents=True, exist_ok=True)
            with exclude.open("a") as f:
                f.write(f"\n{OUTPUT_GLOB}\n")
        if self.git("status", "--porcelain").stdout.strip():
            print("작업 트리가 깨끗하지 않다 — 커밋하거나 stash 한 뒤 실행한다(판정이 git 기록을 본다)")
            return 1
        tdd_on = (self.cfg.get("tdd") or {}).get("enabled", False)
        if not tdd_on and any(s.get("tdd") for s in self.read()["steps"]):
            print("⚠️ tdd.enabled 가 false 다 — tdd-guard 훅 없이 돈다. 테스트 먼저는 러너의 사후 검사로만 확인한다")
        branch = f"feat-{self.task}"
        if self.git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip() != branch:
            exists = self.git("rev-parse", "--verify", "--quiet", branch).returncode == 0
            r = self.git("checkout", "-q", branch) if exists else self.git("checkout", "-q", "-b", branch)
            if r.returncode != 0:
                print(f"브랜치 {branch} 로 못 옮김: {r.stderr.strip()}")
                return 1
        return 0

    # ── 지시문 ─────────────────────────────────────────────────────────────
    def guardrails(self, idx: dict) -> str:
        parts = []
        cm = self.root / "CLAUDE.md"
        if cm.exists():
            parts.append(f"## 프로젝트 규칙 (CLAUDE.md)\n\n{cm.read_text(encoding='utf-8')}")
        docs = idx.get("docs")
        for name in ("PRD", "ARCHITECTURE", "ADR"):
            f = self.root / docs / f"{name}.md" if docs else None
            if f and f.exists():
                parts.append(f"## {name}\n\n{f.read_text(encoding='utf-8')}")
        return "\n\n---\n\n".join(parts)

    def prompt(self, step: dict) -> str:
        idx = self.read()
        done = [f"- Step {s['step']} ({s['name']}): {s['summary']}" for s in idx["steps"]
                if s.get("status") == "completed" and s.get("summary")]
        n, name = step["step"], step["name"]
        if step.get("tdd"):
            tdd = (f"4. 테스트 먼저(TDD): ① 수용 조건을 **실패하는 테스트**로 먼저 쓰고 테스트 명령이 실패하는지 확인한 뒤 "
                   f"테스트 파일만 `test: step {n} — {name} (red)` 로 커밋 ② 구현한다. 테스트 파일은 다시 고치지 않는다 "
                   f"③ 구현을 `feat: step {n} — {name}` 로 커밋")
        else:
            tdd = f"4. 이 step 은 테스트 단계가 없다(이유는 step 파일). 구현을 `feat: step {n} — {name}` 로 커밋"
        retry = ""
        if step.get("last_error"):
            retry = f"## ⚠ 이전 시도 실패 — 아래 사유를 반드시 참고해 고친다\n\n{step['last_error']}\n\n---\n\n"
        cmds = " · ".join(f"`{c}`" + (f"({r} 에서)" if r != "." else "") for r, _, c in self.verify_cmds()) or "(verify 없음)"
        return Template((HERE / "preamble.md").read_text(encoding="utf-8")).safe_substitute(
            project=idx.get("project", self.root.name), task=self.task, step=n,
            guardrails=self.guardrails(idx),
            done_steps=("## 이전 step 산출물\n\n" + "\n".join(done) + "\n\n") if done else "",
            retry=retry, tdd_rule=tdd, verify_cmds=cmds,
            step_md=(self.dir / f"step{n}.md").read_text(encoding="utf-8"))

    # ── 판정 ───────────────────────────────────────────────────────────────
    def commits_since(self, base: str) -> list:
        """[(sha, [파일])] 오래된 것부터."""
        out = []
        for sha in self.git("rev-list", "--reverse", f"{base}..HEAD").stdout.split():
            files = self.git("diff-tree", "--no-commit-id", "--name-only", "-r", sha).stdout.split()
            out.append((sha, [f for f in files if not f.startswith(f"phases/{self.task}/")]))
        return [c for c in out if c[1]]

    def check(self, step: dict, base: str):
        """판정 1~6. 통과면 None, 아니면 Fail. blocked 는 그대로 돌려준다."""
        st = step.get("status")
        if st == "blocked":
            return "blocked"
        if st == "error":
            raise Fail(step.get("error_message") or "에이전트가 error 로 보고")
        if st == "pending":
            raise Fail("에이전트가 index.json 의 status 를 갱신하지 않음")
        if st not in VALID:
            raise Fail(f"허용 밖 status '{st}'")
        # 남은 코드 변경은 러너가 구현 커밋으로 묶는다(강의 execute.py 의 2단계 커밋 중 코드 쪽).
        # 훅 기록 파일(.claude/.last-*)은 .gitignore 가 없는 레포에서도 빼낸다(10-13 실가동에서 섞임)
        rest = [".", f":(exclude)phases/{self.task}", ":(exclude).claude/.last-*"]
        if self.git("status", "--porcelain", "--", *rest).stdout.strip():
            self.git("add", "-A", "--", *rest)
            self.git("commit", "-q", "-m", f"feat: step {step['step']} — {step['name']}", "-m", f"phase: {self.task}")
        commits = self.commits_since(base)
        if step.get("tdd"):
            red = next((c for c in commits if any(TEST_FILE.search(f) for f in c[1])), None)
            if red is None:
                raise Fail("RED: 테스트 커밋이 없다")
            before = commits[:commits.index(red)]
            impl_in_red = [f for f in red[1] if not TEST_FILE.search(f)]
            if before or impl_in_red:
                raise Fail("RED: 테스트 커밋이 구현보다 먼저가 아니다 — 테스트 파일만 먼저 커밋한다"
                           + (f" (같이 커밋된 구현: {', '.join(impl_in_red[:3])})" if impl_in_red else ""))
            tests = self.verify_cmds("test")
            if not tests:
                raise Fail("RED: verify.test 가 없어 테스트를 돌릴 수 없다")
            if self.red_passes(red[0], tests):
                raise Fail("RED: 테스트가 아무것도 잡지 않음 — 테스트 커밋 시점에 이미 통과한다")
            changed = [f for f in self.git("diff", "--name-only", f"{red[0]}..HEAD").stdout.split()
                       if TEST_FILE.search(f) and not f.startswith("phases/")]
            if changed:
                for f in changed:
                    if self.git("cat-file", "-e", f"{red[0]}:{f}").returncode == 0:
                        self.git("checkout", red[0], "--", f)
                    else:
                        self.git("rm", "-q", "-f", "--", f)
                self.commit(f"test: step {step['step']} — 테스트 수정 되돌림")
                raise Fail(f"GREEN: 테스트 파일을 고쳤다(되돌림): {', '.join(changed[:5])} — 테스트는 그대로 두고 구현을 고친다")
        if not commits:
            raise Fail("completed 보고인데 변경 없음")
        for root, name, cmd in self.verify_cmds():
            if not self.run_cmd(root, cmd):
                raise Fail(f"verify 실패: {name} (`{cmd}`)")
        return None

    def red_passes(self, sha: str, tests: list) -> bool:
        """테스트 커밋 시점으로 잠깐 옮겨 verify.test 를 돌린다. 의존성(node_modules 등)이 있는 이 작업 트리 그대로."""
        head = self.git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
        idx_rel = str(self.index_file.relative_to(self.root))
        stashed = bool(self.git("status", "--porcelain", "--", idx_rel).stdout.strip())
        if stashed:  # 진행 중인 index.json(아직 커밋 전)이 체크아웃을 막지 않게 잠깐 치운다
            self.git("stash", "push", "-q", "--", idx_rel, check=True)
        try:
            self.git("checkout", "-q", "--detach", sha, check=True)
            try:
                return all(self.run_cmd(root, cmd) for root, _, cmd in tests)
            finally:
                self.git("checkout", "-q", head, check=True)
        finally:
            if stashed:
                self.git("stash", "pop", "-q", check=True)

    def record(self, n: int, base: str, run_failure=None, usage=None) -> int:
        """판정하고 index.json 에 기록·커밋. 0 완료 · 10 재시도 · 1 실패로 멈춤 · 2 blocked."""
        try:
            if run_failure:
                raise Fail(run_failure)
            res = self.check(self.find(self.read(), n), base)
        except Fail as e:
            res, reason = "fail", str(e)
        idx = self.read()
        s = self.find(idx, n)
        if usage:
            u = s.setdefault("usage", {})
            for k, v in usage.items():
                if isinstance(v, (int, float)):
                    u[k] = u.get(k, 0) + v
        if res == "blocked":
            s["blocked_at"] = stamp()
            self.write(idx)
            self.commit_index(n)
            print(f"⏸ step {n} blocked: {s.get('blocked_reason', '')}")
            return 2
        if res is None:
            s["completed_at"] = stamp()
            s.pop("last_error", None)
            s.pop("error_message", None)
            self.write(idx)
            self.commit_index(n)
            print(f"✓ step {n} {s['name']}: {s.get('summary', '')}")
            return 0
        # retries = 지금까지 한 재시도 수. 3이면 더 재시도하지 않는다(첫 시도 + 재시도 3 = 최대 4회 — harness-run·sdd 와 같은 문장)
        if s.get("retries", 0) >= self.max_retries:
            s.update(status="error", error_message=f"[{s.get('retries', 0) + 1}회 시도 후 실패] {reason}", failed_at=stamp())
            s.pop("last_error", None)
            self.write(idx)
            self.commit_index(n)
            print(f"✗ step {n} 실패로 멈춤: {reason}")
            return 1
        s["retries"] = s.get("retries", 0) + 1
        s.update(status="pending", last_error=reason)
        s.pop("error_message", None)
        self.write(idx)
        print(f"↻ step {n} 재시도 {s['retries']}/{self.max_retries}: {reason}")
        return 10

    # ── 헤드리스 ───────────────────────────────────────────────────────────
    def invoke(self, step: dict):
        """claude -p 1번. (실행 실패 사유 또는 None, usage)."""
        claude = os.environ.get("SDD_RUNNER_CLAUDE", "claude")
        cmd = [claude, "-p", "--dangerously-skip-permissions", "--output-format", "json"]
        if step.get("model"):
            cmd += ["--model", step["model"]]
        cmd.append(self.prompt(step))
        out = {"step": step["step"], "attempt": step.get("retries", 0) + 1, "started_at": stamp()}
        try:
            p = subprocess.run(cmd, cwd=self.root, capture_output=True, text=True, timeout=self.timeout)
            out.update(exitCode=p.returncode, stdout=p.stdout, stderr=p.stderr)
        except subprocess.TimeoutExpired as e:
            out.update(timeout=self.timeout, stdout=(e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or ""))
            self.save_output(step, out)
            return f"실행 실패: 타임아웃 {self.timeout}초", None
        self.save_output(step, out)
        try:
            res = json.loads(p.stdout.strip().splitlines()[-1]) if p.stdout.strip() else {}
        except (json.JSONDecodeError, IndexError):
            res = {}
        usage = dict(res.get("usage") or {})
        for k in ("num_turns", "duration_ms", "total_cost_usd"):
            if isinstance(res.get(k), (int, float)):
                usage[k] = res[k]
        if p.returncode != 0 or res.get("is_error") or not res:
            why = "is_error" if res.get("is_error") else f"종료 코드 {p.returncode}" if p.returncode else "결과 JSON 없음"
            return f"실행 실패: {why} — {str(res.get('result', p.stderr))[:200]}", usage
        return None, usage

    def save_output(self, step: dict, out: dict):
        f = self.dir / f"step{step['step']}-output.json"
        hist = json.loads(f.read_text()) if f.exists() else []
        hist = hist if isinstance(hist, list) else [hist]
        hist.append(out)
        f.write_text(json.dumps(hist, indent=2, ensure_ascii=False))

    def run(self) -> int:
        rc = self.start()
        if rc:
            return rc
        while True:
            step = self.next_pending()
            if step is None:
                print(f"✓ phase {self.task} 완료")
                return 0
            n = step["step"]
            base = self.git("rev-parse", "HEAD").stdout.strip()
            idx = self.read()
            s = self.find(idx, n)
            s.setdefault("started_at", stamp())
            self.write(idx)
            while True:
                failure, usage = self.invoke(self.find(self.read(), n))
                rc = self.record(n, base, failure, usage)
                if rc != 10:
                    break
            if rc:
                return rc


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="SDD 러너")
    ap.add_argument("mode", choices=["run", "start", "prompt", "judge"])
    ap.add_argument("task")
    ap.add_argument("--timeout", type=int, default=1800)
    ap.add_argument("--max-retries", type=int, default=3)
    ap.add_argument("--base")
    a = ap.parse_args(argv)
    r = Runner(a.task, a.max_retries, a.timeout)
    if a.mode == "run":
        return r.run()
    if a.mode == "start":
        return r.start()
    step = r.next_pending()
    if step is None:
        print("pending step 없음")
        return 0
    if a.mode == "prompt":
        print(r.prompt(step))
        return 0
    if not a.base:
        ap.error("judge 는 --base <step 시작 전 HEAD> 가 필요하다")
    return r.record(step["step"], a.base)


if __name__ == "__main__":
    sys.exit(main())
