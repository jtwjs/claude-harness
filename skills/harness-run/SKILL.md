---
name: harness-run
description: SDD IMPLEMENT 러너 — phases/{task}/의 pending step을 순회하며 step마다 서브에이전트 1번(테스트 먼저 → 구현)으로 구현하고, sdd_runner.py judge가 git 기록(RED 커밋 순서·RED가 실제로 실패하나·테스트 파일 수정·verify)으로 판정해 커밋/재시도/중단한다. 사람이 자리에 없을 때는 같은 규칙의 헤드리스 러너(sdd_runner.py run)를 쓴다. Use when harness 스킬로 만든 계획을 실제로 구현할 때.
disable-model-invocation: false
---

강의 `harness_framework`의 `execute.py` 뼈대(step당 호출 1번 · 직전 에러를 붙여 재시도 · 시간 기록)에 우리 검사를 더한 러너다. **규칙의 정본은 `scripts/sdd_runner.py` 하나다** — 세션 안에서는 이 스킬이 그 스크립트의 `start`·`prompt`·`judge`를 부르고, 사람이 없을 때는 같은 스크립트의 `run`이 `claude -p`로 끝까지 돈다. 판정 표·섞은 근거는 `docs/sdd-runner.md`.

```
세션 안 (이 스킬)                                  헤드리스 (터미널에 걸어 두고 떠남)
start → [prompt → 서브에이전트 1번 → judge] 반복      python3 …/sdd_runner.py run {task}
```

> TDD 2단계 도구(`test-writer` → `feature-builder`)는 러너가 부르지 않는다. 강의처럼 TDD와 SDD 러너를 따로 둔다 — 엄격하게 분리해서 쓰고 싶은 부분에 사람이 직접 부른다(2026-10-13).

## 0. 입력

- `task` slug(= `phases/{task}/` 존재). 없으면 사용자에게 확인.
- 설계문서 경로는 **`phases/{task}/index.json`의 `docs`** 에서 읽는다(`harness`가 채운다). 없으면 묻는다 — `docs/` 아래를 뒤져 추측하지 않는다.
- 여러 phase 현황은 `python3 "${CLAUDE_PLUGIN_ROOT}/skills/harness-run/scripts/phases_status.py"`(같은 PRD로 묶고 `after` 순서로). 시작 전 점검은 §1 `start`가 이 스크립트의 `--check`와 같은 검사를 한다

## 1. 시작 — `python3 "${CLAUDE_PLUGIN_ROOT}/skills/harness-run/scripts/sdd_runner.py" start {task}`

선행 phase(`after`)·상태 값·error/blocked 남은 step·작업 트리 깨끗함을 보고 `feat-{task}` 브랜치로 옮긴다. 0이 아니면 출력을 그대로 사람에게 보이고 멈춘다. 작업 트리가 더러우면 판정이 git 기록을 못 믿으니 먼저 커밋·stash 한다.

## 2. 루프 — pending step이 없을 때까지

1. `BASE=$(git rev-parse HEAD)` — 이 step이 시작하기 전 커밋. **step마다 한 번만** 잡는다(재시도 때 다시 잡지 않는다)
2. `python3 "${CLAUDE_PLUGIN_ROOT}/skills/harness-run/scripts/sdd_runner.py" prompt {task}` — stderr의 `▶ step N`이 이번 step 번호다(3에서 쓴다). stdout을 그대로 지시문으로 **일반 서브에이전트(Agent 도구) 1번**을 띄운다. 지시문 = 가드레일(CLAUDE.md + `docs`의 PRD·ARCHITECTURE·ADR) + 완료 step summary + 직전 실패 사유 + 작업 규칙(`scripts/preamble.md`) + stepN.md. step에 `model`이 있으면 그 값만 넘긴다. **지시문을 손으로 고쳐 쓰지 않는다** — 고치면 헤드리스 러너와 규칙이 갈라진다
   - **병렬 트랙이면** 지시문 뒤에 열린 `conductor` + 이 phase 트랙의 `track:` 라벨 이슈 목록 한 번(`gh issue list --label conductor --label "track:<트랙>" --json number,title -q '.[]|"#\(.number) \(.title)"'`)을 붙인다. 선행이 열린 이슈에 걸린 step이면 돌리지 않고 사람에게 묻는다
3. 서브에이전트가 끝나면 `python3 "${CLAUDE_PLUGIN_ROOT}/skills/harness-run/scripts/sdd_runner.py" judge {task} --step N --base $BASE` — 결과 코드대로. `--step`은 필수다(0.18.1 — 예전처럼 '첫 pending'을 고르면 방금 completed로 바뀐 step을 건너뛰고 다음 step을 판정했다):
   - **0 완료** → index.json(시간·usage)을 메타데이터 커밋까지 끝낸 상태다. **사람에게 3줄**(무엇을 바꿨나 · 왜 · 어디가 위험한가/안 돌려 본 것)을 출력하고 다음 step. 멈추지 않는다 — 사람이 구현 도중에 따라오게 하려는 것이다
   - **10 재시도** → 실패 사유가 index.json `last_error`·`attempts`에 남았고 `retries` +1. 2로 돌아간다(지시문에 사유가 붙는다). RED 위반(2·3)이면 러너가 이번 시도의 커밋을 `sdd-discard/{task}/stepN-tryK` 브랜치로 옮겨 두고 BASE로 되돌린다 — 다음 시도는 테스트부터 다시
   - **1 실패로 멈춤** → 재시도 3번 뒤에도 실패(첫 시도 + 재시도 3 = 최대 4회, 재개했으면 재개 뒤부터 센다). 남은 코드는 `wip:` 커밋으로 남는다. 사유를 보고하고 멈춘다. 근본 원인성이면 `root-cause-debugger` / `systematic-debugging`
   - **2 blocked** → `blocked_reason`을 사람에게 보고하고 멈춘다(사람 체크포인트)

`judge`가 보는 것(위에서부터, 첫 실패에서 멈춤 — 정본은 `sdd_runner.py` `check`):
| # | 검사 | 실패 사유 |
|---|---|---|
| 1 | step status | error·pending(갱신 안 함)·허용 밖 값 → 재시도 / blocked → 멈춤(실행 실패보다 우선) |
| 2 | (`tdd: true`) 테스트 파일만 담긴 커밋이 구현 커밋보다 먼저 | "RED: 테스트 커밋이 없다 / 먼저가 아니다" → 이번 시도 버림 |
| 3 | (`tdd: true`) 그 커밋 시점으로 옮겨 `verify.test`(앱별이면 테스트가 든 앱만) → **실패해야** 함 | "RED: 테스트가 아무것도 잡지 않음" → 이번 시도 버림 |
| 4 | (`tdd: true`) 그 뒤 테스트 파일이 안 바뀜 — 바뀌었으면 되돌리고 실패 | "GREEN: 테스트 파일을 고쳤다(되돌림)" |
| 5 | 이 step에서 커밋된 변경이 있다(남은 변경은 러너가 `feat:` 커밋으로 묶는다) | "completed 보고인데 변경 없음" |
| 6 | `verify` 전부(앱별이면 root마다) 통과 | "verify 실패: <이름>" |
헤드리스 `run`은 여기에 **0. 실행 결과**(종료 코드 · JSON `is_error` · 타임아웃 1800초, 타임아웃이면 자식 프로세스까지 끈다)를 먼저 본다. `start`는 `tdd: true` step이 있는데 `verify.test`가 없으면 돌리지 않고, 환경에 `ANTHROPIC_API_KEY`가 있으면 경고한다(헤드리스 `claude -p`는 그 키로 API 과금된다 — 공식 문서).

## 3. 커밋

에이전트가 `test: step N — {name} (red)`(tdd step) → `feat: step N — {name}`을 커밋하고, 러너가 남은 변경 `feat:`과 메타데이터 `chore: update phase index for step N`(body `phase: {task}`)을 커밋한다. 커밋 메시지 형식의 정본은 `commit` 스킬이다. `--no-verify` 등 훅 우회 금지 · push 하지 않는다. `stepN-output.json`(헤드리스 원문 로그)은 `.git/info/exclude`로 커밋에서 빠진다.

## 5. 마무리 (d)

- 모든 step이 `completed`면: 요약 표(step·상태·summary)를 출력하고 **`sdd-review` 스킬**로 검증하도록 안내.
- error/blocked로 멈췄으면: 멈춘 step·사유·재개 방법을 보고.
- **재개 절차** (`sdd` 「재개」와 같은 문장): 원인이 확정되고 사람이 승인하면 **메인이** 그 step을 `error → pending`으로 되돌리고 `error_message`에 근본 원인 한 줄을 남긴 뒤 §1 `start`부터 다시 돈다(`start`가 error·blocked step이 남아 있으면 멈추기 때문). 그 한 줄은 다음 지시문 머리에 들어가고, `start`가 `resumed_at`을 찍어 재시도 한도를 새로 센다. **`retries`는 0으로 되돌리지 않는다** — 승격 판단의 계수기라서다. 고친 index.json은 커밋하지 않은 채로 와도 된다. blocked는 `blocked_reason`이 해소됐을 때만 `pending`으로.

## 비용 메모

- step당 서브에이전트(또는 `claude -p`) **1번**. 예전 RED·GREEN 2번에서 줄였다 — 강의 execute.py와 같은 단위. 테스트 먼저는 `tdd-guard` 훅 + 판정 2~4가 지킨다
- 헤드리스는 호출마다 JSON `usage`를 그 step의 `usage`에 더한다. 사용량을 처음으로 셀 수 있는 자리다(BACKLOG "1회 → 2회로 되돌리는 조건"이 이 숫자를 쓴다)
