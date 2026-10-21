---
paths: ["**/domain/**", "**/service/**", "**/*Service.kt"]
---

# 도메인 — 규칙 있는 곳만 불변 모델 (함수형 코어 · 명령형 껍질)

판정 근거는 `functional-programming.md`(적재적소 · 함수 3층). 여기는 Kotlin · Spring 자리만.

함수 3층 자리: 범용 계산은 최상위 · 확장 함수 · 규칙 조립 `domain/` · 액션 서비스 · 조립 컨트롤러. 호출 자리의 분기 있는 여러 줄 람다는 `private fun`으로 뺀다.

## 언제 도메인 모델을 만드나

- **만든다**: 쓰기 경로이고, 상태 enum + 허용 전이표가 있거나(`db.md` 「상태와 동시성」) 업무 규칙 두 개 이상이 엮인다
- **안 만든다**: 읽기만 하는 곳(SELECT 만). 규칙이 있어도 판정 · 필터는 범용 계산 함수로 둔다
- 규칙 없는 CRUD도 안 만든다. 서비스가 엔티티 · DTO로 바로 읽고 쓴다(트랜잭션 스크립트)
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

같은 쿼리를 소비자 둘 이상(api 컨트롤러 · 배치 잡 등)이 쓰면 쿼리는 행 타입(`…Row`)을 돌려주고, 응답 DTO 변환은 소비자마다 한다. 한쪽 응답 모양에 맞춘 DTO를 다른 소비자가 끌어 쓰면 한쪽 API 변경이 다른 쪽을 깬다.

## 서비스 = 껍질 (쓰기)

읽기 → `decide` → `Accepted`면 상태 저장 · 커밋 뒤 발행 / `Rejected`면 상태를 바꾸지 않는다.

- **결정의 기록(감사 로그)은 거절이어도 쓴다** — 누가 무엇을 요청했고 왜 거절됐는지가 요구사항이면 `Rejected`도 기록한다. 상태 변경만 `Accepted`일 때. 예: 해제 요청이 거절돼도 `action_log`에 `FAILED` + 사유를 남기고, 해제 자체는 `Accepted`에만 한다
- **멱등 선점 INSERT도 `decide` 전에 써도 된다** — UNIQUE 키로 같은 요청이 두 번 도는 것을 막는 행은 업무 상태가 아니다. 업무 상태(엔티티 상태 · 잔액 · 전이)만 `decide` 뒤

- 🔴 **`decide` 전에 업무 상태를 바꾸지 않는다.** `@Transactional`은 예외에만 롤백한다 — 쓰고 나서 `Rejected`를 값으로 돌려주면 그 쓰기는 커밋된다
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
