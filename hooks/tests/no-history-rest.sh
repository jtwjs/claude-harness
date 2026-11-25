# 흐름 스킬(no-history-flow) 밖 나머지 스킬 본문에도 날짜 · 버전 이력 줄이 없다(ADR-016 D0). test.sh 가 source 한다.
# 날짜(20YY-MM) · 버전(N.N.N) 숫자만 센다 — 형식 예시(YYYY-MM-DD · vX.Y.Z)는 숫자가 아니라 걸리지 않는다.
# statechart 는 원본 반입본이라 SKILL.md 만 본다(references · scripts 는 보지 않는다).
printf '\n[no-history-rest] 나머지 스킬 12개 날짜 · 버전 이력 줄 0\n'
_nr_root="$(cd "$HOOKS/.." && pwd)"

# 파일이 없어도 실패 — 이름이 바뀌면 검사 대상도 같이 옮긴다
_nr_left=""; _nr_missing=""; _nr_n=0
for _nr_s in harness-init harness-doctor harness-gaps harness-score project-new slack-writing notion-writing explain no-comments reframe sharpen statechart; do
  _nr_f="$_nr_root/skills/$_nr_s/SKILL.md"
  if [ ! -f "$_nr_f" ]; then _nr_missing="$_nr_missing $_nr_s"; continue; fi
  _nr_n=$((_nr_n+1))
  _nr_hit=$(grep -nE '20[0-9]{2}-[0-9]{2}|[0-9]+\.[0-9]+\.[0-9]+' "$_nr_f" 2>/dev/null | cut -c1-100 | sed "s#^#skills/$_nr_s/SKILL.md:#" || true)
  [ -n "$_nr_hit" ] && _nr_left="${_nr_left:+$_nr_left
}$_nr_hit"
done
[ -z "$_nr_missing" ] || bad "검사할 스킬 파일 없음" "[${_nr_missing# }]"
[ -z "$_nr_left" ] && [ "$_nr_n" -gt 0 ] && ok "나머지 스킬 ${_nr_n}개 — 날짜 · 버전 이력 줄 0" \
  || bad "날짜 · 버전 이력 줄 남음 ($(printf '%s\n' "$_nr_left" | grep -c .)줄)" "$(printf '%s\n' "$_nr_left" | head -3)"
