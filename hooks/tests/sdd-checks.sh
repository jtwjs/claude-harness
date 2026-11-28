# sdd 판정 스크립트 단위 테스트 — gate.py · tests_unchanged.py · tests_pass.py (ADR-028). test.sh 가 source 한다.
# unittest 는 테스트 파일을 레포 루트 기준 경로로만 받아서 루트에서 돌린다.
printf '\n[sdd-checks] skills/sdd/scripts/test_sdd_checks.py\n'
if _sc_out=$(cd "$ROOT" && python3 -m unittest skills/sdd/scripts/test_sdd_checks.py 2>&1); then
  ok "sdd 판정 스크립트 테스트 통과 — $(printf '%s\n' "$_sc_out" | grep -E '^Ran ' | tail -1)"
else
  bad "sdd 판정 스크립트 테스트 실패" "$(printf '%s\n' "$_sc_out" | grep -E '^(FAIL|ERROR):|^Ran |^FAILED' | head -5 | tr '\n' ' ')"
fi
