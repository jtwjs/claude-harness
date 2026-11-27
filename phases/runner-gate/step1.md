# Step 1: gate-open-decisions

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 「R1 관문이 세는 것」이 규칙의 정본이다
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `md_sections`(`:126`) · `main`(`:860`) · 모듈 docstring 사용법 줄(`:11-23`)
- `skills/sdd-run/scripts/test_sdd_runner.py` — `RunnerCase`의 임시 레포 · `session()` 꼴
- 판정할 ADR 표 예: `docs/design-phase-2026-11-26/ADR.md:17-28`(「결정할 것」 표 · 주체 칸)

## 의도

- 채우는 수용 조건: AC-1, AC-2 — 열린 「정할 것」을 세는 관문을 하위 명령 하나로 세운다. step 2(`start`)와 `sdd-plan` §0이 같은 검사를 부른다(ADR-023 R2)

## 작업

- `sdd_runner.py`에 `gate <docs 폴더>` 하위 명령을 더한다. `mode` 선택지에 `gate`를 넣고, 두 번째 위치 인자를 이 모드에서는 docs 폴더(레포 루트 기준 경로)로 읽는다. index.json은 읽지 않는다
- 세는 함수(모듈 함수 또는 `Runner` 메서드, step 2가 다시 쓴다): `open_decisions(docs_dir) -> list[str]` — 열린 항목 한 줄씩. 규칙은 ADR-023 R1 그대로:
  - `ADR.md`: 제목 줄(`#` 개수 무관)에 「결정할 것」이 든 절 안의 마크다운 표. 머리줄에서 「주체」가 든 칸을 찾고, 구분줄(`|---|`)을 뺀 행 중 그 칸이 빈(공백뿐) 행을 연 것으로 센다. 「주체」 칸이 없는 표는 모든 행이 연 것. 항목 글: `ADR <첫 칸>: <둘째 칸>`
  - `PRD.md`: 「남은 ⚠️」가 든 제목 줄이면 다음 같은 급 이상 제목 전까지, 「남은 ⚠️」가 든 불렛 라벨 줄(예: `- **남은 ⚠️** (…)`)이면 그 줄보다 깊게 들여 쓴 줄이 이어지는 동안이 범위다. 범위 안의 첫 단 불렛 항목(`-` 또는 `*`) 중 `→ 결정:` 또는 `막지 않음:`이 없는 줄을 연 것으로 센다. 항목 글: `PRD: <불렛 본문>`
  - 폴더가 없거나 두 파일이 다 없으면 빈 목록
- 출력 · 종료: 열린 것이 있으면 첫 줄 「구현 시작 관문: 열린 「정할 것」 N개 — 지휘(또는 사람)에게 묻고 닫은 뒤 다시」 + 항목마다 `  - <항목 글>`, 종료 2. 없으면 한 줄(「구현 시작 관문: 열린 「정할 것」 0」 또는 문서가 없으면 「구현 시작 관문: ADR · PRD 없음 — 막지 않는다」) 종료 0
- 모듈 docstring 사용법에 `sdd_runner.py gate DOCS_DIR` 한 줄(ADR-023 R1 · R2 참조)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 `hooks/tests/sdd-runner-unit.sh`가 같이 돌린다)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_gate_no_docs_passes` · `test_gate_all_closed_passes`
  - 비정상 입력: `test_gate_table_without_owner_column_counts_all`
  - 실패 경로: `test_gate_open_rows_stop_with_list`
  - 상태 전이: `test_gate_prd_marked_lines_excluded` · `test_gate_prd_heading_and_label_forms`
  - 동시성: 해당 없음: 파일을 읽기만 하고 쓰지 않는다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 「지키는 것」(레포 안 문서만 읽는다).
3. 결과를 `phases/runner-gate/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 이 step은 `start`를 고치지 않는다(step 2). 표준 라이브러리만 쓴다
