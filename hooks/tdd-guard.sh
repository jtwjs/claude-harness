#!/usr/bin/env bash
# TDD Guard — PreToolUse[Write|Edit] (HARD BLOCK)
#
# 구현 파일을 쓰려는데 짝 테스트가 없으면 차단한다.
# 🔴 대상·면제는 하드코딩하지 않는다 — .claude/harness.json 의 tdd.include / tdd.exclude 를 읽는다.
#    (무엇을 테스트하고 무엇을 안 하는지의 '이유'는 .claude/rules/testing.md §0 이 정본이고,
#     이 훅의 exclude 는 그 표와 같은 내용을 가리켜야 한다. 어긋나면 막는 것과 적힌 것이 달라진다.)
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib/hook-log.sh" 2>/dev/null || hook_log_on_exit() { :; }
hook_log_on_exit tdd-guard   # 끝나는 모든 경로에서 기록 한 줄 — 경로마다 HOOK_RESULT 를 정하고 exit

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { HOOK_RESULT=norepo; exit 0; }
CFG="$REPO_ROOT/.claude/harness.json"
[ -f "$CFG" ] || { HOOK_RESULT=nocfg; exit 0; }
command -v python3 >/dev/null 2>&1 || { HOOK_RESULT=nopython; exit 0; }

input=$(cat 2>/dev/null || true)
[ -n "$input" ] || { HOOK_RESULT=noinput; exit 0; }

# 판정은 python 이 한다. 막을 때는 deny JSON 한 줄, 아니면 결과 이름 한 단어(+ 탭 + 상세)를 stdout 에 — 기록용. JSON 만 그대로 내보낸다.
out=$(INPUT="$input" CFG="$CFG" ROOT="$REPO_ROOT" python3 <<'PY'
import json, os, sys, fnmatch, pathlib

def done(result, detail=""):
    print(f"{result}\t{detail}")
    sys.exit(0)

try:
    payload = json.loads(os.environ["INPUT"])
    cfg = json.load(open(os.environ["CFG"], encoding="utf-8"))
except Exception:
    done("badinput")

root = pathlib.Path(os.environ["ROOT"])
tdd = cfg.get("tdd") or {}
if not tdd.get("enabled"):
    done("off")

fp = (payload.get("tool_input") or {}).get("file_path") or ""
if not fp:
    done("noinput")

try:
    rel = str(pathlib.Path(fp).resolve().relative_to(root))
except Exception:
    done("ignore", "outside")        # 레포 밖 파일은 대상 아님

include = tdd.get("include") or []
exclude = tdd.get("exclude") or []
match = lambda pats: any(fnmatch.fnmatch(rel, p) for p in pats)

if not include or not match(include):
    done("ignore", "notarget")       # 대상 범위 밖
if match(exclude):
    done("ignore", "exempt")         # 면제

p = pathlib.Path(rel)
jvm = p.suffix in (".kt", ".java")
if any(s in p.name for s in (".test.", ".spec.")) or "__tests__" in p.parts:
    done("ignore", "testfile")       # 테스트 파일 자체
if jvm and (p.stem.endswith(("Test", "Tests")) or "/src/test/" in f"/{rel}"):
    done("ignore", "testfile")       # JVM 테스트 파일 자체

# 선언만 있는 파일(data class · enum · type · interface, 함수 본문 0)은 짝 테스트 면제 — testing.md §0 「타입 선언」
import re
ti = payload.get("tool_input") or {}
if "content" in ti:
    after = ti.get("content") or ""
else:                                # Edit: 지금 파일에 바꿀 조각을 대 본 결과로 판정
    try:
        cur = (root / rel).read_text(encoding="utf-8")
    except Exception:
        cur = ""
    after = cur.replace(ti.get("old_string") or "", ti.get("new_string") or "")
code = re.sub(r"/\*.*?\*/|//[^\n]*", "", after, flags=re.S)
logic = (r"\bfun\b|\binit\s*\{|\bget\(\)" if jvm else r"\bfunction\b|=>|\bclass\b")
if code.strip() and not re.search(logic, code):
    done("ignore", "decl")

stem = p.name.rsplit(".", 1)[0]
ext  = p.suffix
if jvm:
    # src/main/kotlin/a/Foo.kt ↔ src/test/kotlin/a/FooTest.kt (또는 FooTests.kt)
    tdir = pathlib.Path(f"/{rel}".replace("/src/main/", "/src/test/", 1).lstrip("/")).parent
    cands = [tdir / f"{stem}Test{ext}", tdir / f"{stem}Tests{ext}"]
    expect = f"{tdir}/{stem}Test{ext}"
else:
    cands = [p.with_name(f"{stem}.test{ext}"), p.with_name(f"{stem}.spec{ext}"),
             p.parent / "__tests__" / f"{stem}.test{ext}"]
    for c in (p.with_suffix("").with_name(f"{stem}.test.ts"),
              p.with_suffix("").with_name(f"{stem}.test.tsx")):
        cands.append(c)
    expect = f"{stem}.test{ext} 또는 __tests__/{stem}.test{ext}"

if any((root / c).is_file() for c in cands):
    done("paired")

reason = (
    f"TDD GUARD: '{p.name}' 의 짝 테스트가 없습니다. 구현 전 실패 테스트를 먼저 작성하세요.\n"
    f"  기대 경로: {expect}\n"
    f"  대상 범위는 .claude/harness.json 의 tdd.include, 면제는 tdd.exclude 이고,\n"
    f"  '무엇을 테스트하고 무엇을 안 하는가'의 정본은 .claude/rules/testing.md §0 입니다."
)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": reason,
}}, ensure_ascii=False))
PY
)
case "$out" in
  "{"*) HOOK_RESULT=blocked; printf '%s\n' "$out" ;;
  "") HOOK_RESULT=error ;;   # python 이 죽음(예전처럼 통과)
  *) HOOK_RESULT="${out%%$'\t'*}" HOOK_DETAIL="${out#*$'\t'}" ;;
esac
exit 0
