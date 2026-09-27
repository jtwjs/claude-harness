# 스택 팩

`harness-init`이 판정한 스택마다 `.claude/rules/`에 덧붙이는 규칙과, 검증 명령 후보·CI 셋업을 담는다.
**자동 로드되지 않는다** — `harness-init`이 판정 뒤 이 폴더에서 골라 복사한다. 평소 컨텍스트 비용은 0이다.

코드 뼈대는 여기 없다 — 공개 레포 `jtwjs/stack-kits`가 kit마다 디렉터리로 갖고 있고, 스킬 `harness-new`가 kit 복사 → `harness-init`을 잇는다. 팩 규칙의 근거는 그 kit에서 실측한 것이다.

## 판정 — 빌드 파일로만

```bash
ls build.gradle.kts build.gradle pom.xml package.json tsconfig.json next.config.* 2>/dev/null
```

| 있는 것 | 팩 | 비고 |
|---|---|---|
| `build.gradle.kts`·`build.gradle`·`pom.xml` + 본문에 `org.springframework.boot` | `kotlin-spring/` | Kotlin 소스(`src/main/kotlin`)가 없으면 팩을 적용하지 않고 묻는다 |
| `package.json`의 dependencies에 `next` | `nextjs/` | TS면 기존 `rules/{typescript,functional-programming}.md`도 같이 |
| `tsconfig.json`만 | (팩 없음) | 기존 TS 조건부 규칙만 |

- ⛔ **스택을 추측하지 않는다.** 빌드 파일이 없거나 표에 없는 조합이면 사용자에게 묻는다.
- **모노레포**면 앱 디렉터리마다 따로 판정한다(`apps/api`, `apps/web` …). 팩 규칙의 `paths:` 앞에 그 디렉터리를 붙여 복사한다. 예: `**/controller/**` → `apps/api/**/controller/**`.
- 판정 결과는 `harness.json.stacks.packs`에 `[{ "pack": "kotlin-spring", "root": "apps/api" }]` 형태로 남긴다. `harness-doctor`가 이 값으로 정합을 본다.

## 팩 구성

```
<pack>/
  pack.md     검증 명령 후보(실행해서 통과한 것만 verify 로) · test/tdd 제안 · CI 셋업 스텝
  rules/*.md  전부 paths: 필수. 파일당 ≈4KB 이하
```
