---
paths: ["**/controller/**", "**/dto/**", "**/presentation/**", "**/*Controller.kt", "**/*Dtos.kt", "**/*Dto.kt", "**/http/*.http", "**/contracts/openapi.json"]
---

# API 규칙

## 컨트롤러

- 컨트롤러는 검증·인증·서비스 호출·응답만 한다. 로직은 서비스로.
- 엔티티를 응답으로 내보내지 않는다. DTO로 바꿔서.
- 30초 넘게 걸릴 수 있는 일(외부 AI·렌더·대량 처리)은 요청 안에서 하지 않는다. 작업 행을 저장하고 **커밋 뒤** 큐에 넣고 `202`와 작업 ID를 돌려준다.
- 응답 코드: 생성 201 · enqueue 202 · 삭제 204 · 상태 충돌 409 · 검증 실패 400.
- 에러 응답은 `@RestControllerAdvice` 한 곳에서 같은 모양(`ProblemDetail`)으로 만든다.
- **없는 날짜 · 빈 결과는 404가 아니라 빈 200**(`[]` 또는 빈 필드)이다. 404는 경로의 대상 자체가 없을 때만. 화면이 "데이터 없음"과 "오류"를 가를 수 있어야 한다.
- **목록 API는 상한을 두고, 잘렸는지를 응답에 드러낸다**(`truncated: true` 또는 `nextCursor`). 상한에서 조용히 자르면 화면이 전체인 줄 안다.

## 계약 (OpenAPI)

- `contracts/openapi.json`은 **생성물**이다(springdoc `/v3/api-docs`). 손으로 고치지 않는다. API를 바꾼 PR에는 재생성한 파일이 같이 들어가야 한다. 막는 것은 **스냅샷 테스트 `OpenApiContractTest`**다 — 어긋나면 `./gradlew test`가 실패한다. 재생성: `UPDATE_CONTRACTS=1 ./gradlew test --tests '*OpenApiContractTest'` (⚠️ kit 확정 후 맞출 것 — 앱별 레포면 앱 폴더에서)
- 에러 응답도 계약이다. 컨트롤러에 `@ApiResponse(responseCode = "409", content = [Content(schema = Schema(implementation = ProblemDetail::class))])`처럼 **실제로 나는 에러 코드**를 적는다. 안 적으면 프론트 생성 타입에 에러 모양이 없다.
- 응답 타입에 `Map<String, Any>`·`Any`를 쓰지 않는다 — 프론트 타입이 `unknown`이 된다.
- 컨트롤러 메서드에 `@Operation(summary = …)`, DTO 필드에 `@Schema(description = …)`. 프론트가 읽는 문서다.
- springdoc 2.8.17 미만은 Kotlin `?`를 `nullable: true`로 옮기지 않는다. null이 오는 응답 필드는 `@Schema(nullable = true)`를 직접 붙인다.
- springdoc 3.x는 반대로 Kotlin non-null을 `required`로 옮기지 않는다 — 그대로면 프론트 생성 타입이 전부 선택(`?:`)이 된다. non-null 속성을 `required`에 넣는 `ModelConverter` 빈을 둔다(stack-kits `kotlin-spring`의 `KotlinRequiredSchemaConverter`). `contracts/openapi.json`에서 응답 스키마의 `required`가 비어 있으면 이것부터 의심한다.
- enum은 enum 타입 그대로 노출하고 **이름 있는 스키마**로 뺀다(`@Schema(enumAsRef = true)`). String으로 바꾸면 후보 값이 스펙에서 사라지고, 인라인이면 프론트가 같은 enum을 필드마다 다른 타입으로 받는다.

## 손 확인

- 엔드포인트를 추가하면 `http/<도메인>.http`에 요청을 하나 이상 남긴다. 재현이 저장소 안에 있어야 한다.
