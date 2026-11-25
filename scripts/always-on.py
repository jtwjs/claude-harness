#!/usr/bin/env python3
"""모델이 늘 보는 설명 글자 수 — 자동 입구 스킬 + 에이전트 description (ADR-018 B-16).

`claude plugin details` 의 Always-on 은 닫힌 스킬(disable-model-invocation: true)도 세므로 따로 잰다.
글자 수 = frontmatter description 값(따옴표를 벗긴 뒤)의 문자 수. 본문은 세지 않는다.

사용: python3 scripts/always-on.py <플러그인 루트>
출력(탭 구분): 컴포넌트마다 `skill|agent  이름  글자수`(큰 순), 끝에 `total  합계  skills=N agents=M`
"""
import json
import pathlib
import sys


def frontmatter(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    out, key = {}, None
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line[:1] in (" ", "\t") and key:  # 여러 줄 값(블록 · 접힌 일반 값)
            out[key] += ("\n" if out[key + "\0"] == "|" else " ") + line.strip()
            continue
        k, sep, v = line.partition(":")
        if not sep or not k.strip():
            continue
        key, v = k.strip(), v.strip()
        style = v[:1] if v[:1] in (">", "|") else ""
        out[key + "\0"] = style
        out[key] = "" if style else unquote(v)
    return {k: v.strip() for k, v in out.items() if "\0" not in k}


def unquote(v):
    if len(v) >= 2 and v[0] == v[-1] == "'":
        return v[1:-1].replace("''", "'")
    if len(v) >= 2 and v[0] == v[-1] == '"':
        try:
            return json.loads(v)  # YAML 큰따옴표 이스케이프는 JSON 과 거의 같다
        except ValueError:
            return v[1:-1]
    return v


def main(root):
    root = pathlib.Path(root)
    rows = []
    for p in sorted(root.glob("skills/*/SKILL.md")):
        fm = frontmatter(p)
        if fm.get("disable-model-invocation", "").lower() == "true":
            continue
        rows.append(("skill", p.parent.name, len(fm.get("description", ""))))
    for p in sorted(root.glob("agents/*.md")):
        rows.append(("agent", p.stem, len(frontmatter(p).get("description", ""))))
    rows.sort(key=lambda r: -r[2])
    for kind, name, n in rows:
        print(f"{kind}\t{name}\t{n}")
    s = sum(1 for r in rows if r[0] == "skill")
    print(f"total\t{sum(r[2] for r in rows)}\tskills={s} agents={len(rows) - s}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("사용: always-on.py <플러그인 루트>")
    main(sys.argv[1])
