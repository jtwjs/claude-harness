---
paths: ["e2e/**", "tests/e2e/**", "playwright.config.*", "playwright.*.config.*"]
---

# E2E 규칙 (Playwright)

> react-vite 팩의 `rules/e2e.md`와 같은 내용이다. 다른 곳만 표시한다.

## 구조 · 이름

- 폴더: `e2e/specs`(실행 스펙만, `testDir`) · `e2e/pom/<화면>.page.ts`(FSD `pages` 이름과 맞춤) · `e2e/fixtures/index.ts`(`test.extend`로 POM 주입) · `e2e/setup`(인증·초기화) · `e2e/.auth`(git 제외). `testDir`가 스펙만 보게 해서 pom·fixtures가 테스트로 수집되지 않는다
- 스펙은 `e2e/fixtures`에서만 import 한다. 셀렉터가 두 스펙에서 겹치면 POM으로 올리고, `data-testid`는 역할·레이블로 부족할 때만
- 제목: `test.describe("Feature: …")` > `test.describe("Scenario: …")` > `test("…된다")`. Given/When/Then 접두는 쓰지 않는다(`testing.md` §1 BDD 3계층과 같은 이유)
- fixture 함수의 두 번째 인자는 `use` 대신 `provide`로 쓴다 — `use`면 react-hooks 린트가 훅 규칙 위반으로 막는다(2026-10-15 실측)
- 범위: 회귀 비용이 큰 페이지 흐름만, 개수는 적게. 화면 하나의 상태는 단위 테스트로

> 2026-10-16 #6 — 리뷰 앱 레포(#19, PR #50)에서 먼저 적용해 스펙 2 · POM 4 · fixtures 1로 돌린 뒤 문구를 확정했다.

## API 가로채기

- `page.route("**/api/**")` 같은 **URL glob으로 API를 가로채지 않는다.** 개발 서버가 내려주는 **소스 모듈 경로**도 같은 glob에 걸려, 모듈이 가짜 응답을 받고 오류 없이 빈 화면만 뜬다. 경로가 API 접두로 **시작하는지**로 거른다:
  ```ts
  await page.route((url) => url.pathname.startsWith("/api/"), handler);
  ```
  Next 개발 서버에서 같은 충돌이 나는지는 미실측이다(Vite에서 실측). 그래도 pathname 판정이 안전하다.
- Next 서버 컴포넌트의 fetch는 **브라우저를 거치지 않는다** — `page.route`로 못 가로챈다. 그 경로는 테스트용 API 서버나 환경변수로 바꾼 백엔드 주소로 스텁한다.

## 스텁 안 한 API 경로

- 모르는 경로를 `{}`나 200으로 돌려주지 않는다. 컴포넌트가 배열 필드에서 TypeError를 내고 화면 전체가 오류 화면이 되는데, 원인이 "스텁 누락"으로 보이지 않는다(2026-10-05 실측: 단위 테스트는 통과, e2e만 실패).
- 스텁 핸들러의 기본 분기는 **501 + 경로를 적은 본문**으로 응답하고, 테스트 끝에 스텁 안 된 호출이 있었으면 실패시킨다.
- 화면이 새 API를 부르게 바꾼 PR은 스텁 목록에도 그 경로를 더한다.

## 돌리는 곳

- E2E는 `verify`에 넣지 않는다. CI 별도 잡(비용이 크면 기준 브랜치 push에서만)으로 돌리고, PR에서는 로컬 실행 결과를 본문에 적는다.
- 로컬 `reuseExistingServer`는 **다른 worktree의 서버를 재사용**할 수 있다. 병렬 worktree에서는 포트를 나눈다.
- web 서버는 `reuseExistingServer: false` + 전용 포트로 띄운다. 다른 프로젝트 dev 서버가 그 포트를 쓰고 있으면 테스트가 **엉뚱한 앱을 테스트하고 통과**한다(2026-10-15 실측: 3000·3100을 다른 프로젝트가 쓰고 있었다)
