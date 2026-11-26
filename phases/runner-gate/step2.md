# Step 2: start-runs-gate

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 R1 · R2
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `start`(`:322-386`) · `run`(`:831-834`, `start`를 먼저 부른다) · step 1이 만든 `open_decisions` · `gate`
- `skills/sdd-run/scripts/test_sdd_runner.py` — `RunnerCase.phase()`(index.json `docs` 칸을 `docs/x`로 쓴다 — 그 폴더가 없으니 기존 테스트는 관문을 통과한다) · `test_branch_pattern`

## 의도

- 채우는 수용 조건: AC-1, AC-2 — `sdd-plan` §0을 건너뛰어도 실행 시작에서 진짜 장치로 멈추게 한다(ADR-023 R2). 헤드리스 `run`도 `start`를 거쳐 같은 관문을 탄다

## 작업

- `start`가 index.json의 `docs` 칸 폴더로 step 1의 같은 검사를 돈다. 위치: index.json · after · error/blocked 검사 뒤, **부작용 전**(`.git/info/exclude` 쓰기 · 브랜치 옮기기 · `resumed_at` 찍기보다 앞)
- 열린 것이 있으면 `gate`와 같은 출력(첫 줄 + 항목 목록)을 내고 종료 2. 아무것도 바꾸지 않는다
- `docs` 칸이 없거나 폴더 · 파일이 없으면 막지 않는다(한 줄 안내는 있어도 되고 없어도 된다)
- 헤드리스 `run`은 `start`가 2를 돌려주면 그대로 2로 끝나고 claude를 부르지 않는다(지금 `run` 구조 그대로면 따로 고칠 것이 없다)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_start_gate_no_docs_key_passes`
  - 비정상 입력: 해당 없음: 문서 해석의 비정상 꼴은 step 1 `gate` 테스트가 덮는다
  - 실패 경로: `test_start_gate_open_stops_before_side_effects` · `test_run_gate_open_never_calls_claude`
  - 상태 전이: `test_start_gate_closed_then_passes`
  - 동시성: 해당 없음: 시작 점검은 한 세션이 부르고 문서를 읽기만 한다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 「바뀌는 층」 `start` 행.
3. 결과를 `phases/runner-gate/index.json`의 step 2에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 세는 규칙을 `start` 안에 다시 쓰지 않는다 — step 1의 함수를 부른다(정본이 둘이 되면 갈린다)
