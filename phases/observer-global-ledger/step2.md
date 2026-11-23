# Step 2: observer-append

## 읽어야 할 파일

- docs/observer-global-ledger-2026-11-23/PRD.md · ARCHITECTURE.md · ADR.md (수용 조건 · 형식 · 값의 정본 — 값을 step 에 복사하지 않았다)
- hooks/test.sh (케이스 형식 · env 격리 패턴, 731행 이후 tests/ source) · hooks/tests/ledger-write.sh (케이스 파일 예) · hooks/lib/ledger.py (CLI 형식 · 종료 코드 관례)
- skills/task-observer/scripts/observer.py (step 1 결과 — `ledger_path()`)

## 작업

`observer.py`에 `append [--dry-run] FILE` 서브커맨드. 검증 · ID · 원장 행 · 연결 링크 · 월별 파일 항목 형식 · 쓰기 순서 · 종료 코드는 ARCHITECTURE 「observer.py append」가 정본이다.

- 설정 없으면(`ledger_path()` None) `--dry-run` 이 아닐 때 "원장 설정 없음" 한 줄 · 쓰지 않음 · exit 0(AC1).
- 후보 검증 실패는 그 후보만 건너뛰고 stderr 한 줄(AC6). 남은 후보가 0이면 "후보 없음" · exit 0.
- 🔴 데이터 무결성: 원장의 기존 바이트(다른 행 · 표 밖 문단 · frontmatter)는 그대로 둔다 — 새 행 삽입만. 원장은 임시 파일 + rename 으로 쓴다. 원장에 `| ID | 패턴 |` 표가 없으면 아무것도 쓰지 않고 exit 2(월별 파일도 안 씀). 상태 칸은 늘 `후보`.
- 실행 날짜는 step 1 의 `TASK_OBSERVER_NOW` 를 따른다(월별 파일 이름 · 기본 날짜).

## Acceptance Criteria

- 새 케이스 파일 `hooks/tests/task-observer-append.sh`: PRD AC1 · AC6 · AC7 · AC8 · AC9 · AC10. 최소: 설정 없음 → 무쓰기 exit 0 / 유형 밖 · 레포 1곳 · 같은 레포 두 번 · 방향 밖 · 여러 줄 패턴 거부(나머지는 씀) / 기존 F-004 뒤 F-005 · F-006 / 표 마지막 행 바로 뒤 삽입 · 표 아래 문단 바이트 그대로 / 칸 안 `|` 이스케이프 / 상태 `후보` · 11칸 / `.obsidian` 있는 조상 → 상대 경로 링크, 없으면 `[[YYYY-MM]]` / 월별 파일 없으면 frontmatter 와 생성, 있으면 맨 아래 append / 표 없는 원장 → exit 2 · 둘 다 무변경 / `--dry-run` → 둘 다 무변경 · stdout 에 행.
- `bash hooks/test.sh` 전부 통과. 테스트 커밋 먼저 · 그 시점 실패.

## 검증 절차

1. `bash hooks/test.sh` 실제 실행.
2. ARCHITECTURE 「경계」 대조: 쓰기는 append 한 곳.
3. index.json 해당 step 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 단계에서) 금지.
- 🔴 `hooks/test.sh` 는 고치지 않는다. 러너의 테스트 파일 판정이 이 파일을 못 알아봐서 RED 확인이 깨진다. 새 케이스는 `hooks/tests/` 아래 새 파일에 두고 `ok`·`bad`·`TMP`·`HOOKS` 를 그대로 쓴다(test.sh 가 source 한다).
- 🔴 실제 `~/.claude`(설정 · 대화 기록)와 개인 원장을 읽거나 쓰지 않는다. 테스트는 늘 `CLAUDE_TASK_OBSERVER_CONFIG` · `CLAUDE_TASK_OBSERVER_PROJECTS` 를 `$TMP` 아래로.
- 🔴 공개 레포: 원장 실제 경로 · 볼트 폴더 이름(예: 개인 볼트 하위 폴더명)을 코드 · 문서 · 픽스처에 쓰지 않는다. 픽스처 원장은 `$TMP/vault/ledger/index.md` 같은 가짜 경로.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- macOS bash 3.2 호환: 변수 뒤에 한글이 오면 `${}` 로 감싼다(0.35.0 수정 사례). 파이썬은 표준 라이브러리만.
