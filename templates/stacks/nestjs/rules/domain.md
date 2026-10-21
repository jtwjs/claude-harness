---
paths: ["src/**/domain/**", "src/**/*.service.ts"]
---

# 도메인 — 규칙 있는 곳만 불변 모델 (NestJS)

판정 근거는 `functional-programming.md`(적재적소 · 함수 3층). 여기는 NestJS 자리만.

함수 3층 자리: 범용 계산 `shared/lib` 일반 함수 · 규칙 조립 `domain/` · 액션 서비스(provider) · 조립 컨트롤러.

## 언제

- **만든다**: 쓰기 경로이고, 상태 + 허용 전이가 있거나 업무 규칙 두 개 이상이 엮인다
- **안 만든다**: 읽기만 하는 곳 · 규칙 없는 CRUD. 서비스가 바로 읽고 쓴다
- 왜: 뗄 계산이 없는 곳에 모델을 두면 매핑 코드만 는다

## 모양 (이름은 예)

```ts
type Order = Readonly<{ id: string; status: OrderStatus; amount: number }>;

type Decision =
  | { kind: "accepted"; next: Order; events: readonly OrderEvent[] }
  | { kind: "rejected"; reason: RejectReason };

export const decide = (order: Order, command: CancelOrder, now: Date): Decision => …;  // 순수
```

- `domain/`은 `@nestjs/*` · ORM을 import 하지 않는다. 순수 함수에 `@Injectable`을 붙이지 않는다(DI 대상이 아니다)
- 막는 lint 조각(`eslint.config.*`):
  ```js
  { files: ["src/**/domain/**/*.ts"], rules: { "no-restricted-imports": ["error", { patterns: ["@nestjs/*", "typeorm", "@prisma/*", "mongoose"] }] } }
  ```
  ⚠️ 미실측 — 쓰는 레포가 생기면 그 ORM 이름으로 고친다

## 읽기 경로는 도메인 모델을 거치지 않는다

조회는 쿼리에서 응답 DTO로 바로 만든다. `decide`는 쓰기에만 쓴다. 같은 쿼리를 소비자 둘 이상이 쓰면 쿼리는 행 타입을 돌려주고 DTO 변환은 소비자마다 한다.

## 서비스 = 껍질 (쓰기)

읽기 → `decide` → `accepted`면 상태 저장 · 발행 / `rejected`면 상태를 바꾸지 않는다. 결정의 기록(감사 로그)과 멱등 선점 INSERT는 거절이어도 · `decide` 전이어도 쓴다 — 업무 상태 변경만 `accepted`일 때. 🔴 `decide` 전에 상태를 바꾸지 않는다 — 트랜잭션은 throw에만 롤백한다.

## 실패

호출자가 다르게 행동할 수 있으면 `rejected` 값 → 컨트롤러가 `switch (decision.kind)`로 4xx(`never` 검사로 빠짐을 막는다). 할 수 있는 게 없는 고장은 예외 → Nest 예외 필터.

## 테스트

`decide`는 목 0개 단위 테스트. 안 한다: fp-ts · Either 라이브러리, 모든 함수 순수화.
