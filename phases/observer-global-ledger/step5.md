# Step 5: measure-first-run

> kind: measure — 바꿀 파일 없음. 실제 대화 기록으로 헤드리스 1회를 돌려 소요 시간과 결과를 잰다.

## 읽어야 할 파일

- docs/observer-global-ledger-2026-11-23/PRD.md 「성공지표」 · skills/task-observer/scripts/weekly.sh

## 작업

- `date` 로 시작 시각 → `bash skills/task-observer/scripts/weekly.sh --dry-run` (실제 `claude`, 실제 `~/.claude/projects`, 원장은 쓰지 않음) → 끝 시각.
- summary 에 남길 것: 실행한 명령(백틱) · 시작/끝 시각 · 소요(마지막 줄) · gather 레포 수 · 후보 수 · 후보 패턴 한 줄씩(조직 정보가 보이면 `[가림]`) · 50분 초과 여부(PRD — 넘으면 시각을 당기라는 메모).
- 실패하면 status error 와 사유. 원장 · 설정 파일은 만들지도 쓰지도 않는다.

## Acceptance Criteria

- summary 에 위 항목이 백틱 명령과 함께 있다. 레포 파일 변경 0.

## 검증 절차

1. `git status --short` 가 index.json 외 변경 0.
2. index.json 해당 step 기록.

## 금지사항

- 개인 원장 · `~/.claude/task-observer.json` 을 만들거나 쓰지 않는다(`--dry-run` 만).
- 레포 파일 수정 금지.
