# Step 12: stage-split

## 읽어야 할 파일

- `docs/outcome-eval-2026-11-26/ADR.md`(ADR-020). 이 폴더의 설계 문서는 ADR 한 장이고 루트 `CLAUDE.md`는 없다
- `.claude/rules/non-obvious-patterns.md`
- `evals/check_outcome.py`
- step 7 summary의 `--keep-temp` 샌드박스 `config/` 안 대화 기록(필드 모양만 보고 내용은 옮기지 않는다)

## 작업

- 준비물 「단계 분할」(ADR-020 ①-b)과 이력 오염 확인 case(④-b)
- 새 `evals/probe-history/`(태그 `probe-history`): 손으로 쓴 중립 `history.jsonl`(가상의 요청 1 · 답 1) + `context.history_file`. 지문은 「지금 쓸 수 있는 스킬 이름을 모두 적어 줘」. 채점기는 답과 trace에서 `claude-harness:` 이름을 찾는 regex
- 단계마다 case를 두고 앞 결과를 파일로 넘기는 규칙을 `evals/README.md` 「결과 채점」 절에 적는다. 이력은 파일로 못 넘기는 단계에만 쓴다
- 멈춤선: 이력이 안 읽히거나 없음 쪽에 섞이면(step 13) 파일로만 넘긴다. 파일로도 못 넘기는 단계는 만들지 않고, 남는 것은 첫 구간까지
- tdd: false. eval 재료다. `verify.test`가 돌리는 테스트 대상이 아니다.

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 형식 확인(돈 안 씀): `claude plugin eval . --tag probe-history --scaffold --trust-plugin --no-publish --max-cost-usd 0 --output-dir "$(mktemp -d)"` → exit 2 · 「cost ceiling $0 hit」 · case 파싱 오류와 허가 경고 없음
- `python3 evals/check_outcome.py --self-test` · `python3 evals/check_outcome.py` exit 0

## 검증 절차

1. 위 AC 명령을 실제 실행하고 출력을 확인한다.
2. ADR-020이 정한 값(모델 · 회차 · 상한 · 판정 규칙)은 참조만 하고 파일에 복사한 곳이 있으면 대조한다. 대기 중인 결정이 필요하면 `blocked`로 기록한다.
3. 결과를 `phases/outcome-eval/index.json`의 step 12에 기록:
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
