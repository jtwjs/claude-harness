#!/usr/bin/env python3
"""sdd 판정 스크립트 테스트 — 구현 시작 관문(gate.py) · 테스트 무변경(tests_unchanged.py) · 테스트 통과(tests_pass.py).

임시 git 레포를 만들어 스크립트를 실제로 부른다. 관문 케이스는 러너(sdd_runner.py gate)에서 옮겼다(ADR-028).

실행: python3 -m unittest skills/sdd/scripts/test_sdd_checks.py
"""
import json
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
GATE = HERE / "gate.py"
UNCHANGED = HERE / "tests_unchanged.py"
PASS = HERE / "tests_pass.py"


def git(cwd, *args):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)


def commit(cwd, msg):
    git(cwd, "add", "-A")
    git(cwd, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", msg)
    return git(cwd, "rev-parse", "HEAD").stdout.strip()


class RepoCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        (self.repo / "src").mkdir()
        (self.repo / "src/b.txt").write_text("x")
        commit(self.repo, "init")
        self.out = ""

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_script(self, script, *args, cwd=None):
        p = subprocess.run([sys.executable, str(script), *args], cwd=cwd or self.repo, capture_output=True, text=True)
        self.out = p.stdout + p.stderr
        return p

    def write(self, rel, body):
        f = self.repo / rel
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(body)


# ── 구현 시작 관문 (ADR-023 R1 · R2, 러너 밖으로 옮김) ─────────────────────────
class GateTest(RepoCase):
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
        for name, body in (("ADR.md", adr), ("PRD.md", prd), ("ARCHITECTURE.md", arch)):
            if body is not None:
                self.write(f"{path}/{name}", body)
        commit(self.repo, f"docs {path}")
        return path

    def gate(self, path, cwd=None):
        return self.run_script(GATE, path, cwd=cwd)

    def test_gate_no_docs_passes(self):
        p = self.gate("docs/none")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("ADR · PRD 없음", p.stdout, "문서가 없으면 막지 않는다")
        path = self.docs("docs/arch-only", arch="# ARCHITECTURE\n기존 구조 그대로\n")
        p = self.gate(path)
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("ADR · PRD 없음", p.stdout)
        self.assertEqual(git(self.repo, "status", "--porcelain").stdout.strip(), "", "관문은 아무것도 쓰지 않는다")

    def test_gate_all_closed_passes(self):
        path = self.docs(adr=self.ADR_CLOSED, prd="# PRD\n- **범위**: x\n")
        p = self.gate(path)
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("열린 「정할 것」 0", p.stdout)

    def test_gate_open_rows_stop_with_list(self):
        path = self.docs(adr=self.ADR_OPEN, prd=self.PRD_LABEL)
        p = self.gate(path)
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 3개", p.stdout)
        self.assertIn("  - ADR R2: 세는 칸", p.stdout, "주체 칸이 빈 행")
        self.assertIn("  - ADR S1: 진입점 모양", p.stdout, "주체 칸이 공백뿐인 행 · 둘째 ADR 블록")
        self.assertIn("  - PRD: ⚠️ 테스트 모양", p.stdout)
        self.assertNotIn("R1", p.stdout.replace("ADR-900 R1", ""), "주체가 찬 행은 닫힌 것")
        self.assertNotIn("S2", p.stdout)
        self.assertNotIn("느림", p.stdout, "「결정할 것」 절 밖의 표는 세지 않는다")

    def test_gate_relative_path_from_subfolder(self):
        path = self.docs(adr=self.ADR_OPEN)
        p = self.gate(path, cwd=self.repo / "src")
        self.assertEqual(p.returncode, 2, "상대 경로는 레포 루트 기준이다\n" + self.out)

    def test_gate_table_without_owner_column_counts_all(self):
        adr = textwrap.dedent('''\
            # ADR
            ## 결정할 것
            | # | 정할 것 | 추천 |
            |---|---|---|
            | Q1 | 하나 | A |
            | Q2 | 둘 | B |
        ''')
        p = self.gate(self.docs(adr=adr))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("  - ADR Q1: 하나", p.stdout, "주체 칸이 없으면 모든 행이 열린 것(기본이 멈춤)")
        self.assertIn("  - ADR Q2: 둘", p.stdout)

    def test_gate_prd_marked_lines_excluded(self):
        path = self.docs(prd=self.PRD_LABEL)
        self.assertEqual(self.gate(path).returncode, 2, self.out)
        self.docs(prd=self.PRD_LABEL.replace("⚠️ 테스트 모양", "⚠️ 테스트 모양 → 결정: ADR-900 R2"))
        self.assertEqual(self.gate(path).returncode, 0, "닫힘 표시를 달면 통과한다\n" + self.out)
        self.docs(prd=self.PRD_LABEL.replace("⚠️ 테스트 모양", "⚠️ 테스트 모양 막지 않음: 구현과 무관"))
        self.assertEqual(self.gate(path).returncode, 0, "막지 않음: 표시도 뺀다\n" + self.out)

    def test_gate_prd_heading_and_label_forms(self):
        p = self.gate(self.docs("docs/h", prd=self.PRD_HEADING))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 1개", p.stdout)
        self.assertIn("  - PRD: ⚠️ A 정하기", p.stdout, "제목 꼴: 다음 같은 급 제목 전까지")
        self.assertNotIn("B 다음", p.stdout)
        self.assertNotIn("D 범위 밖", p.stdout)
        p = self.gate(self.docs("docs/l", prd=self.PRD_LABEL))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 1개", p.stdout, "불렛 라벨 꼴: 첫 단 항목만 · 라벨 범위 밖은 안 센다")
        self.assertNotIn("하위 메모", p.stdout)
        self.assertNotIn("AC-1", p.stdout)

    def test_gate_label_inline_strips_marks(self):
        for i, prd in enumerate(("# PRD\n- **남은 ⚠️** — 없음\n", "# PRD\n- **남은 ⚠️:** 없음\n")):
            p = self.gate(self.docs(path=f"docs/n{i}", prd=prd))
            self.assertEqual(p.returncode, 0, "굵게 안 콜론 · 줄표 뒤 「없음」은 항목 없음\n" + self.out)
        p = self.gate(self.docs(path="docs/o", prd="# PRD\n- **남은 ⚠️:** 결제 재시도 미정\n"))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("PRD: 결제 재시도 미정\n", p.stdout, "앞에 ** 가 붙지 않는다")

    def test_gate_prd_none_item_passes(self):
        for prd in ("# PRD\n## 남은 ⚠️\n\n- 없음 (판정 방식은 ADR)\n",
                    "# PRD\n- **남은 ⚠️**\n  - 없음\n"):
            p = self.gate(self.docs(prd=prd))
            self.assertEqual(p.returncode, 0, "「없음」 항목은 항목 없음 표시라 세지 않는다\n" + self.out)

    def test_gate_prd_none_inside_text_still_counts(self):
        p = self.gate(self.docs(prd="# PRD\n## 남은 ⚠️\n- ⚠️ 기본값 없음 처리\n- 없음표 정리\n"))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 2개", p.stdout, "「없음」이 본문 가운데 있거나 낱말 일부면 그대로 센다")

    def test_gate_heading_without_fe0f_counts(self):
        for prd in ("# PRD\n## 남은 ⚠\n- 결제 재시도 정책 미정\n",
                    "# PRD\n- **남은 ⚠**\n  - 결제 재시도 정책 미정\n"):
            p = self.gate(self.docs(prd=prd))
            self.assertEqual(p.returncode, 2, "변이 선택자 없는 ⚠ 도 같은 표시다\n" + self.out)
            self.assertIn("PRD: 결제 재시도 정책 미정", p.stdout)

    def test_gate_escaped_pipe_cell_counts(self):
        head = "# ADR\n### 결정할 것\n\n| # | 정할 것 | 추천 | 주체 |\n|---|---|---|---|\n"
        p = self.gate(self.docs(adr=head + "| R1 | `a \\| b` 중 무엇 | A |  |\n"))
        self.assertEqual(p.returncode, 2, "셀 안 \\| 는 칸 나눔이 아니다 — 주체 칸이 비었다\n" + self.out)
        self.assertIn("ADR R1:", p.stdout)
        p = self.gate(self.docs(path="docs/e", adr=head + "| R1 | `a \\| b` 중 무엇 | A | 사용자 |\n"))
        self.assertEqual(p.returncode, 0, "주체가 찬 행은 칸이 밀려도 닫힘\n" + self.out)

    def test_gate_label_inline_content_counts(self):
        p = self.gate(self.docs(prd="# PRD\n- **남은 ⚠️**: 결제 재시도 정책 미정\n"))
        self.assertEqual(p.returncode, 2, "라벨 줄에 붙여 쓴 내용도 열린 항목\n" + self.out)
        self.assertIn("PRD: 결제 재시도 정책 미정", p.stdout)
        p = self.gate(self.docs(path="docs/e", prd="# PRD\n- **남은 ⚠️**: A 미정\n  - B 미정\n"))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 2개", p.stdout, "붙여 쓴 내용 + 아래 항목")
        for i, prd in enumerate(("# PRD\n- **남은 ⚠️**: 없음\n",
                                 "# PRD\n- **남은 ⚠️**: 재시도 정책 → 결정: ADR-1\n",
                                 "# PRD\n- **남은 ⚠️** (닫힘 표시 규칙은 ADR)\n")):
            p = self.gate(self.docs(path=f"docs/c{i}", prd=prd))
            self.assertEqual(p.returncode, 0, "「없음」 · 닫힘 표시 규칙은 같다 · 괄호 설명은 내용이 아니다\n" + self.out)

    def test_gate_numbered_and_plus_bullets_count(self):
        p = self.gate(self.docs(prd="# PRD\n## 남은 ⚠️\n1. A 미정\n2) B 미정\n+ C 미정\n"))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("열린 「정할 것」 3개", p.stdout, "번호 목록 · + 불렛도 첫 단 항목")
        p = self.gate(self.docs(path="docs/e", prd="# PRD\n- **남은 ⚠️**\n  1. D 미정\n"))
        self.assertEqual(p.returncode, 2, self.out)
        self.assertIn("PRD: D 미정", p.stdout)

    def test_gate_no_docs_prints_resolved_path(self):
        p = self.gate("docs/typo-2026")
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("docs/typo-2026", p.stdout, "문서 없음 · 경로 오타를 가를 수 있게 해석한 폴더를 같이 낸다")


# ── 테스트 무변경 — 검증 세션이 넘긴 테스트 커밋 sha 뒤에 테스트 파일이 바뀌지 않았나 ──────────
class TestsUnchangedTest(RepoCase):
    def setUp(self):
        super().setUp()
        self.write("tests/test_a.py", "assert True\n")
        self.sha = commit(self.repo, "test: a")   # 검증 세션의 테스트 커밋

    def unchanged(self, sha=None):
        return self.run_script(UNCHANGED, sha or self.sha)

    def test_impl_only_passes(self):
        self.write("src/a.py", "x = 1\n")
        commit(self.repo, "feat: a")
        p = self.unchanged()
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("테스트 파일 무변경", p.stdout)

    def test_committed_test_edit_fails_with_list(self):
        self.write("src/a.py", "x = 1\n")
        self.write("tests/test_a.py", "assert 1\n")
        commit(self.repo, "feat: a")
        p = self.unchanged()
        self.assertEqual(p.returncode, 1, "구현 커밋이 테스트를 고치면 종료 1\n" + self.out)
        self.assertIn("tests/test_a.py", p.stdout)

    def test_uncommitted_test_edit_fails(self):
        self.write("tests/test_a.py", "assert 1\n")
        p = self.unchanged()
        self.assertEqual(p.returncode, 1, "커밋 안 한 테스트 수정도 잡는다\n" + self.out)
        git(self.repo, "add", "-A")
        self.assertEqual(self.unchanged().returncode, 1, "스테이징만 한 수정도 잡는다\n" + self.out)

    def test_new_untracked_test_file_fails(self):
        self.write("tests/test_new.py", "assert True\n")
        p = self.unchanged()
        self.assertEqual(p.returncode, 1, "구현 쪽이 더한 테스트 파일(추적 전)도 테스트 변경이다\n" + self.out)
        self.assertIn("tests/test_new.py", p.stdout)

    def test_untracked_test_from_subfolder_fails(self):
        self.write("tests/test_new.py", "assert True\n")
        p = self.run_script(UNCHANGED, self.sha, cwd=self.repo / "src")
        self.assertEqual(p.returncode, 1, "하위 폴더에서 불러도 레포 전체를 본다\n" + self.out)
        self.assertIn("tests/test_new.py", p.stdout, "경로는 레포 루트 기준")

    def test_deleted_test_fails(self):
        git(self.repo, "rm", "-q", "tests/test_a.py")
        commit(self.repo, "chore: 지움")
        p = self.unchanged()
        self.assertEqual(p.returncode, 1, self.out)
        self.assertIn("tests/test_a.py", p.stdout)

    def test_renamed_test_shows_old_path(self):
        git(self.repo, "mv", "tests/test_a.py", "src/a_check.txt")
        commit(self.repo, "chore: 옮김")
        p = self.unchanged()
        self.assertEqual(p.returncode, 1, "이름 바꾸기로 옛 테스트 경로가 숨지 않는다(--no-renames)\n" + self.out)
        self.assertIn("tests/test_a.py", p.stdout)

    def test_non_ascii_path_unquoted(self):
        self.write("tests/한글 테스트.test.ts", "it('a')\n")
        sha = commit(self.repo, "test: 한글")
        self.write("tests/한글 테스트.test.ts", "it('b')\n")
        commit(self.repo, "feat")
        p = self.unchanged(sha)
        self.assertEqual(p.returncode, 1, self.out)
        self.assertIn("tests/한글 테스트.test.ts", p.stdout, "비ASCII · 공백 경로가 따옴표 없이 그대로 나온다")

    def test_pycache_not_a_test_change(self):
        self.write("tests/__pycache__/test_a.cpython-312.pyc", "bytes")
        self.write("src/x.pyc", "bytes")
        p = self.unchanged()
        self.assertEqual(p.returncode, 0, "tests/__pycache__ · .pyc 는 테스트 파일이 아니다(오탐 1건)\n" + self.out)

    def test_test_file_patterns(self):
        for rel in ("web/a.test.ts", "web/__tests__/b.js", "app/src/test/kotlin/C.kt", "api/FooTest.kt",
                    "pkg/x_test.go", "hooks/test.sh", "scripts/test_y.py"):
            with self.subTest(rel=rel):
                self.write(rel, "1")
                self.assertEqual(self.unchanged().returncode, 1, f"{rel} 는 테스트 파일이다\n" + self.out)
                (self.repo / rel).unlink()
        for rel in ("hooks/tdd-guard.sh", "src/testing.py", "docs/test-plan.md"):
            with self.subTest(rel=rel):
                self.write(rel, "1")
                self.assertEqual(self.unchanged().returncode, 0, f"{rel} 는 테스트 파일이 아니다\n" + self.out)
                (self.repo / rel).unlink()

    def test_bad_sha_exits_2(self):
        p = self.unchanged("nope123")
        self.assertEqual(p.returncode, 2, "읽을 수 없는 커밋은 통과가 아니다\n" + self.out)

    def test_no_args_exits_2(self):
        p = self.run_script(UNCHANGED)
        self.assertEqual(p.returncode, 2, self.out)


# ── 테스트 통과 — harness.json verify 의 test 명령을 돌려 종료 코드로 판정 ─────────────────────
class TestsPassTest(RepoCase):
    def setUp(self):
        super().setUp()
        self.start = git(self.repo, "rev-parse", "HEAD").stdout.strip()   # 브랜치 시작점(main 머리)
        git(self.repo, "switch", "-q", "-c", "feature/t")
        self.write("tests/a.expect", "hello")
        commit(self.repo, "test: a")
        # 명령은 받은 인자를 기록하고 src/a.txt 가 tests/a.expect 와 같으면 통과
        self.write("check.sh", 'printf "%s\\n" "$*" >> "$LOG_FILE"\n'
                               '[ "$(cat src/a.txt 2>/dev/null)" = "$(cat tests/a.expect)" ]\n')
        self.log = self.tmp / "log.txt"

    def cfg(self, verify, base="main"):
        self.write(".claude/harness.json", json.dumps({"git": {"baseBranch": base}, "verify": verify}))

    def passes(self, *args):
        p = subprocess.run([sys.executable, str(PASS), *args], cwd=self.repo, capture_output=True, text=True,
                           env={"PATH": "/usr/bin:/bin", "LOG_FILE": str(self.log)})
        self.out = p.stdout + p.stderr
        return p

    def test_full_command_pass_and_fail(self):
        self.cfg({"test": "sh check.sh full"})
        p = self.passes()
        self.assertEqual(p.returncode, 1, "구현 전에는 실패\n" + self.out)
        self.write("src/a.txt", "hello")
        p = self.passes()
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("full", self.log.read_text())

    def test_step_command_gets_branch_start(self):
        self.cfg({"test": "sh check.sh full", "$step": {"test": "sh check.sh since {since}"}})
        self.write("tests/b.expect", "")
        commit(self.repo, "test: b (둘째 테스트 커밋)")
        self.write("src/a.txt", "hello")
        p = self.passes()
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn(f"since {self.start}", self.log.read_text(),
                      "{since} = 브랜치 시작점(ADR-025) — 테스트 커밋이 여럿이어도 전부 범위에 든다")
        self.assertNotIn("full", self.log.read_text())

    def test_step_command_without_base_runs_full(self):
        self.cfg({"test": "sh check.sh full", "$step": {"test": "sh check.sh since {since}"}}, base="nope")
        self.write("src/a.txt", "hello")
        p = self.passes()
        self.assertEqual(p.returncode, 0, self.out)
        self.assertIn("full", self.log.read_text(), "브랜치 시작점을 못 찾으면 전체 명령(놓치는 쪽으로 실패하지 않게)")
        self.assertNotIn("since", self.log.read_text())

    def test_app_form_runs_each_app_in_its_folder(self):
        for app in ("web", "api"):
            self.write(f"{app}/check.sh", f'echo {app} >> "$LOG_FILE"\n[ -f ok ]\n')
        self.write("web/ok", "1")
        self.cfg({"web": {"test": "sh check.sh"}, "api": {"test": "sh check.sh", "lint": "false"}})
        p = self.passes()
        self.assertEqual(p.returncode, 1, "한 앱이라도 실패면 종료 1\n" + self.out)
        self.assertEqual(sorted(self.log.read_text().split()), ["api", "web"], "앱마다 그 폴더에서 · test 만 돈다")
        self.write("api/ok", "1")
        self.assertEqual(self.passes().returncode, 0, self.out)

    def test_no_test_command_exits_2(self):
        self.cfg({"lint": "true"})
        p = self.passes()
        self.assertEqual(p.returncode, 2, "test 명령이 없으면 통과가 아니다\n" + self.out)

    def test_no_harness_json_exits_2(self):
        p = self.passes()
        self.assertEqual(p.returncode, 2, self.out)

    def test_extra_args_exit_2(self):
        self.cfg({"test": "sh check.sh full"})
        p = self.passes("abc123")
        self.assertEqual(p.returncode, 2, "인자는 받지 않는다\n" + self.out)


if __name__ == "__main__":
    unittest.main()
