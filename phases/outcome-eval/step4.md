# Step 4: fake-gh

## 읽어야 할 파일

- `docs/outcome-eval-2026-11-26/ADR.md`(ADR-020). 이 폴더의 설계 문서는 ADR 한 장이고 루트 `CLAUDE.md`는 없다
- `.claude/rules/non-obvious-patterns.md`
- `evals/_lib/shell-env.sh`
- `evals/conductor-fire-contract/prompt.md`

## 작업

- 준비물 「가짜 gh」(ADR-020 ①-b)
- 새 `evals/_lib/fake-gh`: `issue create|list|view|edit|comment|close` · `label list|create` · `repo view`에 최소 응답, 그 밖은 오류. 모든 호출의 인자를 실행 폴더의 `gh-calls.log`에 한 줄씩 적는다. 상태는 실행 폴더 파일에 둔다. 네트워크를 쓰지 않는다
- `shell-env.sh`가 `$HOME/bin/gh`로 설치하고 PATH 앞에 두며, 시작 파일에서 `GH_TOKEN` · `GH_HOST`를 쓸 수 없는 값으로 둔다
- 🔴 확인 전에는 어떤 case에도 `gh` 실행 허가를 주지 않는다. 실제 `gh`가 잡히면 바깥에 이슈가 생길 수 있다
- 멈춤선: 유료 확인(step 7)에서 가짜가 먼저 안 잡히면 `conductor`는 이슈 초안 텍스트(구간)까지만 재고 흐름 2단계는 「안 잼」. `Bash(gh:*)` 허가를 주지 않는다
- tdd: false. eval 재료다. `verify.test`가 돌리는 테스트 대상이 아니다.

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 임시 홈에서 네 방식의 `command -v gh`가 임시 홈의 `bin/gh`
- 절대 경로로 부른 가짜(`"$tmp_home/bin/gh" issue create --title t --body b`)가 `gh-calls.log`에 한 줄을 남김

## 검증 절차

1. 위 AC 명령을 실제 실행하고 출력을 확인한다.
2. ADR-020이 정한 값(모델 · 회차 · 상한 · 판정 규칙)은 참조만 하고 파일에 복사한 곳이 있으면 대조한다. 대기 중인 결정이 필요하면 `blocked`로 기록한다.
3. 결과를 `phases/outcome-eval/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가 · 차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- AC · 검증에서도 이름 `gh`로 명령을 실행하지 않는다. `command -v`와 가짜의 절대 경로만 쓴다
- 스킬 · 에이전트 · 훅(`hooks/`) · 러너 · `harness-doctor`를 고치지 않는다. 바꾸는 곳은 `evals/` · `scripts/eval-tally.py` · `docs/outcome-eval-2026-11-26/` · `phases/outcome-eval/`뿐이다
- 발동 점검 case(`evals/*-fire-*` · `evals/*-quiet-*`)는 고치지 않는다
- 채점 기준과 과제는 스킬 본문을 정답으로 삼지 않는다(ADR-020 ②)
- 승인 줄(`docs/outcome-eval-2026-11-26/RUNS.md`)이 없는 돈 드는 `claude plugin eval` · `claude -p`는 돌리지 않는다. 승인 줄은 지휘가 전한 사용자 확인을 직접 받지 않았으면 쓰지 않는다
- 사람 · 회사 이름, 개인 문서 문구, 개인 경로를 레포 파일에 쓰지 않는다(공개 레포, 「사용자」로 쓴다)
- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 금지. 쌓기만 하는 기록(`docs/`의 지난 설계 · 다른 `phases/*/`)은 고치지 않는다
- push · PR 금지
