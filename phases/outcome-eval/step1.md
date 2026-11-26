# Step 1: outcome-check

## 읽어야 할 파일

- `docs/outcome-eval-2026-11-26/ADR.md`(ADR-020). 이 폴더의 설계 문서는 ADR 한 장이고 루트 `CLAUDE.md`는 없다
- `.claude/rules/non-obvious-patterns.md`
- `evals/README.md`
- `evals/*-fire-*/graders/`(첫 점검 채점기의 문구)

## 작업

- 새 `evals/check_outcome.py`(표준 라이브러리만, 돈 안 씀). 위반이 있으면 파일 · 이유를 출력하고 exit 1
  - `evals/outcome-*`의 `llm` 채점기: case마다 개수가 ADR-020 ② 규칙 안 · 기준 문장에 첫 점검 채점기 문구가 없음 · 겉모양 제외 문장이 있음. 채점기가 아직 없는 case는 `--require-graders`일 때만 실패
  - 이력 파일(`evals/**/history*.jsonl`): ADR-020 ④-b 2번의 항목이 전부 0건
  - `--self-test`: 임시 폴더에 어긴 예(스킬 본문 한 줄을 심은 이력 · 금지 문구가 든 기준)를 만들어 둘 다 걸리고, 깨끗한 예는 통과함을 확인
- tdd: false. 검사 스크립트의 테스트를 `hooks/test.sh`가 돌리지 않고 `hooks/`는 이번 범위 밖이라, AC의 직접 실행으로 확인한다.

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 evals/check_outcome.py --self-test` exit 0
- `python3 evals/check_outcome.py` exit 0

## 검증 절차

1. 위 AC 명령을 실제 실행하고 출력을 확인한다.
2. ADR-020이 정한 값(모델 · 회차 · 상한 · 판정 규칙)은 참조만 하고 파일에 복사한 곳이 있으면 대조한다. 대기 중인 결정이 필요하면 `blocked`로 기록한다.
3. 결과를 `phases/outcome-eval/index.json`의 step 1에 기록:
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
