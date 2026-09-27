---
name: harness-new
description: 새 프로젝트를 stack-kits 보일러플레이트(kotlin-spring·nextjs 등)로 만들고 바로 harness-init 까지 돌린다. "새 프로젝트 만들어줘", "Spring/Next 보일러플레이트로 시작"일 때 쓴다. 기존 레포에 하네스만 깔 때는 harness-init 을 쓴다.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

코드 뼈대는 `jtwjs/stack-kits`, AI 환경은 이 플러그인의 스택 팩이 정본이다. 이 스킬은 둘을 잇기만 한다.

## 1. 고르기

- kit 목록은 **레포에서 읽는다** — 기억으로 적지 않는다: `gh api repos/jtwjs/stack-kits/contents --jq '.[] | select(.type=="dir" and (.name|startswith(".")|not)) | .name'`
- 사용자에게 kit과 대상 경로를 묻는다. 대상 경로가 이미 있고 비어 있지 않으면 **멈춘다**(덮어쓰지 않는다).

## 2. 복사

```bash
npx --yes degit jtwjs/stack-kits/<kit> <대상 경로>
cd <대상 경로> && git init -q
```

- 예시 도메인(article)은 **지우지 않는다** — 첫 검증이 통과하는 것을 본 뒤 사용자가 정한다. 지울 파일 목록만 보고한다.
- 패키지·그룹 이름(`dev.stackkits.app`, `package.json`의 `name`) 변경은 사용자가 원할 때만 한다.

## 3. 첫 검증

kit README의 **검증 명령** 표를 그대로 돈다(`./gradlew …`는 Docker, JDK 21 필요 · `pnpm install` 먼저). red/green을 그대로 보고한다. 실패하면 고치지 말고 원인(Docker 꺼짐·JDK 버전 등)을 보고한다.

## 4. 하네스

`harness-init`을 이어서 돈다. 스택 판정은 빌드 파일로 하므로 kit과 팩이 자연히 맞는다. `CLAUDE.md`가 이미 있으면(nextjs의 `@AGENTS.md` 한 줄) 덮지 말고 그 줄을 보존한 채 위에 쓴다.

## 5. 보고

만든 경로 · kit · 첫 검증 결과 · `harness-init`이 비워 둔 칸 · 지워도 되는 예시 파일 목록.
