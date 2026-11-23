# Step 1: observer-gather

## 읽어야 할 파일

- docs/observer-global-ledger-2026-11-23/PRD.md · ARCHITECTURE.md · ADR.md (수용 조건 · 형식 · 값의 정본 — 값을 step 에 복사하지 않았다)
- hooks/test.sh (케이스 형식 · env 격리 패턴, 731행 이후 tests/ source) · hooks/tests/ledger-write.sh (케이스 파일 예) · hooks/lib/ledger.py (CLI 형식 · 종료 코드 관례)
- skills/task-observer/SKILL.md (5종 정의 · observations.md 표 형식)

## 작업

새 `skills/task-observer/scripts/observer.py`(실행 가능, `#!/usr/bin/env python3`)의 두 서브커맨드. 형식 · 상한 값은 ARCHITECTURE 「observer.py config」 · 「observer.py gather」가 정본이다.

- `config`: 설정 파일(env `CLAUDE_TASK_OBSERVER_CONFIG` 또는 `~/.claude/task-observer.json`)의 `ledger` 경로를 `~` 펼쳐 한 줄로. 없음 · 깨짐 · 칸 없음이면 아무것도 안 찍고 exit 0. 함수 `ledger_path() -> Path | None` 으로도 쓴다(step 2 가 import).
- `gather --days N`(기본 7): 대화 기록(env `CLAUDE_TASK_OBSERVER_PROJECTS` 또는 `~/.claude/projects`, 그 아래 `*/*.jsonl`)에서 창 안 줄의 `cwd` → 레포(공통 git 디렉터리로 worktree 합침) → 레포별 `sessions`(날짜) · `user` · `bash` · `observations` · `undelegated`. JSON 하나를 stdout. 레포 이름 순.
  - 깨진 줄 · 없는 cwd · git 아닌 cwd는 조용히 건너뛴다. 어떤 입력에도 traceback 없이 exit 0.
  - `observations`: 범위 칸이 `전역 후보`이고 `마지막`이 창 안인 「열린 것」 행만(AC4). 범위 칸이 없는 옛 표는 행 0으로.
  - `undelegated`: `status == "blocked"` 또는 `retries >= 3` step 만(AC3).
- 시간 비교는 줄의 `timestamp`(ISO, `Z` 포함)를 aware datetime 으로. 테스트가 "지금"을 고정할 수 있게 env `TASK_OBSERVER_NOW`(ISO 날짜시각)가 있으면 그 값을 지금으로 쓴다.

## Acceptance Criteria

- 새 케이스 파일 `hooks/tests/task-observer-gather.sh`: PRD AC1(config 부분) · AC2 · AC3 · AC4 · AC5 를 하나 이상씩. 최소: 설정 없음 → 빈 출력 exit 0 / 레포 A(main + worktree) · 레포 B · git 아닌 폴더 cwd → 레포 2개 / 창 밖 줄 제외 / tool_result · `<` 시작 사람 말 제외 / 긴 말 잘림 / blocked · retries 3 만 집계 · 0이면 빈 배열 / observations 범위 필터 · 범위 칸 없는 표 / 깨진 jsonl 줄에서 안 죽음.
- `bash hooks/test.sh` 전부 통과(`.claude/harness.json` verify.test). 테스트 커밋이 먼저이고 그 시점에 새 케이스가 실패해야 한다.

## 검증 절차

1. `bash hooks/test.sh` 실제 실행.
2. ARCHITECTURE 「경계」 대조: gather 는 아무 파일도 쓰지 않는다.
3. 결과를 `phases/observer-global-ledger/index.json` 해당 step 에 기록(completed+summary / error+error_message / blocked+blocked_reason). summary 에 step 2 가 import 할 함수 이름을 적는다.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 단계에서) 금지.
- 🔴 `hooks/test.sh` 는 고치지 않는다. 러너의 테스트 파일 판정이 이 파일을 못 알아봐서 RED 확인이 깨진다. 새 케이스는 `hooks/tests/` 아래 새 파일에 두고 `ok`·`bad`·`TMP`·`HOOKS` 를 그대로 쓴다(test.sh 가 source 한다).
- 🔴 실제 `~/.claude`(설정 · 대화 기록)와 개인 원장을 읽거나 쓰지 않는다. 테스트는 늘 `CLAUDE_TASK_OBSERVER_CONFIG` · `CLAUDE_TASK_OBSERVER_PROJECTS` 를 `$TMP` 아래로.
- 🔴 공개 레포: 원장 실제 경로 · 볼트 폴더 이름(예: 개인 볼트 하위 폴더명)을 코드 · 문서 · 픽스처에 쓰지 않는다. 픽스처 원장은 `$TMP/vault/ledger/index.md` 같은 가짜 경로.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- macOS bash 3.2 호환: 변수 뒤에 한글이 오면 `${}` 로 감싼다(0.35.0 수정 사례). 파이썬은 표준 라이브러리만.
