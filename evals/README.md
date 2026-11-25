# 하네스 덜기 점검 eval (ADR-018)

`claude plugin eval`로 같은 과제를 플러그인 있음 / 없음(기본 Claude)으로 돌려 점수 차이(Δ)를 본다. 판정 흐름과 결정(A1~A5)은 `docs/harness-checkup-2026-11-25/ADR.md` ADR-018이 정본이다. 이 폴더는 그 결정대로 만든 case와 돌리는 법만 둔다.

- 과제: 합성(A2 ①). 자동 입구 8개(`python3 scripts/always-on.py .`의 skill 목록)마다 떠야 할 과제 1개 + 안 떠야 할 과제 1개. 문장은 `docs/harness-restructure-2026-11-24/trigger-eval/evals.json` 정답표(0.41.0 기준으로 맞춘 것)에서 골랐다. `sdd`는 REVIEW 과제를 하나 더 둬서 `code-reviewer`를 잰다(ADR-018 B-2)
- 채점: 기본 모델이 안 하는 하네스 고유 결과만 본다. 전부 regex(결정적 채점기)라 LLM 채점기가 없다 → `--judge-model`이 필요 없다. 기본 모델도 하는 행동(요구사항부터 · 근거부터)은 기준으로 쓰지 않았다
- `fired`(`tool_used: Skill`, arm 없음)는 ablation에서 표시만 되고 점수에 안 들어간다. 안 떠야 할 과제의 `not-fired`는 `min: 0 · max: 0 · arm: both`라 두 쪽 모두 점수에 든다
- 턴 상한: 스킬 · 참조를 읽고도 답할 만큼(12 이상, git 과제 20, 리뷰 30). 턴 상한에 걸린 실행은 점수가 아니라 「무효」다 → `scripts/eval-tally.py`가 따로 센다
- 결과 + 실행 비용(A1 ②): `scripts/eval-tally.py`가 case · 쪽마다 유효 통과 · 무효 수 · 평균 $ · 턴 · 초와 Δ를 낸다(입력은 `--json` 출력)

## case 표

| case | 기대는 스킬 | 떠야 / 안 떠야 | outcome 채점기 (regex) | 부품 변형 (뺄 파일) |
|---|---|---|---|---|
| `sdd-fire-vague` | sdd | 떠야 (sdd#1) | `mirror-heard-gaps` 「들은 것 … 빈칸」 되비춤 · `asks-sources` 참고 자료를 묻나 | `skills/sdd/references/design.md` |
| `sdd-fire-review` | sdd | 떠야 (sdd#13) | `cites-violation` `OrderFilter.tsx:<줄>` · `axis-table` 축 표에 「위반」 (표시용 `reviewer-called` = Agent code-reviewer) | `agents/code-reviewer.md` |
| `sdd-quiet-concept` | sdd | 안 떠야 (sdd#14) | `no-design-flow` PRD · 수용 조건 · ARCHITECTURE 없음 · `not-fired` | — |
| `why-fire-claim` | why | 떠야 (why#9) | `verdict-table` 판정표(확인함/추정/모름/근거 필요) · `first-decision` 「회의 전」 한 줄 | `docs/principles/ask-questions.md` |
| `why-quiet-concept` | why | 안 떠야 (why#19) | `no-verdict-flow` · `not-fired` | — |
| `how-fire-placement` | how | 떠야 (how#3) | `cites-line` `파일:줄` 근거 · `answers-api` api 폴더로 답 | `docs/principles/INDEX.md` |
| `how-quiet-general` | how | 안 떠야 (how#18) | `no-code-walk` `파일:줄` 없음 · `not-fired` | — |
| `conductor-fire-contract` | conductor | 떠야 (conductor#4) | `contract-label` `contract-change` · `follow-up-issue` `follow-up` | `skills/conductor/references/decisions.md` |
| `conductor-quiet-metaphor` | conductor | 안 떠야 (conductor#14) | `no-track-flow` · `not-fired` | — |
| `slack-writing-fire-notice` | slack-writing | 떠야 (slack#1) | `no-greeting` 인사 · 맺음말 없음 · `no-em-dash` | `docs/principles/write-for-readers.md` |
| `slack-writing-quiet-oauth` | slack-writing | 안 떠야 (slack#18) | `answers-scope` `channels:history` · `not-fired` | — |
| `notion-writing-fire-proposal` | notion-writing | 떠야 (notion#6) | `machine-check` 「em dash 0」 검사 줄 · `decision-section` · `no-h1` | `docs/principles/write-for-readers.md` |
| `notion-writing-quiet-export` | notion-writing | 안 떠야 (notion#18) | `answers-export` · `not-fired` | — |
| `pr-write-fire-body` | pr-write | 떠야 (pr#1) | `risk-score` 「Risk Score」 · `merge-gate` 「자동 머지」 판정 | `skills/pr-write/references/risk-score.md` |
| `pr-write-quiet-convention` | pr-write | 안 떠야 (pr#19) | `no-pr-body` Risk Score 없음 · `not-fired` | — |
| `commit-fire-split` | commit | 떠야 (commit#2) | `plan-first` 커밋 계획(「포함 파일」) · `waits-approval` trace에 `git commit` 실행 없음 | `hooks/hooks.json` |
| `commit-quiet-hook` | commit | 안 떠야 (commit#16) | `answers-lint-staged` · `not-fired` | — |

- 괄호 = `evals.json`의 스킬 · 번호(1부터). 문장은 과제가 돌 만큼만 덧붙였다(예: why#9에 근거 주장 한 줄, notion#6에 항목 3개)
- 떠야 할 과제 9개(태그 `fire`) · 안 떠야 할 과제 8개(태그 `quiet`). 안 떠야 할 과제는 뺄 부품이 없어 변형을 두지 않는다
- `scaffold.sh`가 있는 4개(`sdd-fire-review` · `how-fire-placement` · `pr-write-fire-body` · `commit-fire-split`)는 실행 폴더에 작은 레포를 만든다 → `--scaffold`가 필요하다. git 과제 3개는 `allowed_tools`에 `Bash(git:*)`가 있어 `--allow-tools "Bash(git:*)"`가 필요하다

## 부품 변형

`bash scripts/eval-variant.sh <부품 경로>` → 임시 폴더에 플러그인 사본(git이 아는 파일, `evals/results/` 제외)을 만들고 그 파일을 지운 뒤 사본 경로를 출력한다. 레포 파일은 지우지 않는다.

eval에는 `--plugin-dir` 같은 옵션이 없다. 대상(target)을 경로로 받으므로(`claude plugin eval [target]`, `--help`) 출력 경로를 대상으로 준다. 사본 안의 `evals/`가 그대로 case가 된다. 변형은 `--ablation none`(있음 쪽 1벌만)으로 돌리고, 같은 case의 통째 실행 「있음」 점수와 비교한다: 있음 − 변형 = 그 부품의 몫.

## step 12 실행 명령

> 돌리기 전에 사람이 확인한다. 아래 명령은 돈을 쓴다.

```bash
OUT="$(mktemp -d)"   # 결과는 레포 밖에 둔다

# 1) 통째 비교 — 있음 / 없음
#    --tag 가 필요하다: 기본 탐색이 docs/harness-checkup-2026-11-25/evals/ 의 시험 case 3개도 함께 잡는다(태그 없음 → 빠짐)
#    --allow-tools 는 값을 여러 개 받으므로 맨 끝에 둔다
claude plugin eval . --ablation with-without --tag fire quiet --runs 3 -j 4 \
  --scaffold --trust-plugin --max-cost-usd 14 \
  --output-dir "$OUT/whole" --json "$OUT/whole.json" \
  --allow-tools "Bash(git:*)"

# 2) 부품 변형 — 떠야 할 과제마다 부품 하나를 뺀 사본, 있음 쪽만
while read -r c part; do
  v="$(bash scripts/eval-variant.sh "$part")"
  claude plugin eval "$v" --ablation none --case "$c" --runs 3 \
    --scaffold --trust-plugin --max-cost-usd 0.65 \
    --output-dir "$OUT/variant-$c" --json "$OUT/variant-$c.json" \
    --allow-tools "Bash(git:*)"
done <<'EOF'
sdd-fire-vague skills/sdd/references/design.md
sdd-fire-review agents/code-reviewer.md
why-fire-claim docs/principles/ask-questions.md
how-fire-placement docs/principles/INDEX.md
conductor-fire-contract skills/conductor/references/decisions.md
slack-writing-fire-notice docs/principles/write-for-readers.md
notion-writing-fire-proposal docs/principles/write-for-readers.md
pr-write-fire-body skills/pr-write/references/risk-score.md
commit-fire-split hooks/hooks.json
EOF

# 3) 무효(턴 상한) 분리 + 비용 · 턴 · 시간
python3 scripts/eval-tally.py "$OUT/whole.json" "$OUT"/variant-*.json
```

- LLM 채점기가 없어 `--judge-model`은 넣지 않았다. 나중에 llm 채점기를 넣으면 `--judge-model sonnet`을 붙인다(시험에서 haiku 3표가 갈렸다, ADR-018 「시험 결과」)
- 첫 실행 뒤 `aggregate-result.json`의 `suite.plugins`에 플러그인이 `problem` 없이 있는지 본다(없으면 있음 쪽이 플러그인 없이 돈 것)

## 예상 비용

회당 값은 ADR-018 「시험 결과」의 시험 1회 기준이다: 있음 ~$0.15 · 없음 ~$0.06. 변형은 있음과 같은 값으로 추정했다.

| 부분 | 계산 | 예상 |
|---|---|---|
| 통째 비교 | 17 case × 3회 × (있음 $0.15 + 없음 $0.06) | 약 $10.7 |
| 부품 변형 | 9 case × 3회 × 있음 $0.15 | 약 $4.1 |
| 합계 | | 약 $14.8 (A4 상한 $20 안) |

[추정] 시험 case는 읽기만 하는 짧은 과제였다. git 과제 4개(scaffold, 턴 상한 20~30)는 회당 값이 이보다 클 수 있다. 그래서 명령에 상한을 나눠 걸었다(통째 $14 + 변형 9 × $0.65 ≈ $19.9). 상한에 걸리면 eval이 남은 실행을 건너뛰고 부분 결과로 끝난다(exit 2).

상한을 넘을 것 같으면 줄이는 순서:

1. 안 떠야 할 과제를 2회로: `--tag quiet --runs 2`를 따로 돌린다(8 × 1회 × $0.21 ≈ $1.7 줄어듦)
2. 변형은 통째 비교에서 있음 ≥ 없음이 나온 case만 돌린다(있음 < 없음이면 부품보다 진입부터 본다)
3. git 과제 4개를 첫 회에서 빼고(`--tag fire quiet` 대신 `--case` 로 나머지만) 첫 결과의 회당 값을 본 뒤 따로 돌린다

## 형식 확인 (돈 안 씀)

`--max-cost-usd 0`이면 첫 실행 전에 상한에 걸려 아무것도 돌지 않는다. case 파싱 · 도구 허가 경고만 본다.

```bash
claude plugin eval . --tag fire quiet --scaffold --trust-plugin --no-publish \
  --max-cost-usd 0 --output-dir "$(mktemp -d)" --allow-tools "Bash(git:*)"
# → "Ablation: 2 arms × 17 cases (102 runs)" · "cost ceiling $0 hit", 허가 경고(⚠ case …) 없음
```
