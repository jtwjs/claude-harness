---
paths: ["**/domain/**", "**/service/**"]
---

# 도메인 — 규칙 있는 곳만 불변 모델 (함수형 코어 · 명령형 껍질)

판정 근거는 `functional-programming.md`(적재적소 · 함수 3층). 여기는 Kotlin · Spring 자리만.

## 언제 도메인 모델을 만드나

- **만든다**: 상태 enum + 허용 전이표가 있거나(`db.md` 「상태와 동시성」), 업무 규칙 두 개 이상이 엮인다
- **안 만든다**: 규칙 없는 조회 · CRUD. 서비스가 엔티티 · DTO로 바로 읽고 쓴다(트랜잭션 스크립트)
- 왜: 뗄 계산이 없는 곳에 모델을 두면 매핑 코드만 는다. DDD도 전술 패턴은 핵심 도메인에만 쓴다

## 모양 (이름은 예 — grep 되게 이 이름을 기본으로)

```kotlin
data class Order(val id: Long, val status: OrderStatus, val amount: Money)   // 불변: val · copy

sealed interface Decision {
    data class Accepted(val next: Order, val events: List<OrderEvent>) : Decision
    data class Rejected(val reason: RejectReason) : Decision
}

fun decide(order: Order, command: CancelOrder, now: Instant): Decision = …   // 순수: 시각 · ID는 인자로
```

- `domain/`은 Spring · JPA를 import 하지 않는다 — kit의 ArchUnit 테스트가 막는다
- 엔티티 ↔ 도메인은 매핑 함수 하나(`toDomain` · `toEntity`). 엔티티는 JPA 사정대로 가변으로 둔다

## 읽기 경로는 도메인 모델을 거치지 않는다

조회는 쿼리에서 응답 DTO로 바로 프로젝션한다(`readOnly = true`). `decide`는 쓰기에만 쓴다. 없으면: 목록 조회 하나에 도메인 매핑이 끼어 느리고 길어진다.

## 서비스 = 껍질 (쓰기)

읽기 → `decide` → `Accepted`면 저장 · 커밋 뒤 발행 / `Rejected`면 아무것도 쓰지 않는다.

- 🔴 **`decide` 전에 쓰지 않는다.** `@Transactional`은 예외에만 롤백한다 — 쓰고 나서 `Rejected`를 값으로 돌려주면 그 쓰기는 커밋된다
- 현재 시각은 `Clock` 빈을 받아 `Instant.now(clock)`으로 넘긴다

## 실패 — 값인가 예외인가

| 실패 | 다루기 | 예 |
|---|---|---|
| 호출자가 다르게 행동할 수 있다(업무 실패) | `Rejected` 값 | 이미 취소됨 · 한도 초과 |
| 호출자가 할 수 있는 게 없다(고장) | 예외 | DB 다운 · 타임아웃 |

컨트롤러는 `when (decision)`으로 `Rejected` → 4xx. sealed라 분기가 빠지면 컴파일 에러다.

## 테스트 · 안 하는 것

- `decide`는 목 0개 단위 테스트(`tdd.include`의 `**/domain/**`)
- 안 한다: Arrow · Either 라이브러리, 모든 함수 순수화, 엔티티 불변 강제
