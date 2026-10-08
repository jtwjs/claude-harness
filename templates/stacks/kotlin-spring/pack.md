# kotlin-spring 팩

## 검증 명령 후보 — 하나씩 실행해 통과한 것만 `verify`에

| 키 | 후보 (위에서부터 시도) | 비고 |
|---|---|---|
| format | `./gradlew ktlintCheck` · `./gradlew spotlessCheck` | 읽기 전용만. 플러그인이 없으면 비운다 |
| lint | — | ktlint 하나만 쓴다(format 칸의 `ktlintCheck`가 겸한다). detekt는 Kotlin 2.3 안정판 미지원이라 후보에서 뺐다(stack-kits README) |
| typecheck | `./gradlew compileKotlin compileTestKotlin` | Kotlin은 컴파일이 타입 검사다 |
| test | `./gradlew test` | Testcontainers를 쓰면 Docker가 떠 있어야 통과한다. 실패 원인이 Docker면 그렇게 보고한다 |
| build | `./gradlew build -x test` | |

- ⚠️ `-x test`는 태스크 그래프 전체에서 test를 뺀다. `./gradlew test build -x test`처럼 한 명령에 섞으면 테스트가 **돌지 않고 초록**이 된다. verify 키마다 따로 적는다.
- `packageManager`는 비운다. 대신 `./gradlew`가 실행 권한을 갖는지 확인한다(`chmod +x`가 필요하면 보고만).

## test · tdd

- `test.runner`: `junit5`(MockK 여부도 적는다). `test.bddAlias`: `false` — 3계층은 `@Nested inner class`로 만든다.
- `tdd.include` 제안: `src/main/kotlin/**/domain/**` + 기능별 패키지면 도메인 로직 이름 glob(예: `src/main/kotlin/**/*Policy.kt` · `**/*Rules.kt` — 레포 이름 규약을 보고 고른다). `service/**`까지 강제하는 것은 과하다 — 얇은 조립 서비스까지 짝 테스트를 요구해, 실제 프로젝트가 `include`에서 service를 뺐다(2026-10 실측)
- `tdd.exclude` 제안: `**/dto/**`, `**/config/**`, `**/entity/**`, `**/*Application.kt` — `rules/testing.md` §0과 같은 이유(얇은 래퍼·선언)
- `tdd-guard`는 `src/main/.../Foo.kt` ↔ `src/test/.../FooTest.kt`(또는 `FooTests.kt`) 짝을 본다.

## CI 셋업 스텝 (`{{SETUP_STEPS}}` 자리)

```yaml
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: "21" }
      - uses: gradle/actions/setup-gradle@v4
```

- Java 버전은 `build.gradle.kts`의 `jvmToolchain`·`sourceCompatibility`·`jvmTarget`에서 읽는다. 못 찾으면 묻는다. CI의 `java-version`과 빌드 파일 toolchain은 **한 값**이어야 한다 — 스텝 옆에 `# build.gradle.kts jvmToolchain 과 같이 바꾼다` 주석을 남긴다.
- 로컬 함정: 기본 `java`가 Gradle 요구 버전보다 낮으면 `./gradlew` 전 태스크가 실패한다. `JAVA_HOME`을 맞는 JDK로 두고 돌린다(실패 원인으로 보고만).
- 앱별 레포면 잡에 `defaults.run.working-directory: <root>`(ci.yml 앱별 형태).
- ubuntu 러너에는 Docker가 있어 Testcontainers가 돈다.

## auto-format

`.kt`·`.kts` 편집 뒤 `ktlint` CLI가 PATH에 있으면 `ktlint --format`을 돈다. 없으면 조용히 건너뛴다(gradle 태스크는 편집마다 돌리기엔 느리다). 설치는 사용자가 정한다: `brew install ktlint`.

## 복사할 규칙

`rules/kotlin.md` · `rules/db.md` · `rules/api.md` · `rules/service.md`
