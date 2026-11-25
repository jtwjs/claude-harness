# Step 13: flow-walk

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 전체)
- `phases/verify-flow/index.json`의 step 1~12 summary

## 작업

근거: ADR-019 전체. 측정 전용 step이다(`kind: measure`) — 코드를 바꾸지 않는다.

바꾸는 파일:

- 바꿀 파일 없음

- 아래를 돌려 명령(백틱)과 결과를 summary에 남긴다
  - `bash hooks/test.sh` 마지막 줄(통과 · 실패 수)
  - 옛 문장 0건: `git grep -n -e '같은 세션의 서브에이전트' -e 'escalate 판정에 따라' -e '5개 섹션 고정' -- skills templates`
  - 걷기: 스크래치 git 레포(`.claude/harness.json`의 `verify.test` · `git.branchPattern: feature/{task}` · `feature/` 브랜치 · 깨끗한 트리 — 없으면 `start`가 멈춘다)에 가짜 phase 하나( `tdd: true` step 1개)로 `prompt --role test` → 테스트 커밋 → `judge --red` → `red` 기록 → `prompt --role impl` → 구현 커밋 → `judge` 완료까지 한 번. 단계마다 종료 코드
  - ADR-019 행 ↔ step 대조 표(행 이름 · 반영 step · 못 넣은 이유)
- 실패가 있으면 고치지 않고 summary에 남기고 `status:"error"`

## Acceptance Criteria

- `summary`에 위 명령(백틱)과 결과가 있다(러너 판정 5 measure 규칙)

## 검증 절차

1. 위 명령을 실제 실행한다.
2. 걷기는 레포 밖 스크래치 폴더에서만 한다(레포에 가짜 phase를 커밋하지 않는다).
3. 결과를 `phases/verify-flow/index.json`의 step 13에 기록:
   - 성공 → `status:"completed"` + `summary`
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- 코드 · 문서 수정 금지(측정만). hook 우회 금지.
- push · PR 금지.
