# Step 3: sandbox-git

## 읽어야 할 파일

- `docs/outcome-eval-2026-11-26/ADR.md`(ADR-020). 이 폴더의 설계 문서는 ADR 한 장이고 루트 `CLAUDE.md`는 없다
- `.claude/rules/non-obvious-patterns.md`
- `evals/how-fire-placement/scaffold.sh`
- `docs/harness-checkup-2026-11-25/ADR.md` 「첫 점검 결과」

## 작업

- 준비물 「샌드박스 git」(ADR-020 ①-b)
- 새 `evals/_lib/shell-env.sh`: `$HOME`의 `.zshenv` · `.zprofile` · `.zshrc`에 Command Line Tools git 경로를 PATH 앞에 두는 줄을 쓴다. `$HOME`이 임시 eval 홈이 아니면(`$HOME/.gitconfig`의 eval 표식 또는 `/e-` 임시 경로로 판정) 아무것도 쓰지 않고 실패한다. 실제 홈의 시작 파일을 덮지 않기 위한 규칙이다
- case의 `scaffold.sh`가 `$0` 기준 상대 경로로 부른다. `_lib`이 case로 잡히거나 상대 경로가 안 되면 case 폴더마다 복사하는 방식으로 바꾼다
- 멈춤선: 유료 확인(step 7)에서 git이 안 되면 `sdd` 흐름은 git이 필요 없는 단계(`sdd`-2)까지만 만든다. `sdd`-3 · 4는 「안 잼」. 구간 case의 git 의존 채점은 빼고 한계를 결과에 적는다
- tdd: false. eval 재료다. `verify.test`가 돌리는 테스트 대상이 아니다.

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 임시 홈에서 `shell-env.sh`를 실행한 뒤 `zsh -c` · `-lc` · `-ic` · `-lic` 네 방식의 `command -v git`이 Command Line Tools 경로
- 임시 홈이 아닌 경로를 `HOME`으로 주면 exit 0이 아니고 파일이 안 바뀜

## 검증 절차

1. 위 AC 명령을 실제 실행하고 출력을 확인한다.
2. ADR-020이 정한 값(모델 · 회차 · 상한 · 판정 규칙)은 참조만 하고 파일에 복사한 곳이 있으면 대조한다. 대기 중인 결정이 필요하면 `blocked`로 기록한다.
3. 결과를 `phases/outcome-eval/index.json`의 step 3에 기록:
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
