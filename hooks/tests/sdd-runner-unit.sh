# SDD 러너 단위 테스트를 verify(bash hooks/test.sh) 하나에 묶는다 — 러너를 고치는 step 의 RED 판정이 이 명령 하나로 된다. test.sh 가 source 한다.
# unittest 는 테스트 파일을 레포 루트 기준 경로로만 받아서(절대 경로는 import 실패) 루트에서 돌린다.
printf '\n[sdd-runner-unit] skills/sdd-run/scripts/test_sdd_runner.py\n'
if _su_out=$(cd "$ROOT" && python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py 2>&1); then
  ok "러너 단위 테스트 통과 — $(printf '%s\n' "$_su_out" | grep -E '^Ran ' | tail -1)"
else
  bad "러너 단위 테스트 실패" "$(printf '%s\n' "$_su_out" | grep -E '^(FAIL|ERROR):|^Ran |^FAILED' | head -5 | tr '\n' ' ')"
fi
