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

0.10.0: 스킬 27 + 4 — ⚠️ claude plugin details로 재측정 필요

## 4. RED → GREEN

- `test-writer`는 **구현 파일을 열지 않고** PRD 수용 조건에서 실패 테스트를 만든다. `verify.test`가 **실패해야** 통과다 — 처음부터 초록이면 잡는 것이 없다는 뜻이다.
- `feature-builder`는 테스트 파일을 고치지 않는다. `verify` 전체 통과 **AND** diff에 테스트 파일 없음.
- 모든 step에 테스트가 붙지는 않는다. `harness`가 step마다 `tdd: true|false`를 판정하고 `false`면 이유를 적는다.
- 모델 배정: 탐색·판정 에이전트(`test-writer`·`code-reviewer`·`root-cause-debugger`)는 상위 모델, `feature-builder`는 정해진 것을 만드는 일이라 기본 모델. 올리는 근거는 느낌이 아니라 `retries` 기록이다(`BACKLOG.md`).

## 5. 계획 게이트는 하나

`why-plan`(2026-10-11 `grilling`+`why-logictree` 합침) — PRD가 없으면 인터뷰로 PRD를 만들고(WHY → 목표·진짜 문제·최적 행동 → 갈래별 한 질문 → So What·Why So), step 승인 직전 빈칸이 많으면 다시 캐묻는다. 사실은 찾고 결정은 묻는다.

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
- 활발한 레포만(0.16.0, 2026-10-12): `hooks/lib/active-repo.sh`(최근 14일 커밋 20건·활동일 3일) 신설. readiness 채점은 7일·커밋 20건 → 2주·활발한 레포만. `brain-sync-auto.sh` 신설 — opt-in(`CLAUDE_BRAIN_SYNC_AUTO=1`, `_SKIP`으로 레포 제외)일 때 활발한 레포에서 `_brain/wiki` 변경이 있으면 `brain-sync auto`를 헤드리스로 띄운다. auto 모드는 확인 없이 쓰되 민감 정보 거부 · 덮어쓰기 금지(겹치면 「충돌」) · vault 로컬 커밋까지(push 없음). 옛 경로(구 vault 위치·옛 폴더 구조)를 가리키는 brainSync 설정은 건너뛴다. 근거: `claude -p`가 구독으로 도는 것을 확인(10-12 launchd 실측). 결정 주체: 사람(2주·무승인·활발한 레포만), AI 추천 수용(기준값 20건·3일, opt-in)
- 로그 자리(0.16.1, 2026-10-12): brain-sync-auto 로그를 `$TMPDIR` → `/tmp` 고정(다른 자동화 로그와 같은 자리, 안내와 실제가 달랐다). 테스트는 `CLAUDE_BRAIN_SYNC_LOG_DIR`로 임시 폴더에 쓴다(실제 로그 폴더에 7개를 남겼다). 첫 실가동: distribution-dashboard 세션 시작 → 이관 1 · 뺀 것 5 · 충돌 1, 72초
- SDD 강의 대조(0.17.0, 2026-10-13): GitBook AI Native(바이브 코딩 실전 테크닉 13 · Harness Engineering 8)와 harness_framework 원문을 대조해 고쳤다. ① `harness-run`의 "claude -p 없이(API 과금 없음)" 문구 — `claude -p`도 구독으로 돈다(위 0.16.0 실측). 서브에이전트를 쓰는 이유는 컨텍스트 격리 ② `harness` §3에 강의 PLAN 원칙 셋(한 step 한 레이어·외부 참조 금지·멱등성·보안·무결성 명시) ③ `harness-run`이 `pending`으로 끝난 step을 error로 다룬다(execute.py의 "Step did not update status"와 같다) ④ 상위 `phases/index.json`은 만들지 않고 phase별 `after`·`docs` + `phases_status.py`(현황·`--check`) — 강의는 PRD 하나를 번호 마일스톤으로 자르는 구조라 상위 파일이 로드맵이고, execute.py는 그 파일을 쓰기만 한다. 우리는 기능별 phase라 상태를 두 곳에 적으면 어긋난다(실측: 한 레포 phase 22개 중 7개 `done`) ⑤ `block-dangerous-bash`에 `guard.prodDb` — 운영 DB만, 이름이 아니라 호스트·프로필로(stage 프로필이 운영 DB를 가리킨 레포), 조회 허용 ⑥ `loop-lock` 판단 단위를 명령 + 코드 상태로 — PostToolUse는 성공한 호출에만 도는 것으로 보여(문서 예시) 실패를 셀 수 없고, 코드가 그대로인 재실행만 의미 없는 반복이다 ⑦ `pr-write` 4.6 심각도 게이트 + Risk Score AND 자동 머지 판정, dry-run(PR 10건 오판 0이면 켜는 결정을 따로). 결정 주체: 사람(운영 DB만·조회 허용·프로필도 차단 · 두 게이트 병합 · loop-lock 기준 · after 방식 채택), AI 추천 수용(dry-run 먼저 · 3번째 차단)
