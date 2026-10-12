#!/usr/bin/env python3
"""운영 DB 판별 — harness.json guard.prodDb 가 가리키는 설정 파일을 디스크에서 읽어 호스트를 뽑는다.

harness.json 에는 값을 적지 않고 위치만 적는다(호스트를 레포 밖·문서로 옮기지 않는다는 규칙, 2026-10-13):
    "guard": { "prodDb": {
        "from":     ["spring:prod", "env:.env:PROD_CPM_DB_HOST"],
        "switches": ["NODE_ENV=production"] } }

  spring:<profile>     application-<profile>.yml|yaml|properties 의 datasource url. ${VAR} 면 레포의 .env* 에서 VAR 를 푼다
  env:<file>:<key>     그 파일의 그 키. git 에서 제외된 .env 라도 로컬에 있으면 읽는다
  switches             Node 처럼 프로필이 없는 레포에서 운영으로 바꾸는 표시. 명령에 그대로 들어 있으면 운영 실행으로 본다

같은 호스트를 가리키는 다른 Spring 프로필은 자동으로 운영 프로필이 된다(stage 가 운영 DB 를 가리킨 레포가 있었다).
호스트를 하나도 못 찾으면 → 그 레포는 에이전트도 운영 DB 에 붙을 정보가 없다. 그래도 설정을 적었는데 못 읽은 것이니
세션 시작 때 '꺼짐' 으로 알린다(prod-db-check.sh). 출력에 호스트 값은 절대 넣지 않는다.

CLI:
    prod_db.py check <repo> <cmd>   → 차단이면 "제목|사유" 한 줄, 아니면 무출력
    prod_db.py status <repo>        → 못 읽은 항목 한 줄씩 (값 없이)
"""
import json
import os
import re
import sys
from pathlib import Path

SKIP_DIRS = {".git", "node_modules", "build", "dist", "out", "target", ".gradle", ".next", ".venv"}
URL_HOST = re.compile(r"^[a-z][a-z0-9+.:-]*://(?:[^@/\s]*@)?\[?([^\]/:?\s;]+)", re.I)
VAR = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::[^}]*)?\}")
WRITE_SQL = re.compile(r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE)\b", re.I)


def walk(root: Path, max_depth: int = 6):
    root_depth = len(root.parts)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        if len(Path(dirpath).parts) - root_depth >= max_depth:
            dirnames[:] = []
        for f in filenames:
            yield Path(dirpath) / f


def read_env(path: Path) -> dict:
    out = {}
    try:
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            m = re.match(r"\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$", line)
            if m:
                out[m.group(1)] = m.group(2).strip().strip("'\"")
    except OSError:
        pass
    return out


def all_env(root: Path) -> dict:
    env = {}
    for p in walk(root, 4):
        if p.name.startswith(".env") and not p.name.endswith((".example", ".sample", ".template")):
            env.update(read_env(p))
    return env


def host_of(value: str, env: dict):
    """url 또는 호스트 값 → (호스트, 그 값을 담은 변수 이름들)."""
    names = set()
    for _ in range(3):  # ${A} → ${B} 처럼 겹친 것까지
        m = VAR.search(value or "")
        if not m:
            break
        names.add(m.group(1))
        if m.group(1) not in env:
            return None, names
        value = VAR.sub(lambda x: env.get(x.group(1), x.group(0)), value)
    value = (value or "").strip()
    if not value:
        return None, names
    if value.startswith("jdbc:"):
        value = value[5:]
    m = URL_HOST.match(value)
    if m:
        return m.group(1), names
    if re.fullmatch(r"[A-Za-z0-9.-]+", value):
        return value, names
    return None, names


def spring_url(text: str):
    for line in text.splitlines():
        m = re.search(r"(?:^|\.)url\s*[:=]\s*(\S+)", line.strip())
        if m and ("jdbc:" in m.group(1) or "${" in m.group(1) or "://" in m.group(1)):
            return m.group(1).strip("'\"")
    return None


def spring_files(root: Path) -> dict:
    """profile → [파일]."""
    out = {}
    for p in walk(root):
        m = re.fullmatch(r"application-([A-Za-z0-9_-]+)\.(ya?ml|properties)", p.name)
        if m:
            out.setdefault(m.group(1), []).append(p)
    return out


def resolve(root: Path, cfg: dict) -> dict:
    env = all_env(root)
    springs = spring_files(root)
    hosts, refs, problems = set(), set(), []
    for item in cfg.get("from", []) or []:
        kind, _, rest = str(item).partition(":")
        found = None
        if kind == "spring":
            for f in springs.get(rest, []):
                url = spring_url(f.read_text(encoding="utf-8", errors="ignore"))
                if url:
                    h, names = host_of(url, env)
                    refs |= names
                    found = h or found
            if not found:
                problems.append(f"{item} — application-{rest} 설정에서 DB 주소를 못 읽음")
        elif kind == "env":
            fname, _, key = rest.rpartition(":")
            val = read_env(root / fname).get(key) if fname else None
            refs.add(key)
            if val:
                found, names = host_of(val, env)
                refs |= names
            if not found:
                problems.append(f"{item} — 파일이 없거나 그 키가 비어 있음")
        else:
            problems.append(f"{item} — spring:<프로필> 또는 env:<파일>:<키> 형식이 아님")
        if found:
            hosts.add(found)
    profiles = set()
    for prof, files in springs.items():
        for f in files:
            url = spring_url(f.read_text(encoding="utf-8", errors="ignore"))
            h = host_of(url, env)[0] if url else None
            if h and h in hosts:
                profiles.add(prof)
    switches = [s for s in cfg.get("switches", []) or [] if isinstance(s, str) and s]
    return {"hosts": hosts, "refs": refs, "profiles": profiles, "switches": switches, "problems": problems}


def load_cfg(root: Path):
    try:
        return (json.loads((root / ".claude/harness.json").read_text(encoding="utf-8")).get("guard") or {}).get("prodDb")
    except (OSError, json.JSONDecodeError):
        return None


def check(root: Path, cmd: str):
    cfg = load_cfg(root)
    if not cfg:
        return None
    r = resolve(root, cfg)
    if any(h in cmd for h in r["hosts"]) or any(re.search(rf"\b{re.escape(k)}\b", cmd) for k in r["refs"]):
        if WRITE_SQL.search(cmd):
            return "운영 DB 쓰기|운영 DB 를 가리키는 명령에 쓰기 SQL 이 있다. 조회(SELECT)만 허용한다. 고쳐야 하면 사람이 직접 실행한다"
        bare = re.sub(r"'[^']*'|\"[^\"]*\"", "''", cmd)  # 따옴표 안의 < 는 SQL 비교 연산자다
        if re.search(r"(^|[^<])<[^<(]|\bsource\b|\\\.", bare):
            return "운영 DB 에 SQL 파일 실행|파일 내용을 볼 수 없어 쓰기인지 가를 수 없다. 조회면 -e/-c 로 SELECT 를 직접 쓴다"
    for m in re.finditer(r"(?:spring[._]profiles[._]active|SPRING_PROFILES_ACTIVE)\s*[=\s]\s*['\"]?([\w,-]+)", cmd):
        hit = r["profiles"] & {p.strip() for p in m.group(1).split(",")}
        if hit:
            return (f"운영 프로필로 실행 ({', '.join(sorted(hit))})|이 프로필의 설정이 운영 DB 를 가리킨다. "
                    "앱이 뜨면 SQL 없이도 운영 데이터가 바뀐다. 필요하면 사람이 터미널에서 직접 실행한다")
    for s in r["switches"]:
        if s in cmd:
            return (f"운영 스위치로 실행 ({s})|harness.json 이 운영으로 바꾸는 표시로 적은 값이다. "
                    "필요하면 사람이 터미널에서 직접 실행한다")
    return None


def status(root: Path):
    cfg = load_cfg(root)
    if not cfg:
        return []
    r = resolve(root, cfg)
    if not r["hosts"]:
        return ["전부 꺼짐 — 운영 DB 주소를 하나도 못 읽음"] + r["problems"]
    return [f"일부 꺼짐 — {p}" for p in r["problems"]]


if __name__ == "__main__":
    mode, repo = sys.argv[1], Path(sys.argv[2])
    if mode == "check":
        res = check(repo, sys.argv[3])
        if res:
            print(res)
    elif mode == "status":
        for line in status(repo):
            print(line)
