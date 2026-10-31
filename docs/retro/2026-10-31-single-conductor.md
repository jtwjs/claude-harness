## 2026-10-31 — single-conductor

- 숫자: `phases_status.py --retro single-conductor` → step 14 · 완료 14 · 재시도 0 · error/blocked 0 · 소요 - (세션 안에서 손으로 러너 규칙을 지켜 시각 미기록). hook 테스트 191 → 252, runner 테스트 47 → 50
- 막힌 지점:
  1. step 6 뒤 러너 단위 테스트가 600초 대기로 멈춤. 원인: verify_busy 부분 문자열 매칭에서 픽스처 verify `true`가 `… || true` 셸 줄과 맞음. TRIVIAL 첫 단어 제외로 고침
  2. step 11 손 확인에서 bv-admin 본 트리(feature 브랜치)가 「지울 worktree」에 들어감 → RED 뒤 fix (테스트에 없던 경우: 본 트리가 기준 브랜치가 아님)
  3. REVIEW 1회차 🟡 9건 중 7건 수정(step 13): 검사 하나를 3개로 셈(`npm run verify` ⊂ `pnpm run verify`, 중간 turbo 줄이 ppid 고리를 끊음) · `ls || true` 를 검사로 판정 · -R 범위(label·pr ready·`&&` 뒤 조각) · 머리 레포에 하네스 없으면 운영 DB 판정 빠짐 · 현황 훅 실패를 「손댈 것 없음」으로 표시 · 30초 timeout 에 현황 통째 유실 · 러너 테스트가 진짜 ps 를 봄
  3-b. REVIEW 2회차: step 13 수정이 회귀 2건을 만듦 — `./gradlew test` 를 명령 자리로 못 봄(BE 검사가 상한 밖) · `\` 줄 이어 쓴 gh 명령을 지휘 자리에서 막음. step 14 로 수정. 1회차의 「부분 문자열 → 명령 자리」 전환이 기존 미덕(넓게 잡기)을 같이 버렸다
  4. 러너 테스트 격리(`CLAUDE_VERIFY_PS`)는 step 13 RED 커밋에서 테스트 파일을 고쳤다(step 6 RED 뒤가 아님)
  5. macOS 에 `timeout` 없음 — "rc=1"을 테스트 실패로 오인할 뻔함(테스트가 아예 안 돌았다)
- 원인 축: 검증(테스트) — ps 를 쓰는 코드의 픽스처가 한 줄짜리 가짜 ps 뿐이라, 실제 프로세스 트리(셸 → pnpm → turbo → pnpm run) 모양을 테스트가 몰랐다
- 하네스 되돌림 후보: ① 프로세스 목록을 세는 코드는 「한 실행의 실제 트리」 픽스처를 먼저 둔다 ② Bash 훅에서 명령을 조각으로 나눌 때는 `\`+줄바꿈을 먼저 붙인다(non-obvious 패턴 두 줄). [확인 필요] 실제 turbo 자식 프로세스 모양 ps 1회
- 남긴 것(🟡 7·8, 🟢): 상태줄 대상 레포 3개 이상 0.6초 초과 가능 · phases 없는 기획 단계 worktree 가 지울 목록에 듦 · wait_for_slot 이 한 간격 더 기다림 · ssh 별칭 origin 은 (origin 없음) — 실측 뒤 결정
