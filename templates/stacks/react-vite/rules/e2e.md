---
paths: ["e2e/**", "tests/e2e/**", "playwright.config.*"]
---

# E2E 규칙 (Playwright)

> nextjs 팩의 `rules/e2e.md`와 같은 내용이다. **[Vite]** 표시가 이 팩 고유다.

## API 가로채기

- `page.route("**/api/**")` 같은 **URL glob으로 API를 가로채지 않는다.** **[Vite]** 개발 서버는 소스를 `/src/shared/api/*.ts` 같은 경로로 내려줘 같은 glob에 걸리고, 모듈이 가짜 응답(404)을 받아 오류 하나 없이 빈 화면만 뜬다(2026-10-04 실측). 경로가 API 접두로 **시작하는지**로 거른다:
  ```ts
  await page.route((url) => url.pathname.startsWith("/api/"), handler);
  ```

## 스텁 안 한 API 경로

- 모르는 경로를 `{}`나 200으로 돌려주지 않는다. 컴포넌트가 배열 필드에서 TypeError를 내고, 에러 바운더리가 없으면 화면 전체가 오류 화면이 되는데, 원인이 "스텁 누락"으로 보이지 않는다(2026-10-05 실측: 단위 테스트는 통과, e2e만 실패).
- 스텁 핸들러의 기본 분기는 **501 + 경로를 적은 본문**으로 응답하고, 테스트 끝에 스텁 안 된 호출이 있었으면 실패시킨다.
- 화면이 새 API를 부르게 바꾼 PR은 스텁 목록에도 그 경로를 더한다.

## 돌리는 곳

- E2E는 `verify`에 넣지 않는다. CI 별도 잡(비용이 크면 기준 브랜치 push에서만)으로 돌리고, PR에서는 로컬 실행 결과를 본문에 적는다.
- 로컬 `reuseExistingServer`는 **다른 worktree의 서버를 재사용**할 수 있다. 병렬 worktree에서는 포트를 나눈다(**[Vite]** `--port`).
