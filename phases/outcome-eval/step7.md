# Step 7: env-probe-run

## 읽어야 할 파일

- `docs/outcome-eval-2026-11-26/ADR.md`(ADR-020). 이 폴더의 설계 문서는 ADR 한 장이고 루트 `CLAUDE.md`는 없다
- `.claude/rules/non-obvious-patterns.md`
- `evals/probe-env/CHECKS.md`

## 작업

- 실행 전 확인: `docs/outcome-eval-2026-11-26/RUNS.md`에 이 실행의 승인 줄(실행 이름 · 상한 · 확인한 날)이 있어야 한다. 줄은 지휘가 전한 사용자 확인을 직접 받은 세션만 쓴다. 줄이 없거나 지휘의 시작 신호 전이면 명령을 돌리지 않고 `blocked`(「승인 대기: <실행 이름>」)로 기록한다
- `-j`는 ADR-020 「본 실행 전의 유료 실행」의 값 이하. 한도 오류(`You've hit your 5-hour limit`)가 나면 멈추고 그때까지 결과를 적은 뒤 `blocked`
- 모델은 전체 ID로 적는다. 결과 폴더는 레포 밖(`mktemp -d`)에 두고 경로를 summary에 남긴다
- 실행 뒤 승인 줄의 「실제 비용」 · 「결과 한 줄」 칸만 채운다
- 헤드리스 러너의 기본 제한 시간(1800초)을 넘길 수 있으면 세션에서 직접 돌린다(`python3 skills/sdd-run/scripts/sdd_runner.py prompt outcome-eval`로 지시문을 받는다)
- `--ablation none --tag probe-env --runs 1 --keep-temp`, 작업 모델은 ADR-020 「본 실행 전의 유료 실행」의 것
- 실행 기록을 직접 읽고 네 항목을 각각 됨 / 안 됨으로 적는다: git · 가짜 `gh` · 과정 채점기 · 단계 문서 읽기. 안 된 항목은 해당 step의 멈춤선을 그대로 적용한다
- 단계 문서를 못 읽으면 `blocked`(ADR-020 ①-b: 본 실행 전에 지휘에 다시 묻는다)
- 같은 실패가 2번이면 `blocked`
- tdd: false. 측정 전용(`kind: measure`)이라 테스트 단계가 없다.

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- summary에 명령(백틱) · 네 항목의 됨 / 안 됨과 근거 한 줄 · 적용한 멈춤선 · 결과 폴더 경로 · 실제 비용

## 검증 절차

1. 위 AC 명령을 실제 실행하고 출력을 확인한다.
2. ADR-020이 정한 값(모델 · 회차 · 상한 · 판정 규칙)은 참조만 하고 파일에 복사한 곳이 있으면 대조한다. 대기 중인 결정이 필요하면 `blocked`로 기록한다.
3. 결과를 `phases/outcome-eval/index.json`의 step 7에 기록:
   - 성공 → `status:"completed"` + `summary`에 돌린 명령(백틱)과 결과
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
