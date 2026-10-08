---
paths: ["**/service/**", "**/application/**", "**/worker/**", "**/scheduler/**", "**/listener/**", "**/*Service.kt", "**/*Worker.kt", "**/*Scheduler.kt", "**/*Listener.kt"]
---

# 서비스 규칙

## 트랜잭션

- `@Transactional`은 서비스의 public 메서드에. 조회는 `readOnly = true`.
- **트랜잭션 안에서 외부 HTTP·LLM·S3 호출을 하지 않는다.** DB 커넥션을 쥔 채 응답을 기다리면 풀이 고갈된다. 외부 호출 → 결과를 들고 짧은 트랜잭션으로 저장.
- `@Transactional`·`@Cacheable`·`@Async`는 **프록시가 가로챌 때만** 동작한다. 같은 클래스 안에서 `this.foo()`로 부르거나 `private`이면 조용히 무효다. 필요하면 별도 빈으로 뺀다.
- 실패해도 남아야 하는 기록(작업 원장·실패 로그)은 `propagation = REQUIRES_NEW`로 따로 커밋한다. 기본값이면 본 작업과 함께 롤백돼 흔적이 사라진다.
- 큐 발행·알림은 커밋 **뒤에**(`afterCommit` 또는 `@TransactionalEventListener(phase = AFTER_COMMIT)`). 커밋 전에 발행하면 워커가 아직 없는 행을 읽는다.

## 작업(잡) 처리

- 긴 작업은 단계마다 원장 한 행: 시작 시 RUNNING을 먼저 커밋 → 성공 시 소요·비용 / 실패 시 에러. 재시도는 `attempt`로 구분한다.
- 큐 소비자는 같은 메시지가 두 번 올 수 있다고 가정한다(재배달). 조건부 UPDATE·외부 ID 선저장·DB 유니크로 멱등하게.
- 바깥에 흔적이 남는 작업(업로드·결제·발송)은 동시성 1 또는 외부 ID를 받자마자 저장한다.

## 성공 위장 금지

- 0개 결과·빈 응답·판정 불가를 성공 상태로 넘기지 않는다. 실패로 기록하거나 "검토 필요"로 표시한다.
- 돈이 나가는 호출(LLM·유료 API·결제)은 **입구 함수 하나**로만 지나가게 하고, ArchUnit 테스트로 우회를 막는다.
