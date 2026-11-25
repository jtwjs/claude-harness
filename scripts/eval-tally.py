#!/usr/bin/env python3
"""claude plugin eval --json 결과를 case · 쪽마다 센다(ADR-018 A1 ② 결과 + 실행 비용).

사용: python3 scripts/eval-tally.py <결과.json> [<결과.json> ...]

- 턴 상한에 걸린 실행은 점수에서 빼고 「무효」로 따로 센다(turns >= case maxTurns, 또는 error 에 max turns).
- 유효 실행만으로 평균 점수와 Δ(있음 − 없음)를 낸다. 비용 · 턴 · 시간은 무효 실행까지 포함한 평균이다(돈은 이미 썼다).
- 출력: 탭 구분 case · 쪽 · 유효통과/유효 · 무효 · 평균점수 · 평균$ · 평균턴 · 평균초, case 마다 Δ 한 줄.
"""
import json
import re
import sys

MAX_TURNS_ERR = re.compile(r"max(imum)?[ _]?(number of )?turns", re.I)


def is_invalid(run, max_turns):
    if MAX_TURNS_ERR.search(run.get("error") or ""):
        return True
    return bool(max_turns) and (run.get("turns") or 0) >= max_turns


def mean(xs):
    return sum(xs) / len(xs) if xs else None


def fmt(x, nd=2):
    return "-" if x is None else f"{x:.{nd}f}"


def tally(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    for case in data.get("cases", []):
        name, max_turns = case.get("name", "?"), case.get("maxTurns")
        scores = {}
        for arm in ("with", "without"):
            runs = (case.get("arms") or {}).get(arm)
            if runs is None:
                continue
            valid = [r for r in runs if not is_invalid(r, max_turns)]
            passed = sum(1 for r in valid if r.get("passed"))
            score = mean([r.get("score", 0) for r in valid])
            scores[arm] = score
            print("\t".join([
                name, arm, f"{passed}/{len(valid)}", str(len(runs) - len(valid)), fmt(score),
                fmt(mean([r.get("costUsd", 0) for r in runs]), 3),
                fmt(mean([r.get("turns", 0) for r in runs]), 1),
                fmt(mean([r.get("durationSeconds") for r in runs if r.get("durationSeconds") is not None]), 0),
            ]))
        if scores.get("with") is not None and scores.get("without") is not None:
            print(f"{name}\tdelta\t{scores['with'] - scores['without']:+.2f}")


def main(argv):
    if not argv:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    print("case\tarm\tvalid_pass\tinvalid\tscore\tusd\tturns\tsec")
    for p in argv:
        tally(p)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
