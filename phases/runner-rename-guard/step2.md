# Step 2: test-edits-doc-line

## 읽어야 할 파일

- docs/runner-rename-guard-2026-11-28/PRD.md — AC-4
- `docs/sdd-runner.md` — `test_edits` 칸 항목(「다음 시도(새 BASE)부터」가 든 줄)
- `docs/changes/0.45.0.md` — 업그레이드 영향 줄(「step 도중 더한 칸은 남은 재시도에는 안 먹고, 멈춘 뒤 재개(새 BASE)부터 적용된다」). 읽기만 한다 — `docs/changes/**`는 릴리스 세션 몫이라 고치지 않는다

## 의도

- 채우는 수용 조건: AC-4 — 러너 문서가 실제 동작(칸은 BASE 커밋의 계획에서 읽으니 재시도는 같은 BASE라 안 먹고, 재개 때 새 BASE부터 먹는다)과 같게
- tdd: false — 문서 한 줄이라 테스트할 동작이 없다

## 작업

- `docs/sdd-runner.md` `test_edits` 항목의 「step 도중 더한 칸은 계획을 커밋한 뒤 다음 시도(새 BASE)부터 적용된다」를 「step 도중 더한 칸은 계획을 커밋해도 남은 재시도에는 안 먹고, 멈춘 뒤 재개(새 BASE)부터 적용된다」로 바꾼다. 같은 줄의 다른 문장은 그대로 둔다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `grep -c '다음 시도(새 BASE)부터' docs/sdd-runner.md` 출력 0
- `grep -c '남은 재시도에는 안 먹고' docs/sdd-runner.md` 출력 1 이상

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-rename-guard-2026-11-28/ARCHITECTURE.md` 「코드 지도」.
3. 결과를 `phases/runner-rename-guard/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `docs/changes/**` 수정 금지(릴리스 세션 몫).
