---
paths: ["**/entity/**", "**/repository/**", "**/*Repository.kt", "**/*Entity.kt", "**/db/migration/**", "**/resources/application*.yml", "**/resources/application*.yaml"]
---

# DB 규칙

## 스키마

- 스키마 변경은 **Flyway 마이그레이션 파일로만**. `ddl-auto`는 `validate` — 엔티티와 스키마가 어긋나면 기동이 실패해야 한다.
- 버전은 **타임스탬프**: `db/migration/V20261008120000__의도.sql`. 순번(`V3__`)은 병렬 브랜치 둘이 같은 번호를 만들어, 두 번째가 기준 브랜치에 들어가는 순간 "more than one migration with version"으로 테스트가 깨진다(2026-09 병렬 트랙 실측). 기존 순번 파일은 그대로 둔다.
- 열린 PR에 더 이른 버전이 있는데 내 마이그레이션을 **운영에 먼저 적용하지 않는다** — 운영 버전이 앞서 나가 그 PR의 파일이 「순서 밖(outOfOrder)」으로 거부된다. 먼저 적용했다면 열린 PR의 버전을 운영 버전 뒤로 옮긴다(2026-10-07 실측).
- 컬럼 삭제는 두 배포로: 코드에서 사용 중단 → 다음 배포에서 삭제. 새 컬럼은 NULL 허용 또는 DEFAULT로 먼저 넣는다. 배포 순서는 마이그레이션 → 앱이다.
- 이미 적용된 마이그레이션 파일은 고치지 않는다. 새 파일로 되돌린다.

## 이름

- 테이블은 단수 명사. PK는 `{테이블}_id`. 자연 키는 PK로 쓰지 않고 UNIQUE로.
- **같은 역할은 같은 이름**: 행 생성 · 수정 시각은 어디서나 `created_at` · `updated_at`. 새 컬럼을 만들기 전에 같은 역할의 컬럼이 이미 있는지 찾는다.
- COMMENT는 **처음 보는 사람이 그것만 읽고 뜻을 알게** 쓴다. 내부 줄임말만 적지 않는다. 코드 값은 값마다 뜻을 붙인다(`mute(음소거 중) | cap(상한 초과)`).
- 인덱스는 `uk_{테이블}_{컬럼}` · `idx_{테이블}_{컬럼}`.
- 새 테이블은 엔진 · 문자셋 · **콜레이션을 명시**한다. 기존 테이블과 콜레이션이 다르면 조인이 `Illegal mix of collations`로 실패한다.

## 매핑

- `@Enumerated(EnumType.STRING)` 필수. 기본 ORDINAL은 enum 순서가 바뀌면 기존 행이 **에러 없이** 다른 값으로 읽힌다.
- 시각은 `Instant`(또는 `OffsetDateTime`). `LocalDateTime`은 시간대가 없어 서버 TZ에 기댄다.
- 레거시 `DATETIME` · `DEFAULT CURRENT_TIMESTAMP`는 **행을 넣는 세션의 시간대**를 따른다. 세션이 UTC면 9시간 어긋난다. 커넥션 풀 init SQL로 세션 시간대를 고정한다(`spring.datasource.hikari.connection-init-sql: "SET time_zone = '<기존 데이터가 쓰인 시간대>'"`).
- `MAX` 같은 집계는 **행이 없어도 NULL 한 행**을 돌려준다. `JdbcClient` `.single()`이 그 null에서 터진다 → `.list().firstOrNull()`로 읽는다.
- 서비스 간 식별자 참조를 콤마 구분 문자열로 저장하지 않는다. 조인 테이블로.

## 상태와 동시성

- status 칸은 enum + 허용 전이표(ADR 또는 enum 옆 주석). 허용되지 않은 전이는 서비스에서 409.
- 중복 방지는 앱 검사(친절한 409)와 **DB 유니크(최종 방어)** 두 겹. 두 요청이 동시에 앱 검사를 통과할 수 있다.
- **MySQL엔 부분 인덱스가 없다.** "살아 있는 행만 유일"은 생성 컬럼 `live_key = IF(status IN (...종료...), NULL, 1)` + `UNIQUE(..., live_key)`로(유니크는 NULL을 여러 개 허용).
- 워커끼리 같은 행을 집는 경주는 조건부 UPDATE로 푼다: `UPDATE … SET status='RUNNING' WHERE id=? AND status='QUEUED'` → 영향 행 0이면 물러난다.

## 설정

- 프로필 이름을 믿지 않는다. 실행·쿼리 전에 datasource 호스트가 어디를 가리키는지 확인한다.
- 비밀값은 yml에 쓰지 않는다. `${ENV}`로만.
