---
paths: ["src/**"]
---

# FSD 레이어 규칙

> FSD(Feature-Sliced Design)는 **선택지**다. 이 레포가 FSD를 쓰기로 했을 때만 이 파일을 둔다(`harness-init`이 묻는다). 막는 장치의 정본은 `eslint.config.*`의 `no-restricted-imports`다 — stack-kits `fullstack` kit `apps/web/eslint.config.*`에서 가져온다.

## 1. 레이어와 방향

| 레이어 | 두는 것 |
|---|---|
| `app/` | 라우터 · 전역 프로바이더 · 전역 스타일. 진입점 `main.tsx`만 `src` 바로 아래 |
| `pages/` | 화면 하나. 폴더가 경로를 드러낸다 |
| `widgets/` | 여러 화면이 쓰는 독립 UI 블록 |
| `features/` | 사용자 행동(유즈케이스) 하나. **처음 생길 때 만든다** — 조회만 있는 동안은 없다 |
| `entities/` | 도메인 단위의 API 호출 · 쿼리 팩토리 · 도메인 계산 |
| `shared/` | 도메인과 **완전히 무관한** 것. 계약 생성물 · HTTP 클라이언트는 `shared/api` |

**위에서 아래로만 import 한다**: `app → pages → widgets → features → entities → shared`. 역방향 금지.

## 2. 슬라이스 경계

- **같은 레이어의 다른 슬라이스를 import 하지 않는다.** 둘이 같이 쓰면 아래 레이어로 내린다
- entity끼리는 **단방향 · 무순환**일 때만 `entities/{제공}/@x/{소비}.ts` 슬롯으로 연다
- 슬라이스 밖에서는 **`index.ts`(public API)만** import 한다. `export default`·`export *`는 쓰지 않는다
- **슬라이스 밖은 `@/` 별칭, 안은 상대 경로.** 상대 경로는 슬라이스를 벗어나지 않는다
- `ui`의 부품은 모듈 폴더(`ui/<모듈>/<모듈>.tsx` · `.stories.tsx` · `.test.tsx` · `index.ts`)로 묶고, 밖에서는 그 `index.ts`로만 가져온다

## 3. 세그먼트

`ui` · `api` · `model`(타입 · 순수 계산) · `lib` · `config`. 쓰는 것만 만든다.

- **응집도가 먼저다.** 나눠서 분명히 나아지지 않으면 나누지 않는다. 한 화면만 쓰는 것은 그 `pages/<화면>/`에
- `shared`에 도메인 문구 · 도메인 규칙을 넣지 않는다
- 계약 타입은 `shared/api`가 다시 내보낸 이름으로 쓴다. 생성 파일을 직접 import 하지 않는다

## 4. 이름 · 파일

- 폴더 · 파일은 kebab-case. 컴포넌트 PascalCase, 훅 `use*`
- entity는 단수 명사, feature는 `{대상}-{행동}`
- 테스트 · 스토리는 대상 파일 옆
- 코드 레이어 안에 `CLAUDE.md`를 두지 않는다. 규칙은 `.claude/rules/`에 `paths:`로

## 5. lint가 막는 것과 못 막는 것

막는다: 레이어 역방향 · 같은 레이어 슬라이스 import · public API를 건너뛴 깊은 경로 · 슬라이스를 벗어나는 상대 경로 · 이웃 모듈의 안쪽 파일.

못 막는다(리뷰로 본다): `shared`에 도메인 로직이 들어오는 것 · `@x` 슬롯의 단방향 · 무순환 · 동적 `import()`.
