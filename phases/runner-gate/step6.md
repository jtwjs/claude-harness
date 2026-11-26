# Step 6: scratch-walk

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `docs/sdd-runner.md` 나눔 모드 · 구현 시작 관문 항목(step 5)

## 의도

- 채우는 수용 조건: AC-3(스크래치 레포 걷기), AC-1 · AC-2(실제 CLI로 한 번), AC-4 — 단위 테스트 밖에서 CLI를 실제로 불러 두 길이 사람 손 정리 없이 도는지 본다
- kind: measure — 바꿀 파일이 없다. 검증 세션 몫이다(나눔 모드 차례 표)

## 작업

- 스크래치 레포(스크래치 폴더, 레포 밖)에서 실제 `sdd_runner.py`로:
  1. 관문: ADR 「결정할 것」 표 열린 행 1 + PRD 「남은 ⚠️」 1인 docs로 `gate` → 종료 2 · 두 항목. 닫힘 표시를 단 뒤 `gate` · `start` → 0. docs 칸이 없는 phase로 `start` → 0
  2. 재판정: `tdd: true` step 하나 — 검증 `prompt --role test --base` → 테스트 커밋 → `judge --red` → 구현이 「테스트가 수용 조건과 다르다」로 blocked → 검증이 테스트만 고쳐 커밋 → `rejudge --step 1` → 구현 `prompt --role impl` → `judge --step 1` 완료. 끝에서 구현 커밋 · 고친 테스트가 둘 다 브랜치에 있고 `sdd-discard/` 브랜치 0
- 진행 중인 다른 phase의 docs 폴더(지휘가 지정한 곳, 읽기만)에 `gate`를 돌려 통과/멈춤 · 이유를 적는다. 멈추면 지휘에 묻는다
- 이 레포에서 `bash hooks/test.sh` · `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py`를 돌린다
- summary에 명령(백틱)과 결과(종료 코드 · 개수)를 한 줄씩

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`) — phase 마지막 step이라 러너가 전체로 돈다
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- summary에 측정 명령(백틱)과 결과

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 흐름 그림과 걷기 결과가 같은지.
3. 결과를 `phases/runner-gate/index.json`의 step 6에 기록:
   - 성공 → `status:"completed"` + `summary`(측정 명령 · 결과)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 다른 phase의 worktree · 파일에는 쓰지 않는다(읽기만). 스크래치 레포는 레포 밖에 둔다
