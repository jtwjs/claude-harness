#!/usr/bin/env python3
"""CI 워크플로 플레이스홀더 채우기 — harness-init §4. 템플릿 사본을 그 자리에서 고친다.

Usage:
    fill_ci.py <harness.json> <ci.yml>
    <harness.json> 은 <레포>/.claude/harness.json, <ci.yml> 은 ${CLAUDE_PLUGIN_ROOT}/templates/.github/workflows/ci.yml 을 복사한 레포 파일.

    {{BASE_BRANCH}}    ← scripts/base-branch.sh <레포> (git.baseBranch → origin/HEAD). 못 정하면 남긴다 — 사람에게 묻는다
    {{SETUP_STEPS}}    팩이 없으면(stacks.packs 빈 값) 주석 줄째 지운다. 팩이 있으면 pack.md 「CI 셋업 스텝」으로 먼저 채워 둔다
                       (Java 버전 · 패키지 매니저는 판단이라 스크립트가 고르지 않는다). 남아 있으면 남긴 것으로 센다
    {{VERIFY_FORMAT}} {{VERIFY_LINT}} {{VERIFY_TYPECHECK}} {{VERIFY_BUILD}}
                       ← verify.format · lint · typecheck · build. 빈 값이면 그 `- name:` 스텝을 통째로 지운다
    {{VERIFY_TEST}}    ← verify.test. 빈 값이면 ci.test 가 "deferred" 일 때만 echo 줄, 아니면 남긴다(테스트 스텝은 지우지 않는다)
    verify 가 앱별({"<root>": {…}})이면 VERIFY_* 는 건드리지 않는다 — jobs 를 ci.yml 맨 아래 앱별 형태로 바꾼 뒤 다시 돌린다.

    채운 것은 stdout. 남은 플레이스홀더(\\{\\{[A-Z_]+\\}\\}, GitHub 식 ${{ … }} 는 아님)가 있으면 이유를 stderr 로 내고 exit 1.
    채울 수 있는 것은 exit 1 이어도 채워 두니, 원인을 고치고 다시 돌리면 된다. 파일을 못 읽으면 exit 2.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

PH = re.compile(r"\{\{([A-Z_]+)\}\}")
BASE_SH = Path(__file__).resolve().parents[3] / "scripts" / "base-branch.sh"
DEFERRED = 'echo "test deferred — .claude/harness.json ci.test 참고"'
STEPS = {"VERIFY_FORMAT": "format", "VERIFY_LINT": "lint", "VERIFY_TYPECHECK": "typecheck", "VERIFY_BUILD": "build"}


def scalar(cmd: str) -> str:
    """run: 값. YAML 평문으로 못 쓰는 명령(「: 」 · 「 #」 · 끝 콜론 · 앞 지시자)만 따옴표로 — 깨진 YAML 은 워크플로째 거부된다."""
    if ": " in cmd or " #" in cmd or cmd.endswith(":") or cmd[0] in "-?:,[]{}#&*!|>'\"%@`":
        return json.dumps(cmd, ensure_ascii=False)
    return cmd


def base_branch(cfg_path: str):
    repo = os.path.dirname(os.path.dirname(os.path.abspath(cfg_path)))
    r = subprocess.run(["bash", str(BASE_SH), repo], capture_output=True, text=True)
    out = r.stdout.strip()
    if r.returncode == 0 and out:
        return ("값", out)
    return ("남김", r.stderr.strip() or "scripts/base-branch.sh 실패 — 사람에게 묻는다")


def plan(cfg: dict, cfg_path: str) -> dict:
    """플레이스홀더 → ("값", 넣을 값) | ("스텝", 지우는 이유) | ("줄", 지우는 이유) | ("남김", 남기는 이유)."""
    p = {"BASE_BRANCH": base_branch(cfg_path)}
    packs = (cfg.get("stacks") or {}).get("packs") or []
    p["SETUP_STEPS"] = ("남김", "stacks.packs 가 있다 — pack.md 「CI 셋업 스텝」으로 먼저 채운다") if packs else ("줄", "팩 없음")
    verify = cfg.get("verify") or {}
    if any(not k.startswith("$") and isinstance(v, dict) for k, v in verify.items()):
        why = "verify 가 앱별 — jobs 를 ci.yml 맨 아래 앱별 형태로 바꾼 뒤 다시 돌린다"
        p.update({n: ("남김", why) for n in (*STEPS, "VERIFY_TEST")})
        return p
    val = {k: (v.strip() if isinstance(v, str) else "") for k, v in verify.items()}
    for name, key in STEPS.items():
        p[name] = ("값", val[key]) if val.get(key) else ("스텝", f"verify.{key} 빈 값")
    if val.get("test"):
        p["VERIFY_TEST"] = ("값", val["test"])
    elif (cfg.get("ci") or {}).get("test") == "deferred":
        p["VERIFY_TEST"] = ("값", DEFERRED)
    else:
        p["VERIFY_TEST"] = ("남김", 'verify.test 가 비었는데 ci.test 가 "deferred" 가 아니다 — 둘 중 하나를 채운다')
    return p


def fill(text: str, p: dict):
    done = []
    for name, (kind, v) in p.items():
        tok = "{{%s}}" % name
        if tok not in text or kind == "남김":
            continue
        if kind == "값":
            text = text.replace(tok, v if name == "BASE_BRANCH" else scalar(v))
            done.append(f"{tok} → {v}")
            continue
        if kind == "스텝":  # `- name: x` 줄 + `run: {{…}}` 줄 + 뒤 빈 줄 하나
            pat = r"^[ \t]*- name:[^\n]*\n[ \t]*run:[ \t]*" + re.escape(tok) + r"[ \t]*(?:\n|\Z)(?:[ \t]*\n)?"
        else:  # 주석 줄 + 뒤 빈 줄 하나
            pat = r"^[ \t]*#[^\n]*" + re.escape(tok) + r"[^\n]*(?:\n|\Z)(?:[ \t]*\n)?"
        text, n = re.subn(pat, "", text, flags=re.M)
        if n:
            done.append(f"{tok} → {'스텝' if kind == '스텝' else '줄'} 삭제({v})")
    return text, done


def main(argv: list) -> int:
    ap = argparse.ArgumentParser(prog="fill_ci.py", description="CI 워크플로 플레이스홀더를 harness.json 으로 채운다")
    ap.add_argument("harness_json", help="<레포>/.claude/harness.json")
    ap.add_argument("ci_yml", help="템플릿을 복사한 .github/workflows/ci.yml (그 자리에서 고친다)")
    args = ap.parse_args(argv)
    try:
        cfg = json.loads(Path(args.harness_json).read_text(encoding="utf-8"))
        text = Path(args.ci_yml).read_text(encoding="utf-8")
    except (OSError, ValueError) as e:
        print(f"fill_ci.py: 파일을 못 읽음: {e}", file=sys.stderr)
        return 2
    if not isinstance(cfg, dict):
        print(f"fill_ci.py: {args.harness_json} 가 JSON 객체가 아니다", file=sys.stderr)
        return 2
    p = plan(cfg, args.harness_json)
    new, done = fill(text, p)
    if new != text:
        Path(args.ci_yml).write_text(new, encoding="utf-8")
    for line in done:
        print(line)
    left = sorted(set(PH.findall(new)))
    if not left:
        return 0
    print(f"fill_ci.py: 남은 플레이스홀더 {len(left)}개", file=sys.stderr)
    for name in left:
        kind, why = p.get(name, ("남김", "fill_ci.py 가 모르는 플레이스홀더 — 손으로 채운다"))
        print(f"  {{{{{name}}}}} — {why if kind == '남김' else '템플릿과 모양이 달라 못 지움 — 손으로 지운다'}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
