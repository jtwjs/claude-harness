# BACKLOG

승격 **조건만** 적는다. 조건은 **셀 수 있어야** 한다 — "놓친 사례 3건"처럼 세는 주체가 없는 조건은 쓰지 않는다.

| 항목 | 승격 조건 |
|---|---|
| `review-code` 차원별 병렬 리뷰 | 리뷰 통과 후 머지된 diff에서 나온 `fix:` 커밋 **3건** (`git log --grep='^fix:'`) |
| `build-rules` | PR **100개+** 누적 후 (repo 첫날 실행 금지) |
| `security-scan` | 프로덕션 트래픽이 붙은 레포가 생겼을 때 |
| `improve-token-efficiency` | 월 비용이 신경 쓰일 때 |
| `oncall-agent` | 운영 알림·CI 권한을 받았을 때 |
| `review-{task}.json` 리포트 계약 | **3번째 레포**에서 순환 재검증이 실제로 일어난 뒤 |
| `references/testing-patterns.md` | `test-writer` 보고에 "셋업을 몰라서 못 씀"이 **3회** 누적 (`task-observer`·재교정) |
| `implementation-patterns.md` 7번째 패턴 | 같은 종류 지적이 `code-reviewer` 리뷰에서 **3회** 반복 (`task-observer`·재교정) |
| `evals/` (공식 `claude plugin eval` 러너) | 스킬이 **실제로 안 불리는 사례 3건** (`task-observer`·불발). 트리거 회귀는 그때부터 값이 생긴다 |
| **품질 골든셋 + LLM-as-judge 채점** | `.claude/observations.md`의 **`닫힌 것` 행 5개** 누적 (`task-observer`). **그 5개가 곧 첫 골든셋이다** — 새로 만들지 않는다 |
| `InstructionsLoaded` 훅 계측 | `harness-doctor` 검사 5의 바이트 계측으로 부족해진 뒤 |
| `task-observer` 상시 관찰 훅 | REFLECT 되짚기가 **놓친 반복 3건**이 나중에 뒤늦게 발견된 뒤 (`.claude/observations.md`의 `마지막` 날짜가 실제 발생일보다 늦은 경우) |
| 세션 handoff 파일 규약 (강의 Harness Engineering 맥락 축) | 압축·`/clear` 뒤 사람이 같은 지시를 다시 한 사례 **3건** (`task-observer`·재지시 — 압축된 세션은 스스로 못 알아채니 사람의 재지시로 센다) |
| `harness-doctor` 안 쓰는 스킬·MCP 검사 | 30일 호출 0인 스킬을 손으로 지운 일 **3회** (`git log --grep='삭제'` 중 스킬 삭제 커밋) |
| 다른 모델 교차 리뷰 (Codex 등) | `review-code` 행과 같은 계수 — 그때 차원별 병렬과 다른 모델 중 고른다 |
| `harness-run` 독립 phase 병렬 (Fan-out) | `after`로 서로 묶이지 않은 pending phase 둘 이상을 순차로 돌려 기다린 사례 **3건** (`phases_status.py` 현황으로 센다) |
| `ai-readiness-cartography` Sanity 단계(죽은 코드 먼저) | 지도(`CODEBASE_MAP`·`_brain`)가 가리킨 경로가 죽은 코드였던 사례 **3건** (`task-observer`) |
| step `model` 승격 (기본 → opus) | `phases/*/index.json` 의 `retries` ≥ 2 인 step **3건**. 올리기 전에 step 분해부터 의심한다 |
| 실제 자동 머지 켜기 (`pr-write` 4.6, 지금 dry-run) | PR 본문에 `자동 머지 조건` 줄이 있는 **머지된 PR 10건**(`gh pr list --state merged --search '"자동 머지 조건" in:body'`)에서 오판 **0건**. 오판 = `충족`이었는데 머지 뒤 그 PR 파일을 고친 `fix:`·`revert` 커밋이 나옴, 또는 `미충족`이었는데 사람이 아무것도 고치지 않고 머지함. 켜면 `block-dangerous-bash`의 `gh pr merge` ask를 같이 푼다 |
| 헤드리스 러너 worktree 격리 (강의 Contain 층) | 헤드리스 `run`이 step 범위 밖 파일을 바꾼 사례 **3건** (`git diff --stat`에 step 파일의 「작업」에 없는 경로) |
| 운영 DB 가드 — Bash 밖 경로(MCP DB 도구·docker compose·설정 파일 Edit) | 이 경로로 운영 DB 에 붙은 사례 **1건** — 사고 1번이 곧 조건이다 |
| 차단·허용 audit log (강의 Detect 층) | 차단된 명령을 사람이 "왜 막혔지"로 다시 찾은 일 **3회** (`task-observer`·재지시) |
| 러너 step을 1회 → 2회 호출(TDD 도구 test-writer → feature-builder)로 되돌리기 | 러너로 통과한 `tdd: true` step에서 머지 뒤 `fix:` 커밋이 나온 사례 **3건** — `fix:` 커밋이 고친 파일이 그 step의 `feat: step N` 커밋 파일과 겹치면 센다 — 같은 머리가 테스트와 구현을 다 써서 테스트가 구현에 맞춰진 신호. 사용량 차이는 step `usage`로 잰다 |

> ⚠️ `evals/` 행과 **품질 골든셋** 행은 이름이 비슷하지만 **다른 물건**이다 — `evals/`는 *스킬이 불리나*(트리거 회귀), 골든셋은 *산출물이 좋아졌나*(품질 점수). 한쪽을 깔았다고 다른 쪽이 덮이지 않는다.
>
> **"3번부터."** 두 번까지는 우연이고 세 번째가 패턴이다.
>
> 세는 주체가 `task-observer`인 행은 `.claude/observations.md`의 `횟수` 칸이 근거다. **기억이 아니라 파일을 읽어서 센다.**
