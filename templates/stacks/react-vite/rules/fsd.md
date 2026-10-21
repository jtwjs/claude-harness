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
| `features/` | 사용자 행동(유즈케이스) 하나 — **쓰기(뮤테이션)는 여기**. **처음 생길 때 만든다** — 조회만 있는 동안은 없다 |
| `entities/` | 도메인 단위의 **읽기**(API 조회 · 쿼리 팩토리) · 도메인 계산. 뮤테이션을 두지 않는다 |
| `shared/` | 도메인과 **완전히 무관한** 것. 계약 생성물 · HTTP 클라이언트는 `shared/api` |

**위에서 아래로만 import 한다**: `app → pages → widgets → features → entities → shared`. 역방향 금지.

## 2. 슬라이스 경계

- **같은 레이어의 다른 슬라이스를 import 하지 않는다.** 둘이 같이 쓰면 아래 레이어로 내린다
- entity끼리는 **단방향 · 무순환**일 때만 `entities/{제공}/@x/{소비}.ts` 슬롯으로 연다
- 슬라이스 밖에서는 **`index.ts`(public API)만** import 한다. `export default`·`export *`는 쓰지 않는다(예외: Storybook 규약상 `*.stories.tsx` · `.storybook/` 설정은 default export)
- **슬라이스 밖은 `@/` 별칭, 안은 상대 경로.** 상대 경로는 슬라이스를 벗어나지 않는다
- `ui`의 부품은 모듈 폴더(`ui/<모듈>/<모듈>.tsx` · `.stories.tsx` · `.test.tsx` · `index.ts`)로 묶고, 밖에서는 그 `index.ts`로만 가져온다

## 3. 세그먼트

`ui` · `api` · `model`(타입 · 순수 계산) · `lib` · `config`. 쓰는 것만 만든다.

- **슬라이스 안 방향은 `ui` → `model` · `api` → `lib` · `config`.** `model`은 `ui`를 import 하지 않는다 — 타입 하나라도 `model`이 `ui` 파일을 끌어오면 계산을 테스트 · 재사용할 때 화면이 같이 딸려 오고 `ui` ↔ `model` 순환이 생긴다. `ui`에 선언된 타입이 필요하면 그 타입을 `model`로 옮기고 `ui`가 가져다 쓴다
- **응집도가 먼저다.** 나눠서 분명히 나아지지 않으면 나누지 않는다. 한 화면만 쓰는 것은 그 `pages/<화면>/`에 두되, 그 안에서도 섹션마다 `pages/<화면>/ui/<섹션>/` 모듈 폴더로 나눈다(§6)
- `shared`에 도메인 문구 · 도메인 규칙을 넣지 않는다
- 계약 타입은 `shared/api`가 다시 내보낸 이름으로 쓴다. 생성 파일을 직접 import 하지 않는다

## 4. 이름 · 파일

- 폴더 · 파일은 kebab-case. 컴포넌트 PascalCase, 훅 `use*`
- entity는 단수 명사, feature는 `{대상}-{행동}`
- 테스트 · 스토리는 대상 파일 옆
- 코드 레이어 안에 `CLAUDE.md`를 두지 않는다. 규칙은 `.claude/rules/`에 `paths:`로

## 5. lint가 막는 것과 못 막는 것

막는다(stack-kits kit 기준): 레이어 역방향 · 본문 코드의 픽스처 · MSW 핸들러 import. 레포가 더 막았으면(예: `viewus-distribution-dashboard`) 그 레포 `eslint.config.*`가 정본이다 — 막는다고 믿기 전에 거기서 확인한다.

에러: JSX 속성의 중괄호 몸통 화살표(`onChange={(e) => { … }}` — 이름 있는 핸들러로 뺀다, `functional-programming.md` 「함수 3층」). 한 줄 위임(`() => remove(id)`)은 허용.

경고만 한다: 300줄 넘는 파일(`max-lines`, §6).

못 막는다(리뷰로 본다): 슬라이스 안 `model` → `ui` import(경계 lint는 슬라이스 사이만 본다 — 아래 블록을 넣으면 막는다) · kit에선 같은 레이어 슬라이스 import · public API를 건너뛴 깊은 경로 · 슬라이스를 벗어나는 상대 경로 · 이웃 모듈의 안쪽 파일도 여기다 · `shared`에 도메인 로직이 들어오는 것 · `@x` 슬롯의 단방향 · 무순환 · 동적 `import()` · 화면 파일에 섹션 본문이 들어오는 것 · 파일당 컴포넌트 수 · 화살표 함수 · 콜백 순서 · 훅 순서(§6).

슬라이스 안 방향을 lint로 막으려면 `eslint.config.*`에 블록 하나:

```js
{
  files: ["src/**/model/**/*.{ts,tsx}"],
  rules: {
    "no-restricted-imports": ["error", { patterns: [{ group: ["../ui", "../ui/*", "../../ui/*"], message: "model 은 ui 를 import 하지 않는다 — 타입은 model 로 옮긴다 (fsd §3)" }] }],
  },
},
```

## 6. 컴포넌트 · 파일

`viewus-fe-creator-cms-v2`에서 가져온 것(화살표 함수 · 콜백 순서 · 훅 순서 · 재사용 임계)과, 거기에도 없어 새로 쓴 것(화면은 조립만 · 파일당 컴포넌트 하나 · 300줄 경고)이다. 근거: `viewus-distribution-dashboard` `pages/` 18파일 6,017줄 · 컴포넌트 2개 이상 파일 42% (2026-10-20 실측).

- **화면 파일은 조립만 한다.** `pages/<화면>/ui/<화면>-screen.tsx`에는 섹션 배치 · 데이터 훅 연결 · 라우트 파라미터만 둔다. 표 · 필터 · 폼 · 타임라인 본문은 섹션 모듈(`ui/<섹션>/`)로, 계산은 `model/`로 뺀다
- **파일 하나에 export 컴포넌트 하나.** 화면이 조립하는 섹션은 위 줄대로 모듈 폴더로 가고, 그 안에서 export 하지 않는 보조 컴포넌트는 같은 파일에 둔다 — **보조 컴포넌트의 기본은 같은 파일**이다. 옆 모듈 폴더로 빼는 것은 ① 다른 곳에서도 쓰거나(소비처 2 이상) ② 자기 상태 · 훅을 갖거나 ③ 합치면 300줄을 넘을 때뿐이다. 왜: 「하나만 export」와 300줄을 같이 지키라고만 하면 에이전트가 보조 컴포넌트까지 전부 폴더로 빼, 한 곳만 쓰는 작은 파일이 쏟아진다(2026-10-21 실측: 화면 6개 쪼개기에서 새 파일 62 중 소비처 하나뿐인 것 50, 「같이 둬도 된다」 문장이 있었는데도)
- **300줄 경고**: 파일이 300줄(빈 줄 · 주석 제외)을 넘으면 lint 경고가 난다. 막지 않는다 — 섹션 · 훅 · `model` 계산을 뺄 신호다. 테스트 · 스토리 · 생성물은 세지 않는다
- **화살표 함수**: `export const Foo = ({ … }: FooProps) => { … }`. `function` 선언 · `function` 표현식으로 컴포넌트를 만들지 않는다. 파일 안 헬퍼도 `const foo = () => …`
- **콜백은 마지막**: props 구조 분해와 `FooProps` 필드 모두 `on*` 콜백을 맨 뒤에 모은다
- **훅 순서**: `useRef` → `useState` → 구독 · 데이터 훅(context · 라우터 · Query · 커스텀) → `useMemo` → `useCallback` → `useEffect`
- **재사용 임계**: 3곳 이상에서 쓰일 UI는 `shared/ui`로 올린다(합의 후). 1~2곳이면 쓰는 슬라이스에 둔다
