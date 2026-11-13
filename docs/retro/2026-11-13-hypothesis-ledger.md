## 2026-11-13 — hypothesis-ledger

- 숫자: `phases_status.py --retro hypothesis-ledger` → step 10 · 완료 10 · 재시도 1 · error/blocked 0 · 소요 3h10m
- 막힌 지점:
  1. step 2: 재시도 1회, 손으로 개입
  2. step 8: 2h27m(전체의 대부분). 러너가 테스트 파일을 얼려 둔 상태에서 RED 커밋을 고쳐야 했고 손으로 개입
  3. 리뷰 3회전: 1회차 🟡 2건(step 8로 수정) · 2회차 지적(step 9로 수정) · 3회차 지적 0건. 3회차는 내 diff 읽기만 했고 `code-reviewer` 심층은 안 돌림
  4. 손으로 개입이 2번(step 2, step 8)
  5. 3회차 뒤 `code-reviewer` 심층 리뷰에서 🟡 2건: 깊게 중첩된 JSON 줄(`RecursionError`)과 짝 없는 서로게이트·줄바꿈이 든 `ts` 로 읽기 서브커맨드가 죽음. step 10 으로 수정. 리뷰 보고가 `.isascii()` 만으로 줄바꿈도 막힌다고 했지만 틀려서(`"\n".isascii()` 는 참) 정규식 `[\x21-\x7e]{1,64}` 로 정했다. step 9 의 "어떤 원장 내용에도 exit 0" 약속은 sdd-review 3회전이 못 잡았다
- 원인 축: 검증(러너의 테스트 파일 판정이 `hooks/test.sh` 를 못 알아봐서 RED 확인이 깨짐) / 도구
- 남긴 자산: `.claude/rules/non-obvious-patterns.md` 새 파일 — 「새 테스트는 `hooks/tests/*.sh` 에만」 한 줄
- 지울 후보: 앞으로 만들 step 파일의 복붙 🔴 `hooks/test.sh` 문단(규칙이 한 곳에 생겨서). 기존 `phases/*/` 는 쌓기만 하는 기록이라 안 고침
- 다음 후보: 주입 문구 길이(미측정: 훅 stdout `wc -m` / 실사용 1주 뒤) · 동시 쓰기 N 확대와 실제 `ts` 겹침률(미측정: 50건 넘는 병렬 append / 실사용 1주 뒤)
- REFLECT 건너뜀: 지식 정리 — `_brain` 없음
- REFLECT 건너뜀: 적중 판정·보정 확인 — 원장 파일이 아직 없어 대상 0건
