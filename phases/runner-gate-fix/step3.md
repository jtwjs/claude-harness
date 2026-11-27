# Step 3: gate-missed-forms

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 R1 · R3와 「갱신」 줄
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- 이슈 #86 본문(`gh issue view 86`) — 이 step이 맡는 행
- `skills/sdd-run/scripts/sdd_runner.py` — `open_decisions` · `_cells` · `gate`(문서 없을 때 문구) · `start`의 `exclude =Path(`
- `skills/sdd-run/scripts/test_sdd_runner.py` — gate 테스트들

## 의도

- 채우는 수용 조건: #86 F4(R1 「기본이 멈춤」 방향으로) · F6 코드 두 줄

## 작업

- F4 넷을 열린 항목으로 센다: ① 변이 선택자(U+FE0F) 없는 「남은 ⚠」 제목 · 라벨 ② 라벨 줄에 붙여 쓴 내용(`- **남은 ⚠️**: X 미정` → `PRD: X 미정`, 닫힘 표시 · 「없음」 규칙은 같게) ③ 번호 목록(`1.` `1)`) · `+` 불렛 ④ 셀 안 `\|`는 칸 나눔으로 안 본다
- F6: `exclude =Path(` 공백 · `gate`가 문서 없음일 때 해석한 폴더 경로를 같이 출력
- 「하지 않을 것」: 「없음」 닫힘 범위 넓히기

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- 엣지 5축:
  - 빈 값·경계: `test_gate_heading_without_fe0f_counts`
  - 비정상 입력: `test_gate_escaped_pipe_cell_counts`
  - 실패 경로: `test_gate_label_inline_content_counts` · `test_gate_numbered_and_plus_bullets_count`
  - 상태 전이: `test_gate_no_docs_prints_resolved_path`
  - 동시성: 해당 없음: 읽기만 한다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 「지키는 것」.
3. 결과를 `phases/runner-gate-fix/index.json`의 step 3에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. ADR-023에 바뀌는 행은 본문을 고치지 않고 「갱신」 줄로 단다.
