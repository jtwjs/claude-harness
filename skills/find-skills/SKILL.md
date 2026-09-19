---
name: find-skills
description: 설치된 스킬을 키워드로 찾아 SKILL.md 전체 경로를 찍는다. "이런 거 하는 스킬 있었나"·"그 스킬 원문 어디 있지"·"이 스킬 뭐라고 써 있나" 할 때 쓴다. 이름과 description 만 매칭하고 본문은 보지 않는다. superpowers 의 Codex CLI 서브커맨드를 그대로 이식한 것이다.
allowed-tools: [Bash, Read]
---

## 실행

```bash
SCRIPT=$(ls -d ~/.claude/plugins/cache/*/claude-harness/*/skills/find-skills/find-skills.mjs | sort -V | tail -1)
node "$SCRIPT" <키워드...>
```

> `sort -V | tail -1` 로 가장 높은 버전을 고른다. 캐시에는 옛 버전이 그대로 남기 때문이다(실측: 7개).
> `CLAUDE_PLUGIN_ROOT` 는 훅에만 주입되고 Bash 도구에는 안 들어온다 — 그래서 경로를 이렇게 푼다.

키워드 없이 부르면 전부 나온다. `-h` 는 도움말.

## 출력

```
claude-harness:notion-writing
  노션처럼 조직에 공유하는 문서(제안·보고·기획·PRD 공유본)를 쓰거나…
  /Users/…/claude-harness/0.3.0/skills/notion-writing/SKILL.md

2개 일치 / 스캔 78개
```

경로는 **Read 도구에 그대로** 넣는다. 원문을 읽어야 할 때 쓰라고 `/SKILL.md` 까지 붙여 준다.

## 무엇을 보고 무엇을 안 보나

|            |                                                                                                                  |
| ---------- | ---------------------------------------------------------------------------------------------------------------- |
| 매칭 대상  | `label:이름` + `description` **문자열만**                                                                        |
| 안 보는 것 | **SKILL.md 본문.** 설명에 없는 단어는 안 잡힌다                                                                  |
| 스캔 범위  | 설치 플러그인(`installed_plugins.json` 기준 **켜진 버전 하나**) · `~/.claude/skills/` · `<레포>/.claude/skills/` |

🔴 **디스크에 없는 스킬은 못 잡는다.** Claude Code 에 내장돼 배포되는 것(`code-review`·`dataviz`·`artifact-design` 등)은 `~/.claude` 아래에 파일이 없다. 세션 스킬 목록에는 보이는데 여기서 안 나오면 대개 이 경우다.

## 경계

- **이미 시스템 프롬프트에 스킬 목록이 들어온다.** 이 도구는 그 목록을 대신하는 것이 아니라 **원문 경로**를 주는 것이다. 목록만 필요하면 부르지 않는다
- 중복·트리거 충돌 진단은 하지 않는다 — 그건 `harness-doctor` 검사 4(라우팅 1:1)와 `task-observer`(불발 계수) 몫이다
