# Step 8: tally-outcome

## 읽어야 할 파일

- `docs/outcome-eval-2026-11-26/ADR.md`(ADR-020). 이 폴더의 설계 문서는 ADR 한 장이고 루트 `CLAUDE.md`는 없다
- `.claude/rules/non-obvious-patterns.md`
- `scripts/eval-tally.py`
- step 7 summary의 결과 폴더(`--json` 출력 · trace.jsonl)

## 작업

- `scripts/eval-tally.py`에 더한다: 에이전트 비용(`costUsd` − `judgeCostUsd`)과 채점비를 나눈 열 · 발동한 실행 수 · 갈린 표가 있는 채점 수 · 작업 모델(trace의 `model`). 값이 없는 옛 결과는 `-`로 두고 기존 열 · Δ 계산은 그대로
- 필드 이름은 step 7의 실제 결과에서 확인한다(지어내지 않는다). 결과 파일이 없으면 `blocked`
- tdd: false. 검사 스크립트의 테스트를 `hooks/test.sh`가 돌리지 않고 `hooks/`는 이번 범위 밖이라, AC의 직접 실행으로 확인한다.

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `heredoc`으로 만든 작은 결과 JSON(채점비 있는 실행 1 · 없는 실행 1)을 넣어 두 비용 열의 값이 손 계산과 같음
- 첫 점검과 같은 모양의 JSON(새 필드 없음)도 오류 없이 돌아감

## 검증 절차

1. 위 AC 명령을 실제 실행하고 출력을 확인한다.
2. ADR-020이 정한 값(모델 · 회차 · 상한 · 판정 규칙)은 참조만 하고 파일에 복사한 곳이 있으면 대조한다. 대기 중인 결정이 필요하면 `blocked`로 기록한다.
3. 결과를 `phases/outcome-eval/index.json`의 step 8에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가 · 차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- 스킬 · 에이전트 · 훅(`hooks/`) · 러너 · `harness-doctor`를 고치지 않는다. 바꾸는 곳은 `evals/` · `scripts/eval-tally.py` · `docs/outcome-eval-2026-11-26/` · `phases/outcome-eval/`뿐이다
- 발동 점검 case(`evals/*-fire-*` · `evals/*-quiet-*`)는 고치지 않는다
- 채점 기준과 과제는 스킬 본문을 정답으로 삼지 않는다(ADR-020 ②)
- 승인 줄(`docs/outcome-eval-2026-11-26/RUNS.md`)이 없는 돈 드는 `claude plugin eval` · `claude -p`는 돌리지 않는다. 승인 줄은 지휘가 전한 사용자 확인을 직접 받지 않았으면 쓰지 않는다
- 사람 · 회사 이름, 개인 문서 문구, 개인 경로를 레포 파일에 쓰지 않는다(공개 레포, 「사용자」로 쓴다)
- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 금지. 쌓기만 하는 기록(`docs/`의 지난 설계 · 다른 `phases/*/`)은 고치지 않는다
- push · PR 금지
