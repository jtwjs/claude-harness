# Step 3: hook-log-all

## 읽어야 할 파일

- `docs/harness-checkup-2026-11-25/ADR.md`(ADR-018 — A 정할 것 · B 판정표 · 시험 결과). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `hooks/lib/hook-log.sh`(`hook_log_on_exit`) · 기록 중인 훅 3개 · `hooks/tests/hook-log-exits.sh` · `hooks/hooks.json`

## 작업

근거: ADR-018 B-4 · B-11.

바꾸는 파일:

- 기록 안 하는 훅 8개 · `hooks/lib/hook-log.sh`(회전 · 상한) · 새 `hooks/tests/hook-log-all.sh`

- 나머지 8개 훅도 끝나는 모든 경로에서 `HOOK_RESULT`를 정하고 `hook_log_on_exit`로 한 줄 남긴다. 막은 경우는 결과 이름으로 구분(막음 / 알림 / 건너뜀)
- 기록 파일 회전 · 상한: 크기 값은 사용자 결정으로 「1주 실측 뒤 정함」이다. 이 step은 기록을 넓히고 1주 동안 파일 크기 · 줄 수를 재는 것까지 하고, 회전은 값이 정해질 때까지 blocked로 둔다(blocked_reason에 실측 방법)
- `hypothesis-gate`는 원장 쓰기 실패를 한 줄로 남긴다(옛 캐시 폴더가 지워진 오래된 세션, B-11)
- 테스트 먼저: 훅마다 경로별 결과 이름 · 한 호출 한 줄 · 회전

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `bash hooks/test.sh 2>&1 | grep -F '[hook-log-all]'` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-018이 정한 값은 참조만 했는지 대조한다(값을 step에 복사하지 않는다).
3. 결과를 `phases/harness-checkup/index.json`의 step 3에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다.
- push · PR 금지(러너 밖에서 사람이 한다).
