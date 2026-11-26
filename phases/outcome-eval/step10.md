# Step 10: segment-criteria

## 읽어야 할 파일

- `docs/outcome-eval-2026-11-26/ADR.md`(ADR-020). 이 폴더의 설계 문서는 ADR 한 장이고 루트 `CLAUDE.md`는 없다
- `.claude/rules/non-obvious-patterns.md`
- `evals/outcome-*/prompt.md` · `READER.md`

## 작업

- ADR-020 ② A. 초안은 case마다 1건, 빈 임시 폴더에서 설정 · 플러그인을 끈 `claude -p --safe-mode --tools ""`로 받는다. 입력은 지문 + 받는 사람뿐이다. 모델은 ②, `--max-budget-usd` 합이 ADR-020 상한 표를 넘지 않게 한다
- 돈 드는 호출 전에 `docs/outcome-eval-2026-11-26/RUNS.md`의 승인 줄 확인. 없으면 `blocked`
- 첫 호출 기록으로 전역 지시 · 플러그인 · 스킬이 실리지 않았음을 확인한다. 실렸으면 멈추고 `blocked`
- 초안을 `docs/outcome-eval-2026-11-26/criteria/<case>.md`에 저장하고 사용자 확정을 기다린다(`blocked` 「사용자 확정 대기」). 파일 머리에 확정 표시가 생기면 그 문장대로 `llm` 채점기를 만든다. 확정 문장을 임의로 고치지 않는다
- 기준마다 지문의 필요한 사실과 겉모양 제외 문장을 넣는다(②)
- tdd: false. eval 재료다. `verify.test`가 돌리는 테스트 대상이 아니다.

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 형식 확인(돈 안 씀): `claude plugin eval . --tag outcome --scaffold --trust-plugin --no-publish --max-cost-usd 0 --output-dir "$(mktemp -d)"`(허가가 필요한 도구가 있으면 맨 끝에 `--allow-tools`(`RUNS.md` 「허가 옵션」)) → exit 2 · 「cost ceiling $0 hit」 · case 파싱 오류 없음
- 허가 확인(돈 안 씀): `RUNS.md` 「허가 옵션」의 case 하나씩 확인에서 태그 `outcome`의 모든 case가 `OK`이고 줄 수가 위 출력의 case 수와 같음
- `python3 evals/check_outcome.py --require-graders` exit 0

## 검증 절차

1. 위 AC 명령을 실제 실행하고 출력을 확인한다.
2. ADR-020이 정한 값(모델 · 회차 · 상한 · 판정 규칙)은 참조만 하고 파일에 복사한 곳이 있으면 대조한다. 대기 중인 결정이 필요하면 `blocked`로 기록한다.
3. 결과를 `phases/outcome-eval/index.json`의 step 10에 기록:
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
