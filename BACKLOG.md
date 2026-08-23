# BACKLOG

승격 **조건만** 적는다. 조건은 **셀 수 있어야** 한다 — "놓친 사례 3건"처럼 세는 주체가 없는 조건은 쓰지 않는다.

| 항목 | 승격 조건 |
|---|---|
| `review-code` 차원별 병렬 리뷰 | 리뷰 통과 후 머지된 diff에서 나온 `fix:` 커밋 **3건** (`git log --grep='^fix:'`) |
| `build-rules` | PR **100개+** 누적 후 (repo 첫날 실행 금지) |
| `security-scan` | 프로덕션 트래픽이 붙은 레포가 생겼을 때 |
| `improve-token-efficiency` | 월 비용이 신경 쓰일 때 |
| `oncall-agent` | 운영 알림·CI 권한을 받았을 때 |
| design 3종 + `DESIGN.md` 템플릿 | UI 비중 큰 프로젝트 착수 시 (`incubator/ready/`에서 `mv`) |
| `review-{task}.json` 리포트 계약 | **3번째 레포**에서 순환 재검증이 실제로 일어난 뒤 |
| `references/testing-patterns.md` | `test-writer` 보고에 "셋업을 몰라서 못 씀"이 **3회** 누적 |
| `implementation-patterns.md` 7번째 패턴 | 같은 종류 지적이 `code-reviewer` 리뷰에서 **3회** 반복 |
| `evals/` (공식 `claude plugin eval` 러너) | 스킬이 **실제로 안 불리는 사례 3건**이 관측된 뒤 (트리거 회귀는 그때부터 값이 생긴다) |
| `InstructionsLoaded` 훅 계측 | `harness-doctor` 검사 5의 바이트 계측으로 부족해진 뒤 |

> `habit.md:78` — **"3번부터."** 두 번까지는 우연이고 세 번째가 패턴이다.
