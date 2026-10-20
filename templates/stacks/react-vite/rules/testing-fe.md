---
paths: ["src/**/*.test.ts", "src/**/*.test.tsx", "src/**/*.stories.tsx", "e2e/**"]
---

# FE 테스트 — 자리마다 도구 하나

무엇을 테스트하고 무엇을 안 하는지는 공통 `testing.md` §0이 정본이다. 여기는 **어느 자리를 어느 도구로**만 정한다. 한 로직을 두 도구로 중복 검증하지 않는다.

| 자리 | 도구 | 무엇을 | 파일 |
|---|---|---|---|
| `model/` · `lib/` 계산 | Vitest 단위 | 규칙 · 파생 계산. 목 0개 | 대상 옆 `*.test.ts` |
| `shared/ui` · `entities/ui` 표시 부품 | Storybook 스토리. play는 상호작용(포커스 · 키보드 · 열고 닫기)에만 | 상태별 모양(빈 · 로딩 · 에러 · 긴 텍스트). 부품별 Vitest는 쓰지 않는다 | 모듈 폴더 안 `*.stories.tsx` |
| `features` · 화면 섹션 흐름 | Vitest + Testing Library + MSW, 기능당 통합 1개 | 목록 · 필터 · 빈 화면 · 에러 · 재시도 | 대상 옆 `*.test.tsx` |
| `pages` 핵심 여정 | Playwright, 적게 | 회귀 비용이 큰 흐름만 | `e2e/specs/*.spec.ts` |

## 통합 (Vitest + Testing Library + MSW)

- 렌더는 `shared/test/render.tsx` 하나로(테스트용 QueryClient · MemoryRouter를 감싼다). 테스트마다 프로바이더를 새로 조립하지 않는다
- HTTP는 MSW로 고정한다. 핸들러는 엔티티마다 `entities/<도메인>/api/<도메인>.msw.ts` 하나 — 개발 목 · 테스트 · 스토리가 같은 것을 쓴다. 핸들러 자체는 테스트하지 않는다
- 쿼리는 `getByRole` → `getByLabelText` 순. 입력은 `userEvent`. 클래스명 · 구현 세부를 단언하지 않는다

## 스토리 · play

- play는 바뀐 컴포넌트만 돈다: `vitest run --project storybook --changed <기준>`(addon-vitest, import 그래프로 고른다). `--changed`는 `.storybook/` 변경을 못 잡는다(2026-10-20 kit 실측) → kit `vite.config.ts`의 `forceRerunTriggers`에 `**/.storybook/**`를 넣어 그때는 전체를 돈다. 다른 전역 파일(토큰 CSS 등)을 두면 같은 자리에 더한다
- 스토리 데이터는 고정값. 렌더 중 `Date.now()` 같은 값이 들어가면 화면이 매번 달라진다(`react-components.md`)

## E2E (Playwright)

- `e2e/specs/`(실행되는 스펙만) · `e2e/fixtures/`(`test.extend` 진입점) · `e2e/pom/`(Page Object — 셀렉터는 여기 한 곳) · `e2e/setup/`(인증 · `storageState`)
- 셀렉터는 역할 · 레이블 먼저. `data-testid`는 그것으로 안 될 때만
- verify에 넣지 않는다. CI 별도 잡

## 확장자

단위 · 통합은 `*.test.ts(x)`, E2E는 `*.spec.ts`. 도구 사이에 섞지 않는다(Vitest `include` · Playwright `testMatch`가 이것으로 가른다).
