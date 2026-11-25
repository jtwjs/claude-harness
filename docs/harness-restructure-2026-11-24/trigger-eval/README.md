# 자동 입구 발동 정확도 (Before · After 같은 방법)

- 문항: `evals.json` — 스킬 8개 × 20문항(`how`는 0.41.0에 들어와 `before-0.40.0.json`에는 없다)(떠야 할 말 10 · 안 떠야 할 말 10). skill-creator 「Description Optimization」 방식으로 만들었다
- 실행: `python3 -I run_trigger.py --evals evals.json --cwd <대상 레포> --out <결과.json> --runs 3 --workers 4 --model claude-opus-5-5`
- 판정: 설치된 플러그인 스킬이 첫 도구 호출로 불리면 발동. 훅은 끄고, 세션은 저장하지 않고, `dontAsk` 권한으로 돌리며, 첫 도구 블록이 나오면 바로 끊는다(도구가 실행되지 않는다)
- 대상 레포: `bash make_target_repo.sh <폴더> <claude-harness 루트>`로 만든다. `templates/CLAUDE.md.tmpl` · `templates/.claude/README.md`를 채운 작은 React 앱이고, 작업 트리에 변경 1개를 남긴다. 레포 밖 스크래치 폴더에 만든다
- `before-0.40.0.json`: 2026-11-24에 설치본 0.40.0으로 잰 원자료. commit 60회는 첫 측정이 사용 한도에 걸려 전부 무효라 따로 다시 쟀다(오류 응답은 `first_tool: error:*`로 표시하도록 측정기를 고친 뒤)
- 한계: 스킬 전에 Bash로 상태부터 보는 경우는 미발동으로 센다
- 재채점: `python3 rescore.py <결과.json> evals.json` — 원자료를 지금 정답표로 다시 채점한다(재실행 없음, `error:*` 행은 무효로 뺀다)

## 정답 바꾼 문항 (0.41.0 입구 구조, ADR-018 B-15)

0.41.0에서 모델이 부를 수 있는 입구는 자동 입구 8개뿐이다. 부정 문항 중 닫힌 스킬(`disable-model-invocation: true`)이 맡던 요청을 가장 가까운 자동 입구 기준으로 다시 달았다.

| 스킬 · idx | 문항 | 옛 정답 → 새 정답 | 이유 |
|---|---|---|---|
| sdd · 11 | phases/order-filter 계획 다 짰으니까 이제 구현 러너 돌려줘 | false → true | `sdd-run`이 닫혔고, ② IMPLEMENT로 들어가는 자동 입구는 `sdd`다 |
| sdd · 12 | 방금 구현한 거 머지 전에 ARCHITECTURE랑 ADR 기준으로 리뷰해줘 | false → true | `sdd-review`가 닫혔고, ③ REVIEW로 들어가는 자동 입구는 `sdd`다 |
| notion-writing · 13 | 이 diff 풀어서 노션 페이지로 설명해줘 | false → true | `explain`이 닫혔고, 노션 페이지로 남기는 자동 입구는 `notion-writing`이다 |

같은 기준으로 보고 그대로 둔 것: diff 설명(why · 15, pr-write · 17)은 가장 가까운 입구가 `how`라 해당 스킬 정답은 그대로 false. changeset(pr-write · 14, commit · 16)은 사람이 `/changeset`으로 부르는 스킬이고 `commit`은 실행을 권하는 한 줄만 낸다 — false 유지. 계획 · 진행 상태 · 리뷰 요청(conductor · 10 · 12, commit · 17, how · 19)은 입구가 `sdd`라 해당 스킬 정답은 그대로다.
