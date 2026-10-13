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
# DB 클라이언트가 없는 명령(스크립트에 SQL 을 넘기는 등)에서만 쓰는 넓은 목록. 클라이언트 명령은 아래 허용 목록으로 가른다
WRITE_SQL = re.compile(r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|REPLACE|CREATE|MERGE|GRANT|REVOKE|RENAME|CALL|LOAD\s+DATA|COPY)\b", re.I)
# 허용 목록(Finn 결정 10-13): 운영 DB 를 가리키는 클라이언트 명령은 이 말로 시작하는 문장만 통과
READ_ONLY = {"SELECT", "SHOW", "EXPLAIN", "DESCRIBE", "DESC", "WITH"}
READ_BUT_UNSAFE = re.compile(r"\bINTO\s+(OUT|DUMP)FILE\b|\bFOR\s+(UPDATE|SHARE)\b|\bLOCK\s+IN\s+SHARE\b", re.I)
DB_CLIENT = re.compile(r"(^|[\s;&(/])(mysql|mariadb|psql|pgcli|mycli|sqlcmd|sqlite3|mongosh|mongo|redis-cli|"
                       r"clickhouse-client|clickhouse|usql|cockroach)(\s|$)")
SQL_ARG = re.compile(r"(?:^|\s)(?:-e|-c|--execute|--command|--eval)(?:=|\s+)(?:\"((?:[^\"\\]|\\.)*)\"|'([^']*)'|(\S+))")
APP_RUN = re.compile(r"\b(bootRun|gradlew|gradle|mvnw?|java|npm|npx|pnpm|yarn|node|bun|deno|docker|kubectl|"
                     r"flyway|liquibase|prisma|knex|sequelize|typeorm)\b")
DB_SCHEME = re.compile(r"^(jdbc:|\$\{|(mysql|mariadb|postgres(ql)?|mongodb(\+srv)?|redis|sqlserver|oracle)[a-z+]*://)", re.I)


def walk(root: Path, max_depth: int = 6):
    root_depth = len(root.parts)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        if len(Path(dirpath).parts) - root_depth >= max_depth:
            dirnames[:] = []
        for f in filenames:
            yield Path(dirpath) / f


def read_text(path: Path) -> str:
    try:   # 끊어진 링크·권한 — 못 읽으면 빈 값(가드 전체가 죽어 명령이 통과하지 않게)
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


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
    """레포의 .env* 를 합친다. 같은 키가 파일마다 다르면 어느 쪽인지 모르니 그 키는 비운다(None) — 리뷰 10-13"""
    env = {}
    for p in walk(root, 4):
        if p.name.startswith(".env") and not p.name.endswith((".example", ".sample", ".template")):
            for k, v in read_env(p).items():
                env[k] = v if env.get(k, v) == v else None
    return env


def host_of(value: str, env: dict):
    """url 또는 호스트 값 → (호스트, 그 값을 담은 변수 이름들)."""
    names = set()
    for _ in range(3):  # ${A} → ${B} 처럼 겹친 것까지
        m = VAR.search(value or "")
        if not m:
            break
        names.add(m.group(1))
        if env.get(m.group(1)) is None:   # 없음 · 파일마다 달라 모호함
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
    """datasource url — jdbc-url(Hikari) 포함. DB 주소 꼴만 본다(외부 API https url 을 운영 DB 로 잡지 않게)."""
    for line in text.splitlines():
        m = re.search(r"(?:^|[.-])url\s*[:=]\s*(\S+)", line.strip())
        if m and DB_SCHEME.match(m.group(1).strip("'\"")):
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
                url = spring_url(read_text(f))
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
            url = spring_url(read_text(f))
            h = host_of(url, env)[0] if url else None
            if h and h in hosts:
                profiles.add(prof)
    switches = [s for s in cfg.get("switches", []) or [] if isinstance(s, str) and s]
    return {"hosts": hosts, "refs": refs, "profiles": profiles, "switches": switches, "problems": problems}


def load_cfg(root: Path):
    try:
        guard = json.loads((root / ".claude/harness.json").read_text(encoding="utf-8")).get("guard")
    except (OSError, json.JSONDecodeError, AttributeError):
        return None
    cfg = guard.get("prodDb") if isinstance(guard, dict) else None
    return cfg if isinstance(cfg, dict) else None


def mask_quotes(cmd: str) -> str:
    """따옴표 안을 같은 길이의 x 로 — 위치를 유지한 채 | ; < 같은 기호가 SQL 문자열 안인지 가른다."""
    return re.sub(r"'[^']*'|\"(?:[^\"\\]|\\.)*\"", lambda m: m.group(0)[0] + "x" * (len(m.group(0)) - 2) + m.group(0)[-1], cmd)


def flags_view(cmd: str) -> str:
    """프로필·스위치 검사용: KEY="v" → KEY=v, '-로 시작' 은 따옴표만 벗김, 나머지 따옴표 문자열(커밋 메시지·grep 패턴)은 지움."""
    cmd = re.sub(r"([A-Za-z_][\w.]*=)([\"'])([^\"'\s]*)\2", r"\1\3", cmd)
    return re.sub(r"'([^']*)'|\"((?:[^\"\\]|\\.)*)\"",
                  lambda m: (m.group(1) if m.group(1) is not None else m.group(2))
                  if (m.group(1) or m.group(2) or "").startswith("-") else "''", cmd)


def unsafe_sql(sql: str):
    """허용 목록 밖 문장이면 그 문장(앞 40자), 아니면 None."""
    for stmt in sql.split(";"):
        st = re.sub(r"/\*.*?\*/|--[^\n]*", " ", stmt, flags=re.S).strip()
        if not st:
            continue
        if st.startswith("\\"):   # psql 메타 명령 — \d·\l 류 조회만
            if re.match(r"\\(d[a-zA-Z+]*|l\+?)(\s|$)", st):
                continue
            return st[:40]
        head = st.split(None, 1)[0].upper()
        if head not in READ_ONLY or READ_BUT_UNSAFE.search(st) or (head == "WITH" and WRITE_SQL.search(st)):
            return st[:40]
    return None


def check(root: Path, cmd: str):
    cfg = load_cfg(root)
    if not cfg:
        return None
    r = resolve(root, cfg)
    if any(h.lower() in cmd.lower() for h in r["hosts"]) or any(re.search(rf"\b{re.escape(k)}\b", cmd) for k in r["refs"]):
        masked = mask_quotes(cmd)
        # 파이프로 SQL 을 받는 클라이언트 — 파이프 앞에서 무엇이 오는지 볼 수 없다
        bounds = [m.start() for m in re.finditer(r"(?<!\|)\|(?!\|)", masked)]
        segs, last = [], 0
        for b in bounds + [len(cmd)]:
            segs.append((cmd[last:b], masked[last:b]))
            last = b + 1
        clients = [(i, raw, msk) for i, (raw, msk) in enumerate(segs) if DB_CLIENT.search(msk)]
        for i, raw, msk in clients:
            if i > 0:
                return "운영 DB 에 파이프로 SQL 전달|무엇이 들어가는지 볼 수 없다. 조회면 -e/-c 로 SELECT 를 직접 쓴다"
            if re.search(r"(^|[^<])<[^<(]|<<|(^|\s)(-f|--file)(\s|=)|\bsource\b|\\[.i](\s|$)", msk):
                return "운영 DB 에 SQL 파일·입력 실행|파일 내용을 볼 수 없어 가를 수 없다. 조회면 -e/-c 로 SELECT 를 직접 쓴다"
            args = [next(g for g in m.groups() if g is not None) for m in SQL_ARG.finditer(raw)]
            if not args:
                return "운영 DB 대화형 접속|무엇을 실행할지 볼 수 없다. 조회면 -e/-c 로 SELECT 를 직접 쓴다"
            for a in args:
                bad = unsafe_sql(a)
                if bad:
                    return (f"운영 DB 에 조회 밖 SQL ({bad})|운영 DB 는 SELECT·SHOW·EXPLAIN·DESCRIBE 만 허용한다"
                            "(잠금·파일 쓰기 SELECT 도 막는다). 고쳐야 하면 사람이 직접 실행한다")
        if not clients:
            if APP_RUN.search(masked):
                return ("운영 DB 주소로 실행|명령에 운영 DB 주소(또는 그 값을 담은 변수)를 넘겨 앱·마이그레이션을 띄운다. "
                        "필요하면 사람이 터미널에서 직접 실행한다")
            if WRITE_SQL.search(cmd):
                return "운영 DB 쓰기|운영 DB 를 가리키는 명령에 쓰기 SQL 이 있다. 고쳐야 하면 사람이 직접 실행한다"
    view = flags_view(cmd)
    for m in re.finditer(r"(?:spring[._]profiles[._](?:active|include)|SPRING_PROFILES_(?:ACTIVE|INCLUDE))\s*[=\s]\s*['\"]?([\w,-]+)", view):
        hit = r["profiles"] & {p.strip() for p in m.group(1).split(",")}
        if hit:
            return (f"운영 프로필로 실행 ({', '.join(sorted(hit))})|이 프로필의 설정이 운영 DB 를 가리킨다. "
                    "앱이 뜨면 SQL 없이도 운영 데이터가 바뀐다. 필요하면 사람이 터미널에서 직접 실행한다")
    for sw in r["switches"]:
        if re.search(rf"(^|[\s;&|(]){re.escape(sw)}($|[\s;&|)])", view):
            return (f"운영 스위치로 실행 ({sw})|harness.json 이 운영으로 바꾸는 표시로 적은 값이다. "
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
