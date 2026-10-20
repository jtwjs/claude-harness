---
paths: ["src/**/*.tsx"]
---

# React 컴포넌트 — 함수형 판정을 컴포넌트 자리에

`functional-programming.md`의 판정 6개를 컴포넌트로 옮긴 것만 적는다. 크기 · 파일 · 스타일은 팩 규칙(`fsd.md` §6 등)이 맡는다.

| 판정 | 컴포넌트에서 | ✅ | ❌ | 없으면 나빠지는 것 |
|---|---|---|---|---|
| 렌더 = 계산 (판정 1·3) | 같은 props · state면 같은 화면. 렌더 중에 현재 시각 · 난수 · 전역을 읽지 않는다 | `<Clock now={now} />` (위에서 받음) | 렌더 안 `Date.now()` · `Math.random()` | 스토리 · 테스트가 매번 다른 화면을 낸다 |
| 액션은 바깥으로 (판정 2) | 쿼리 · 뮤테이션 · effect는 화면 · 섹션이 쥐고, 표시 부품은 props만 받는다 | `ArticleTable rows={rows}` | 표시 부품 안 `useQuery` | 부품을 스토리 · 다른 화면에서 못 쓴다 |
| 파생 값은 계산 | 다른 state에서 나오는 값은 렌더 중 계산 또는 `model/` 함수. state + `useEffect`로 동기화하지 않는다 | `const total = sumAmounts(rows)` | `useEffect(() => setTotal(…), [rows])` | 한 박자 늦은 화면 · 이중 렌더 |
| 규칙은 model로 (판정 6) | 필터 · 정렬 · 집계 · 표시 규칙은 `model/` 순수 함수 + 단위 테스트. 컴포넌트엔 조립만 | `visibleRows(rows, filter)` | JSX 안 `.filter().sort()` 체인 | 규칙을 테스트하려면 화면을 띄워야 한다 |
| 실패는 값 (판정 4) | 쿼리의 error 상태로 분기. `try/catch`는 이벤트 핸들러 경계에서만 | `if (query.isError) return <ErrorState />` | 렌더 경로의 `try/catch` | 실패 화면이 흩어지고 빠진다 |

- `useMemo`는 계산이 비쌀 때만. 습관적 `memo` · `useCallback`은 쓰지 않는다
- 상태 갱신은 복사본으로(판정 5): `setRows((prev) => [...prev, row])`. `prev.push` 금지
