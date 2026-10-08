---
name: harness-run
description: SDD IMPLEMENT 러너 — phases/{task}/의 pending step을 순회하며 step마다 test-writer(RED) → feature-builder(GREEN) 서브에이전트를 띄워 구현·검증하고, index.json 재읽기로 상태를 판정해 커밋/재시도/중단한다. Use when harness 스킬로 만든 계획을 실제로 구현할 때. claude -p 없이 세션 내 서브에이전트로만 동작(API 과금 없음).
disable-model-invocation: false
---

`harness_framework`의 `execute.py` 루프를 **세션 내 스킬**로 이식한 것. 핵심: **메인 세션은 오케스트레이션 + index.json 읽기(값싼 작업)만** 하고, **실제 step 작업은 `test-writer`(RED)·`feature-builder`(GREEN) 서브에이전트**가 처리한다 → step 컨텍스트가 메인에서 격리되고 구독으로 실행(`claude -p`/API 미사용).

## 0. 입력

- `task` slug(= `phases/{task}/` 존재). 없으면 사용자에게 확인.
- 설계문서 경로는 **`phases/{task}/index.json`의 `docs`** 에서 읽는다(`harness`가 채운다). 없으면 묻는다 — `docs/` 아래를 뒤져 추측하지 않는다.

## 1. 브랜치 (a)

- `feat-{task}` 브랜치를 checkout(없으면 생성). 위험 명령 금지, hook 우회 금지.

## 2. 가드레일 로드 (b) — 이 파일들만

- 루트 `CLAUDE.md` + `{index.json.docs}/{PRD,ARCHITECTURE,ADR}.md`. (그 외 docs 미열람.)
- 이 텍스트를 **preamble 재료**로 보관.

## 3. 루프 (c) — `index.json`의 pending step을 번호순으로

각 step:

1. **preamble 구성**(서브에이전트에 넘길 컨텍스트):
   - 가드레일(위 2)
   - **완료 step 요약**: index.json의 각 completed step `summary`(누적 문맥)
   - **재시도라면** 직전 `error_message`(무엇이 왜 실패했는지)
   - 대상 `phases/{task}/stepN.md` 전문
   - **병렬 트랙이면** — 레포에 `conductor` 라벨이 있으면(`gh label list --search conductor`) 열린 `conductor` + 이 phase 트랙의 `track:` 라벨 이슈를 **한 번** 조회해 목록(번호·제목)을 넣는다: `gh issue list --label conductor --label "track:<트랙>" --json number,title -q '.[]|"#\(.number) \(.title)"'`. 선행이 열린 이슈에 걸린 step이면 돌리지 않고 `blocked`

2. **서브에이전트 실행 — step의 `tdd` 값에 따라 1단 또는 2단.** step 에 `model` 이 있으면 Agent 도구의 `model` 로 **그 값만** 넘기고, 없으면 넘기지 않는다(에이전트 정의값).

   **2-a. RED — `tdd: true`인 step만.** Agent 도구로 **`test-writer`**를 띄우고 preamble + `{index.json.docs}/PRD.md`의 수용 조건을 전달한다. 지시:
   - 구현 파일을 열지 않고, step의 수용 조건을 **실패하는 테스트**로 쓴다(짝 테스트 위치는 `tdd-guard`가 보는 자리 — TS `*.test.ts(x)`, JVM `src/test/…/FooTest.kt`).
   - 끝나면 메인이 `verify.test`를 **실제 실행**한다. **실패해야 RED 통과.** 전부 통과하면 잡는 게 없다는 뜻이다 → step `error`, `error_message: "RED: 테스트가 아무것도 잡지 않음"`. 2-b로 넘어가지 않는다.
   - `verify.test`가 비어 있으면 RED를 돌 수 없다 → step `blocked`, `blocked_reason: "verify.test 없음 — tdd:true step을 돌릴 수 없다"`.

   **2-b. GREEN — 모든 step.** Agent 도구로 **`feature-builder`**를 띄우고 preamble을 전달한다. 지시:
   - stepN.md의 `읽어야 할 파일`을 먼저 읽고, `작업`을 시그니처대로 구현.
   - `Acceptance Criteria` 쉘 명령을 **실제 실행**해 통과시킨다. 명령은 step 파일에 적힌 것(= `.claude/harness.json`의 `verify`)을 쓴다.
   - TDD: 짝 테스트는 **RED 단계(test-writer) 산출물**이다. `tdd: true`인데 구현 파일에 짝 테스트가 없으면 구현하지 말고 `blocked`, `blocked_reason: "짝 테스트 없음 — RED 미실행"`으로 보고한다. **테스트 파일은 쓰지도 고치지도 않는다**(feature-builder 「테스트 불가침」).
   - 완료 후 **반드시 `phases/{task}/index.json`의 해당 step 상태를 갱신**(completed+summary / error+error_message / blocked+blocked_reason).
   - 메인 세션에는 결과 코드를 재출력하지 말고 짧게 보고.

3. **판정 = index.json 재읽기**(서브에이전트 stdout 아님):
   - `completed` → 메인이 **GREEN 게이트**를 한 번 더 확인한다: `verify` 전체 통과 **AND** `git diff --name-only`에 테스트 파일이 없다(`tdd: true`면 RED가 만든 테스트 파일은 **RED 직후 따로 커밋**해 두므로 여기 섞이지 않는다 — 아래 4). 테스트 파일이 섞였으면 그 변경을 되돌리고 step을 `error`, `error_message: "GREEN: 구현 단계가 테스트 파일을 수정함"`. 통과하면 **커밋(4)** 후 다음 step.
   - `error` → 같은 step 재시도. 재시도할 때 index.json 의 그 step `retries` 를 +1 해서 남긴다 — 모델 승격 판단(`BACKLOG.md` 승격 조건)이 읽는 유일한 계수기다. **`retries`가 3이 되면 루프 중단**(= 첫 시도 + 재시도 3회, 최대 4회 실행. `sdd`·`task-observer`도 같은 문장을 쓴다) 하고 사용자에게 보고. 근본 원인성 실패면 `root-cause-debugger` 에이전트 / `systematic-debugging` 스킬로 전환.
   - `blocked` → 즉시 **중단**, `blocked_reason`을 사용자에게 보고(사람 체크포인트).

## 4. 커밋 — RED 1회(tdd step만) + 코드 + 메타데이터

메시지 형식의 정본은 `commit` 스킬이다. 요약하면 `harness.json`의 `git.commitScope`가 `false`(기본)면 괄호 스코프 없이 **타입만** 쓰고 phase는 **본문**에 넣는다. `true`면 `feat({phase}): step N — {name}`.

0. **RED 커밋** (`tdd: true` step, 2-a 통과 직후)
   - subject: `test: step N — {name} (red)`
   - body: `phase: {task}` + 어떤 수용 조건을 잡는지 1줄. 이 커밋 뒤에 GREEN이 돌아야 3의 "diff에 테스트 파일 없음" 판정이 성립한다.
1. **코드 커밋**
   - subject: `feat: step N — {name}` (구현이 리팩터/수정이면 `refactor:`/`fix:`)
   - body: `phase: {task}` + step 요약 1줄
   - 커밋 전 `.claude/harness.json`의 `verify`를 순서대로 실행한다. **1회만** — 서브에이전트 자체 점검과 중복하지 않는다.
2. **메타데이터 커밋**
   - `phases/{task}/index.json` 변경분: `chore: update phase index for step N` (body: `phase: {task}`).

- `--no-verify` 등 hook 우회 금지. 위험 명령 금지.

## 5. 마무리 (d)

- 모든 step이 `completed`면: 요약 표(step·상태·summary)를 출력하고 **`sdd-review` 스킬**로 검증하도록 안내.
- error/blocked로 멈췄으면: 멈춘 step·사유·재개 방법을 보고.
- **재개 절차** (`sdd` 「재개」와 같은 문장): 원인이 확정되고 사람이 승인하면 **메인이** 그 step을 `error → pending`으로 되돌리고 `error_message`에 근본 원인 한 줄을 남긴 뒤 §3 루프를 다시 돈다. **`retries`는 0으로 되돌리지 않는다** — 승격 판단의 계수기라서다. blocked는 `blocked_reason`이 해소됐을 때만 `pending`으로.

## 비용 메모

- 메인 세션이 하는 일: 브랜치·가드레일·preamble 조립·index.json 읽기·커밋 = 저렴.
- step 구현/테스트/빌드의 무거운 컨텍스트는 전부 `test-writer`·`feature-builder` 서브에이전트 안에서 소비된다. `tdd: true` step은 서브에이전트 호출이 2회라 `tdd: false`보다 비싸다 — 그래서 `harness` §3이 step마다 tdd 여부를 판정하고 false면 사유를 적는다.
