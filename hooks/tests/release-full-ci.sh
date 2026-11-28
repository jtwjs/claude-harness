# scripts/release.sh 사전 확인 — main 머리에서 CI full 잡을 발동하고 새 실행 결과를 기다린다(ADR-028 결정 8). test.sh 가 source 한다.
# 임시 레포(main, 버전 맞춤)에서 /bin/bash 로 돌린다 — macOS 기본 bash 3.2 에서만 나는 파싱 오류를 잡으려고(B1 리뷰 🔴).
# 가짜 gh: 같은 커밋에 지난 실행(성공)이 있고, 발동 뒤 새 실행이 나타난다. 진짜 gh · CI 는 부르지 않는다.
printf '\n[release-full-ci] release.sh — CI full 발동 · 새 실행 결과\n'
_rf_d="$TMP/_rf_"; mkdir -p "$_rf_d/bin" "$_rf_d/r/scripts" "$_rf_d/r/.claude-plugin" "$_rf_d/r/skills/a"
cp "$ROOT/scripts/release.sh" "$_rf_d/r/scripts/"
printf '{"version":"9.9.9"}\n' > "$_rf_d/r/.claude-plugin/plugin.json"
printf '{"plugins":[{"name":"claude-harness","version":"9.9.9"}]}\n' > "$_rf_d/r/.claude-plugin/marketplace.json"
: > "$_rf_d/r/skills/a/SKILL.md"
(cd "$_rf_d/r" && git init -q -b main && git add -A && git -c user.email=t@t -c user.name=t commit -qm i)
_rf_head="$(git -C "$_rf_d/r" rev-parse HEAD)"
# 실행 목록: 발동 전에는 지난 실행 1 하나, 발동(POST) 뒤 둘째 조회부터 새 실행 2(결론은 RF_NEW)가 맨 앞에 붙는다
cat > "$_rf_d/bin/gh" <<FAKE
#!/bin/sh
printf '%s\n' "\$*" >> "$_rf_d/gh.log"
case "\$*" in
  *"-X POST"*) : > "$_rf_d/posted"; exit 0 ;;
  *commits/main*) echo "$_rf_head" ;;
  *full.yml/runs*)   # 발동 뒤 첫 조회에는 아직 안 뜬다 — 그때 지난 실행(성공)을 집으면 거름이 빠진 것
    if [ -f "$_rf_d/posted" ]; then
      if [ -f "$_rf_d/seen" ]; then echo "2 completed \$RF_NEW https://x/runs/2"; else : > "$_rf_d/seen"; fi
    fi
    echo "1 completed success https://x/runs/1" ;;
  *) exit 1 ;;
esac
FAKE
printf '#!/bin/sh\nexit 0\n' > "$_rf_d/bin/sleep"
printf '#!/bin/sh\nexit 1\n' > "$_rf_d/bin/claude"   # dry-run 끝 상시 비용이 실제 설치본을 읽지 않게
chmod +x "$_rf_d/bin/gh" "$_rf_d/bin/sleep" "$_rf_d/bin/claude"
_rf_run() { rm -f "$_rf_d/posted" "$_rf_d/seen" "$_rf_d/gh.log"; (cd "$_rf_d/r" && PATH="$_rf_d/bin:$PATH" /bin/bash scripts/release.sh "$@" >"$_rf_d/out" 2>&1); echo $?; }

# 새 실행이 실패면 지난 실행이 성공이어도 멈춘다 — 실행 거름이 /bin/bash 에서 돈다
_rf_c=$(RF_NEW=failure _rf_run)
[ "$_rf_c" = 1 ] && grep -q 'CI full 실패(failure)' "$_rf_d/out" && [ "$(grep -c -- '-X POST' "$_rf_d/gh.log")" = 1 ] \
  && ok "새 실행 실패면 멈춤 · 발동 1번" || bad "새 실행 실패" "exit=$_rf_c $(tr '\n' ' ' < "$_rf_d/out")"
# dry-run 은 발동하지 않는다
_rf_c=$(RF_NEW=failure _rf_run --dry-run)
! grep -q -- '-X POST' "$_rf_d/gh.log" && grep -q '(dry-run) CI full' "$_rf_d/out" \
  && ok "dry-run 은 발동 0번" || bad "dry-run 발동" "exit=$_rf_c $(tr '\n' ' ' < "$_rf_d/out")"
