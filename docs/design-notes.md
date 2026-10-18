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
- 모든 step에 테스트가 붙지는 않는다. `harness`가 step마다 `tdd: true|false`를 판정하고 `false`면 이유를 적는다.
- 모델 배정: 탐색·판정 에이전트(`test-writer`·`code-reviewer`·`root-cause-debugger`)는 상위 모델, `feature-builder`는 정해진 것을 만드는 일이라 기본 모델. 올리는 근거는 느낌이 아니라 `retries` 기록이다(`BACKLOG.md`).

## 5. 계획은 한 단계, 게이트는 둘

① 계획 = DESIGN → PLAN 한 단계, 게이트 둘(0.22.0, 2026-10-16). DESIGN 절차(인터뷰 → 세 장 → Readiness)는 `skills/sdd/references/design.md`로 sdd에 내장했다 — 별도 스킬(`why-plan`, 2026-10-11 `grilling`+`why-logictree` 합침)은 30일 sdd 세션 8건 중 호출 0이었고 sdd가 PRD를 인라인으로 썼다. 호출 한 단계를 없애고 절차를 sdd가 직접 읽는다. 범용 부분(WHY·3질문·로직트리·So What/Why So·질문 규칙 정본)은 `why` 스킬로 — 파일을 쓰지 않고 이유·근거만 본다. step 승인 직전의 빈칸은 `harness` §2가 같은 질문 규칙으로 그 자리에서 캐묻는다(옛 재호출 경로는 실사용 0건이었고, DESIGN이 PLAN 산출물을 고치는 교차를 만들었다). DESIGN·PLAN을 **스킬 하나로 합치지 않은** 근거: `harness` 단독 호출(30일 37회 vs DESIGN 2회 — PRD가 있는 기능에 step만 추가하는 경우가 대부분) · 게이트가 묻는 것이 다름(Readiness "무엇을 왜가 굳었나" / step 승인 "어떻게 쪼갰나", 디자인 트랙 브리프→시안 승인이 그 사이) · 한 텍스트에 인터뷰와 분해가 같이 있으면 모델이 분해로 서두른다(sdd 인라인 PRD가 그 증거). 결정 주체: 사람(단계는 묶고 스킬·게이트는 둘 · why 분리).

## 6. 3회 규칙

두 번까지는 우연, 세 번째가 패턴이다. 같은 지시·같은 교정·안 불린 스킬을 `task-observer`가 세고, 3회에 닿은 것만 rules 한 줄 → 스킬 순으로 승격한다. 승격 조건은 **셀 수 있어야** 한다(`BACKLOG.md`).

## 7. 코드 뼈대와 AI 환경을 나눈다

- AI 환경(규칙·훅·검증 명령·CI 게이트)의 정본은 이 플러그인의 **스택 팩**(`templates/stacks/`).
- 코드 뼈대는 별도 공개 레포 [`jtwjs/stack-kits`](https://github.com/jtwjs/stack-kits) — kit마다 CI로 스스로 초록이어야 한다. 플러그인 캐시 안의 템플릿은 빌드·의존성 갱신을 검증할 수 없어서다.
- 둘은 `project-new`가 잇는다. kit에는 `.claude/`를 넣지 않는다 — 정본이 둘이면 버전이 어긋난다.
- 팩 규칙은 kit에서 **실측한 것**으로 쓴다(예: springdoc 3.x는 Kotlin non-null을 `required`로 옮기지 않는다).

## 8. 플러그인을 나누는 기준

BE/FE 전용 플러그인을 따로 두지 않는다. 절차 스킬은 스택과 무관하게 공통이고 템플릿은 상시 비용이 0이다. 나누는 신호는 **다른 사람이 설치하겠다고 할 때**이고, 그때 팩이 디렉터리 단위라 `git mv` 한 번이면 된다.

## 9. 변경 이력: 2026-10-11 정리 (0.10.7 → 0.13.0)

세션 로그 30일 호출 수와 인터뷰로 정리했다. README에서 옮겨 왔다.

- 합침: `grilling` + `why-logictree` → `why-plan`
- 삭제: `brain-intake`(30일 0회, raw는 통합 wiki에 던진다), 하네스판 `find-skills`(전역 find-skills와 이름 충돌)
- 이름 변경: `harness-new` → `project-new`
- incubator: 비어 있음 (`brain-recall`은 2026-10-12 삭제 — 전역 CLAUDE.md가 대신)
- 신설: `_learn`, readiness 자동 채점, 상태줄 권고
- 설계 3장: `why-plan`이 PRD·ARCHITECTURE·ADR을 쓴다(ARCHITECTURE를 쓰는 스킬이 없던 빈칸을 메움). `_brain`은 REFLECT에서 세 장을 보고 정리한다
- 도구화: `task-observer`가 「반복 절차」도 세어 `scripts/`로 승격을 제안한다. 첫 사례 `scripts/release.sh`
- 질문 순서: 종류(제품·기술) 대신 "팀장이 왜냐고 물으면 내가 답해야 하나?"로 가른다. 예면 사용자 생각 먼저, 사소한 것만 추천 먼저. PRD 결정 절에도 결정 주체 칸
- 업그레이드 모드(0.13.0): 레포마다 복사된 템플릿 사본이 낡아도 고칠 장치가 없었다. `harness-init`을 다시 부르면 이름표·라우팅·`_brain/CLAUDE.md`·버전만 맞춘다
- 이해 게이트(0.14.0, 2026-10-12): `sdd` IMPLEMENT 끝에 🙋빈틈 3곳(모를 지점 3 → 고른 것만 12살 설명 → 내 말 한 줄), `pr-write` 4.9단계에 퀴즈 5(3 이하면 draft). 전엔 PR을 만든 뒤 explain-diff를 한 줄 제안했고 실사용 0회였다
- sdd 합류(0.14.1): `why-plan`이 sdd 밖에서 불려 구현 산출물이면 "sdd로 이어갈까요? (PLAN부터)"를 묻는다. 전엔 문서 저장 후 멈춰 사람이 sdd를 따로 불러야 했다
- 시안 평가(0.15.0, 2026-10-12): 디자인 트랙에 `design-critique` 신설, `design-brief`에 레퍼런스 먼저 · 닐슨 렌즈 · 제작 체크리스트 · 레포 캔버스. 근거는 2026-10 두 레포(bv-admin · distribution-dashboard)의 시안 작업 — 시안 제작·리뷰(체크포인트·페르소나 리뷰·A/B·as-is/to-be)가 매번 하네스 밖에서 즉흥으로 돌았고, 렌더 미확인 발행 · 브리프 뒤 톤 교체 · 업로드 누락 · 글로만 된 변경 목록이 반복됐다. 제작은 스킬로 두지 않고 체크리스트로(한 줄로 끝나는 규칙을 스킬로 만들지 않는다, §3). 캔버스는 레포당 하나(`현행`·`작업`·DS·컴포넌트 탭), 소스는 `.claude/design/canvas/`에 커밋하는 게 정본 — `DesignSync`는 `/design-sync` 전용이라 시안 읽기에서 뺐다. 레퍼런스 캡처는 커밋하지 않는다. 닐슨 10원칙은 외부 스킬 3개(ux-heuristics · heuristic-evaluation · design-critique)를 설치하지 않고 `design-critique/references/`로 흡수했다. 결정 주체: 사람(스킬 모양 · 레포당 캔버스 · 레퍼런스 로컬), AI 추천 수용(현행/작업 탭 구조)
- 퀴즈 해설(0.15.2, 2026-10-12): `pr-write` 4.9단계 채점 뒤 맞힌 문항도 정답 이유 한 줄. 전엔 3 이하일 때 틀린 문항만 설명했다(Finn 요청)
- critique 보강(0.15.1, 2026-10-12): distribution-dashboard /oncall 7보드 테스트 1회차(평가자 5 · 약 100초 · 서브에이전트 약 31만 토큰 · 🔴7 🟡10 🟢8)에서 둘을 고쳤다 — ① 입력 기준일 확인(낡은 사본 평가로 이미 고친 값이 발견으로 나옴) ② DS가 있으면 디자이너 + 레퍼런스 실측을 합침(발견 겹침)
- 활발한 레포만(0.16.0, 2026-10-12): `hooks/lib/active-repo.sh`(최근 14일 커밋 20건·활동일 3일) 신설. readiness 채점은 7일·커밋 20건 → 2주·활발한 레포만. `brain-sync-auto.sh` 신설 — opt-in(`CLAUDE_BRAIN_SYNC_AUTO=1`, `_SKIP`으로 레포 제외)일 때 활발한 레포에서 `_brain/wiki` 변경이 있으면 `brain-sync auto`를 헤드리스로 띄운다. auto 모드는 확인 없이 쓰되 민감 정보 거부 · 덮어쓰기 금지(겹치면 「충돌」) · vault 로컬 커밋까지(push 없음). 옛 경로(구 vault 위치·옛 폴더 구조)를 가리키는 brainSync 설정은 건너뛴다. 근거: `claude -p`가 구독으로 도는 것을 확인(10-12 launchd 실측. 단 환경에 `ANTHROPIC_API_KEY`가 있으면 `-p`는 항상 그 키로 API 과금 — 공식 문서, 0.18.1에서 확인). 결정 주체: 사람(2주·무승인·활발한 레포만), AI 추천 수용(기준값 20건·3일, opt-in)
- 로그 자리(0.16.1, 2026-10-12): brain-sync-auto 로그를 `$TMPDIR` → `/tmp` 고정(다른 자동화 로그와 같은 자리, 안내와 실제가 달랐다). 테스트는 `CLAUDE_BRAIN_SYNC_LOG_DIR`로 임시 폴더에 쓴다(실제 로그 폴더에 7개를 남겼다). 첫 실가동: distribution-dashboard 세션 시작 → 이관 1 · 뺀 것 5 · 충돌 1, 72초
- SDD 강의 대조(0.17.0, 2026-10-13): GitBook AI Native(바이브 코딩 실전 테크닉 13 · Harness Engineering 8)와 harness_framework 원문을 대조해 고쳤다. ① `harness-run`의 "claude -p 없이(API 과금 없음)" 문구 — `claude -p`도 구독으로 돈다(위 0.16.0 실측). 서브에이전트를 쓰는 이유는 컨텍스트 격리 ② `harness` §3에 강의 PLAN 원칙 셋(한 step 한 레이어·외부 참조 금지·멱등성·보안·무결성 명시) ③ `harness-run`이 `pending`으로 끝난 step을 error로 다룬다(execute.py의 "Step did not update status"와 같다) ④ 상위 `phases/index.json`은 만들지 않고 phase별 `after`·`docs` + `phases_status.py`(현황·`--check`) — 강의는 PRD 하나를 번호 마일스톤으로 자르는 구조라 상위 파일이 로드맵이고, execute.py는 그 파일을 쓰기만 한다. 우리는 기능별 phase라 상태를 두 곳에 적으면 어긋난다(실측: 한 레포 phase 22개 중 7개 `done`) ⑤ `block-dangerous-bash`에 `guard.prodDb` — 운영 DB만, 이름이 아니라 호스트·프로필로(stage 프로필이 운영 DB를 가리킨 레포), 조회 허용 ⑥ `loop-lock` 판단 단위를 명령 + 코드 상태로 — PostToolUse는 성공한 호출에만 도는 것으로 보여(문서 예시) 실패를 셀 수 없고, 코드가 그대로인 재실행만 의미 없는 반복이다 ⑦ `pr-write` 4.6 심각도 게이트 + Risk Score AND 자동 머지 판정, dry-run(PR 10건 오판 0이면 켜는 결정을 따로). 결정 주체: 사람(운영 DB만·조회 허용·프로필도 차단 · 두 게이트 병합 · loop-lock 기준 · after 방식 채택), AI 추천 수용(dry-run 먼저 · 3번째 차단)
- 운영 DB 판별을 위치 참조로(0.17.1, 2026-10-13): 0.17.0은 `harness.json`에 호스트 값을 적게 했는데, 운영 호스트 값은 레포 밖·문서로 옮기지 않는다는 규칙과 부딪혔다. 이제 `from`에 위치만 적고(`spring:<프로필>` · `env:<파일>:<키>`) `hooks/lib/prod_db.py`가 실행 때 디스크에서 읽는다. yml의 `${VAR}`는 레포 `.env*`에서 풀고, 같은 호스트를 가리키는 Spring 프로필은 자동으로 운영 취급, 명령에 그 값을 담은 변수 이름(`$PROD_CPM_DB_HOST`)이 나와도 운영으로 본다. Node는 `switches`. 못 읽으면 `prod-db-check`(SessionStart)가 '꺼짐'을 알린다(값은 출력 안 함). 실측: vcm `spring:prod` → 호스트 1·자동 운영 프로필 prod·stage, contents-sqs-ts `env:.env:PROD_CPM_DB_HOST` → 호스트 1, distribution-dashboard는 운영 주소가 배포 env로만 들어가 디스크에 없음(적용 대상 아님). 결정 주체: 사람(위치 참조 방식 · Spring·Node 둘 다), AI 추천 수용(세션 시작 알림·변수 이름 매칭)
- SDD 러너(0.18.0, 2026-10-13): `skills/harness-run/scripts/sdd_runner.py` — step당 호출 1번(테스트 먼저 → 구현) + 러너가 git 기록으로 판정(RED 커밋 순서 · RED 시점 재실행이 실패해야 · 테스트 파일 무변경 · 변경 유무 · verify). 세션 안 `harness-run`은 `start`·`prompt`·`judge`를, 헤드리스는 `run`을 부른다 — 규칙 정본 하나. test-writer → feature-builder 2단계는 러너에서 빼고 TDD 도구로(강의가 TDD와 SDD 러너를 따로 둔 것을 따름). 강의 execute.py에서 시간 기록·원문 로그·타임아웃·재시도 에러 문장을, 우리에서 tdd-guard·좁은 가드레일·retries·after를 가져왔다. 근거·판정 표·루프 그림은 `docs/sdd-runner.md`. 결정 주체: 사람(위치·언어·같은 규칙·TDD 분리·좋은 점 섞기), AI 추천 수용(1회 + 사후 검사·가짜 claude 테스트)
- 이슈 둘(0.22.1, 2026-10-16): #8 `kind: "measure"` — 측정·실측·대조 전용 step은 변경 0이 정상이라 러너 판정 5가 변경 대신 `summary`의 백틱 명령 + 결과를 본다(없으면 실패, 통과 시 verify 생략, `tdd: true`와 같이 쓰면 start가 거부). `harness`가 분해할 때 표시한다. 전엔 수동 completed 처리로 우회했다(10-14 실측 1건). #6 E2E 구조·이름 관례(specs·pom·fixtures·setup · Feature/Scenario 제목 · fixtures에서만 import · `provide` · 전용 포트)를 react-vite·nextjs `rules/e2e.md`에 — 리뷰 앱 #19·PR #50에서 먼저 돌린 뒤 문구 확정. 결정 주체: 사람(이슈 둘 다 jtwjs 작성), AI 추천 수용(summary 백틱 판정 · verify 생략)
- 워크플로우 리뷰(0.22.0, 2026-10-15~16): 30일 레포 세션 Skill 호출 집계(wiki 제외)로 sdd 5단계를 대조했다 — 전형 순서는 `sdd > harness > harness-run > sdd-review > revise-claude-md > pr-write`. ① DESIGN: `why-plan` 2회, sdd 세션 8건 중 0회·4건은 sdd가 PRD를 인라인으로 씀 → `why-plan`을 sdd에 내장(`references/design.md`) + 범용 `why` 스킬 신설 ② "step 승인 직전 재호출" 0회 → 삭제, `harness` §2가 같은 질문 규칙으로 캐묻기 ③ REFLECT: `_brain` 정리 0/8·brain-sync 2·changeset 4·pr-write 125 — wiki가 회고의 핵심이라 적은 「막힌 지점 → 남긴 자산」 한 장이 sdd에 아예 없었다(record-layers: LEARNED.md 3곳 전부 사망, 남긴 자산이 비면 회고 실패). REFLECT를 넷으로 다시 짰다 — 회고 1장(`_brain/wiki/infra/retro.md` append) → 하네스 되돌림 ≥1(흘린 것 revise-claude-md · 사고 non-obvious-patterns · 반복 task-observer · 더하기만 금지) → 지식 정리(`_brain`·brain-sync) → 이해 증명(리허설). 출구 조건: 회고 있음 · 막힘이 있으면 남긴 자산 ≥1(없으면 안 남긴 이유) · 건너뜀은 이유와 함께 — 못 맞추면 ⑤로 못 간다. 릴리스(changeset→commit→pr-write)는 **⑤ 마무리**로 분리 — 작업이 끝났을 때만, REFLECT 산출물과 같은 PR ④ 옛 이름 `grilling` 33회(10-11 뒤에도 9회+, `Unknown skill` 오류)·레포 사본 17개에 grilling·why-logictree·design-plan 잔존 → 이름표에 `design-plan`(행 삭제)·`why-plan` 추가, 템플릿 라우팅에 디자인 트랙 행, 레포는 `harness-init` 업그레이드로 ⑤ 6축은 README 대조표 한 장만(앞 두 축=레포당 1회, 뒤 네 축=①~④, ⑤는 축 밖) ⑥ technic.md "리뷰는 새 세션에" vs sdd-review 서브에이전트 → sdd-review가 맞다(컨텍스트 격리면 충분). 결정 주체: 사람(워크플로우 기준 리뷰 · 단계는 묶고 스킬은 둘 · why 분리 · ⑤ 분리 · 회고 자리 infra · 출구 조건은 막기 · sdd-review), AI 추천 수용(교차 삭제 · 되돌림 4종 · 더하기만 금지)
- 리뷰 반영(0.18.1, 2026-10-13): GitBook 노트·execute.py 기준 리뷰 3갈래(러너·훅·문서)에서 🔴 7건. ① `judge`가 '첫 pending'을 골라 방금 끝난 step 대신 다음 step을 판정 → `--step N` 필수 ② RED 위반은 같은 BASE에서 못 고침 → 그 시도를 백업 브랜치로 옮기고 BASE로 되돌림 ③ 운영 DB 판별 스크립트가 죽으면 통과(fail-open) → 차단 + 세션 시작 알림 ④ 운영 DB 쓰기 판정을 **허용 목록**으로(SELECT·SHOW·EXPLAIN·DESCRIBE만, 파일·파이프·대화형·잠금 SELECT 차단) ⑤ `loop-lock`을 PostToolUseFailure에도 — 실패 반복을 못 셌다 ⑥ `gh pr merge`를 사람 확인(ask)으로 — dry-run이 문장뿐이었다. 막지 않고 묻는 이유: 사람이 시킨 머지는 그대로 승인하면 된다 ⑦ pyc 커밋 제거. 그 밖에 멈출 때 `wip:` 커밋 · 재개 원인을 지시문에 · 재개 뒤 한도 새로 · 실패 이력 `attempts` · `jdbc-url`·`.env*` 충돌·URL 직접 주입·`SPRING_PROFILES_INCLUDE` · `ANTHROPIC_API_KEY` 경고. 결정 주체: 사람(허용 목록), AI 추천 수용(나머지, 머지는 ask)
- 학습 블록을 기술 중심으로(0.23.0, 2026-10-17): 초급·중급이 "이 diff가 무엇을 바꿨나"만 다뤄 용어 한 줄 정의에서 끝났다. 사용자 인터뷰로 정함 — 초급은 기술 카드 2~3장(키워드 12살 설명 · 원래 맥락 · 여기선 왜 · 안 쓰면 · 조심할 것 · 흐름 그림) + 끝에 정답 공개 빈칸 1(채점 없음), 이미 `_learn`에 같은 기술 카드가 있으면 여기선 왜 · 조심할 것만. 중급은 큰 흐름 2 + 적용 1. 고급·도메인 블록은 그대로. 정본 `docs/learning-level.md` §3, 가리키는 곳 4곳(pr-write 4.9 · sdd 빈틈 3곳·리허설 · explain-diff 둘)과 세션 주입 문구를 같이 고쳤다. 길이는 카드 8줄·블록 25줄 상한, 실사용 길이는 미측정
- 빈틈 3곳 한 줄 요약(0.23.3, 2026-10-18): 지점 분야가 초급·중급이면 '내 말 한 줄'을 사람이 쓰지 않고 AI가 `N: 무엇을 왜 — 없으면 생기는 일` 형식으로 써서 바로 `_learn`에 쌓는다. 사람은 고치거나 `?`만(→ 막힌 질문 카드). 사용자 결정 — 대가는 '내 말로 다시 말하기'가 되새김으로 약해지는 것. 기술 카드 빈칸 · 중급 객관식은 그대로
- deadhd 아이디어 흡수(0.24.0, 2026-10-18): 동료가 공유한 lcalmsky/deadhd(세션 진행 관제, MIT)를 깔지 않고 아이디어만 가져왔다. 원본은 `/deadhd`를 켠 세션만 추적하고 모델이 체크리스트를 따로 써서 하네스 phases와 이중 기록이 된다. 승인 대기·세션 목록은 Orca IDE가 이미 준다. 그래서 하네스 데이터만 읽는 스크립트 셋 — ① `phases_status.py --retro`: step별 결과·재시도·소요(자기 started→completed, 겹친 실행 실례 있음) + 합계 줄을 sdd 회고 `- 숫자:` 칸에 ② `conductor/scripts/tracks_status.py`: worktree × 진행·마지막 신호(💤 30분)·⛔·후속 이슈, 트랙은 브랜치로 매칭 ③ `scripts/daily-hub/daily_hub.py`: 하루 마감 정적 HTML(세션·프로젝트·배운 것·막힌 것, 모델 토큰 0·서버 없음). 스킬 md는 두지 않았다(상시 로드 약 170토큰) — evening 루틴과 dotfiles 래퍼 `~/.claude/bin/daily-hub`가 부른다. 상태줄 조각(진행 + 마지막 요청)은 dotfiles. 뺀 것: 밴드 mod(화면 API 결합)·로컬 서버·ETA 보정·모델 체크리스트. 역할 구분: 마감 페이지는 `_learn`을 보기만 하고 vault 이관은 `/gauge week`, evening은 한 줄 요약만. 성공 기준: 마감 페이지 14일 중 연 날 7일 이상(opened.log), 3일 미만이면 접음 · 다음 sdd 회고 3건 모두 숫자 줄 · 상태줄 도입 30일 뒤 "어디까지·진행 상황"류 질문 세션 15/262(10-18 비포, 30일·typed) → 절반 이하. 결정 주체: 사람(흡수 방향·마감 페이지 역할 분담·범위 다섯 절·18:10+재생성), AI 추천 수용(밴드 제외·스킬 대신 스크립트·리뷰 2갈래 반영)
- 비유 대신 실제 사례(0.23.4, 2026-10-18): 빈틈 3곳의 12살 설명과 beginner 기술 카드에서 "React/TS 비유 하나"를 뺐다. 모든 개념에 React/TS 비유가 맞는지 의문이고, 0.23.3 한 줄 요약 예시(실제 코드 이름 + 없거나 다르게 했으면 생기는 일)가 가장 이해하기 쉬웠다는 사용자 판단. 비유는 사람이 원할 때만. 같은 원칙을 개인 output style finn-brief(dotfiles)에도 넣었다. 결정 주체: 사람
- 공유본에서 12살 설명 금지(0.24.1, 2026-10-18): 유통 대시보드 협업에서 12살 이해법 설명을 붙인 설계·요청 문서에 팀원이 "이해할 수 없다"고 피드백했다. 12살 설명은 쓰는 사람을 이해시키는 도구라, 좁은 맥락에서 읽는 팀원에게는 해독 단계가 하나 늘어난다는 사용자 판단. notion-writing 「지우는 것」 표와 slack-writing 「전 유형 금지」에 한 줄씩. 학습 블록·빈틈 3곳의 12살 설명(본인 학습용)은 그대로. vault 정본 shared-doc-format 같은 날 갱신. 결정 주체: 사람
- 낡은 문서 정리(0.23.1, 2026-10-17): 흐름 개편(0.18.0 러너 · 0.22.0 ① 계획·⑤ 마무리 · 0.23.0 학습 블록) 뒤 따라 바뀌지 않은 문장을 전수 점검했다(경로 참조·스킬 이름·개수는 기계 대조, 의미는 서브에이전트 2갈래 + 직접 재확인). 고친 것: harness-run 절 번호(§5→§4, 끊긴 §4 참조 2곳) · REVIEW 수정 경로를 sdd 기준(수정 step → harness-run, 작은 수정만 feature-builder)으로 4곳 통일 · sdd-review 커밋 순서 위치(⑤ 마무리) · explain-diff 설명 줄 · 템플릿 revise-claude-md 시점 · PR 템플릿·pr-write 본문에 회고 칸 · 상대 경로 · Stop 훅을 "응답 끝"으로 · BACKLOG 셀 수 없게 된 조건 · 로드 예산 0.23.0 실측 한 줄
