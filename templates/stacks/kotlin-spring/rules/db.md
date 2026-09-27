---
paths: ["**/entity/**", "**/repository/**", "**/db/migration/**", "**/resources/application*.yml", "**/resources/application*.yaml"]
---

# DB 규칙

## 스키마

- 스키마 변경은 **Flyway 마이그레이션 파일로만**(`db/migration/V{n}__의도.sql`). `ddl-auto`는 `validate` — 엔티티와 스키마가 어긋나면 기동이 실패해야 한다.
- 컬럼 삭제는 두 배포로: 코드에서 사용 중단 → 다음 배포에서 삭제. 새 컬럼은 NULL 허용 또는 DEFAULT로 먼저 넣는다. 배포 순서는 마이그레이션 → 앱이다.
- 이미 적용된 마이그레이션 파일은 고치지 않는다. 새 파일로 되돌린다.

## 매핑

- `@Enumerated(EnumType.STRING)` 필수. 기본 ORDINAL은 enum 순서가 바뀌면 기존 행이 **에러 없이** 다른 값으로 읽힌다.
- 시각은 `Instant`(또는 `OffsetDateTime`). `LocalDateTime`은 시간대가 없어 서버 TZ에 기댄다.
- 서비스 간 식별자 참조를 콤마 구분 문자열로 저장하지 않는다. 조인 테이블로.

## 상태와 동시성

- status 칸은 enum + 허용 전이표(ADR 또는 enum 옆 주석). 허용되지 않은 전이는 서비스에서 409.
- 중복 방지는 앱 검사(친절한 409)와 **DB 유니크(최종 방어)** 두 겹. 두 요청이 동시에 앱 검사를 통과할 수 있다.
- **MySQL엔 부분 인덱스가 없다.** "살아 있는 행만 유일"은 생성 컬럼 `live_key = IF(status IN (...종료...), NULL, 1)` + `UNIQUE(..., live_key)`로(유니크는 NULL을 여러 개 허용).
- 워커끼리 같은 행을 집는 경주는 조건부 UPDATE로 푼다: `UPDATE … SET status='RUNNING' WHERE id=? AND status='QUEUED'` → 영향 행 0이면 물러난다.

## 설정

- 프로필 이름을 믿지 않는다. 실행·쿼리 전에 datasource 호스트가 어디를 가리키는지 확인한다.
- 비밀값은 yml에 쓰지 않는다. `${ENV}`로만.
