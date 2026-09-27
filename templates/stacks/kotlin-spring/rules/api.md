---
paths: ["**/controller/**", "**/dto/**", "**/presentation/**", "**/http/*.http", "**/contracts/openapi.json"]
---

# API 규칙

## 컨트롤러

- 컨트롤러는 검증·인증·서비스 호출·응답만 한다. 로직은 서비스로.
- 엔티티를 응답으로 내보내지 않는다. DTO로 바꿔서.
- 30초 넘게 걸릴 수 있는 일(외부 AI·렌더·대량 처리)은 요청 안에서 하지 않는다. 작업 행을 저장하고 **커밋 뒤** 큐에 넣고 `202`와 작업 ID를 돌려준다.
- 응답 코드: 생성 201 · enqueue 202 · 삭제 204 · 상태 충돌 409 · 검증 실패 400.
- 에러 응답은 `@RestControllerAdvice` 한 곳에서 같은 모양으로 만든다.

## 계약 (OpenAPI)

- `contracts/openapi.json`은 **생성물**이다(springdoc `/v3/api-docs`). 손으로 고치지 않는다. API를 바꾼 PR에는 재생성한 파일이 같이 들어가야 한다(CI가 `git diff --exit-code`로 막는다).
- 응답 타입에 `Map<String, Any>`·`Any`를 쓰지 않는다 — 프론트 타입이 `unknown`이 된다.
- 컨트롤러 메서드에 `@Operation(summary = …)`, DTO 필드에 `@Schema(description = …)`. 프론트가 읽는 문서다.
- springdoc 2.8.17 미만은 Kotlin `?`를 `nullable: true`로 옮기지 않는다(필수 목록에서 빠지기만 한다). null이 오는 응답 필드는 `@Schema(nullable = true)`를 직접 붙인다.
- enum은 enum 타입 그대로 노출한다. String으로 바꾸면 후보 값이 스펙에서 사라진다.

## 손 확인

- 엔드포인트를 추가하면 `http/<도메인>.http`에 요청을 하나 이상 남긴다. 재현이 저장소 안에 있어야 한다.
