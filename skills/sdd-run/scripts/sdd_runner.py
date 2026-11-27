#!/usr/bin/env python3
"""SDD 러너 — phases/{task}/ 의 pending step 을 하나씩 구현하고 git 기록으로 판정한다.

강의 harness_framework 의 execute.py 뼈대(step 당 claude -p 1번 · 직전 에러를 붙여 재시도 · 시간 기록 · 원문 로그 ·
타임아웃)에 우리 하네스가 실측으로 얻은 검사를 더했다. 강의는 에이전트가 index.json 에 스스로 적은 status 만 믿는다.
여기서는 그 status 에 더해 실행 결과(is_error·종료 코드)와 git 기록(RED 커밋 순서·RED 가 실제로 실패하나·테스트
파일 수정·변경 유무·verify)을 러너가 직접 본다. 판정 표의 정본은 docs/sdd-runner.md.

세션 안 sdd-run 과 같은 규칙을 쓴다 — 두 러너가 이 파일의 prompt·judge 를 같이 부른다.

  sdd_runner.py run TASK [--timeout 1800] [--max-retries 3]   헤드리스: claude -p 로 끝까지
  sdd_runner.py start TASK                                    시작 전 점검 + 브랜치 (세션 안)
  sdd_runner.py prompt TASK [--base SHA]                      다음 pending step 의 지시문 출력, stderr 에 "▶ step N" (세션 안.
                                                              --base 는 그 step 의 BASE 로 index.json 에 고정, 재시도에서 안 덮음)
  sdd_runner.py judge TASK --step N [--base SHA]              step N 판정·기록 (세션 안. BASE 는 고정값이 먼저)
  sdd_runner.py gate DOCS_DIR                                 구현 시작 관문: DOCS_DIR 의 ADR · PRD 에 열린 「정할 것」이
                                                              있으면 목록 + 종료 2 (ADR-023 R1 · R2, 레포 루트 기준 경로)
  나눔 모드(검증 세션 · 구현 세션, ADR-019 A4 · E12) — 차례는 index.json 이 정한다:
  sdd_runner.py prompt TASK --role test|impl [--base SHA]     그 역할 차례일 때만 지시문(test = 테스트만 · impl = 구현만)
  sdd_runner.py judge TASK --red --step N                     검증 쪽: 판정 2·3 만, 통과하면 step 에 red 기록
  sdd_runner.py rejudge TASK --step N                         검증 쪽: 재판정 「테스트가 틀렸다」 — 고친 테스트 커밋을 새 red 로,
                                                              구현 커밋은 그대로 두고 구현 차례로 (ADR-023 R3)
  effort(ADR-019 C2): 역할이 정한다 — prompt 는 stderr 에 "▶ effort <값>"(Agent effort 로 넘긴다) · run 은 claude -p --effort.
  --effort 로 덮는다(prompt · run). step 파일에는 effort 칸이 없다

종료 코드: 0 완료 · 1 실패로 멈춤 · 2 blocked(사람 필요) · 10 재시도(judge 만) · 3 차례 아님(나눔 모드, 아무것도 안 바꿈)
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
import time
from pathlib import Path as _P

sys.path.insert(0, str(_P(__file__).resolve().parents[3] / "hooks" / "lib"))
try:
    import verify_busy  # 검사 상한 (ADR-007)
except ImportError:   # 플러그인 밖에서 스크립트만 복사해 쓴 경우 — 상한 없이 지금처럼
    verify_busy = None


def wait_for_slot(root, interval=5, timeout=600, busy=None, sleep=time.sleep) -> bool:
    """이 머신에서 도는 검사가 상한 이상이면 아래로 내려올 때까지 기다린다. 기다렸으면 True.
    timeout 을 넘기면 그대로 진행한다 — 판정이 영영 안 도는 것보다 낫다. 세션이 하나면 닿지 않는다."""
    if busy is None:
        if verify_busy is None:
            return False
        busy = verify_busy.busy
    waited, n = 0, busy(root)
    if not n:
        return False
    print(f"⏸ 검사 대기 — 다른 세션 {n}개", file=sys.stderr)
    while n and waited <= timeout:
        sleep(interval)
        waited += interval
        n = busy(root)
    if n:
        print(f"⏸ 검사 대기 {timeout}초 넘음 — 그대로 진행", file=sys.stderr)
    return True
from pathlib import Path
from string import Template

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import phases_status  # noqa: E402

TZ = timezone(timedelta(hours=9))
VALID = {"pending", "completed", "error", "blocked"}
DEFER_MARK = "전체 test 미룸 — 릴리스 전 한 번"   # --defer-full-test 로 줄인 step 의 summary 끝 — #13
MEASURE_SUMMARY = re.compile(r"`[^`]+`")   # kind: measure step 의 summary 에 있어야 하는 측정 명령(백틱) — #8
# 테스트 파일 판별 — tdd-guard 의 짝 테스트 자리와 같은 계열(TS *.test/*.spec · __tests__ · tests/ · JVM *Test.kt · py test_* · 셸 test.sh)
# 셸은 test.sh 이름만 — 넓히면 구현 스크립트가 테스트로 잡혀 「테스트 커밋에 구현 없음」이 거짓으로 통과한다
TEST_FILE = re.compile(r"(\.(test|spec)\.[^/]+$|(^|/)__tests__/|(^|/)tests?/|(^|/)src/test/|Tests?\.(kt|java)$|(^|/)test_[^/]+\.py$|_test\.(py|go)$|(^|/)test\.sh$)")
OUTPUT_GLOB = "phases/*/step*-output.json"
HOOK_STAMPS = ":(exclude).claude/.last-*"   # 훅 기록 파일 — .gitignore 가 없는 레포에서도 커밋에 섞지 않는다(10-13 실가동)
# verify 실패 사유에 붙이는 출력 꼬리(#12): 끝 40줄 + 그 앞의 실패한 테스트 이름 줄(최대 10) · 4,000자 상한(index.json 이 붓지 않게)
TAIL_LINES, TAIL_FAILS, TAIL_CAP, TAIL_CUT = 40, 10, 4000, "…(앞 생략)\n"
FAIL_LINE = re.compile(r"^\s*(FAIL|✗|✕|🔴)")   # FAIL 은 FAILED 도 잡는다. 이 레포 hooks/test.sh 실패 줄은 「  🔴」
ROLE = {"test": "검증", "impl": "구현"}   # 나눔 모드 세션 역할(ADR-019 E1)
NOT_TURN = 3   # 나눔 모드: 차례가 아닌 역할의 호출 — 아무것도 바꾸지 않는다(ADR-019 E12)
# effort 는 세션 역할이 정한다(ADR-019 C2 · E1). 역할 없는 1회 모드: 세션 안 prompt = 구현(C7a, 머지 전 code-reviewer 가 받침)
# · 헤드리스 run = 검증(C7b, 사람도 검증 세션도 없이 테스트까지 쓴다)
EFFORT, ONE_SHOT = {"검증": "high", "구현": "medium"}, {"session": "구현", "headless": "검증"}
EDGE_AXES = ("빈 값·경계", "비정상 입력", "실패 경로", "상태 전이", "동시성")   # testing.md §2 와 같은 글자(ADR-019 G6)
EDGE_VALUE = re.compile(r"`[^`]+`( · `[^`]+`)*")   # 백틱 테스트 이름 하나 이상(` · ` 구분). 아니면 「해당 없음…」
INTENT_PLACEHOLDER = "AC-N(, AC-M)"   # sdd-plan step 템플릿 의도 절의 자리표시
EFFORT_LEVELS = ("low", "medium", "high", "xhigh", "max")   # claude --effort 가 받는 값
EDGE_NOTE = " step 파일 엣지 5축 칸의 테스트 이름을 그대로 테스트 이름에 쓴다(러너가 테스트 커밋에서 그 이름을 찾는다)."
# 구현 쪽이 막혔을 때(ADR-019 E3) — 테스트를 고쳐 풀지 않는다
IMPL_RULE = ("테스트는 고치지 않는다 — 막히면 `\"status\": \"blocked\"` + `\"blocked_reason\"`(이유)로 멈추고, "
             "검증 세션이 다시 판정한다")
# 지시문 6번 · 맺음말(preamble.md $status_rule · $judge_note). 검증 차례는 index.json 을 고치지 않고 러너가 red 를 적는다
STATUS_RULE = """6. `phases/{task}/index.json` 의 step {n} 을 갱신한다. **이 파일은 커밋하지 않는다**(러너가 커밋한다):
   - 검증 통과 → `"status": "completed"` + `"summary"`: 다음 step 에 넘길 산출물 한 줄(만든 파일·핵심 결정). step 파일과 다르게 한 것(계획에 없던 선택)은 `…로 했다(계획은 X, 이유: Y)` 형태로 이유 한 구절을 적고, 계획대로 한 것은 적지 않는다
   - 고쳐도 실패 → `"status": "error"` + `"error_message"`: 무엇이 왜 실패했는지
   - 사람만 할 수 있는 일(API 키·외부 인증·수동 설정) · 테스트가 수용 조건과 다르다 · 설계 문서에 없는 결정이 필요하다 → `"status": "blocked"` + `"blocked_reason"` 후 즉시 멈춘다"""
STATUS_RULE_TEST = """6. `phases/{task}/index.json` 의 step {n} status 는 `pending` 그대로 둔다 — 구현 차례로 넘기는 표시(`red`)는 러너(`judge --red`)가 적는다. 검증 차례에는 status 를 바꾸지 않는다 — 아래 step 파일 「검증 절차」의 completed 기록 줄보다 이 줄이 앞선다(completed 는 구현 차례가 적는다). 수용 조건을 테스트로 쓸 수 없다 · 설계 문서에 없는 결정이 필요하다 · 사람만 할 수 있는 일이면 `"status": "blocked"` + `"blocked_reason"` 후 멈춘다"""
JUDGE_NOTE = ("러너가 끝난 뒤 git 기록으로 확인한다: 테스트 커밋이 구현보다 먼저인가 · 테스트 커밋 시점에 테스트가 실제로 실패하는가 · "
              "그 뒤 테스트 파일이 바뀌지 않았나 · 검증 명령이 전부 통과하는가. 하나라도 어긋나면 이 step 은 실패로 처리된다.")
JUDGE_NOTE_TEST = ("러너(`judge --red`)가 git 기록으로 확인한다: BASE 뒤 커밋이 테스트 파일만 담았나 · 그 시점에 테스트가 실제로 실패하는가. "
                   "어긋나면 이 시도의 커밋을 버리고 테스트부터 다시 한다.")
JUDGE_NOTE_IMPL = ("러너가 끝난 뒤 git 기록으로 확인한다: 테스트 커밋(`red`) 뒤 테스트 파일이 바뀌지 않았나 · 구현 변경이 있나 · "
                   "검증 명령이 전부 통과하는가. 하나라도 어긋나면 이 step 은 실패로 처리된다.")


def error_tail(out: str) -> str:
    """verify 출력에서 다음 시도가 볼 꼬리. 넘치면 끝 줄 쪽 앞을 잘라 실패 이름 줄은 남긴다."""
    lines = out.rstrip("\n").splitlines()
    if not lines:
        return ""
    fails = [ln for ln in lines[:-TAIL_LINES] if FAIL_LINE.match(ln)][:TAIL_FAILS]
    head = ("실패 줄(끝 40줄 앞):\n" + "\n".join(fails) + "\n\n") if fails else ""
    body = "출력 끝:\n" + "\n".join(lines[-TAIL_LINES:])
    text = head + body
    if len(text) <= TAIL_CAP:
        return text
    keep = TAIL_CAP - len(head) - len(TAIL_CUT)
    if keep > 0:
        return head + TAIL_CUT + body[-keep:]
    return TAIL_CUT + text[-(TAIL_CAP - len(TAIL_CUT)):]


def md_sections(md: str) -> dict:
    """{`## 제목`: 본문} — `#`(h1)에서 끊고 `###` 이하는 본문에 남긴다."""
    out, cur = {}, None
    for ln in md.splitlines():
        m = re.match(r"^##\s+(.+?)\s*$", ln)
        if m:
            cur = m.group(1)
            out[cur] = []
        elif ln.startswith("# "):
            cur = None
        elif cur is not None:
            out[cur].append(ln)
    return {k: "\n".join(v) for k, v in out.items()}


def _md_heading(ln: str):
    m = re.match(r"^(#+)\s+(.*)$", ln)
    return (len(m.group(1)), m.group(2)) if m else None


def _cells(ln: str) -> list:
    """표 한 줄의 칸 — 셀 안 `\\|` 는 칸 나눔이 아니다(#86 F4)."""
    parts = re.split(r"(?<!\\)\|", ln.strip())
    if parts and not parts[0].strip():
        parts = parts[1:]
    if parts and not parts[-1].strip():
        parts = parts[:-1]
    return [c.strip() for c in parts]


_LIST_ITEM = r"(?:[-*+]|\d+[.)])"   # 불렛 · 번호 목록(#86 F4)
_OPEN_MARK = "남은 ⚠"   # 변이 선택자(U+FE0F) 있든 없든(#86 F4)


def _prd_open(t: str) -> bool:
    return "→ 결정:" not in t and "막지 않음:" not in t and not re.match(r"없음(?:$|[\s(])", t)


def open_decisions(docs_dir) -> list:
    """구현 시작 관문(ADR-023 R1) — docs_dir 의 ADR.md · PRD.md 에서 열린 「정할 것」을 한 줄씩."""
    d = Path(docs_dir)
    out = []
    adr = d / "ADR.md"
    if adr.is_file():
        level, header, owner = None, None, None   # 「결정할 것」 절 급 · 지금 표 머리 · 주체 칸 번호
        for ln in adr.read_text(encoding="utf-8").splitlines():
            h = _md_heading(ln)
            if h:
                if level is not None and h[0] <= level:
                    level = None
                if "결정할 것" in h[1]:
                    level = h[0]
                header = None
                continue
            if level is None:
                continue
            if not ln.lstrip().startswith("|"):
                header = None
                continue
            cells = _cells(ln)
            if header is None:
                header = cells
                owner = next((i for i, c in enumerate(cells) if "주체" in c), None)
                continue
            if all(re.fullmatch(r":?-+:?", c) for c in cells if c):
                continue
            if owner is None or owner >= len(cells) or not cells[owner]:
                out.append(f"ADR {cells[0]}: {cells[1] if len(cells) > 1 else ''}".rstrip())
    prd = d / "PRD.md"
    if prd.is_file():
        lines = prd.read_text(encoding="utf-8").splitlines()
        i = 0
        while i < len(lines):
            ln = lines[i]
            h = _md_heading(ln)
            label = re.match(rf"^(\s*){_LIST_ITEM}\s+(?:\*\*)?{_OPEN_MARK}\ufe0f?(?:\*\*)?(.*)$", ln)
            if h and _OPEN_MARK in h[1]:
                j = i + 1
                while j < len(lines) and not ((hh := _md_heading(lines[j])) and hh[0] <= h[0]):
                    j += 1
            elif label:
                ind = len(label.group(1))
                inline = re.sub(r"^[\s*:：—–-]+", "", label.group(2)).strip()   # 라벨 줄에 붙여 쓴 내용(#86 F4) — 앞 ** · : · 줄표는 벗긴다
                if inline and not inline.startswith("(") and _prd_open(inline):
                    out.append(f"PRD: {inline}")
                j = i + 1
                while j < len(lines) and (not lines[j].strip() or len(lines[j]) - len(lines[j].lstrip()) > ind):
                    j += 1
            else:
                i += 1
                continue
            bullets = [(len(m.group(1)), m.group(2)) for m in
                       (re.match(rf"^(\s*){_LIST_ITEM}\s+(.*?)\s*$", x) for x in lines[i + 1:j]) if m]
            top = min((b[0] for b in bullets), default=0)
            out += [f"PRD: {t}" for k, t in bullets if k == top and _prd_open(t)]   # 「- 없음 (…)」은 항목 없음 표시(리뷰 1회차)
            i = j
    return out


def gate(docs_dir) -> int:
    """`gate DOCS_DIR` — 열린 것이 있으면 목록 + 종료 2, 없으면 한 줄 + 0. 읽기만 한다."""
    d = Path(docs_dir)
    if not d.is_absolute():
        r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        d = (Path(r.stdout.strip()) if r.returncode == 0 else Path.cwd()) / d
    if not (d / "ADR.md").is_file() and not (d / "PRD.md").is_file():
        print(f"구현 시작 관문: ADR · PRD 없음 — 막지 않는다 ({d})")   # 경로 오타와 가를 수 있게(#86 F6)
        return 0
    items = open_decisions(d)
    if not items:
        print("구현 시작 관문: 열린 「정할 것」 0")
        return 0
    print(f"구현 시작 관문: 열린 「정할 것」 {len(items)}개 — 지휘(또는 사람)에게 묻고 닫은 뒤 다시")
    for it in items:
        print(f"  - {it}")
    return 2


def edge_axes(ac: str):
    """Acceptance Criteria 절의 `- 엣지 5축` 하위 줄 `  - <축>: <값>`. ({축: 테스트 이름 목록(해당 없음이면 [])}, 빈 축 목록)."""
    lines = ac.splitlines()
    i = next((k for k, ln in enumerate(lines) if ln.startswith("- 엣지 5축")), None)
    got = {}
    for ln in lines[i + 1:] if i is not None else ():
        m = re.match(r"^\s+-\s*([^:]+?)\s*:\s*(.*?)\s*$", ln)
        if not m:
            break
        got[m.group(1)] = m.group(2)
    names, empty = {}, []
    for ax in EDGE_AXES:
        v = got.get(ax, "")
        if v.startswith("해당 없음"):
            names[ax] = []
        elif EDGE_VALUE.fullmatch(v) and not re.search(r"<[^>]*>", v):   # 템플릿 자리표시 `<테스트 이름>` 은 빈 칸
            names[ax] = re.findall(r"`([^`]+)`", v)
        else:
            empty.append(ax)
    return names, empty


def stamp() -> str:
    return datetime.now(TZ).strftime("%Y-%m-%dT%H:%M:%S%z")


class Fail(Exception):
    """판정 실패 — 재시도 대상."""


class PhaseFail(Exception):
    """phase 마지막 step 의 전체 verify 가 깨졌는데 이 step 범위는 통과 — 앞 step 탓이라 재시도하지 않고 사람에게."""


class RedFail(Fail):
    """RED 순서·RED 가 아무것도 안 잡음 — 이 시도의 커밋을 버리고 BASE 에서 다시 해야 고칠 수 있다."""


class Runner:
    def __init__(self, task: str, max_retries: int = 3, timeout: int = 1800, defer_full_test: bool = False,
                 effort=None):
        r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit("git 레포가 아니다")
        self.root = Path(r.stdout.strip())
        self.task = task
        self.dir = self.root / "phases" / task
        self.index_file = self.dir / "index.json"
        self.max_retries = max_retries
        self.timeout = timeout
        self.defer_full_test = defer_full_test
        self.effort_override = effort   # --effort — 역할 값을 덮는다
        self.deferred = {}   # {step 번호: 미룬 「전체」 이유} — 판정 통과 때 summary 에 표시를 붙인다
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

    def current(self):
        """나눔 모드에서 차례를 정하는 step — 끝나지 않은 첫 step. 뒤 step 으로 건너뛰지 않는다(한 step 씩 번갈아)."""
        return next((s for s in self.read()["steps"] if s.get("status") != "completed"), None)

    @staticmethod
    def turn(step: dict):
        """나눔 모드 차례(ADR-019 E12) — 'test'(검증) · 'impl'(구현) · None(error: 사람).
        measure 는 tdd: false 여도 검증 몫이라 먼저 본다. blocked 는 검증 재판정(E3)."""
        st = step.get("status")
        if st == "blocked":
            return "test"
        if st != "pending":
            return None
        if step.get("kind") == "measure" or (step.get("tdd") and not step.get("red")):
            return "test"
        return "impl"

    def refuse_turn(self, step: dict, role: str):
        """차례가 아니면 한 줄 + NOT_TURN, 맞으면 None. 아무것도 바꾸지 않는다."""
        t = self.turn(step)
        if t == role:
            return None
        who = f"{ROLE[t]} 차례" if t else "사람 차례"
        why = step.get("blocked_reason") or step.get("error_message") or ""
        print(f"지금은 {who} — step {step['step']} {step['name']} ({step.get('status')}"
              + (", red 있음" if step.get("red") else "") + ")" + (f": {why}" if why else ""))
        return NOT_TURN

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

    def full_reason(self, step: dict, outside=None):
        """step 명령 대신 전체 명령을 쓸 이유. 재개 step 은 앞 시도의 wip 커밋이 {since} 앞에 있어 범위가 빈다.
        outside = verify_scope 가 찾은 앱 밖 파일. --defer-full-test 면 이유가 있어도 None(#13) — prompt·invoke·
        verify_scope 가 모두 여기서 「전체」를 정하므로 한 곳에서 건다. `$step` 명령이 없으면 줄일 범위가 없어 그대로."""
        if self.is_last(step):
            why = "phase 마지막 step"
        elif step.get("resumed_at"):
            why = "재개한 step"
        elif outside:
            why = f"앱 밖 파일 {outside}"
        else:
            return None
        if self.defer_full_test and any(self.step_override(r, n) for r, n, _ in self.verify_cmds()):
            self.deferred[step["step"]] = why
            return None
        return why

    def run_out(self, root: str, cmd: str):
        """(통과 여부, 출력). 그 시점에 앱 폴더가 아직 없으면 실행할 수 없다 = 통과 아님."""
        cwd = self.root / root
        if not cwd.is_dir():
            return False, ""
        p = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True, errors="replace")
        return p.returncode == 0, (p.stdout or "") + (p.stderr or "")

    def run_cmd(self, root: str, cmd: str) -> bool:
        return self.run_out(root, cmd)[0]

    def pin_base(self, n: int, base=None):
        """step 시작 커밋(BASE)을 index.json 에 고정한다(#11). 이미 있으면 그대로 — 재시도에서 덮지 않는다.
        세션 모드에서 모델이 BASE 를 기억하지 않아도 judge 가 같은 값을 읽는다. 끝난 step 에서는 record 가 지운다."""
        idx = self.read()
        s = self.find(idx, n)
        if not s.get("base") and base:
            s["base"] = base
            self.write(idx)
        return s.get("base") or base

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
        docs = self.read().get("docs")
        if docs and gate(self.root / docs):   # 구현 시작 관문 — 부작용 전에(ADR-023 R2)
            return 2
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
    def effort(self, role=None, headless=False) -> str:
        """ADR-019 C2: role 'test' · 'impl' 은 그 역할, 없으면 1회 모드 — 세션 안 · 헤드리스가 갈린다(C7a · C7b)."""
        return self.effort_override or EFFORT[ROLE[role] if role else ONE_SHOT["headless" if headless else "session"]]

    def step_md(self, step: dict) -> str:
        return (self.dir / f"step{step['step']}.md").read_text(encoding="utf-8")

    def is_new_form(self, step: dict) -> bool:
        return "의도" in md_sections(self.step_md(step))

    def plan_gate(self, step: dict):
        """계획 칸(ADR-019 C1 의도 · G6 엣지 5축). 비면 막는 이유(에이전트가 못 고치는 칸이라 재시도하지 않는다), 아니면 None.
        의도 절이 없는 옛 꼴은 stderr 경고 한 줄만 — 이미 쓴 phase 를 깨지 않게."""
        secs = md_sections(self.step_md(step))
        if "의도" not in secs:
            print(f"⚠ step {step['step']}: `## 의도` 절이 없다(옛 꼴) — 의도 · 엣지 5축 칸을 보지 않고 지시문을 낸다", file=sys.stderr)
            return None
        if not secs["의도"].strip() or INTENT_PLACEHOLDER in secs["의도"]:   # 템플릿 그대로도 빈 것
            return "의도 절이 비었다 — 채우는 수용 조건 번호 · 이유 한 줄, 계획을 고친 뒤 재개"
        if step.get("tdd") and step.get("kind") != "measure":
            empty = edge_axes(secs.get("Acceptance Criteria", ""))[1]
            if empty:
                return f"엣지 5축 칸이 비었다 — {' · '.join(empty)}, 계획을 고친 뒤 재개"
        return None

    def edge_names(self, step: dict) -> dict:
        """새 꼴 tdd step 의 {축: 테스트 이름 목록}. 옛 꼴 · tdd: false 는 빈 dict(이름 대조 안 함)."""
        if not step.get("tdd") or not self.is_new_form(step):
            return {}
        return edge_axes(md_sections(self.step_md(step)).get("Acceptance Criteria", ""))[0]

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

    def prompt(self, step: dict, base=None, role=None) -> str:
        """role: 나눔 모드 역할('test' · 'impl'). 없으면 1회 모드 — 테스트와 구현을 한 번에."""
        idx = self.read()
        done = [f"- Step {s['step']} ({s['name']}): {s['summary']}" for s in idx["steps"]
                if s.get("status") == "completed" and s.get("summary")]
        n, name = step["step"], step["name"]
        if step.get("kind") == "measure":
            tdd = ("4. 이 step 은 **측정 전용(kind: measure)** 이다 — 코드를 바꾸지 않는다. 측정·실측·대조만 하고, 실행한 **명령(백틱)과 결과**를 "
                   "`summary` 에 적는다. 그것이 이 step 의 산출물이라 summary 에 명령이 없으면 실패로 판정된다. 커밋할 것은 없다")
        elif step.get("tdd") and role == "test":
            tdd = (f"4. 이 step 은 **검증 차례(테스트만)** 다: 수용 조건을 **실패하는 테스트**로만 쓰고 테스트 명령이 실패하는지 확인한 뒤 "
                   f"테스트 파일만 `test: step {n} — {name} (red)` 로 커밋한다. **구현 파일을 만들지 않는다** — 구현은 구현 세션이 한다")
            if self.is_new_form(step):
                tdd += "." + EDGE_NOTE
        elif step.get("tdd") and step.get("red"):
            tdd = (f"4. **테스트는 이미 있다**(검증 세션의 테스트 커밋 `{step['red'][:12]}`). 구현만 해서 테스트를 통과시키고 "
                   f"`feat: step {n} — {name}` 로 커밋한다. {IMPL_RULE}(테스트가 수용 조건과 다르거나 테스트 파일 자체가 검증에 걸릴 때도 — "
                   f"고치면 러너가 되돌린다)")
        elif step.get("tdd"):
            tdd = (f"4. 테스트 먼저(TDD): ① 수용 조건을 **실패하는 테스트**로 먼저 쓰고 테스트 명령이 실패하는지 확인한 뒤 "
                   f"테스트 파일만 `test: step {n} — {name} (red)` 로 커밋 ② 구현한다. 테스트 파일은 다시 고치지 않는다 "
                   f"③ 구현을 `feat: step {n} — {name}` 로 커밋")
            if self.is_new_form(step):
                tdd += "." + EDGE_NOTE
            if (self.cfg.get("test") or {}).get("runner"):
                tdd += (". 테스트 구조는 `.claude/harness.json` 의 `test.runner`·`test.bddAlias` 를 따른다"
                        "(bddAlias 가 false 면 별칭 파일을 만들지 않고 중첩 describe 로 3계층)")
        else:
            tdd = f"4. 이 step 은 테스트 단계가 없다(이유는 step 파일). 구현을 `feat: step {n} — {name}` 로 커밋"
            if role == "impl":
                tdd += f". {IMPL_RULE}"
        retry = ""
        if step.get("last_error"):
            kept = ""
            # 이전 시도의 RED 커밋이 남아 있으면 '테스트 먼저'를 다시 하지 않게 알린다(#9)
            if step.get("tdd") and not step.get("red") and role != "test" and base and any(TEST_FILE.search(f) for _, fs in self.commits_since(base) for f in fs):
                kept = ("\n\n이전 시도의 테스트 커밋이 남아 있다 — 테스트는 다시 쓰거나 고치지 않는다(고치면 되돌린다). 구현만 고친다. "
                        "테스트 파일 자체가 검증에 걸리면 러너가 이 시도를 버리고 테스트부터 다시 하게 한다")
            retry = f"## ⚠ 이전 시도 실패 — 아래 사유를 보고 고친다\n\n{step['last_error']}{kept}\n\n---\n\n"
        elif step.get("error_message"):   # 재개: 사람이 되돌리며 적은 근본 원인
            retry = f"## ⚠ 이전 실행이 멈춘 원인(사람이 적음) — 이 원인을 반영해 고친다\n\n{step['error_message']}\n\n---\n\n"
        shown = self.verify_cmds()
        if base and not self.full_reason(step):
            shown = self.scoped(shown, base)
        cmds = " · ".join(f"`{c}`" + (f"({r} 에서)" if r != "." else "") for r, _, c in shown) or "(verify 없음)"
        test_turn = role == "test" and step.get("tdd") and step.get("kind") != "measure"
        return Template((HERE / "preamble.md").read_text(encoding="utf-8")).safe_substitute(
            project=idx.get("project", self.root.name), task=self.task, step=n,
            guardrails=self.guardrails(idx),
            done_steps=("## 이전 step 산출물\n\n" + "\n".join(done) + "\n\n") if done else "",
            retry=retry, tdd_rule=tdd, verify_cmds=cmds,
            status_rule=(STATUS_RULE_TEST if test_turn else STATUS_RULE).format(task=self.task, n=n),
            judge_note=JUDGE_NOTE_TEST if test_turn else JUDGE_NOTE_IMPL if step.get("red") else JUDGE_NOTE,
            step_md=self.step_md(step))

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
        red_tests = []
        if step.get("tdd"):
            if step.get("red"):   # 나눔 모드 구현 쪽: 판정 2·3 은 judge --red 가 이미 했다 — red 를 기준으로 4·5
                red_sha = step["red"]
                red_tests = [f for f in self.git("diff", "--name-only", base, red_sha).stdout.split() if TEST_FILE.search(f)]
            else:
                red_sha, red_tests = self.red_check(commits, base, step=step)
            changed = [f for f in self.git("diff", "--name-only", f"{red_sha}..HEAD").stdout.split()
                       if TEST_FILE.search(f) and not f.startswith("phases/")]
            if changed:
                for f in changed:
                    if self.git("cat-file", "-e", f"{red_sha}:{f}").returncode == 0:
                        self.git("checkout", red_sha, "--", f)
                    else:
                        self.git("rm", "-q", "-f", "--", f)
                self.commit(f"test: step {step['step']} — 테스트 수정 되돌림")
                raise Fail(f"GREEN: 테스트 파일을 고쳤다(되돌림): {', '.join(changed[:5])} — 테스트는 그대로 두고 구현을 고친다")
        scope = commits   # 판정 6 범위는 테스트 파일까지 — 테스트가 든 앱도 돈다
        if step.get("rejudged"):   # 판정 5(ADR-023 R3): red 가 고친 테스트라 구현은 그 앞에 있을 수 있다 — BASE 뒤 구현 변경
            commits = [c for c in commits if any(not TEST_FILE.search(f) and not f.startswith("phases/") for f in c[1])]
        elif step.get("red"):
            commits = self.commits_since(step["red"])   # 판정 5: 테스트 커밋 뒤 구현 변경
        if not commits:
            if step.get("kind") != "measure":
                raise Fail("completed 보고인데 변경 없음")
            # 측정·실측·대조 전용 step(#8): 변경 0 이 정상이고 산출물은 summary 의 측정 명령 + 결과다
            if not MEASURE_SUMMARY.search(step.get("summary") or ""):
                raise Fail("measure: summary 에 측정 명령(백틱)과 결과가 없다 — 코드 변경이 없는 step 은 측정 출력이 산출물이다")
            if not self.is_last(step) or not self.full_reason(step):
                print("measure step: 코드 변경 없음 — summary 의 측정 결과로 통과, verify 생략", file=sys.stderr)
                return None
            # phase 마지막 step 이 측정이면 여기서 phase 전체 verify 를 한 번 돌린다 — 안 하면 전체가 한 번도 안 돈다
            print("measure step: 코드 변경 없음 · phase 마지막 step 이라 전체 verify", file=sys.stderr)
            commits = []
        last = self.is_last(step)
        wait_for_slot(str(self.root))
        for root, name, cmd in self.verify_scope(step, scope, base):
            ok, out = self.run_out(root, cmd)
            if not ok:
                hit = self.red_blame(out, root, red_tests) if name != "test" else None
                if hit:
                    raise RedFail(f"verify 실패: {name} (`{cmd}`) 가 RED 테스트 파일에서 난다 — {hit}. 테스트는 RED 뒤 고칠 수 없다. "
                                  f"테스트를 쓸 때 {name} 도 통과하게 쓴다")
                tail = error_tail(out)
                tail = f"\n\n{tail}" if tail else ""
                if last:
                    self.blame_earlier(root, name, cmd, commits, base, tail)
                raise Fail(f"verify 실패: {name} (`{cmd}`){tail}")
        return None

    def red_check(self, commits: list, base: str, only_tests=False, step=None):
        """판정 2·3. (테스트 커밋 sha, 그 테스트 파일). only_tests(judge --red) 면 BASE 뒤 커밋이 모두 테스트만이어야 하고
        sha 는 그 마지막 커밋 — 뒤 테스트 커밋이 판정 4 에서 「RED 뒤 테스트 수정」으로 되돌려지지 않게."""
        red = next((c for c in commits if any(TEST_FILE.search(f) for f in c[1])), None)
        if red is None:
            raise RedFail("RED: 테스트 커밋이 없다")
        before = commits[:commits.index(red)]
        impl_in_red = [f for f in (sum((c[1] for c in commits), []) if only_tests else red[1]) if not TEST_FILE.search(f)]
        if before or impl_in_red:
            raise RedFail("RED: 테스트 커밋이 구현보다 먼저가 아니다 — 테스트 파일만 먼저 커밋한다"
                          + (f" (같이 커밋된 구현: {', '.join(impl_in_red[:3])})" if impl_in_red else ""))
        if only_tests:
            red = (commits[-1][0], sorted({f for c in commits for f in c[1]}))
        # 엣지 5축 칸의 이름이 테스트 커밋의 테스트 파일 내용에 있어야 한다(G6). 러너 출력이 아니라 파일 — 출력 꼴은 프레임워크마다 다르다
        wanted = [(ax, nm) for ax, nms in (self.edge_names(step) if step else {}).items() for nm in nms]
        if wanted:
            text = "\n".join(self.git("show", f"{red[0]}:{f}").stdout for f in red[1] if TEST_FILE.search(f))
            miss = next(((ax, nm) for ax, nm in wanted if nm not in text), None)
            if miss:
                raise RedFail(f"엣지 5축: {miss[0]} 테스트 이름 {miss[1]} 이 테스트 커밋에 없다")
        tests = self.verify_cmds("test")
        if not tests:
            raise Fail("RED: verify.test 가 없어 테스트를 돌릴 수 없다")
        # 앱별 verify 면 테스트 파일이 들어간 앱의 test 만 본다 — 상관없는 앱의 실패가 RED 로 잡히지 않게
        mine = [t for t in tests if t[0] != "." and any(f.startswith(t[0].rstrip("/") + "/") for f in red[1])]
        if self.red_passes(red[0], self.scoped(mine or tests, base)):
            raise RedFail("RED: 테스트가 아무것도 잡지 않음 — 테스트 커밋 시점에 이미 통과한다")
        return red[0], [f for f in red[1] if TEST_FILE.search(f)]

    def red_blame(self, out: str, root: str, red_tests: list):
        """test 밖 verify(lint·typecheck 등) 출력이 RED 테스트 파일을 가리키면 그 줄(#9). test 출력은 늘 테스트 이름을
        담으니 보지 않는다. 앱별이면 출력 경로가 앱 기준이라 앱 상대 경로·파일 이름도 맞춰 본다."""
        for f in red_tests:
            names = {f, Path(f).name}
            if root != "." and f.startswith(root.rstrip("/") + "/"):
                names.add(f[len(root.rstrip("/")) + 1:])
            lines = [ln.strip() for ln in out.splitlines() if any(n in ln for n in names)]
            if lines:
                return " / ".join(lines[:3])[:300]
        return None

    def blame_earlier(self, root: str, name: str, cmd: str, commits: list, base: str, tail: str = ""):
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
        raise Fail(f"verify 실패: {name} (`{cmd}`) — 이 step 범위에서도 깨진다{tail}")

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
                    full = self.full_reason(step, f)
                    if not full:   # 미룸 — 어느 앱 탓인지 못 고르니 모든 앱의 step 명령
                        picked = None
                    break
                picked.add(own)
                for pat, extra in affects.items():
                    if fnmatch.fnmatch(f, pat):
                        picked.update(extra if isinstance(extra, list) else [extra])
        if full:
            print(f"verify 범위: 전부 — {full}", file=sys.stderr)
            return cmds
        if step["step"] in self.deferred:
            print(f"verify 범위: 전체 미룸(--defer-full-test) — {self.deferred[step['step']]}", file=sys.stderr)
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

    # ── 재판정 진입점 (ADR-023 R3) ─────────────────────────────────────────
    def base_with_tests(self, base: str) -> str:
        """BASE 트리에 HEAD 의 테스트 파일(BASE 뒤 바뀐 것, 지워진 것은 지움)을 얹은 임시 커밋 sha. 브랜치·트리는 그대로."""
        git_dir = Path(self.root, self.git("rev-parse", "--git-dir").stdout.strip())
        env = {**os.environ, "GIT_INDEX_FILE": str(git_dir / f"sdd-rejudge-{self.task}.index")}
        run = lambda *a: subprocess.run(["git", *a], cwd=self.root, env=env, capture_output=True, text=True, check=True)
        try:
            run("read-tree", base)
            for f in self.git("diff", "--name-only", base, "HEAD").stdout.splitlines():
                if not TEST_FILE.search(f) or f.startswith("phases/"):
                    continue
                ls = self.git("ls-tree", "HEAD", "--", f).stdout.split()
                if ls:
                    run("update-index", "--add", "--cacheinfo", f"{ls[0]},{ls[2]},{f}")
                else:
                    run("update-index", "--force-remove", "--", f)
            tree = run("write-tree").stdout.strip()
            return run("commit-tree", tree, "-p", base, "-m", "sdd rejudge: BASE + 고친 테스트").stdout.strip()
        finally:
            Path(env["GIT_INDEX_FILE"]).unlink(missing_ok=True)

    def rejudge(self, n: int) -> int:
        """검증 재판정(ADR-019 E3)이 「테스트가 틀렸다」일 때 — 고친 테스트 커밋을 새 red 로 넘긴다. 걸리면 아무것도 안 바꾼다."""
        cur = self.current()
        if cur is None or cur["step"] != n:
            print(f"지금 차례인 step 은 {cur['step'] if cur else '없음'} 이다 — step {n} 이 아니다")
            return NOT_TURN
        step = cur
        if step.get("status") != "blocked" or not step.get("red"):
            rc = self.refuse_turn(step, "test") if step.get("status") != "blocked" else None
            if rc is None:
                print(f"step {n} 에 red 가 없다 — 재판정 진입점은 red 뒤 구현이 막힌 step 에만 쓴다")
                rc = NOT_TURN
            return rc
        if step.get("rejudged"):
            print(f"step {n} 은 한 번 다시 판정했다 — 그래도 갈리면 사용자에게(ADR-019 E3): {step.get('blocked_reason', '')}")
            return 2
        if self.git("status", "--porcelain", "--", ".", f":(exclude)phases/{self.task}", HOOK_STAMPS).stdout.strip():
            print("커밋하지 않은 변경이 있다 — 고친 테스트만 커밋한 뒤 다시 rejudge")
            return 1
        base, old = step["base"], step["red"]
        fix, touched = self.rejudge_split(step)
        if fix is None:
            print(touched)
            return 1
        if touched:
            print("구현 구간(옛 red 뒤 ~ 고친 테스트 커밋 앞)에서 테스트 파일이 바뀌었다 — 검증이 되돌리는 테스트 커밋을 올린 뒤 "
                  "다시 rejudge:\n" + "\n".join(f"  - {f}" for f in touched))
            return 1
        if not fix or self.git("diff", "--quiet", old, "HEAD", "--", *sorted(set(fix))).returncode == 0:
            print("고친 테스트 커밋이 없다 — HEAD 쪽 끝에 테스트 파일만 담은 커밋으로 고친 테스트를 올린 뒤 다시 rejudge")
            return 1
        tests = self.verify_cmds("test")
        if not tests:
            print("verify.test 가 없어 고친 테스트를 BASE 에서 돌릴 수 없다")
            return 1
        mine = [t for t in tests if t[0] != "." and any(f.startswith(t[0].rstrip("/") + "/") for f in fix)]
        if self.red_passes(self.base_with_tests(base), self.scoped(mine or tests, base)):
            print("고친 테스트가 구현 전(BASE)에서도 통과 — 아무것도 잡지 않는다")
            return 1
        head = self.git("rev-parse", "HEAD").stdout.strip()
        idx = self.read()
        s = self.find(idx, n)
        s["red"], s["status"] = head, "pending"
        s.pop("blocked_reason", None)
        s.pop("blocked_at", None)
        s.pop("blocked_head", None)
        s.setdefault("rejudged", []).append({"at": stamp(), "red_before": old, "attempts_before": len(s.get("attempts") or [])})
        self.write(idx)
        self.commit_index(n)
        print(f"✓ step {n} 재판정 — 테스트 고침 · red: {head[:12]} · 구현 차례")
        return 0

    def rejudge_split(self, step: dict):
        """고친 테스트 묶음 · 구현 구간 가르기. (묶음의 테스트 파일, 구현 구간에서 바뀐 테스트 파일). 묶음이 어긋나면 (None, 이유).
        blocked_head 가 있으면(#86 D4) 묶음 = blocked_head..HEAD · 구현 구간 = 옛 red..blocked_head, 순변화만 센다(D5).
        없는 옛 기록은 끝에서 거꾸로 테스트만 담은(wip: 아닌) 커밋을 묶음으로 본다(D1)."""
        old = step["red"]
        is_test = lambda f: TEST_FILE.search(f) and not f.startswith("phases/")
        blob = lambda rev, f: self.git("rev-parse", "-q", "--verify", f"{rev}:{f}").stdout.strip()
        files_of = lambda sha: self.git("diff-tree", "--no-commit-id", "--name-only", "-r", sha).stdout.split()
        bh = step.get("blocked_head")
        if bh:
            fix = []
            for sha in self.git("rev-list", "--reverse", f"{bh}..HEAD").stdout.split():
                files = files_of(sha)
                if not all(TEST_FILE.search(f) or f.startswith("phases/") for f in files):
                    return None, (f"blocked 뒤 커밋 {sha[:12]} 이 테스트 · phases/ 밖 파일을 담았다 — "
                                  "재판정 뒤에는 테스트 파일만 고쳐 커밋한 뒤 다시 rejudge")
                fix += [f for f in files if is_test(f)]
            changed = {f for sha in self.git("rev-list", f"{old}..{bh}").stdout.split() for f in files_of(sha) if is_test(f)}
            # D5: 판정 4가 되돌려 구현 구간 순변화가 0 이면 받는다 · 검증이 옛 red 내용으로 되돌렸어도 받는다
            touched = sorted(f for f in changed if blob(old, f) != blob(bh, f) and blob(old, f) != blob("HEAD", f))
            return fix, touched
        fix, bundle = [], set()
        for sha, files in reversed(self.commits_since(step["base"])):
            if not all(TEST_FILE.search(f) or f.startswith("phases/") for f in files) \
                    or self.git("log", "-1", "--format=%s", sha).stdout.startswith("wip: "):   # 구현 시도 커밋은 묶음 밖
                break
            bundle.add(sha)
            fix += [f for f in files if is_test(f)]
        touched = sorted({f for sha in self.git("rev-list", f"{old}..HEAD").stdout.split() if sha not in bundle
                          for f in files_of(sha) if is_test(f)})
        return fix, [f for f in touched if blob(old, f) != blob("HEAD", f)]

    def red_passes(self, sha: str, tests: list) -> bool:
        """테스트 커밋 시점으로 잠깐 옮겨 verify.test 를 돌린다. 의존성(node_modules 등)이 있는 이 작업 트리 그대로."""
        head = self.git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
        if head == "HEAD":   # detached — 이름 「HEAD」로 돌아가면 옮겨 간 커밋에 남는다. 시작 sha 로(#86 D3)
            head = self.git("rev-parse", "HEAD").stdout.strip()
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

    def record(self, n: int, base: str, run_failure=None, usage=None, red_only=False) -> int:
        """판정하고 index.json 에 기록·커밋. 0 완료 · 10 재시도 · 1 실패로 멈춤 · 2 blocked.
        red_only(judge --red, 나눔 모드 검증 쪽): 판정 2·3 만 — 통과하면 red 를 적고 step 은 pending 그대로."""
        red = None
        try:
            st = self.find(self.read(), n).get("status")
            if run_failure and st != "blocked":   # 에이전트가 blocked 를 적었으면 실행 실패보다 그게 먼저다
                raise Fail(run_failure)
            if red_only:
                red, res = self.red_check(self.commits_since(base), base, only_tests=True,
                                          step=self.find(self.read(), n))[0], None
            else:
                res = self.check(self.find(self.read(), n), base)
        except PhaseFail as e:
            idx = self.read()
            s = self.find(idx, n)
            s.update(status="blocked", blocked_reason=str(e))
            self.write(idx)
            res = "blocked"
        except RedFail as e:
            res, reason = "fail", str(e)
            idx = self.read()
            s = self.find(idx, n)
            if s.get("red"):   # 나눔 모드 구현 쪽: BASE 로 되돌리면 검증 세션의 테스트 커밋이 지워져 red 가 고아가 된다
                s.update(status="blocked", blocked_reason=f"{e} — 테스트 파일이 verify 에 걸림: 검증 세션 재판정(ADR-019 E3)")
                self.write(idx)
                res = "blocked"
            else:
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
        if red is not None:
            s["red"] = red
            s.pop("last_error", None)
            self.write(idx)
            self.commit_index(n)
            print(f"✓ step {n} RED 확인 — red: {red[:12]} · 구현 차례")
            return 0
        if res == "blocked":
            s["blocked_at"] = stamp()
            if not s.get("red"):   # 나눔 모드는 red 와 짝인 BASE 를 남긴다(재판정 뒤 구현 쪽이 그대로 쓴다)
                s.pop("base", None)   # 재개는 새 BASE 로(앞 시도는 wip 커밋으로 남는다)
            self.write(idx)
            self.commit(f"wip: step {n} — {s['name']} (blocked 시점 코드)")
            if s.get("red"):   # 재판정 묶음 경계(#86 D4) — 이 뒤 커밋은 검증 세션 몫. index 커밋은 phases/ 만 담아 묶음에 섞여도 된다
                s["blocked_head"] = self.git("rev-parse", "HEAD").stdout.strip()
                self.write(idx)
            self.commit_index(n)
            print(f"⏸ step {n} blocked: {s.get('blocked_reason', '')}")
            return 2
        if res is None:
            s["completed_at"] = stamp()
            if n in self.deferred and DEFER_MARK not in (s.get("summary") or ""):
                s["summary"] = " · ".join(x for x in ((s.get("summary") or "").rstrip(), DEFER_MARK) if x)
            s.pop("last_error", None)   # 실패 사유 이력은 attempts 에 남는다(REFLECT 재료)
            s.pop("error_message", None)
            s.pop("base", None)
            self.write(idx)
            self.commit_index(n)
            print(f"✓ step {n} {s['name']}: {s.get('summary', '')}")
            return 0
        # retries = 누적 재시도 수(승격 계수기, 0으로 안 돌림). 한도는 이번 실행(재개 이후)의 실패 수로 센다:
        # 첫 시도 + 재시도 3 = 최대 4회 — sdd-run·sdd 와 같은 문장
        s.setdefault("attempts", []).append({"at": stamp(), "error": reason})
        # 재판정 뒤 구현 차례는 한도를 새로 받는다 — resumed_at 은 쓰지 않는다(쓰면 전체 verify 가 켜진다, #86 D2).
        # 경계는 재판정 때의 attempts 개수로 센다 — 시각은 초 단위라 같은 초의 앞 실패가 섞인다
        last = (s.get("rejudged") or [{}])[-1]
        skip = last.get("attempts_before", 0)
        since = max(s.get("resumed_at", ""), last.get("at", "") if "attempts_before" not in last else "")
        fails_now = sum(1 for a in s["attempts"][skip:] if a["at"] >= since)
        if fails_now > self.max_retries:
            s.update(status="error", error_message=f"[{fails_now}회 시도 후 실패] {reason}", failed_at=stamp())
            s.pop("last_error", None)
            if not s.get("red"):
                s.pop("base", None)
            self.write(idx)
            self.commit(f"wip: step {n} — {s['name']} (멈춘 시점 코드)")   # 강의 execute.py 처럼 실패해도 코드는 남긴다
            self.commit_index(n)
            print(f"✗ step {n} 실패로 멈춤: {reason}")
            return 1
        s["retries"] = s.get("retries", 0) + 1
        s.update(status="pending", last_error=reason)
        s.pop("error_message", None)
        self.write(idx)
        shown = fails_now if s.get("rejudged") else s["retries"]   # 재판정 뒤는 재판정 뒤 수(리뷰 1회차)
        print(f"↻ step {n} 재시도 {shown}/{self.max_retries}: {reason}")
        return 10

    # ── 헤드리스 ───────────────────────────────────────────────────────────
    def invoke(self, step: dict, base: str):
        """claude -p 1번. (실행 실패 사유 또는 None, usage)."""
        claude = os.environ.get("SDD_RUNNER_CLAUDE", "claude")
        cmd = [claude, "-p", "--dangerously-skip-permissions", "--output-format", "json"]
        if step.get("model"):
            cmd += ["--model", step["model"]]
        cmd += ["--effort", self.effort(headless=True)]
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
            base = self.pin_base(n, self.git("rev-parse", "HEAD").stdout.strip())
            idx = self.read()
            s = self.find(idx, n)
            s.setdefault("started_at", stamp())
            why = self.plan_gate(s)
            if why:   # 계획 칸 — claude 를 불러도 못 고친다. 재시도 없이 blocked
                s.update(status="blocked", blocked_reason=why)
                self.write(idx)
                return self.record(n, base)
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
    ap.add_argument("mode", choices=["run", "start", "prompt", "judge", "gate", "rejudge"])
    ap.add_argument("task", help="gate 에서는 DOCS_DIR(레포 루트 기준)")
    ap.add_argument("--timeout", type=int, default=1800)
    ap.add_argument("--max-retries", type=int, default=3)
    ap.add_argument("--base")
    ap.add_argument("--step", type=int)
    ap.add_argument("--role", choices=sorted(ROLE), help="prompt: 나눔 모드 세션 역할 — test(검증) · impl(구현)")
    ap.add_argument("--red", action="store_true", help="judge: 나눔 모드 검증 쪽 — 판정 2·3 만, 통과하면 red 기록")
    ap.add_argument("--effort", choices=EFFORT_LEVELS, help="prompt·run: 역할이 정한 effort 를 덮는다(ADR-019 C2)")
    ap.add_argument("--defer-full-test", action="store_true",
                    help="judge·run: 「전체」로 넓어지는 verify 도 $step 명령만(부하 중, 전체는 릴리스 전 한 번)")
    a = ap.parse_args(argv)
    if a.role and a.mode != "prompt" or a.red and a.mode != "judge":
        ap.error("--role 은 prompt, --red 는 judge 에만 쓴다")
    if a.mode == "gate":   # index.json 을 읽지 않는다 — 계획 전(sdd-plan §0)에도 부른다(ADR-023 R2)
        return gate(a.task)
    r = Runner(a.task, a.max_retries, a.timeout, a.defer_full_test, a.effort)
    if a.mode == "run":
        return r.run()
    if a.mode == "start":
        return r.start()
    if a.mode == "rejudge":
        if not a.step:
            ap.error("rejudge 는 --step N 이 필요하다")
        return r.rejudge(a.step)
    if a.mode == "prompt":
        if a.role:   # 나눔 모드: 끝나지 않은 첫 step 의 차례가 이 역할일 때만(ADR-019 E12)
            step = r.current()
            if step is None:
                print("pending step 없음")
                return 0
            if a.step and a.step != step["step"]:
                print(f"지금 차례인 step 은 {step['step']} 이다 — step {a.step} 이 아니다")
                return NOT_TURN
            rc = r.refuse_turn(step, a.role)
            if rc:
                return rc
            if step.get("status") == "blocked":   # 검증 재판정(E3) — 지시문이 아니라 사유를 본다
                print(f"step {step['step']} blocked — 검증 재판정: {step.get('blocked_reason', '')}")
                print(f"  다음 수: 테스트가 틀렸으면 테스트만 고쳐 커밋한 뒤 `rejudge {r.task} --step {step['step']}`"
                      " · 구현이 고칠 일이면 index.json 의 status 를 pending 으로 되돌린다(ADR-023 R3)")
                return 2
        else:
            step = r.find(r.read(), a.step) if a.step else r.next_pending()
        if step is None:
            print("pending step 없음")
            return 0
        why = r.plan_gate(step)
        if why:   # 계획 칸 — 서브에이전트가 못 고친다. 지시문을 내지 않는다(ADR-019 C1 · G6)
            print(f"step {step['step']} 지시문을 내지 않는다 — {why}")
            return 2
        idx = r.read()
        r.find(idx, step["step"]).setdefault("started_at", stamp())
        r.write(idx)
        base = r.pin_base(step["step"], a.base) if a.base else step.get("base")
        print(f"▶ step {step['step']}", file=sys.stderr)   # judge --step 에 넘길 번호
        print(f"▶ effort {r.effort(a.role)}", file=sys.stderr)   # Agent effort 로 넘긴다(ADR-019 C2)
        print(r.prompt(r.find(r.read(), step["step"]), base, a.role))
        return 0
    # judge: 판정 대상은 번호로 받는다 — '첫 pending' 으로 고르면 방금 completed 로 바뀐 step 을 건너뛴다(10-13 리뷰)
    # BASE 는 prompt --base 가 index.json 에 고정한 값이 먼저다(#11). 없을 때만 --base
    base = r.find(r.read(), a.step).get("base") if a.step else None
    base = base or a.base
    if not a.step or not base:
        ap.error("judge 는 --step N 과 BASE(prompt --base 로 고정했거나 --base <그 step 시작 전 HEAD>)가 필요하다")
    if a.red:   # 차례가 아니면 checkout --detach · reset --hard 가 구현 중인 트리를 친다 — 먼저 막는다
        step, cur = r.find(r.read(), a.step), r.current()
        st = step.get("status")
        # 검증 차례 에이전트가 status 를 바꿨으면 차례 판정보다 먼저 본다 — 아니면 current() 가 다음 step 을 집어
        # 「차례 아님」(3)으로 끝나고, 구현 없이 step 이 넘어간다(리뷰 경고 2)
        if st == "blocked" and not step.get("red") and not step.get("blocked_at"):
            return r.record(a.step, base)   # 막힘 — 1회 모드처럼 기록 · 커밋하고 종료 2(사람)
        if st not in ("pending", "blocked"):
            print(f"step {a.step} status 가 {st} 다 — 검증 차례에는 status 를 바꾸지 않는다(red 는 러너가 적는다). "
                  "index.json 의 status 를 pending 으로 되돌린 뒤 다시 judge --red")
            return 1
        if cur is None or cur["step"] != a.step:
            print(f"지금 차례인 step 은 {cur['step'] if cur else '없음'} 이다 — step {a.step} 이 아니다")
            return NOT_TURN
        rc = r.refuse_turn(step, "test")
        if rc:
            return rc
        if step.get("status") != "pending" or not step.get("tdd") or step.get("kind") == "measure":
            print(f"step {a.step} 은 judge --red 대상이 아니다(tdd: true · pending 만) — "
                  + ("blocked 는 검증 재판정" if step.get("status") == "blocked" else "measure 는 judge --step N"))
            return NOT_TURN
        if r.git("status", "--porcelain", "--", ".", f":(exclude)phases/{r.task}", HOOK_STAMPS).stdout.strip():
            print("커밋하지 않은 변경이 있다 — 테스트 파일만 커밋한 뒤 다시 judge --red")
            return 1
    return r.record(a.step, base, red_only=a.red)


if __name__ == "__main__":
    sys.exit(main())
