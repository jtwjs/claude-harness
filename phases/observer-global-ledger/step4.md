# Step 4: skill-docs

> tdd: false — 문서(SKILL.md · 템플릿 README · 버전 파일)만 바꾼다. 기계 판정할 동작이 없다.

## 읽어야 할 파일

- docs/observer-global-ledger-2026-11-23/PRD.md · ARCHITECTURE.md · ADR.md (수용 조건 · 형식 · 값의 정본 — 값을 step 에 복사하지 않았다)
- hooks/test.sh (케이스 형식 · env 격리 패턴, 731행 이후 tests/ source) · hooks/tests/ledger-write.sh (케이스 파일 예) · hooks/lib/ledger.py (CLI 형식 · 종료 코드 관례)
- skills/task-observer/SKILL.md · templates/.claude/README.md 16 · 26행 · skills/sdd/SKILL.md 67행 · .claude-plugin/plugin.json · .claude-plugin/marketplace.json

## 작업

- `skills/task-observer/SKILL.md` (외과적 수정):
  - §1 표 아래: 재지시/재교정 경계 한 줄(ADR 참조, 문장 그대로).
  - §2 표 형식: 「열린 것」에 `범위` 칸(`레포 고유 | 전역 후보`) 추가. 판정 기준 한 줄 — 다른 레포에서도 같은 에이전트가 같은 데서 막힐 내용(플러그인 스킬 · 전역 지시 · 공통 도구)이면 전역 후보, 이 레포 코드 · 규칙에만 걸리면 레포 고유. 원장에는 쓰지 않는다(레포 2곳 이상은 헤드리스가 센다).
  - 새 절 「전역 후보 → 개인 원장 (주 1회 헤드리스)」: 흐름 그림 한 개 · 개인 설정 `~/.claude/task-observer.json` `{"ledger": "<원장 index.md 경로>"}`(없으면 이 절 전체가 꺼짐) · 실행 `skills/task-observer/scripts/weekly.sh [--dry-run]` · 상태는 늘 `후보`(열림은 사람이 원장 쪽에서) · 미위임은 스크립트 집계 · 스케줄 등록(launchd 등)은 개인 설정이라 플러그인 밖. 경로 예시는 `~/vault/friction/index.md` 같은 가짜 경로만.
  - 「금지」 첫 줄의 "사람 확인 없이 쓰지 않는다" 목록과 충돌하지 않게 한 줄: 원장 `후보` 행은 예외(사람 확인 전 단계라서) — ADR 참조.
- `templates/.claude/README.md` 26행 `observations.md` 설명에 「범위 칸」 몇 단어만.
- 버전 0.39.0 → 0.40.0: `.claude-plugin/plugin.json`, `marketplace.json` 에 버전이 있으면 같이.
- frontmatter description 은 바꾸지 않는다(상시 로드 토큰 — 0.37 이후 180토큰 상한 정리).

## Acceptance Criteria

- `bash hooks/test.sh` 전부 통과(문서 변경이 기존 케이스를 깨지 않음 — no-brain 등).
- `grep -n "범위" skills/task-observer/SKILL.md` 에 표 칸이 보인다. `grep -rn "1_MyBrain\|brain/friction" skills templates` 0.

## 검증 절차

1. 위 명령 실제 실행.
2. index.json 해당 step 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 단계에서) 금지.
- 🔴 `hooks/test.sh` 는 고치지 않는다. 러너의 테스트 파일 판정이 이 파일을 못 알아봐서 RED 확인이 깨진다. 새 케이스는 `hooks/tests/` 아래 새 파일에 두고 `ok`·`bad`·`TMP`·`HOOKS` 를 그대로 쓴다(test.sh 가 source 한다).
- 🔴 실제 `~/.claude`(설정 · 대화 기록)와 개인 원장을 읽거나 쓰지 않는다. 테스트는 늘 `CLAUDE_TASK_OBSERVER_CONFIG` · `CLAUDE_TASK_OBSERVER_PROJECTS` 를 `$TMP` 아래로.
- 🔴 공개 레포: 원장 실제 경로 · 볼트 폴더 이름(예: 개인 볼트 하위 폴더명)을 코드 · 문서 · 픽스처에 쓰지 않는다. 픽스처 원장은 `$TMP/vault/ledger/index.md` 같은 가짜 경로.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- macOS bash 3.2 호환: 변수 뒤에 한글이 오면 `${}` 로 감싼다(0.35.0 수정 사례). 파이썬은 표준 라이브러리만.
