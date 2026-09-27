---
paths: ["app/**", "src/app/**", "src/**/*.tsx", "next.config.*", "middleware.ts", "src/middleware.ts"]
---

# Next.js 규칙 (App Router)

## 서버 / 클라이언트 경계

- 기본은 서버 컴포넌트다. `"use client"`는 상태·이벤트·브라우저 API가 필요한 **가장 아래 잎 컴포넌트**에만 붙인다. 위쪽에 붙이면 그 아래 트리 전체가 클라이언트 번들이 된다.
- 비밀값은 서버에서만 읽는다. `NEXT_PUBLIC_` 접두사가 붙은 환경변수는 브라우저로 나간다 — 토큰·키에 쓰지 않는다.
- 서버 전용 모듈(DB·시크릿을 만지는 것)은 `import "server-only"`로 클라이언트 import를 빌드에서 막는다.

## 데이터

- API 타입은 생성물(`src/api/generated/` 등 OpenAPI → orval, 또는 공유 zod 패키지)에서만 import한다. **손으로 쓴 응답 타입 금지** — 서버가 바뀐 날 조용히 틀어진다.
- 서버 응답을 믿지 않는 경계(외부 API)는 zod로 parse한다.
- 서버 상태는 TanStack Query(클라이언트) 또는 서버 컴포넌트 fetch 중 하나로 정하고 섞지 않는다. 결정은 `non-obvious-patterns.md`에 한 줄로 남긴다.
- 캐시·재검증 동작은 Next 메이저 버전마다 기본값이 바뀌어 왔다. 추측하지 말고 설치된 버전 문서(context7)를 확인한 뒤 명시적으로 적는다.

## 라우트

- `page.tsx`·`layout.tsx`는 조립만 한다. 로직은 테스트 가능한 모듈로 뺀다(tdd-guard 대상이 되게).
- 로딩·에러 상태를 `loading.tsx`·`error.tsx`로 둔다. 빈 상태·에러 상태 없는 화면은 완성이 아니다.
