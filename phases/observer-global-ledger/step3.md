# Step 3: weekly-runner

## 읽어야 할 파일

- docs/observer-global-ledger-2026-11-23/PRD.md · ARCHITECTURE.md · ADR.md (수용 조건 · 형식 · 값의 정본 — 값을 step 에 복사하지 않았다)
- hooks/test.sh (케이스 형식 · env 격리 패턴, 731행 이후 tests/ source) · hooks/tests/ledger-write.sh (케이스 파일 예) · hooks/lib/ledger.py (CLI 형식 · 종료 코드 관례)
- skills/task-observer/scripts/observer.py (step 1 · 2 결과)
- skills/harness-run/scripts/sdd_runner.py `invoke()` (claude -p 호출 · 결과 JSON 마지막 줄 파싱 · ANTHROPIC_API_KEY 경고 패턴)

## 작업

- 새 `skills/task-observer/references/weekly-prompt.md`: `claude -p` 지시문. 들어갈 것 — 5종 정의(SKILL.md 표를 요약해 인용) · 재지시/재교정 경계(ADR, 「이미 한 결과를 고치면 재교정, 하기 전에 미리 말하면 재지시」) · 미위임은 재료의 `undelegated` 사유만 근거로 · **레포 2곳 이상에 나온 것만** 후보 · 잡동사니 금지(5종 밖 · "잘 된 것" 안 냄) · 근거 없는 후보 금지 · 출력은 후보 JSON 배열만(형식은 ARCHITECTURE append FILE) · 없으면 `[]` · 원문 인용 대신 근거는 `<레포> <날짜> 세션` · `phases/<폴더>` 형태. 조직명 · 내부 도메인을 패턴에 쓰지 말고 일반형으로.
- 새 `skills/task-observer/scripts/weekly.sh`(실행 가능) `[--dry-run] [--days N]`: ARCHITECTURE 「데이터 흐름」 · 「weekly.sh」 그대로. gather → 레포 2곳 미만이면 "후보 없음" exit 0 → `${TASK_OBSERVER_CLAUDE:-claude} -p --tools "" --no-session-persistence --output-format json` 에 지시문 + 재료를 stdin 으로 → `.result` 에서 JSON 배열 추출(코드 펜스로 감싸져 와도 벗김) → append. 마지막 줄 `task-observer weekly: 후보 n · 쓴 행 m · 소요 Ns`.
  - 설정 없고 `--dry-run` 아니면 claude 를 부르지 않고 "원장 설정 없음" exit 0(AC1 — 구독 사용량을 쓰지 않는다).
  - claude 실패(비0 · is_error · JSON 없음 · 배열 아님)면 원장 무쓰기 · exit 1 · 사유 한 줄(AC12).
  - 임시 파일은 `mktemp -d` 아래, trap 으로 지운다.

## Acceptance Criteria

- 새 케이스 파일 `hooks/tests/task-observer-weekly.sh`(가짜 claude = `$TMP` 의 셸 스크립트, 받은 인자 · stdin 을 파일에 남기고 정해진 JSON 을 낸다): 설정 없음 → 가짜 claude 안 불림 / 레포 1곳 → 안 불림 · "후보 없음" / 인자에 `--tools` "" · `--no-session-persistence` 포함(AC11) / stdin 에 지시문과 재료 / 정상 결과 → 원장에 후보 행 / 펜스 감싼 결과도 파싱 / 실패 결과 → exit 1 · 원장 무변경(AC12) / `--dry-run` → 원장 무변경 / 마지막 줄 형식 / AC13: `skills/task-observer` · `hooks/tests/task-observer-*.sh` 에 `1_MyBrain` · `brain/friction` grep 0.
- `bash hooks/test.sh` 전부 통과. 테스트 커밋 먼저 · 그 시점 실패.

## 검증 절차

1. `bash hooks/test.sh` 실제 실행.
2. 실제 claude 는 부르지 않는다(측정은 step 5).
3. index.json 해당 step 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 단계에서) 금지.
- 🔴 `hooks/test.sh` 는 고치지 않는다. 러너의 테스트 파일 판정이 이 파일을 못 알아봐서 RED 확인이 깨진다. 새 케이스는 `hooks/tests/` 아래 새 파일에 두고 `ok`·`bad`·`TMP`·`HOOKS` 를 그대로 쓴다(test.sh 가 source 한다).
- 🔴 실제 `~/.claude`(설정 · 대화 기록)와 개인 원장을 읽거나 쓰지 않는다. 테스트는 늘 `CLAUDE_TASK_OBSERVER_CONFIG` · `CLAUDE_TASK_OBSERVER_PROJECTS` 를 `$TMP` 아래로.
- 🔴 공개 레포: 원장 실제 경로 · 볼트 폴더 이름(예: 개인 볼트 하위 폴더명)을 코드 · 문서 · 픽스처에 쓰지 않는다. 픽스처 원장은 `$TMP/vault/ledger/index.md` 같은 가짜 경로.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- macOS bash 3.2 호환: 변수 뒤에 한글이 오면 `${}` 로 감싼다(0.35.0 수정 사례). 파이썬은 표준 라이브러리만.
