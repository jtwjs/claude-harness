---
paths: ["**/*.kt", "**/*.kts"]
---

# Kotlin 규칙

## nullable — 엔티티의 `?`와 DTO의 `?`는 따로 판단한다

- 엔티티의 `?`는 JPA 사정이다(저장 전에는 PK가 없다: `val id: Long? = null`). **DTO에는 이 사정이 없다.** DTO 필드는 "비즈니스상 비어 있을 수 있다"일 때만 `?`를 붙인다.
- 엔티티 → DTO 변환에서 **한 번만** 푼다: `id = requireNotNull(entity.id)`. `!!`를 흩뿌리지 않는다 — 실패 지점이 런타임 NPE로 흩어진다.
- 응답 DTO의 `?`는 스펙(OpenAPI)으로 새어 나가 프론트가 null 분기를 떠안는다.
- 예외: **요청 DTO**. non-null 필드가 JSON에서 빠지면 jackson-module-kotlin이 `@Valid`보다 먼저 400을 던져 검증 메시지가 안 나온다. 필수 입력은 `val email: String? = null` + `@NotBlank`(대상 규칙은 아래 줄)로 받는다.
- 검증 어노테이션의 대상: 빌드 파일 `freeCompilerArgs`에 `-Xannotation-default-target=param-property`가 **있으면** `@NotBlank`만으로 필드까지 붙는다. **없으면** `@field:NotBlank`로 적어야 한다 — 안 적으면 생성자 파라미터에만 붙어 검증이 **에러 없이 빠진다**(2026-09-27 stack-kits 실측: 플래그 제거 시 400 테스트 실패).

## 클래스

- DTO는 `data class`. **엔티티는 `data class`로 만들지 않는다** — 자동 `equals`·`hashCode`·`toString`이 지연 로딩 연관을 건드린다.
- 엔티티·빈은 `kotlin("plugin.jpa")`·`kotlin("plugin.spring")`(allopen·noarg)이 있어야 프록시가 된다. 빌드 파일에 없으면 추가를 제안한다.
- 의존성은 생성자 주입. `@Autowired lateinit var` 필드 주입은 쓰지 않는다.

## 로그

- `println` 금지. 로거는 클래스마다 하나(`LoggerFactory.getLogger(javaClass)` 또는 kotlin-logging).
- 요청 ID(MDC)가 모든 줄에 붙어야 한 요청을 끝까지 따라간다. 시크릿·토큰·개인정보는 찍지 않는다.
- 레벨: 사용자 영향 ERROR · 재시도로 넘긴 것 WARN · 흐름 INFO · 값 덤프 DEBUG.

## 테스트

- JUnit 5 + MockK. 구현 `src/main/kotlin/.../Foo.kt`의 짝은 `src/test/kotlin/.../FooTest.kt`(tdd-guard가 이 짝을 본다).
- 크기별로 고른다: 순수 로직은 단위 · 컨트롤러는 `@WebMvcTest` · 쿼리·트랜잭션은 Testcontainers(MySQL) 통합. **H2 금지** — MySQL 방언·JSON·인덱스 동작이 다르다.
- `@SpringBootTest`는 핵심 흐름에만. `@ActiveProfiles`에 운영 프로필을 넣지 않는다.
