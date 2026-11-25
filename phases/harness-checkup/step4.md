# Step 4: version-drift-notice

## 읽어야 할 파일

- `docs/harness-checkup-2026-11-25/ADR.md`(ADR-018 — A 정할 것 · B 판정표 · 시험 결과). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `hooks/cadence-reminder.sh` · `hooks/test.sh`의 cadence 검사(고치지 않는다)

## 작업

근거: ADR-018 B-10.

바꾸는 파일:

- `hooks/cadence-reminder.sh` · 새 `hooks/tests/version-drift.sh`

- 세션 시작 때 레포 `.claude/harness.json`의 `harness.version`이 설치본 `plugin.json` 버전과 다르면 한 줄: 「하네스 <레포> → <설치본>, /harness-init 업그레이드 모드」. 같으면 아무것도 안 낸다
- 테스트 먼저: 다름 → 한 줄 · 같음 → 0줄 · harness.json 없음 → 0줄

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `bash hooks/test.sh 2>&1 | grep -F '[version-drift]'` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-018이 정한 값은 참조만 했는지 대조한다(값을 step에 복사하지 않는다).
3. 결과를 `phases/harness-checkup/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다.
- push · PR 금지(러너 밖에서 사람이 한다).
