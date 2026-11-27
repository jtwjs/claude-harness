# Step 5: probe-rerun

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 R1 · R3와 「갱신」 줄
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- 이슈 #86 본문(`gh issue view 86`) — 이 step이 맡는 행

## 의도

- 채우는 수용 조건: #86 「끝」 — 리뷰어 재현 시나리오(F1 · F2 · F3 · F4 네 꼴)를 레포 밖에서 다시 돌려 고쳐졌는지 본다
- kind: measure — 검증 세션 몫. 바꿀 파일 없음

## 작업

- 레포 밖 재현 스크립트로 F1 · F2 · F3 시나리오 · 관문 꼴 14개를 돌려 전/후를 summary에
- 레포 docs 폴더 전체에 `gate` — 멈춤 · 오탐 목록
- `bash hooks/test.sh` · 러너 단위 테스트

## Acceptance Criteria

- `bash hooks/test.sh` 통과 — phase 마지막 step이라 러너가 전체로 돈다
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- summary에 측정 명령(백틱)과 결과

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 흐름 그림과 걷기 결과.
3. 결과를 `phases/runner-gate-fix/index.json`의 step 5에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. ADR-023에 바뀌는 행은 본문을 고치지 않고 「갱신」 줄로 단다.
- 재현 스크립트 경로 · 내용은 레포에 옮기지 않는다
