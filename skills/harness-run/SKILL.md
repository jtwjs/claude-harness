---
description: SDD IMPLEMENT 러너 — phases/{task}/의 pending step을 순회하며 step마다 feature-builder 서브에이전트를 띄워 구현·검증하고, index.json 재읽기로 상태를 판정해 커밋/재시도/중단한다. Use when harness 스킬로 만든 계획을 실제로 구현할 때. claude -p 없이 세션 내 서브에이전트로만 동작(API 과금 없음).
disable-model-invocation: false
---

`harness_framework`의 `execute.py` 루프를 **세션 내 스킬**로 이식한 것. 핵심: **메인 세션은 오케스트레이션 + index.json 읽기(값싼 작업)만** 하고, **실제 step 작업은 `feature-builder` Task 서브에이전트**가 처리한다 → step 컨텍스트가 메인에서 격리되고 구독으로 실행(`claude -p`/API 미사용).

## 0. 입력

- `task` slug(= `phases/{task}/` 존재). 없으면 사용자에게 확인.

## 1. 브랜치 (a)

- `feat-{task}` 브랜치를 checkout(없으면 생성). 위험 명령 금지, hook 우회 금지.

## 2. 가드레일 로드 (b) — 이 파일들만

- 루트 `CLAUDE.md` + `docs/{feature-date}/{PRD,ARCHITECTURE,ADR}.md`. (그 외 docs 미열람.)
- 이 텍스트를 **preamble 재료**로 보관.

## 3. 루프 (c) — `index.json`의 pending step을 번호순으로

각 step:

1. **preamble 구성**(서브에이전트에 넘길 컨텍스트):
   - 가드레일(위 2)
   - **완료 step 요약**: index.json의 각 completed step `summary`(누적 문맥)
   - **재시도라면** 직전 `error_message`(무엇이 왜 실패했는지)
   - 대상 `phases/{task}/stepN.md` 전문

2. **서브에이전트 실행**: Agent 도구로 **`feature-builder`**를 띄우고 위 preamble을 프롬프트로 전달한다. 지시:
   - stepN.md의 `읽어야 할 파일`을 먼저 읽고, `작업`을 시그니처대로 구현.
   - `Acceptance Criteria` 쉘 명령을 **실제 실행**해 통과시킨다(`pnpm --filter 참고레포A ...` / `pnpm typecheck` / `pnpm test` / `pnpm build`).
   - TDD: 구현 `.ts(x)`에 짝 `*.test.ts(x)` 필수(hook hard-block).
   - 완료 후 **반드시 `phases/{task}/index.json`의 해당 step 상태를 갱신**(completed+summary / error+error_message / blocked+blocked_reason).
   - 메인 세션에는 결과 코드를 재출력하지 말고 짧게 보고.

3. **판정 = index.json 재읽기**(서브에이전트 stdout 아님):
   - `completed` → **두 커밋(4)** 후 다음 step.
   - `error` → 같은 step 재시도. retry 카운트 ≤ **3**(MAX_RETRIES). 3회 초과 시 루프 **중단**하고 사용자에게 보고. 근본 원인성 실패면 `root-cause-debugger` 에이전트 / `systematic-debugging` 스킬로 전환.
   - `blocked` → 즉시 **중단**, `blocked_reason`을 사용자에게 보고(사람 체크포인트).

## 4. 두 단계 커밋 (⚠️ 이 저장소는 괄호 스코프 금지)

참조 하네스는 `feat({phase}): step N — {name}`를 쓰지만, 이 repo는 **커밋 괄호 스코프를 CRITICAL로 금지**한다. → **타입만** 쓰고 phase는 **본문**에 넣는다.

1. **코드 커밋**
   - subject: `feat: step N — {name}` (구현이 리팩터/수정이면 `refactor:`/`fix:`)
   - body: `phase: {task}` + step 요약 1줄
   - 커밋 전 루트에서 `pnpm typecheck` → `pnpm format` → `pnpm lint -- --fix`.
2. **메타데이터 커밋**
   - `phases/{task}/index.json` 변경분: `chore: update phase index for step N` (body: `phase: {task}`).

- `--no-verify` 등 hook 우회 금지. 위험 명령 금지.

## 5. 마무리 (d)

- 모든 step이 `completed`면: 요약 표(step·상태·summary)를 출력하고 **`sdd-review` 스킬**로 검증하도록 안내.
- error/blocked로 멈췄으면: 멈춘 step·사유·재개 방법을 보고.

## 비용 메모

- 메인 세션이 하는 일: 브랜치·가드레일·preamble 조립·index.json 읽기·커밋 = 저렴.
- step 구현/테스트/빌드의 무거운 컨텍스트는 전부 `feature-builder` 서브에이전트 안에서 소비된다.
