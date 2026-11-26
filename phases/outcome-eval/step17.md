# Step 17: record-results

## 읽어야 할 파일

- `docs/outcome-eval-2026-11-26/ADR.md`(ADR-020). 이 폴더의 설계 문서는 ADR 한 장이고 루트 `CLAUDE.md`는 없다
- `.claude/rules/non-obvious-patterns.md`
- step 6 · 7 · 11 · 13 · 15 · 16 summary
- `evals/README.md`

## 작업

- 새 `docs/outcome-eval-2026-11-26/RESULTS.md`: 스킬 × 쪽의 통과 판정 수 · 에이전트 비용 · 채점비 · 묶음마다 잰 커밋(`HEAD` · `HEAD:skills`) · 안 잰 것과 이유. 덜기 판정 칸은 비워 사용자가 확정한다(ADR-018 판정 흐름). 흐름 결과 옆에 「단계를 끊어 잰 값」 한계를 적는다
- 새 `evals/baseline.json`(ADR-020 ⑤-2): `fire` · `outcome` 칸마다 작업 모델 · Claude Code 버전 · 채점 모델 · 날짜. `outcome`은 이번 실행 기록에서(실행마다 잰 커밋을 `commit` · `skills_tree` 키로), `fire`는 `docs/harness-checkup-2026-11-25/ADR.md`의 첫 점검 기록에서 옮기고 거기 없는 값은 `null`. 읽는 쪽(#61)은 만들지 않는다
- `evals/README.md`에 「결과 채점」 절(명령 · 태그 · 돈 안 쓰는 확인 · 항상 `--tag`를 줄 것). 발동 점검 명령은 ADR-020 ⑤-1b의 결정대로 고치고, 돈 드는 `fire` · 부품 변형 명령에는 `--model claude-opus-5-5`를 넣는다(ADR-020 ⑤-1 「발동 점검」)
- ADR-020 ⑤-1b 구현: 취향 스킬 4개(`pr-write` · `commit` · `slack-writing` · `notion-writing`)의 case 8개에서 `prompt.md`의 `tags`를 `[fire]` → `[taste-fire]`, `[quiet]` → `[taste-quiet]`로 바꾼다. README에는 이 8개를 있음 쪽만 1회 도는 명령 하나(`--tag taste-fire taste-quiet --ablation none --runs 1`)를 더하고, 부품 변형 목록에서 4개를 뺀다. case 표 · 개수 · 형식 확인의 예상 출력 · 예상 비용도 맞춘다
- README의 eval 명령은 `RUNS.md` 「허가 옵션」대로 `--allow-tools`를 넣는다
- 쓰는 숫자는 결과 파일에서 온 것만
- tdd: false. eval 재료다. `verify.test`가 돌리는 테스트 대상이 아니다.

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `RESULTS.md`의 통과 판정 수 · 비용이 `scripts/eval-tally.py` 출력과 같음(명령 출력과 대조)
- `python3 evals/check_outcome.py --require-graders` exit 0
- `evals/README.md`의 `fire` · 부품 변형 · 결과 채점 본 실행 명령마다 `--model claude-opus-5-5`가 있음(채점기 시험 · 환경 확인 명령과 `--max-cost-usd 0` 형식 확인은 제외)
- `python3 -c "import json; d = json.load(open('evals/baseline.json')); d['fire']; d['outcome']"` exit 0
- `evals/baseline.json`의 `commit` · `skills_tree`와 `RESULTS.md`의 잰 커밋이 step 11 · 15 · 16 summary와 같음(안 돌린 묶음은 제외)
- ⑤-1b: `grep -lE '^tags: \[taste-(fire|quiet)\]' evals/*/prompt.md | wc -l`이 8
- ⑤-1b: `git diff -U0 "$(git merge-base origin/main HEAD)" -- 'evals/*-fire-*' 'evals/*-quiet-*' | grep -E '^[-+]' | grep -vE '^(\+\+\+ b/|--- a/|\+\+\+ /dev/null|--- /dev/null)' | grep -vcE '^[-+]tags: '`이 0이고, `git ls-files --others --exclude-standard -- 'evals/*-fire-*' 'evals/*-quiet-*'` 출력이 없음(tags 줄만 바뀜)
- ⑤-1b: README의 부품 변형 목록에 취향 스킬 case가 없고, `--tag taste-fire taste-quiet` 명령에 `--ablation none --runs 1`이 있음
- 형식 확인(돈 안 씀): `claude plugin eval . --tag taste-fire taste-quiet --scaffold --trust-plugin --no-publish --max-cost-usd 0 --output-dir "$(mktemp -d)" --allow-tools "Bash(git:*)"` → 8개 case · 「cost ceiling $0 hit」 · 허가 경고 없음. `--tag fire quiet`는 9개 case

## 검증 절차

1. 위 AC 명령을 실제 실행하고 출력을 확인한다.
2. ADR-020이 정한 값(모델 · 회차 · 상한 · 판정 규칙)은 참조만 하고 파일에 복사한 곳이 있으면 대조한다. 대기 중인 결정이 필요하면 `blocked`로 기록한다.
3. 결과를 `phases/outcome-eval/index.json`의 step 17에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가 · 차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- 스킬 · 에이전트 · 훅(`hooks/`) · 러너 · `harness-doctor`를 고치지 않는다. 바꾸는 곳은 `evals/` · `scripts/eval-tally.py` · `docs/outcome-eval-2026-11-26/` · `phases/outcome-eval/`뿐이다
- 발동 점검 case(`evals/*-fire-*` · `evals/*-quiet-*`)는 고치지 않는다. 예외(ADR-020 ⑤-1b 구현, 이 step만): 취향 스킬 case 8개의 `prompt.md` `tags` 줄
- 채점 기준과 과제는 스킬 본문을 정답으로 삼지 않는다(ADR-020 ②)
- 승인 줄(`docs/outcome-eval-2026-11-26/RUNS.md`)이 없는 돈 드는 `claude plugin eval` · `claude -p`는 돌리지 않는다. 승인 줄은 지휘가 전한 사용자 확인을 직접 받지 않았으면 쓰지 않는다
- 사람 · 회사 이름, 개인 문서 문구, 개인 경로를 레포 파일에 쓰지 않는다(공개 레포, 「사용자」로 쓴다)
- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 금지. 쌓기만 하는 기록(`docs/`의 지난 설계 · 다른 `phases/*/`)은 고치지 않는다
- push · PR 금지
