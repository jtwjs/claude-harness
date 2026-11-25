#!/usr/bin/env python3
"""측정 원자료(run_trigger.py 결과)를 evals.json 정답으로 다시 채점한다. 재실행은 하지 않는다.

- 행마다 정답(should_trigger)을 evals.json[skill][idx]에서 다시 읽고, 측정값(triggered)과 대조한다
- 오류 응답(first_tool 이 error:*)은 무효로 빼고 센다
- evals.json 에 없는 스킬 · 문항, 또는 문항 글이 다른 행은 경고하고 뺀다
"""
import argparse
import json
import sys
from collections import defaultdict


def main():
    ap = argparse.ArgumentParser(description="측정 원자료를 새 정답으로 다시 채점한다(재실행 없음).")
    ap.add_argument("results", help="run_trigger.py --out 결과 JSON")
    ap.add_argument("evals", help="정답표 evals.json")
    a = ap.parse_args()

    rows = json.load(open(a.results))
    evals = json.load(open(a.evals))

    per = defaultdict(lambda: [0, 0])  # skill -> [맞음, 유효]
    invalid, skipped, relabeled = 0, 0, 0
    fp, fn = defaultdict(list), defaultdict(list)
    for r in rows:
        if str(r.get("first_tool", "")).startswith("error"):
            invalid += 1
            continue
        items = evals.get(r["skill"])
        if items is None or r["idx"] >= len(items) or items[r["idx"]]["query"] != r["query"]:
            print(f"경고: 정답표와 안 맞는 행을 뺌 {r['skill']}#{r['idx']}", file=sys.stderr)
            skipped += 1
            continue
        want = items[r["idx"]]["should_trigger"]
        if want != r["should_trigger"]:
            relabeled += 1
        per[r["skill"]][1] += 1
        if want == r["triggered"]:
            per[r["skill"]][0] += 1
        else:
            (fp if not want else fn)[(r["skill"], r["idx"])].append(r.get("skill_called") or r.get("first_tool"))

    ok = sum(v[0] for v in per.values())
    n = sum(v[1] for v in per.values())
    print(f"정확도 {ok}/{n} = {ok / n:.1%}  (무효 {invalid} · 뺀 행 {skipped} · 정답이 바뀐 행 {relabeled})" if n else "유효 행 없음")
    for s, (o, c) in per.items():
        print(f"  {s}: {o}/{c}")
    for title, bucket in (("오발동(안 떠야 하는데 뜸)", fp), ("미발동(떠야 하는데 안 뜸)", fn)):
        print(f"{title}: {sum(len(v) for v in bucket.values())}건")
        for (s, i), got in sorted(bucket.items()):
            q = evals[s][i]["query"]
            print(f"  {s}#{i} ×{len(got)} [{', '.join(sorted(set(map(str, got))))}] {q}")


if __name__ == "__main__":
    main()
