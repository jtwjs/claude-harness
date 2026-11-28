# 문서 정합 — test.sh 본문 케이스 10을 옮겼다(ADR-025 — 문서만 바뀐 부분 실행이 본문을 돌지 않게). test.sh 가 source 한다.
# ── 케이스 10: 문서 정합 — 지운·바꾼 스킬 이름과 옛 결정 경로가 지시문에 남지 않는다 (2026-10-11) ──
# 규칙을 한 곳만 바꾸고 둘레(sdd·훅 지시문)에 옛 규칙이 남던 것을 리뷰가 두 번 잡았다.
printf '\n[10] 문서 정합\n'
left=$(grep -rnE '`(grilling|why-logictree|why-plan|brain-intake|find-skills|harness-new)`|claude-harness:(brain-recall|why-plan)|decisions/<기능>' \
  "$ROOT/skills" "$ROOT/agents" "$ROOT/hooks" "$ROOT/templates" 2>/dev/null | grep -v '/hooks/test.sh:' | grep -v '/hooks/tests/doc-consistency.sh:' | grep -vE '삭제|당시 기준|합쳤다|합침|원형|2026-10-11 \|')   # 업그레이드 이름표 행(| 날짜 |)은 옛 이름이 정상
[ -z "$left" ] && ok "지운 스킬·옛 결정 경로 참조 0" || bad "남은 참조" "$(echo "$left" | head -3)"
# 설계 3장 (0.12.4 · 0.22.0 sdd 내장): DESIGN 절차는 세 장만 쓴다. 옛 결정 경로(decisions/)로 바로 쓰는 문구가 남지 않는다.
direct=$(grep -nE 'DESIGN`?이 `?decisions' \
  "$ROOT/skills" "$ROOT/templates" -r 2>/dev/null)
grep -q '지식 정리' "$ROOT/skills/sdd/SKILL.md" && grep -q 'ARCHITECTURE.md\*\* — PRD 확정 직후' "$ROOT/skills/sdd/references/design.md" && [ -z "$direct" ] \
  && ok "DESIGN 절차는 세 장 · REFLECT 지식 정리" || bad "설계 3장 흐름" "${direct:-sdd REFLECT 지식 정리 또는 design.md ARCHITECTURE 단계 없음}"
# 0.22.0: ① 계획(DESIGN→PLAN) · why 는 파일을 안 쓴다 · step 빈칸은 harness §2 · REFLECT 는 회고 1장 + 출구 조건 · ⑤ 마무리가 릴리스. 되돌아가면 실패.
cross=$(grep -nE 'why-plan`? 한 번 더|step 승인 직전에 불렸으면|빈칸이 많다 \| `why-plan`' "$ROOT/skills/sdd/SKILL.md" "$ROOT/skills/sdd/references/design.md" "$ROOT/templates/.claude/README.md" "$ROOT/README.md" || true)
for need in '이 자리에서 묻는다:skills/sdd-plan/SKILL.md' '절차를 건너뛰고 세 장을 바로 쓰지 않는다:skills/sdd/SKILL.md' '회고 1장 새 파일:skills/sdd/references/reflect.md' '출구 조건:skills/sdd/SKILL.md' 'REFLECT 건너뜀:skills/sdd/SKILL.md' '마무리(SHIP):skills/sdd/SKILL.md' '파일은 쓰지 않는다:skills/why/SKILL.md' '물러서는 조건:docs/principles/ask-questions.md' 'docs/retro/YYYY-MM-DD:skills/sdd/references/reflect.md'; do
  grep -q "${need%%:*}" "$ROOT/${need#*:}" || cross="${cross}
없음: ${need}"
done
top=$(grep -nF '최신이 위' "$ROOT/skills/sdd/references/reflect.md" || true)
[ -z "$top" ] && ok "회고·로그는 한 건 = 파일 하나(한 파일 맨 위에 쌓지 않는다 — 병렬 PR 충돌)" || bad "회고·로그 한 파일 맨 위" "$top"
[ -z "$cross" ] && ok "① 계획 두 게이트 · why 는 화면만 · REFLECT 회고+출구 조건 · ⑤ 마무리" || bad "0.22.0 흐름" "$cross"
