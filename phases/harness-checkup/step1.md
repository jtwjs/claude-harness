# Step 1: answer-key-0-41

## 읽어야 할 파일

- `docs/harness-checkup-2026-11-25/ADR.md`(ADR-018 — A 정할 것 · B 판정표 · 시험 결과). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `docs/harness-restructure-2026-11-24/trigger-eval/evals.json` · `README.md` · `run_trigger.py`

## 작업

근거: ADR-018 B-15.

바꾸는 파일:

- `docs/harness-restructure-2026-11-24/trigger-eval/evals.json`(정답 칸만) · 새 `docs/harness-restructure-2026-11-24/trigger-eval/rescore.py`

- 0.41.0에서 모델이 부를 수 있는 입구는 자동 입구 8개뿐이다(닫힌 스킬은 `disable-model-invocation: true`). 부정 문항 중 「닫힌 스킬의 몫이던 요청」을 가장 가까운 자동 입구 기준으로 다시 단다 — 바꾼 문항마다 이유 한 구절을 evals.json 옆 README 표에
- `rescore.py <결과.json> <evals.json>`: 기존 측정 원자료를 새 정답으로 다시 채점(재실행 없음). 0.41.0 After 원자료로 돌려 남는 오발동만 summary에
- tdd: false — 평가 재료와 채점 스크립트다(채점 결과를 summary 숫자로 대조)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `python3 docs/harness-restructure-2026-11-24/trigger-eval/rescore.py --help` exit 0

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-018이 정한 값은 참조만 했는지 대조한다(값을 step에 복사하지 않는다).
3. 결과를 `phases/harness-checkup/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다.
- push · PR 금지(러너 밖에서 사람이 한다).
