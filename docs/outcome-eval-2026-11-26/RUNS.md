# 유료 실행 승인 · 기록 (outcome-eval)

돈 드는 `claude plugin eval` · `claude -p`는 아래 표에 승인 줄이 있어야 돌린다. 승인 줄은 지휘가 전한 사용자 확인을 직접 받은 세션만, 받은 값 그대로 쓴다. 전달을 받지 않은 실행(헤드리스 step 등)은 「승인」 칸을 쓰지 않는다. 상한 · 회차는 ADR-020이 정본이다.

| 실행 이름 | 상한(USD) | 승인(확인한 날 · 전한 곳) | 실제 비용 | 결과 한 줄 |
|---|---|---|---|---|
| 끌림 sonnet (ADR-020 ④) | 2.0 | 사용자(AI 추천 수용), 2026-11-26 지휘 전달. 시작 신호도 지휘 전달(같은 날) | 2.34 | 8/10회에서 상한 도달(exit 2), 칸마다 24표라 판정 안 함. 오류 0. c1 · c2 96표 전부 기대대로. c4 PASS a 5/24 · b 14/24, 나머지 칸 갈린 표 0 |
| 끌림 haiku (ADR-020 ④) | 0.5 | 사용자(AI 추천 수용), 2026-11-26 지휘 전달. 시작 신호도 지휘 전달(같은 날) | 0.13 | 10/10회 완료, 칸마다 30표. 오류 0 · 건너뛴 채점 0. c1 · c2 120표 전부 기대대로, 갈린 표 합 0, 끌림 0(c4도 a · b 30/30). exit 1은 c2가 기대 FAIL이라 case가 통과 못 한 것 |
| 거름 확인 haiku (ADR-020 ④-c) | 0.5 | 사용자(AI 추천 수용), 2026-11-26 지휘 전달(시작 신호 겸) | 0.05 | 10/10회 완료, 칸마다 30표. 오류 0 · 건너뛴 채점 0. PASS c3(확실 · 확인 필요) 4/30 · c4(먼저 할 일) 0/30, 둘 다 합격. exit 1은 두 채점기가 기대 FAIL |

명령(끌림 두 줄, 레포 루트에서, `<M>` · `<상한>`은 표의 끌림 두 줄: `claude-sonnet-5-5` · 2.0, `claude-haiku-5-5` · 0.5). 하나가 끝난 뒤 다음을 돌린다.

```
D="$(mktemp -d)"; claude plugin eval . --tag probe-bias --ablation none --model claude-haiku-5-5 --judge-model <M> --runs 10 -j 2 \
  --scaffold --trust-plugin --no-publish --keep-temp --max-cost-usd <상한> --json "$D/result.json" --output-dir "$D"; echo "$D"
```

세는 법(실행 전에 고정). 칸(기준 × 파일)은 30표다. 30표가 안 되는 칸이 있으면(상한에 걸려 건너뜀 · 채점 오류) 판정하지 않는다. 「갈린 표 합」은 칸마다 적은 쪽 표 수를 더한 값이고(ADR-020 ③), 「끌림」은 `a` · `b` PASS 표 차이 9 이상이다(④).

```
python3 - "$D/result.json" <<'EOF'
import json, sys
r = json.load(open(sys.argv[1])); cell = {}
for run in r["cases"][0]["arms"]["with"]:
    for g in run["graders"]:
        cell.setdefault(g["name"], []).extend(g.get("judgeVotes") or [])
for n in sorted(cell): v = cell[n]; print(n, f"PASS {sum(v)}/{len(v)}")
print("갈린 표 합", sum(min(sum(v), len(v) - sum(v)) for v in cell.values()))
for i in range(1, 5):
    diff = abs(sum(cell[f"c{i}-a"]) - sum(cell[f"c{i}-b"])); print(f"c{i} 차이 {diff}", "끌림" if diff >= 9 else "")
print("30표 안 되는 칸", [n for n, v in cell.items() if len(v) != 30], "비용", r["costUsd"], "중단", r.get("partialReason"))
EOF
```

### 거름 확인 (ADR-020 ④-c, 합격선은 실행 전에 고정)

`evals/probe-judge-strict/`의 답은 「먼저 할 일」을 가리키는 문장과 확인 정도 표시를 뺀 것이라 두 기준 모두 기대가 FAIL이다. **합격: 기준마다 30표 중 PASS 9표 이하.** 한 기준이라도 10표 이상이면 haiku로 확정하지 않고 결과와 선택지(sonnet 채점 / 기준 문장 수정)를 지휘에 보낸다. 30표가 안 되는 칸이 있으면 판정하지 않는다.

```
D="$(mktemp -d)"; claude plugin eval . --tag probe-strict --ablation none --model claude-haiku-5-5 --judge-model claude-haiku-5-5 --runs 10 -j 2 \
  --scaffold --trust-plugin --no-publish --keep-temp --max-cost-usd 0.5 --json "$D/result.json" --output-dir "$D"; echo "$D"
```

```
python3 - "$D/result.json" <<'EOF'
import json, sys
r = json.load(open(sys.argv[1])); cell = {}
for run in r["cases"][0]["arms"]["with"]:
    for g in run["graders"]:
        cell.setdefault(g["name"], []).extend(g.get("judgeVotes") or [])
for n in sorted(cell):
    v = cell[n]; print(n, f"PASS {sum(v)}/{len(v)}", "판정 안 함" if len(v) != 30 else ("합격" if sum(v) <= 9 else "불합격"))
print("비용", r["costUsd"], "중단", r.get("partialReason"))
EOF
```

## 본 실행 · 파일럿 명령 틀 (ADR-020 ⑤-1)

작업 모델은 `claude-opus-5-5`를 명시한다(빼지 않는다). 파일럿은 `<회차>` 1, 본 실행은 3. case에 필요한 옵션은 그 step이 더한다. 채점기 시험 · 환경 · 이력 오염 확인은 작업 모델이 `claude-haiku-5-5`다.

```
D="$(mktemp -d)"; claude plugin eval . --tag <tag> --ablation with-without --model claude-opus-5-5 --judge-model claude-haiku-5-5 --runs <회차> -j 2 \
  --scaffold --trust-plugin --no-publish --keep-temp --max-cost-usd <넘기는 값> --json "$D/result.json" --output-dir "$D" \
  --allow-tools <허가 도구>; echo "$D"
```

### 허가 옵션

case의 `allowed_tools`에 `Bash(…)` · `Write` · `Edit` · `WebFetch` · `mcp__*`가 있으면 `--allow-tools`(값 여러 개, 맨 끝)로 고른 case들의 그 항목을 전부 넘긴다. case에 적힌 값보다 넓히지 않는다. 그런 항목이 없으면 옵션을 뺀다. 빠진 도구는 거부된 채 돈다.

돈 쓰기 전에 허가를 case 하나씩 확인한다(돈 안 씀). 여러 case를 한 번에 돌리면 `not granted` 경고가 다 나오지 않는다(2026-11-26 확인: 17개 중 허가가 필요한 3개 가운데 1개만 경고, 태그를 바꾼 9개에서는 1개가 필요한데 0). 통과: 모든 줄이 `OK`이고, 줄 수가 같은 대상을 한 번에 돌린 `--max-cost-usd 0` 출력의 case 수와 같다. 아니면 돌리지 않는다.

```
A=(--allow-tools <허가 도구>)   # 허가할 것이 없으면 A=()
# case 이름: 태그로 고르면 아래처럼(<태그>는 fire|quiet 꼴), --case로 돌릴 실행은 그 이름만
for c in $(grep -lE '^tags: .*[[ ,](<태그>)[],]' evals/*/prompt.md | xargs -n1 dirname | xargs -n1 basename); do
  o="$(claude plugin eval . --case "$c" --scaffold --trust-plugin --no-publish --max-cost-usd 0 --output-dir "$(mktemp -d)" "${A[@]}" 2>&1)"
  if grep -qF 'cost ceiling $0 hit' <<<"$o" && ! grep -qF 'not granted' <<<"$o"; then echo "OK $c"; else echo "FAIL $c"; fi
done
```

### 잰 본문 기록

본 실행 · 파일럿마다 실행 직전에 아래를 돌린다. 첫 명령에 출력이 있으면(플러그인이 읽는 곳이나 `evals/`에 커밋 안 한 변경) 돌리지 않는다. 실행 뒤 그 승인 줄 「결과 한 줄」 칸에 `commit=…`과 `경로=해시`를 모두 적는다. step 커밋마다 `HEAD`가 바뀌므로 본문과 채점기가 같은지는 경로 해시로 비교한다. `evals` 해시는 다른 case를 더해도 바뀌므로, 다르면 `git diff --stat <앞 commit> <뒤 commit> -- evals`로 잰 case가 바뀌었는지 본다.

```
P=(.claude-plugin agents docs/learning-level.md docs/principles evals hooks scripts skills templates)
git status --porcelain -- "${P[@]}"
echo "commit=$(git rev-parse --short HEAD)"
for p in "${P[@]}"; do echo "$p=$(git rev-parse --short "HEAD:$p")"; done
```

## 상한에 넘기는 값 (본 실행부터)

상한은 새 실행을 시작하기 전에만 검사해서 진행 중인 실행만큼 넘는다(sonnet 끌림에서 $0.34 넘음). `--max-cost-usd`에는 승인 상한이 아니라 **승인 상한 − (동시 실행 수 × 실행 1회 비용)** 을 넘긴다. 실행 1회 비용은 같은 묶음 파일럿의 실행별 `costUsd`(채점분 포함) 중 최댓값이다. 파일럿은 앞선 실측이 없어 승인 상한을 그대로 넘긴다. 계산값이 0 이하면 돌리지 않고 다시 묻는다.

## 안 잼

| 단계 · case | 이유 |
|---|---|
