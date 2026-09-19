#!/usr/bin/env node
/**
 * find-skills — 키워드로 스킬을 찾아 SKILL.md 전체 경로를 찍는다.
 *
 * 원본: superpowers 의 Codex CLI 서브커맨드 `superpowers-codex find-skills` (6.3.0 RELEASE-NOTES).
 * 이식 원칙 — 원본 그대로: 매칭은 **name + description 문자열만** 본다(본문 검색 아님).
 * 출력은 `/SKILL.md` 까지 붙인 전체 경로다 — Read 도구에 그대로 붙이라고 원본이 6.x 에서 고친 부분이다.
 *
 * 🔴 캐시에는 한 플러그인의 옛 버전이 그대로 남는다(실측 2026-09-19: claude-harness 7개).
 *    glob 으로 훑으면 같은 스킬이 7번 나오고 6개가 죽은 경로다.
 *    → installed_plugins.json 으로 '지금 켜진 것' 하나만 고른다. 고르는 순서는 Claude Code 와 같다:
 *      cwd 를 포함하는 project 스코프 > user 스코프 > 첫 항목.
 */
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const HOME = homedir();
const CLAUDE_DIR = process.env.CLAUDE_CONFIG_DIR || join(HOME, ".claude");

/** 스캔 대상 — { label, dir }. dir 은 스킬 폴더들을 담은 상위 폴더다 */
function roots() {
  const out = [];
  const manifest = join(CLAUDE_DIR, "plugins", "installed_plugins.json");
  if (existsSync(manifest)) {
    let parsed;
    try {
      parsed = JSON.parse(readFileSync(manifest, "utf8"));
    } catch {
      parsed = null;
    }
    const cwd = process.cwd();
    for (const [key, entries] of Object.entries(parsed?.plugins ?? {})) {
      if (!Array.isArray(entries) || entries.length === 0) continue;
      const picked =
        entries.find((e) => e.projectPath && cwd.startsWith(e.projectPath)) ??
        entries.find((e) => e.scope === "user") ??
        entries[0];
      if (!picked?.installPath) continue;
      out.push({
        label: key.split("@")[0],
        dir: join(picked.installPath, "skills"),
      });
    }
  }
  out.push({ label: "user", dir: join(CLAUDE_DIR, "skills") });
  out.push({ label: "project", dir: join(process.cwd(), ".claude", "skills") });
  return out.filter((r) => existsSync(r.dir));
}

/**
 * YAML 프런트매터에서 필요한 키만 꺼낸다. 블록 스칼라(`>`·`|`·`>-`·`|-`)를 한 줄로 접는다 —
 * 실측: plannotator-visual-explainer 의 description 이 `>` 형태라 순진하게 자르면 빈 문자열이 된다.
 */
function frontmatter(text) {
  const m = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text);
  if (!m) return {};
  const lines = m[1].split(/\r?\n/);
  const out = {};
  for (let i = 0; i < lines.length; i++) {
    const kv = /^([A-Za-z][A-Za-z0-9_-]*):(.*)$/.exec(lines[i]);
    if (!kv) continue;
    let value = kv[2].trim();
    if (value === ">" || value === "|" || value === ">-" || value === "|-") {
      const buf = [];
      while (
        i + 1 < lines.length &&
        !/^[A-Za-z][A-Za-z0-9_-]*:/.test(lines[i + 1])
      ) {
        buf.push(lines[++i].trim());
      }
      value = buf.join(" ").trim();
    }
    out[kv[1]] = value.replace(/^["']|["']$/g, "");
  }
  return out;
}

/**
 * 스킬 폴더를 훑는다.
 * 🔴 두 가지를 놓치면 목록이 조용히 빈다 — 둘 다 이 머신에서 실측한 것이다(2026-09-19).
 *   ① `~/.claude/skills/*` 13개가 `~/.agents/skills/` 로 가는 **심볼릭 링크**다.
 *      `isDirectory()` 는 링크에 false 를 준다 → 링크를 따라가는 `statSync` 로 본다. (53 → 66개)
 *   ② anthropic 계열 12개가 `~/.claude/skills/synced/<uuid>/<skill>/` 로 **두 겹** 아래 있다.
 *      그래서 SKILL.md 가 없는 폴더는 두 겹까지 더 내려가 본다. (66 → 78개)
 */
function scan(dir, label, found, depth = 0) {
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    const child = join(dir, entry.name);
    let isDir = false;
    try {
      isDir = statSync(child).isDirectory();
    } catch {
      continue;
    }
    if (!isDir) continue;

    const path = join(child, "SKILL.md");
    if (!existsSync(path)) {
      if (depth < 2) scan(child, label, found, depth + 1);
      continue;
    }
    let meta = {};
    try {
      meta = frontmatter(readFileSync(path, "utf8"));
    } catch {
      /* 읽을 수 없으면 폴더 이름만으로 남긴다 */
    }
    found.push({
      name: meta.name || entry.name,
      label,
      description: meta.description || "",
      path,
    });
  }
}

function collect() {
  const found = [];
  for (const { label, dir } of roots()) scan(dir, label, found);
  return found.sort((a, b) =>
    `${a.label}:${a.name}`.localeCompare(`${b.label}:${b.name}`),
  );
}

const HELP = `find-skills — 키워드로 스킬을 찾아 SKILL.md 전체 경로를 찍는다

사용법
  node find-skills.mjs [키워드...]     키워드를 전부 포함하는 스킬 (대소문자 무시)
  node find-skills.mjs                 설치된 스킬 전부
  node find-skills.mjs -h              이 도움말

매칭 대상은 스킬 이름과 description 뿐이다. SKILL.md 본문은 보지 않는다.
출력된 경로는 Read 도구에 그대로 넣을 수 있다.`;

const args = process.argv.slice(2);
if (args.includes("-h") || args.includes("--help")) {
  console.log(HELP);
  process.exit(0);
}

const terms = args.map((t) => t.toLowerCase()).filter(Boolean);
const all = collect();
const hits = all.filter((s) => {
  const hay = `${s.label}:${s.name} ${s.description}`.toLowerCase();
  return terms.every((t) => hay.includes(t));
});

if (hits.length === 0) {
  console.log(`일치하는 스킬 없음 (${terms.join(" ")}) — 스캔 ${all.length}개`);
  process.exit(0);
}

for (const s of hits) {
  console.log(`${s.label}:${s.name}`);
  if (s.description) {
    const one = s.description.replace(/\s+/g, " ").trim();
    console.log(`  ${one.length > 160 ? `${one.slice(0, 160)}…` : one}`);
  }
  console.log(`  ${s.path}`);
  console.log("");
}
console.log(
  terms.length
    ? `${hits.length}개 일치 / 스캔 ${all.length}개`
    : `${all.length}개`,
);
