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
| `references/testing-patterns.md` | `test-writer` 보고에 "셋업을 몰라서 못 씀"이 **3회** 누적 (`task-observer`·재교정) |
| `implementation-patterns.md` 7번째 패턴 | 같은 종류 지적이 `code-reviewer` 리뷰에서 **3회** 반복 (`task-observer`·재교정) |
| `evals/` (공식 `claude plugin eval` 러너) | 스킬이 **실제로 안 불리는 사례 3건** (`task-observer`·불발). 트리거 회귀는 그때부터 값이 생긴다 |
| **품질 골든셋 + LLM-as-judge 채점** | `.claude/observations.md`의 **`닫힌 것` 행 5개** 누적 (`task-observer`). **그 5개가 곧 첫 골든셋이다** — 새로 만들지 않는다 |
| `InstructionsLoaded` 훅 계측 | `harness-doctor` 검사 5의 바이트 계측으로 부족해진 뒤 |
| `task-observer` 상시 관찰 훅 | REFLECT 되짚기가 **놓친 반복 3건**이 나중에 뒤늦게 발견된 뒤 (`.claude/observations.md`의 `마지막` 날짜가 실제 발생일보다 늦은 경우) |
| `hooks/test.sh` find-skills 회귀 케이스 | 스캔 수가 조용히 0 또는 급감한 사례 **1건** (실패가 침묵이라 3의 법칙 예외) |
| `feature-builder` opus 승격 | `phases/*/index.json` 의 `retries` ≥ 2 인 step **3건**. 올리기 전에 step 분해부터 의심한다 |

> ⚠️ `evals/` 행과 **품질 골든셋** 행은 이름이 비슷하지만 **다른 물건**이다 — `evals/`는 *스킬이 불리나*(트리거 회귀), 골든셋은 *산출물이 좋아졌나*(품질 점수). 한쪽을 깔았다고 다른 쪽이 덮이지 않는다.
>
> **"3번부터."** 두 번까지는 우연이고 세 번째가 패턴이다.
>
> 세는 주체가 `task-observer`인 행은 `.claude/observations.md`의 `횟수` 칸이 근거다. **기억이 아니라 파일을 읽어서 센다.**
