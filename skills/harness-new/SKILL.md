---
name: harness-new
description: 새 프로젝트를 stack-kits 보일러플레이트(kotlin-spring·nextjs·fullstack 등)로 만들고 바로 harness-init 까지 돌린다. "새 프로젝트 만들어줘", "Spring/Next 보일러플레이트로 시작"일 때 쓴다. 기존 레포에 하네스만 깔 때는 harness-init 을 쓴다.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

코드 뼈대는 `jtwjs/stack-kits`, AI 환경은 이 플러그인의 스택 팩이 정본이다. 이 스킬은 둘을 잇기만 한다.

## 1. 고르기

- kit 목록은 **레포에서 읽는다** — 기억으로 적지 않는다: `gh api repos/jtwjs/stack-kits/contents --jq '.[] | select(.type=="dir" and (.name|startswith(".")|not)) | .name'`
- 고정할 ref(태그)도 레포에서 읽는다: `gh api repos/jtwjs/stack-kits/tags --jq '.[].name'`. 최신 태그를 제안하고, 태그가 없으면 그 사실을 보고하고 묻는다(브랜치 이름으로 대신하지 않는다)
- 사용자에게 kit · ref · 대상 경로를 묻는다. 대상 경로가 이미 있고 비어 있지 않으면 **멈춘다**(덮어쓰지 않는다).

| kit | 모양 | 팩 |
|---|---|---|
| `kotlin-spring` | 단일 앱 | `kotlin-spring` |
| `nextjs` | 단일 앱 | `nextjs` |
| `fullstack` | 모노레포 `apps/api`(Kotlin Spring) + `apps/web`(React + Vite), 계약 파이프라인 포함(openapi.json → 생성 타입) | `kotlin-spring` + `react-vite` |

## 2. 복사

```bash
npx --yes degit jtwjs/stack-kits/<kit>#<ref> <대상 경로>    # ref 고정 — 예: jtwjs/stack-kits/fullstack#v0.2.0
cd <대상 경로> && git init -q
```

- ref 없이 degit 하지 않는다. 같은 kit 이름이라도 시점마다 다른 뼈대가 나온다. 쓴 값은 §4에서 `harness.json` `stacks.kitRef`에 `"jtwjs/stack-kits/<kit>#<ref>"`로 남긴다
- 예시 도메인(article)은 **지우지 않는다** — 첫 검증이 통과하는 것을 본 뒤 사용자가 정한다. 지울 파일 목록만 보고한다.
- 패키지·그룹 이름(`dev.stackkits.app`, `package.json`의 `name`) 변경은 사용자가 원할 때만 한다.

## 3. 첫 검증

검증 명령은 **degit한 폴더 안의 kit README 검증 표**를 읽어 그대로 돈다 — 기억이나 이 스킬의 예로 대신하지 않는다(`./gradlew …`는 Docker · JDK 필요, `pnpm install` 먼저). 모노레포면 앱 폴더마다 그 폴더에서 돈다. red/green을 그대로 보고한다. 실패하면 고치지 말고 원인(Docker 꺼짐 · JDK 버전 · `JAVA_HOME` 등)을 보고한다.

## 4. 하네스

`harness-init`을 이어서 돈다. 스택 판정은 빌드 파일로 하므로 kit과 팩이 자연히 맞는다. `CLAUDE.md`가 이미 있으면(nextjs의 `@AGENTS.md` 한 줄) 덮지 말고 그 줄을 보존한 채 위에 쓴다.

- `stacks.kitRef` ← §2의 값
- `fullstack`이면 결과가 이렇게 나와야 한다. 다르면 판정을 다시 보고 보고한다:
  - `stacks.packs`: `[{"pack": "kotlin-spring", "root": "apps/api"}, {"pack": "react-vite", "root": "apps/web"}]`
  - `verify`: 앱별 형태 `{"apps/api": {…}, "apps/web": {…}}` — 값은 §3에서 통과한 명령
  - CI: `ci.yml` 앱별 형태(앱별 잡 + paths 필터 + `ci-gate`)

## 5. 보고

만든 경로 · kit · ref · 첫 검증 결과(앱별이면 앱마다) · `harness-init`이 비워 둔 칸 · 지워도 되는 예시 파일 목록.
