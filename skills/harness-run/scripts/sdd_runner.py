#!/usr/bin/env python3
"""SDD 러너 — phases/{task}/ 의 pending step 을 하나씩 구현하고 git 기록으로 판정한다.

강의 harness_framework 의 execute.py 뼈대(step 당 claude -p 1번 · 직전 에러를 붙여 재시도 · 시간 기록 · 원문 로그 ·
타임아웃)에 우리 하네스가 실측으로 얻은 검사를 더했다. 강의는 에이전트가 index.json 에 스스로 적은 status 만 믿는다.
여기서는 그 status 에 더해 실행 결과(is_error·종료 코드)와 git 기록(RED 커밋 순서·RED 가 실제로 실패하나·테스트
파일 수정·변경 유무·verify)을 러너가 직접 본다. 판정 표의 정본은 docs/sdd-runner.md.

세션 안 harness-run 과 같은 규칙을 쓴다 — 두 러너가 이 파일의 prompt·judge 를 같이 부른다.

  sdd_runner.py run TASK [--timeout 1800] [--max-retries 3]   헤드리스: claude -p 로 끝까지
  sdd_runner.py start TASK                                    시작 전 점검 + 브랜치 (세션 안)
  sdd_runner.py prompt TASK [--base SHA]                      다음 pending step 의 지시문 출력, stderr 에 "▶ step N" (세션 안)
  sdd_runner.py judge TASK --step N --base SHA                step N 판정·기록 (세션 안. BASE 는 그 step 시작 전 HEAD)

종료 코드: 0 완료 · 1 실패로 멈춤 · 2 blocked(사람 필요) · 10 재시도(judge 만)
claude 실행 파일은 SDD_RUNNER_CLAUDE 로 바꿀 수 있다(테스트용 가짜).
"""
import argparse
import fnmatch
import json
import os
import re
import shlex
import signal
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
MEASURE_SUMMARY = re.compile(r"`[^`]+`")   # kind: measure step 의 summary 에 있어야 하는 측정 명령(백틱) — #8
# 테스트 파일 판별 — tdd-guard 의 짝 테스트 자리와 같은 계열(TS *.test/*.spec · __tests__ · tests/ · JVM *Test.kt · py test_*)
TEST_FILE = re.compile(r"(\.(test|spec)\.[^/]+$|(^|/)__tests__/|(^|/)tests?/|(^|/)src/test/|Tests?\.(kt|java)$|(^|/)test_[^/]+\.py$|_test\.(py|go)$)")
OUTPUT_GLOB = "phases/*/step*-output.json"
HOOK_STAMPS = ":(exclude).claude/.last-*"   # 훅 기록 파일 — .gitignore 가 없는 레포에서도 커밋에 섞지 않는다(10-13 실가동)


def stamp() -> str:
    return datetime.now(TZ).strftime("%Y-%m-%dT%H:%M:%S%z")


class Fail(Exception):
    """판정 실패 — 재시도 대상."""


class PhaseFail(Exception):
    """phase 마지막 step 의 전체 verify 가 깨졌는데 이 step 범위는 통과 — 앞 step 탓이라 재시도하지 않고 사람에게."""


class RedFail(Fail):
    """RED 순서·RED 가 아무것도 안 잡음 — 이 시도의 커밋을 버리고 BASE 에서 다시 해야 고칠 수 있다."""


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

    def step_override(self, root: str, name: str):
        """앱(또는 단일 앱 verify)의 `$step` 에 적힌 step 명령. `$` 키라 verify_cmds 는 전체 명령으로 모으지 않는다."""
        v = self.cfg.get("verify") or {}
        m = v if root == "." else v.get(root)
        o = m.get("$step") if isinstance(m, dict) else None
        c = o.get(name) if isinstance(o, dict) else None
        return c if isinstance(c, str) and c.strip() else None

    def scoped(self, cmds: list, since: str) -> list:
        """step 명령이 있는 것만 바꾼다. {since} = 그 step 시작 커밋(명령이 git diff 로 바뀐 파일을 스스로 고른다)."""
        return [(r, n, o.replace("{since}", shlex.quote(since)) if (o := self.step_override(r, n)) else c)
                for r, n, c in cmds]

    def is_last(self, step: dict) -> bool:
        return all(s.get("status") == "completed" for s in self.read()["steps"] if s["step"] != step["step"])

    def full_reason(self, step: dict):
        """step 명령 대신 전체 명령을 쓸 이유. 재개 step 은 앞 시도의 wip 커밋이 {since} 앞에 있어 범위가 빈다."""
        if self.is_last(step):
            return "phase 마지막 step"
        if step.get("resumed_at"):
            return "재개한 step"
        return None

    def run_cmd(self, root: str, cmd: str) -> bool:
        cwd = self.root / root
        if not cwd.is_dir():   # 그 시점에 앱 폴더가 아직 없으면 실행할 수 없다 = 통과 아님
            return False
        return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True).returncode == 0

    def commit(self, msg: str, paths=None):
        if paths:
            self.git("add", "-f", "--", *paths)
        else:  # 진행 중인 index.json 은 메타데이터 커밋만 담는다
            self.git("add", "-A", "--", ".", f":(exclude)phases/{self.task}", HOOK_STAMPS)
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
        # 이 phase 의 index.json 은 빼고 본다 — 재개할 때 사람이 status·error_message 를 고친 채로 온다
        if self.git("status", "--porcelain", "--", ".", f":(exclude)phases/{self.task}", HOOK_STAMPS).stdout.strip():
            print("작업 트리가 깨끗하지 않다 — 커밋하거나 stash 한 뒤 실행한다(판정이 git 기록을 본다)")
            return 1
        steps = self.read()["steps"]
        if any(s.get("tdd") for s in steps) and not self.verify_cmds("test"):
            print("tdd: true step 이 있는데 harness.json verify.test 가 없다 — RED 를 확인할 수 없어 돌리지 않는다")
            return 1
        bad = [s["step"] for s in steps if s.get("kind") == "measure" and s.get("tdd")]
        if bad:
            print(f"kind: measure step 은 tdd: true 를 가질 수 없다(코드 변경이 없는 step 이다): step {bad}")
            return 1
        tdd_on = (self.cfg.get("tdd") or {}).get("enabled", False)
        if not tdd_on and any(s.get("tdd") for s in steps):
            print("⚠️ tdd.enabled 가 false 다 — tdd-guard 훅 없이 돈다. 테스트 먼저는 러너의 사후 검사로만 확인한다")
        if os.environ.get("ANTHROPIC_API_KEY"):
            print("⚠️ ANTHROPIC_API_KEY 가 설정돼 있다 — 헤드리스 claude -p 는 이 키가 있으면 항상 API 로 과금된다(공식 문서). "
                  "구독으로 돌리려면 unset 후 실행")
        # 브랜치 이름은 레포 규칙(harness.json git.branchPattern)을 따른다. 없으면 feat-{task} (#4, 2026-10-15)
        gcfg = self.cfg.get("git") or {}
        pattern = gcfg.get("branchPattern") or "feat-{task}"
        if "{task}" not in pattern:
            print(f"git.branchPattern 에 {{task}} 가 없다: {pattern!r}")
            return 1
        branch = pattern.replace("{task}", self.task)
        cur = self.git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
        prefix = pattern.split("{task}")[0]
        # 규칙을 적은 레포에서 이미 규칙에 맞는 브랜치(트랙 worktree 등)에 있으면 그대로 쓴다 — 주제 이름이 task 와 달라도
        if gcfg.get("branchPattern") and prefix and cur != branch and cur.startswith(prefix) \
                and cur not in (gcfg.get("baseBranch") or "", "main", "master"):
            print(f"현재 브랜치 {cur} 가 규칙({pattern})에 맞아 그대로 쓴다")
        elif cur != branch:
            exists = self.git("rev-parse", "--verify", "--quiet", branch).returncode == 0
            r = self.git("checkout", "-q", branch) if exists else self.git("checkout", "-q", "-b", branch)
            if r.returncode != 0:
                print(f"브랜치 {branch} 로 못 옮김: {r.stderr.strip()}")
                return 1
        # 재개: 멈췄던 step 을 사람이 pending 으로 되돌렸으면 이번 실행의 재시도 한도를 새로 센다(retries 계수기는 그대로)
        idx = self.read()
        for s in idx["steps"]:
            stopped = max(s.get("failed_at", ""), s.get("blocked_at", ""))
            if s.get("status") == "pending" and stopped and stopped > s.get("resumed_at", ""):
                s["resumed_at"] = stamp()
                self.write(idx)
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

    def prompt(self, step: dict, base=None) -> str:
        idx = self.read()
        done = [f"- Step {s['step']} ({s['name']}): {s['summary']}" for s in idx["steps"]
                if s.get("status") == "completed" and s.get("summary")]
        n, name = step["step"], step["name"]
        if step.get("kind") == "measure":
            tdd = ("4. 이 step 은 **측정 전용(kind: measure)** 이다 — 코드를 바꾸지 않는다. 측정·실측·대조만 하고, 실행한 **명령(백틱)과 결과**를 "
                   "`summary` 에 적는다. 그것이 이 step 의 산출물이라 summary 에 명령이 없으면 실패로 판정된다. 커밋할 것은 없다")
        elif step.get("tdd"):
            tdd = (f"4. 테스트 먼저(TDD): ① 수용 조건을 **실패하는 테스트**로 먼저 쓰고 테스트 명령이 실패하는지 확인한 뒤 "
                   f"테스트 파일만 `test: step {n} — {name} (red)` 로 커밋 ② 구현한다. 테스트 파일은 다시 고치지 않는다 "
                   f"③ 구현을 `feat: step {n} — {name}` 로 커밋")
            if (self.cfg.get("test") or {}).get("runner"):
                tdd += (". 테스트 구조는 `.claude/harness.json` 의 `test.runner`·`test.bddAlias` 를 따른다"
                        "(bddAlias 가 false 면 별칭 파일을 만들지 않고 중첩 describe 로 3계층)")
        else:
            tdd = f"4. 이 step 은 테스트 단계가 없다(이유는 step 파일). 구현을 `feat: step {n} — {name}` 로 커밋"
        retry = ""
        if step.get("last_error"):
            retry = f"## ⚠ 이전 시도 실패 — 아래 사유를 반드시 참고해 고친다\n\n{step['last_error']}\n\n---\n\n"
        elif step.get("error_message"):   # 재개: 사람이 되돌리며 적은 근본 원인
            retry = f"## ⚠ 이전 실행이 멈춘 원인(사람이 적음) — 반드시 반영한다\n\n{step['error_message']}\n\n---\n\n"
        shown = self.verify_cmds()
        if base and not self.full_reason(step):
            shown = self.scoped(shown, base)
        cmds = " · ".join(f"`{c}`" + (f"({r} 에서)" if r != "." else "") for r, _, c in shown) or "(verify 없음)"
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
        rest = [".", f":(exclude)phases/{self.task}", HOOK_STAMPS]
        if self.git("status", "--porcelain", "--", *rest).stdout.strip():
            self.git("add", "-A", "--", *rest)
            self.git("commit", "-q", "-m", f"feat: step {step['step']} — {step['name']}", "-m", f"phase: {self.task}")
        commits = self.commits_since(base)
        if step.get("tdd"):
            red = next((c for c in commits if any(TEST_FILE.search(f) for f in c[1])), None)
            if red is None:
                raise RedFail("RED: 테스트 커밋이 없다")
            before = commits[:commits.index(red)]
            impl_in_red = [f for f in red[1] if not TEST_FILE.search(f)]
            if before or impl_in_red:
                raise RedFail("RED: 테스트 커밋이 구현보다 먼저가 아니다 — 테스트 파일만 먼저 커밋한다"
                           + (f" (같이 커밋된 구현: {', '.join(impl_in_red[:3])})" if impl_in_red else ""))
            tests = self.verify_cmds("test")
            if not tests:
                raise Fail("RED: verify.test 가 없어 테스트를 돌릴 수 없다")
            # 앱별 verify 면 테스트 파일이 들어간 앱의 test 만 본다 — 상관없는 앱의 실패가 RED 로 잡히지 않게
            mine = [t for t in tests if t[0] != "." and any(f.startswith(t[0].rstrip("/") + "/") for f in red[1])]
            if self.red_passes(red[0], self.scoped(mine or tests, base)):
                raise RedFail("RED: 테스트가 아무것도 잡지 않음 — 테스트 커밋 시점에 이미 통과한다")
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
            if step.get("kind") != "measure":
                raise Fail("completed 보고인데 변경 없음")
            # 측정·실측·대조 전용 step(#8): 변경 0 이 정상이고 산출물은 summary 의 측정 명령 + 결과다
            if not MEASURE_SUMMARY.search(step.get("summary") or ""):
                raise Fail("measure: summary 에 측정 명령(백틱)과 결과가 없다 — 코드 변경이 없는 step 은 측정 출력이 산출물이다")
            if not self.is_last(step):
                print("measure step: 코드 변경 없음 — summary 의 측정 결과로 통과, verify 생략", file=sys.stderr)
                return None
            # phase 마지막 step 이 측정이면 여기서 phase 전체 verify 를 한 번 돌린다 — 안 하면 전체가 한 번도 안 돈다
            print("measure step: 코드 변경 없음 · phase 마지막 step 이라 전체 verify", file=sys.stderr)
            commits = []
        last = self.is_last(step)
        for root, name, cmd in self.verify_scope(step, commits, base):
            if not self.run_cmd(root, cmd):
                if last:
                    self.blame_earlier(root, name, cmd, commits, base)
                raise Fail(f"verify 실패: {name} (`{cmd}`)")
        return None

    def blame_earlier(self, root: str, name: str, cmd: str, commits: list, base: str):
        """마지막 step 의 전체 verify 실패가 앞 step 탓이면 PhaseFail. 이 step 에이전트가 고칠 수 없는 실패를
        재시도 4회로 붙잡지 않게 한다(0.25.0). 측정 step(변경 없음)이면 언제나, 아니면 step 명령이 통과할 때.
        step 명령이 없으면 가릴 수 없어 그대로 둔다(→ 재시도)."""
        where = f"{root} {name}" if root != "." else name
        if not commits:
            raise PhaseFail(f"verify 실패: {name} (`{cmd}`) — 이 step 은 코드를 바꾸지 않았다. 앞 step 의 변경이 phase 전체 "
                            f"verify({where})를 깨뜨렸다. 커밋을 거꾸로 짚어 원인 step 을 찾는다")
        own = self.step_override(root, name)
        if own is None:
            return
        if self.run_cmd(root, own.replace("{since}", shlex.quote(base))):
            raise PhaseFail(f"verify 실패: {name} (`{cmd}`) — 이 step 범위(step 명령)는 통과, phase 전체({where})만 깨진다. "
                            f"앞 step 탓으로 보여 재시도하지 않는다. 커밋을 거꾸로 짚어 원인 step 을 찾는다")
        raise Fail(f"verify 실패: {name} (`{cmd}`) — 이 step 범위에서도 깨진다")

    def verify_scope(self, step: dict, commits: list, base: str) -> list:
        """판정 6에서 돌릴 verify. 앱별 verify 면 바뀐 파일이 든 앱 + verifyAffects 만(#5, 2026-10-15),
        `$step` 명령이 있으면 그것으로(0.25.0). 앱 밖 파일 · phase 마지막 step · 재개 step 이면 전체 명령 전부."""
        cmds = self.verify_cmds()
        full = self.full_reason(step)
        roots = sorted({r for r, _, _ in cmds if r != "."}, key=len, reverse=True)
        picked = None
        if not full and roots and not any(r == "." for r, _, _ in cmds):
            affects = {k: v for k, v in (self.cfg.get("verifyAffects") or {}).items() if not k.startswith("$")}
            picked = set()
            for f in sorted({f for _, fs in commits for f in fs}):
                own = next((r for r in roots if f.startswith(r.rstrip("/") + "/")), None)
                if own is None:
                    full = f"앱 밖 파일 {f}"
                    break
                picked.add(own)
                for pat, extra in affects.items():
                    if fnmatch.fnmatch(f, pat):
                        picked.update(extra if isinstance(extra, list) else [extra])
        if full:
            print(f"verify 범위: 전부 — {full}", file=sys.stderr)
            return cmds
        if picked is not None:
            skipped = [r for r in roots if r not in picked]
            print(f"verify 범위: {', '.join(sorted(picked))}" + (f" (건너뜀: {', '.join(skipped)})" if skipped else ""),
                  file=sys.stderr)
            cmds = [c for c in cmds if c[0] in picked]
        out = self.scoped(cmds, base)
        stepped = [f"{r} {n}" if r != "." else n for (r, n, c), (_, _, o) in zip(cmds, out) if c != o]
        if stepped:
            print(f"step 명령: {', '.join(stepped)}", file=sys.stderr)
        return out

    def red_passes(self, sha: str, tests: list) -> bool:
        """테스트 커밋 시점으로 잠깐 옮겨 verify.test 를 돌린다. 의존성(node_modules 등)이 있는 이 작업 트리 그대로."""
        head = self.git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
        idx_rel = str(self.index_file.relative_to(self.root))
        # 진행 중인 index.json(아직 커밋 전)이 체크아웃을 막지 않게 HEAD 내용으로 잠깐 돌린다.
        # stash 는 쓰지 않는다 — stash 목록은 모든 worktree 가 공유해 병렬 세션의 것을 꺼낼 수 있다
        keep = backup = None
        if self.git("status", "--porcelain", "--", idx_rel).stdout.strip():
            keep = self.index_file.read_text(encoding="utf-8")
            git_dir = Path(self.root, self.git("rev-parse", "--git-dir").stdout.strip())  # worktree 전용 git dir
            backup = git_dir / f"sdd-index-{self.task}.json"
            backup.write_text(keep, encoding="utf-8")   # 프로세스가 죽어도 복구할 수 있게
            self.git("checkout", "-q", "--", idx_rel, check=True)
        try:
            self.git("checkout", "-q", "--detach", sha, check=True)
            try:
                return all(self.run_cmd(root, cmd) for root, _, cmd in tests)
            finally:
                # 테스트가 만든 산출물이 돌아가는 체크아웃을 막지 않게 -f. 그래도 실패하면 사람이 볼 수 있게 크게 멈춘다
                if self.git("checkout", "-q", "-f", head).returncode != 0:
                    keep = None   # 엉뚱한 트리에 쓰지 않고 백업을 남긴다
                    sys.exit(f"✗ RED 확인 뒤 {head} 로 못 돌아옴 — `git checkout {head}`"
                             + (f" 후 `cp {backup} {idx_rel}`(진행 중 index.json)" if backup else "") + " 으로 복구")
        finally:
            if keep is not None:
                self.index_file.write_text(keep, encoding="utf-8")
                backup.unlink(missing_ok=True)

    def discard_attempt(self, n: int, base: str):
        """RED 위반 시도의 커밋을 브랜치에서 빼고 백업 브랜치로 남긴다. 진행 중 index.json 은 보존."""
        tries = len(self.find(self.read(), n).get("attempts", [])) + 1
        if self.git("rev-parse", "HEAD").stdout.strip() == base:
            return
        keep = self.index_file.read_text(encoding="utf-8")
        self.git("branch", "-f", f"sdd-discard/{self.task}/step{n}-try{tries}", "HEAD")
        self.git("reset", "-q", "--hard", base, check=True)
        self.index_file.write_text(keep, encoding="utf-8")

    def record(self, n: int, base: str, run_failure=None, usage=None) -> int:
        """판정하고 index.json 에 기록·커밋. 0 완료 · 10 재시도 · 1 실패로 멈춤 · 2 blocked."""
        try:
            st = self.find(self.read(), n).get("status")
            if run_failure and st != "blocked":   # 에이전트가 blocked 를 적었으면 실행 실패보다 그게 먼저다
                raise Fail(run_failure)
            res = self.check(self.find(self.read(), n), base)
        except PhaseFail as e:
            idx = self.read()
            s = self.find(idx, n)
            s.update(status="blocked", blocked_reason=str(e))
            self.write(idx)
            res = "blocked"
        except RedFail as e:
            res, reason = "fail", str(e)
            self.discard_attempt(n, base)
            reason += " (이 시도의 커밋은 버렸다 — BASE 에서 테스트부터 다시)"
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
            self.commit(f"wip: step {n} — {s['name']} (blocked 시점 코드)")
            self.commit_index(n)
            print(f"⏸ step {n} blocked: {s.get('blocked_reason', '')}")
            return 2
        if res is None:
            s["completed_at"] = stamp()
            s.pop("last_error", None)   # 실패 사유 이력은 attempts 에 남는다(REFLECT 재료)
            s.pop("error_message", None)
            self.write(idx)
            self.commit_index(n)
            print(f"✓ step {n} {s['name']}: {s.get('summary', '')}")
            return 0
        # retries = 누적 재시도 수(승격 계수기, 0으로 안 돌림). 한도는 이번 실행(재개 이후)의 실패 수로 센다:
        # 첫 시도 + 재시도 3 = 최대 4회 — harness-run·sdd 와 같은 문장
        s.setdefault("attempts", []).append({"at": stamp(), "error": reason})
        fails_now = sum(1 for a in s["attempts"] if a["at"] >= s.get("resumed_at", ""))
        if fails_now > self.max_retries:
            s.update(status="error", error_message=f"[{fails_now}회 시도 후 실패] {reason}", failed_at=stamp())
            s.pop("last_error", None)
            self.write(idx)
            self.commit(f"wip: step {n} — {s['name']} (멈춘 시점 코드)")   # 강의 execute.py 처럼 실패해도 코드는 남긴다
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
    def invoke(self, step: dict, base: str):
        """claude -p 1번. (실행 실패 사유 또는 None, usage)."""
        claude = os.environ.get("SDD_RUNNER_CLAUDE", "claude")
        cmd = [claude, "-p", "--dangerously-skip-permissions", "--output-format", "json"]
        if step.get("model"):
            cmd += ["--model", step["model"]]
        cmd.append(self.prompt(step, base))
        env = dict(os.environ)
        env.pop("SDD_RUNNER_SINCE", None)
        if not self.full_reason(step):   # Stop 훅도 step 명령을 쓴다(validate-session-end.sh)
            env["SDD_RUNNER_SINCE"] = base
        out = {"step": step["step"], "attempt": step.get("retries", 0) + 1, "started_at": stamp()}
        # 새 프로세스 그룹 — 타임아웃이면 claude 가 띄운 자식(테스트 watch·서버)까지 같이 끈다
        p = subprocess.Popen(cmd, cwd=self.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                             start_new_session=True, env=env)
        try:
            stdout, stderr = p.communicate(timeout=self.timeout)
            out.update(exitCode=p.returncode, stdout=stdout, stderr=stderr)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(p.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            stdout, _ = p.communicate()
            out.update(timeout=self.timeout, stdout=stdout or "")
            self.save_output(step, out)
            return f"실행 실패: 타임아웃 {self.timeout}초", None
        self.save_output(step, out)
        try:
            res = json.loads(stdout.strip().splitlines()[-1]) if stdout.strip() else {}
        except (json.JSONDecodeError, IndexError):
            res = {}
        res = res if isinstance(res, dict) else {}
        usage = dict(res.get("usage") or {})
        for k in ("num_turns", "duration_ms", "total_cost_usd"):
            if isinstance(res.get(k), (int, float)):
                usage[k] = res[k]
        if p.returncode != 0 or res.get("is_error") or not res:
            why = "is_error" if res.get("is_error") else f"종료 코드 {p.returncode}" if p.returncode else "결과 JSON 없음"
            return f"실행 실패: {why} — {str(res.get('result', stderr))[:200]}", usage
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
                failure, usage = self.invoke(self.find(self.read(), n), base)
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
    ap.add_argument("--step", type=int)
    a = ap.parse_args(argv)
    r = Runner(a.task, a.max_retries, a.timeout)
    if a.mode == "run":
        return r.run()
    if a.mode == "start":
        return r.start()
    if a.mode == "prompt":
        step = r.find(r.read(), a.step) if a.step else r.next_pending()
        if step is None:
            print("pending step 없음")
            return 0
        idx = r.read()
        r.find(idx, step["step"]).setdefault("started_at", stamp())
        r.write(idx)
        print(f"▶ step {step['step']}", file=sys.stderr)   # judge --step 에 넘길 번호
        print(r.prompt(step, a.base))
        return 0
    # judge: 판정 대상은 번호로 받는다 — '첫 pending' 으로 고르면 방금 completed 로 바뀐 step 을 건너뛴다(10-13 리뷰)
    if not a.base or not a.step:
        ap.error("judge 는 --step N --base <그 step 시작 전 HEAD> 가 필요하다")
    return r.record(a.step, a.base)


if __name__ == "__main__":
    sys.exit(main())
