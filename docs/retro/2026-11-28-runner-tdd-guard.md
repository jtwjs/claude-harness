## 2026-11-28 — runner-tdd-guard

- 숫자: step 5 · 완료 5 · 재시도 0 · error/blocked 0 · 소요 1h23m (`phases_status.py --retro runner-tdd-guard`)
- 막힌 지점
  1. 설계서 가정 「시작 커밋은 러너가 기록한 커밋」이 나눔 모드 tdd:false step에서 코드와 달랐다(구현 차례 `prompt`에 `--base`가 없어 BASE가 비고 `judge`가 거절 — 옆 트랙이 먼저 겪음). 결정 T3로 러너가 고정
  2. 설계서 안에서 기능 요구사항(「테스트 먼저 단계와 같게」)과 흐름 그림(「나머지 판정 계속」)이 갈렸다 → 결정 T2. ADR을 쓰다 설계서에 없는 결정 둘(T4 칸 꼴 · T5 blocked 보고 우회로)이 더 나왔다 — 결정 묶음 2회
  3. step 1 구현 blocked 1회: 검증 테스트가 「작업 트리 전체가 깨끗하다」를 단언했는데 재시도 갈래는 원래 index.json을 커밋하지 않는다. 테스트를 `phases/` 밖으로 좁혀 `rejudge` 1회로 통과
- 원인 축: 검증(테스트) — 3은 러너의 기존 동작(재시도 때 index 미커밋)을 모른 채 단언했다. 1 · 2는 공유(설계서 가정을 코드로 확인하기 전 승인)
- 남긴 자산: 판정 4' · `test_edits` 칸 · 구현 차례 BASE 고정 · blocked 되돌림 · `start` 칸 검사(이 PR, ADR-024) · `docs/sdd-runner.md` 판정 4' 줄
- 다음 후보: (REVIEW 뒤 채움)
- 지울 후보: 없음
