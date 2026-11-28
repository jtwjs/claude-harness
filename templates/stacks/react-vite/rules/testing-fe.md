---
paths: ["src/**/*.test.ts", "src/**/*.test.tsx", "src/**/*.stories.tsx", "e2e/**"]
---

# FE 테스트 — 자리마다 도구 하나

무엇을 테스트하고 무엇을 안 하는지는 공통 `testing.md` §0이 정본이다. 여기는 **어느 자리를 어느 도구로**만 정한다. 한 로직을 두 도구로 중복 검증하지 않는다.

| 자리 | 도구 | 무엇을 | 파일 |
|---|---|---|---|
| `model/` · `lib/` 계산 | Vitest 단위 | 규칙 · 파생 계산. 목 0개 | 대상 옆 `*.test.ts` |
| `shared/ui` · `entities/ui` 표시 부품 | Storybook 스토리. play는 상호작용(포커스 · 키보드 · 열고 닫기)에만 | 상태별 모양(빈 · 로딩 · 에러 · 긴 텍스트). 부품별 Vitest는 쓰지 않는다 | 모듈 폴더 안 `*.stories.tsx` |
| `features` · 화면 섹션 흐름 | Vitest + Testing Library + MSW, 흐름마다 통합(개수는 미리 정하지 않는다) | 목록 · 필터 · 빈 화면 · 에러 · 재시도 | 대상 옆 `*.test.tsx` |
| `pages` 핵심 여정 | Playwright, 적게 | 회귀 비용이 큰 흐름만 | `e2e/specs/*.spec.ts` |

## 통합 (Vitest + Testing Library + MSW)

- 렌더는 `shared/test/render.tsx` 하나로(테스트용 QueryClient · MemoryRouter를 감싼다). 테스트마다 프로바이더를 새로 조립하지 않는다
- HTTP는 MSW로 고정한다. 핸들러는 엔티티마다 `entities/<도메인>/api/<도메인>.msw.ts` 하나 — 개발 목 · 테스트 · 스토리가 같은 것을 쓴다. 핸들러 자체는 테스트하지 않는다
- 쿼리는 `getByRole` → `getByLabelText` 순. 입력은 `userEvent`. 클래스명 · 구현 세부를 단언하지 않는다

## 엣지 5축을 사용자 장면으로

축 정의와 질문은 공통 `testing.md` §2가 정본이다. FE는 같은 축을 사용자가 화면에서 겪는 장면으로 옮겨 묻는다. 엣지 케이스는 이 기능의 의도를 얼마나 이해했는지 보여 주고, FE 테스트는 사용자 관점으로 깊게 팔수록 좋은 테스트가 된다. 아래는 예시다. 기능마다 이 기능의 사용자가 실제로 할 행동으로 바꿔 쓴다.

| 축 | 사용자 장면 예시 |
|---|---|
| 빈 값·경계 | 목록이 비어 처음 들어온 화면 · 아주 긴 이름 · 마지막 페이지 |
| 비정상 입력 | 마우스 없이 키보드만으로 끝까지 · 서식이 섞인 글을 붙여넣기 |
| 실패 경로 | 느린 네트워크에서 로딩이 길어진 화면 · 중간에 끊긴 네트워크 · 재시도 |
| 상태 전이 | 입력 도중 뒤로가기 · 새로고침 뒤 다시 들어온 화면 |
| 동시성 | 제출 버튼 연타 · 응답이 오기 전에 필터를 또 바꿈 |

## 스토리 · play

- play는 바뀐 컴포넌트만 돈다: `vitest run --project storybook --changed <기준>`(addon-vitest, import 그래프로 고른다). `--changed`는 `.storybook/` 변경을 못 잡는다(2026-10-20 kit 실측) → kit `vite.config.ts`의 `forceRerunTriggers`에 `**/.storybook/**`를 넣어 그때는 전체를 돈다. 다른 전역 파일(토큰 CSS 등)을 두면 같은 자리에 더한다
- 스토리 데이터는 고정값. 렌더 중 `Date.now()` 같은 값이 들어가면 화면이 매번 달라진다(`react-components.md`)

## E2E (Playwright)

- `e2e/specs/`(실행되는 스펙만) · `e2e/fixtures/`(`test.extend` 진입점) · `e2e/pom/`(Page Object — 셀렉터는 여기 한 곳) · `e2e/setup/`(인증 · `storageState`)
- 셀렉터는 역할 · 레이블 먼저. `data-testid`는 그것으로 안 될 때만
- verify에 넣지 않는다. CI 별도 잡

## 이 레포 현황 (기존 레포만 — `harness-init`이 채운다)

위 표는 kit 뼈대(`shared/test/render.tsx` · MSW · `e2e/specs`)를 전제한다. 그 인프라가 없는 레포에 이 규칙만 깔리면 에이전트가 아무 PR에서나 MSW · 렌더 헬퍼를 새로 들인다. 다른 자리를 여기 적는다.

| 자리 | 이 레포 지금 | 새 코드는 |
|---|---|---|
| 렌더 헬퍼 | <예: 없음 — 테스트마다 QueryClientProvider 조립> | <지금 방식을 따른다 / 헬퍼로> |
| HTTP 고정 | <예: MSW 없음 — `vi.fn` fetch 목> | <지금 방식을 따른다 / MSW로> |
| E2E 폴더 | <예: `e2e/*.spec.ts` 1개, pom · fixtures 없음> | <지금 방식을 따른다 / 위 구조로> |

- 「새 코드는」이 「지금 방식」인 줄은 kit 인프라를 들이지 않는다. 들이는 것은 따로 합의한 작업에서만
- 레포가 위 표 그대로면(kit으로 시작한 레포) 이 절을 지운다

## 확장자

단위 · 통합은 `*.test.ts(x)`, E2E는 `*.spec.ts`. 도구 사이에 섞지 않는다(Vitest `include` · Playwright `testMatch`가 이것으로 가른다).
