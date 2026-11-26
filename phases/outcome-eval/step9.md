# Step 9: segment-cases

## 읽어야 할 파일

- `docs/outcome-eval-2026-11-26/ADR.md`(ADR-020). 이 폴더의 설계 문서는 ADR 한 장이고 루트 `CLAUDE.md`는 없다
- `.claude/rules/non-obvious-patterns.md`
- `evals/README.md`
- 발동 case의 `prompt.md` · `scaffold.sh`(`sdd-fire-vague` · `how-fire-placement` · `why-fire-claim` · `conductor-fire-contract`)

## 작업

- 구간 case 8개 `evals/outcome-<skill>-<task>/`: `sdd` · `conductor` 2개씩(태그 `outcome` `outcome-core`), `why` · `how` 2개씩(태그 `outcome` `outcome-extra`). 지문 · `scaffold.sh` · 발동 표시 채점기(`tool_used: Skill`)만 만들고 `llm` 채점기는 step 10에서 넣는다
- 지문에 스킬 이름 · 스킬 산출물 이름을 쓰지 않는다. 풀 정보는 지문과 scaffold 안에 둔다(두 쪽이 같은 것을 본다). 가상의 작은 프로젝트로 만든다
- `scaffold.sh`가 있는 case는 step 7에서 「됨」인 준비물만 부른다
- 받는 사람 한 명과 「받는 사람이 알아야 · 할 수 있어야 하는 것」을 case 옆 `READER.md`에 적는다(ADR-020 ②)
- tdd: false. eval 재료다. `verify.test`가 돌리는 테스트 대상이 아니다.

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 형식 확인(돈 안 씀): `claude plugin eval . --tag outcome --scaffold --trust-plugin --no-publish --max-cost-usd 0 --output-dir "$(mktemp -d)"`(허가가 필요한 도구가 있으면 맨 끝에 `--allow-tools`(`RUNS.md` 「허가 옵션」)) → exit 2 · 「cost ceiling $0 hit」 · case 파싱 오류 없음
- 허가 확인(돈 안 씀): `RUNS.md` 「허가 옵션」의 case 하나씩 확인에서 태그 `outcome`의 모든 case가 `OK`이고 줄 수가 위 출력의 case 수와 같음
- `ls -d evals/outcome-*` 8개 · `python3 evals/check_outcome.py` exit 0

## 검증 절차

1. 위 AC 명령을 실제 실행하고 출력을 확인한다.
2. ADR-020이 정한 값(모델 · 회차 · 상한 · 판정 규칙)은 참조만 하고 파일에 복사한 곳이 있으면 대조한다. 대기 중인 결정이 필요하면 `blocked`로 기록한다.
3. 결과를 `phases/outcome-eval/index.json`의 step 9에 기록:
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
