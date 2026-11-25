# 설계 노트

이 플러그인이 왜 이렇게 생겼는지의 결론만 적는다. 긴 설계 로그(실측·판정 이력)는 레포 밖에 둔다.

## 1. 추측으로 채우지 않는다

- `harness-init`은 명령을 **실제로 돌려서 통과한 것만** `harness.json.verify`에 적는다. 실패한 후보는 뺀다. 이 하네스의 유일한 실패 모드는 "돌지 않는 명령을 적는 것"이다.
- 빈칸은 비워 두지 않고 **이름으로 남긴다** — `ci.test: "deferred"`, `tdd.enabled: false`, `release.tool: null`. 비었다는 사실을 말하지 않으면 조용히 죽는다.
- 스택은 빌드 파일로만 판정한다. 없으면 묻는다.

## 2. 컨텍스트 3층

| 층 | 로드 | 크기 |
|---|---|---|
| `CLAUDE.md` | 매 세션 | ~40줄. CRITICAL + 링크만 |
| `.claude/rules/*.md` | 그 파일을 열 때만(`paths:` 필수) | 파일당 ≈10KB 이하 |
| `.claude/references/*.md` | rules의 트리거로 직접 열 때만 | 길어도 된다(평소 0) |

판정 한 줄: **"이걸 안 읽고 코드를 쓰면 규칙을 어기게 되나?"** → 예면 `rules/`, 아니오면 `references/`. 폴더별 하위 `CLAUDE.md` 대신 `paths:` glob을 쓴다(코드가 import하지 않는 폴더 — 예: `_brain/` — 만 예외).

## 3. 로드 예산

- `paths:` 없는 rules 합계 ≈10KB · 개별 rules 파일 ≈10KB — `harness-doctor` 검사 5가 잰다. `paths:`는 빈도를 줄이지 크기를 줄이지 않는다.
- 플러그인 상시 비용은 **컴포넌트(스킬·에이전트)당 ≤180토큰**. 상시 비용을 키우는 것은 본문이 아니라 **`description` 길이뿐**이다. 스킬 하나는 공짜가 아니다 — 한 줄로 끝나는 규칙을 스킬로 만들지 않는다.
- 스킬을 늘리거나 줄인 릴리스마다 `claude plugin details`로 재서 아래 표에 한 줄 남긴다.

| 버전 | 스킬 + 에이전트 | 상시(토큰) | 컴포넌트당 |
|---|---|---|---|
| 0.5.0 | 25 + 4 | 4,839 | 166.9 |
| 0.6.0 | 26 + 4 | 5,074 | 169.1 |
| 0.7.0 | 27 + 4 | 5,221 | 168.4 |
| 0.8.0 | 27 + 4 | 5,120 | 165.2 |
| 0.9.0 | 26 + 4 | 3,994 | 133.1 |
| 0.23.0 | 25 + 4 | 4,748 | 163.7 |

0.10.0~0.22.1은 재지 않았다(재기 시작 2026-10-17). 0.23.0에서 컴포넌트당 180토큰을 넘는 것: `plannotator-visual-explainer` ~290 · `harness-init` ~250 · `explain-diff-html` ~230 · `harness-run` ~220 · `sdd`·`test-writer` ~210 — `description` 다듬기 후보

## 4. RED → GREEN

- SDD의 RED/GREEN 판정은 `sdd_runner.py judge`가 git 기록으로 한다(0.18.0~) — 테스트만 담긴 커밋이 먼저 · RED 시점 재실행이 **실패해야** · RED 뒤 테스트 파일 무변경 · verify 통과. 처음부터 초록이면 잡는 것이 없다는 뜻이다. 정본 `docs/sdd-runner.md`
- `test-writer`(구현 파일을 열지 않고 실패 테스트)·`feature-builder`(테스트 파일을 고치지 않고 통과)는 러너가 부르지 않는 수동 TDD 도구다. 사람이 엄격한 분리를 원할 때와 REVIEW의 작은 수정에 쓴다.
- 모든 step에 테스트가 붙지는 않는다. `sdd-plan`이 step마다 `tdd: true|false`를 판정하고 `false`면 이유를 적는다.
- 모델 배정: 탐색·판정 에이전트(`test-writer`·`code-reviewer`·`root-cause-debugger`)는 상위 모델, `feature-builder`는 정해진 것을 만드는 일이라 기본 모델. 올리는 근거는 느낌이 아니라 `retries` 기록이다(`BACKLOG.md`).

## 5. 계획은 한 단계, 게이트는 둘

① 계획 = DESIGN → PLAN 한 단계, 게이트 둘(0.22.0, 2026-10-16). DESIGN 절차(인터뷰 → 세 장 → Readiness)는 `skills/sdd/references/design.md`로 sdd에 내장했다 — 별도 스킬(`why-plan`, 2026-10-11 `grilling`+`why-logictree` 합침)은 30일 sdd 세션 8건 중 호출 0이었고 sdd가 PRD를 인라인으로 썼다. 호출 한 단계를 없애고 절차를 sdd가 직접 읽는다. 범용 부분(WHY·3질문·로직트리·So What/Why So·질문 규칙 정본)은 `why` 스킬로 — 파일을 쓰지 않고 이유·근거만 본다. step 승인 직전의 빈칸은 `sdd-plan` §2가 같은 질문 규칙으로 그 자리에서 캐묻는다(옛 재호출 경로는 실사용 0건이었고, DESIGN이 PLAN 산출물을 고치는 교차를 만들었다). DESIGN·PLAN을 **스킬 하나로 합치지 않은** 근거: `sdd-plan` 단독 호출(30일 37회 vs DESIGN 2회 — PRD가 있는 기능에 step만 추가하는 경우가 대부분) · 게이트가 묻는 것이 다름(Readiness "무엇을 왜가 굳었나" / step 승인 "어떻게 쪼갰나", 디자인 트랙 브리프→시안 승인이 그 사이) · 한 텍스트에 인터뷰와 분해가 같이 있으면 모델이 분해로 서두른다(sdd 인라인 PRD가 그 증거). 결정 주체: 사람(단계는 묶고 스킬·게이트는 둘 · why 분리).

## 6. 3회 규칙

두 번까지는 우연, 세 번째가 패턴이다. 같은 지시·같은 교정·안 불린 스킬을 `harness-gaps`가 세고, 3회에 닿은 것만 rules 한 줄 → 스킬 순으로 승격한다. 승격 조건은 **셀 수 있어야** 한다(`BACKLOG.md`).

## 7. 코드 뼈대와 AI 환경을 나눈다

- AI 환경(규칙·훅·검증 명령·CI 게이트)의 정본은 이 플러그인의 **스택 팩**(`templates/stacks/`).
- 코드 뼈대는 별도 공개 레포 [`jtwjs/stack-kits`](https://github.com/jtwjs/stack-kits) — kit마다 CI로 스스로 초록이어야 한다. 플러그인 캐시 안의 템플릿은 빌드·의존성 갱신을 검증할 수 없어서다.
- 둘은 `project-new`가 잇는다. kit에는 `.claude/`를 넣지 않는다 — 정본이 둘이면 버전이 어긋난다.
- 팩 규칙은 kit에서 **실측한 것**으로 쓴다(예: springdoc 3.x는 Kotlin non-null을 `required`로 옮기지 않는다).

## 8. 플러그인을 나누는 기준

BE/FE 전용 플러그인을 따로 두지 않는다. 절차 스킬은 스택과 무관하게 공통이고 템플릿은 상시 비용이 0이다. 나누는 신호는 **다른 사람이 설치하겠다고 할 때**이고, 그때 팩이 디렉터리 단위라 `git mv` 한 번이면 된다.

## 9. 변경 이력

`docs/changes/`
