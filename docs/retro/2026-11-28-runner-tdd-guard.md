## 2026-11-28 — runner-tdd-guard

- 숫자: step 6 · 완료 6 · 재시도 0 · error/blocked 0 · 소요 1h39m (`phases_status.py --retro runner-tdd-guard`) · 새 맥락 리뷰 2회(1회차 🔴1 · 🟡4 → step 6, 2회차 재현 5건 모두 되돌림)
- 막힌 지점
  1. 설계서 가정 「시작 커밋은 러너가 기록한 커밋」이 나눔 모드 tdd:false step에서 코드와 달랐다(구현 차례 `prompt`에 `--base`가 없어 BASE가 비고 `judge`가 거절 — 옆 트랙이 먼저 겪음). 결정 T3로 러너가 고정
  2. 설계서 안에서 기능 요구사항(「테스트 먼저 단계와 같게」)과 흐름 그림(「나머지 판정 계속」)이 갈렸다 → T2. ADR을 쓰다 설계서에 없는 결정 둘(T4 칸 꼴 · T5 blocked 우회로)이 더 나왔다 — 결정 묶음 2회
  3. step 1 구현 blocked 1회: 검증 테스트가 「작업 트리 전체가 깨끗하다」를 단언했는데 재시도 갈래는 원래 index.json을 커밋하지 않는다. 테스트를 `phases/` 밖으로 좁혀 `rejudge` 1회
  4. 새 맥락 `code-reviewer` 🔴 1 · 🟡 4 — `git diff --name-only` 기본값이 이름 바꾸기의 옛 경로를 숨기고 비ASCII 경로에 따옴표를 붙여 옮긴 · 한글 경로 테스트가 판정을 빠져나감, 구현의 자기 허가(진행 중 index.json), error 멈춤 경로 씻김, glob 키. ARCHITECTURE 첫 초안이 이름 바꾸기 동작을 반대로 적었다(코드로 확인 안 함). 결정 T6~T8(지휘) → step 6. 검증 세션 리뷰 · 23개 테스트는 하나도 못 찾음
- 원인 축: 검증(테스트) — 테스트가 구현 시도를 「write → commit」 꼴로만 만들고 git mv · 특수 경로 · index 쓰기 · error 경로를 만들지 않았다. 맥락 — git 명령 기본값을 확인하지 않고 문서에 동작을 적었다
- 남긴 자산: 판정 4' · `test_edits`(BASE 계획에서 읽음) · 구현 차례 BASE 고정 · blocked · error 멈춤 되돌림 · `start` 칸 검사(이 PR, ADR-024 T1~T8) · `.claude/rules/non-obvious-patterns.md` 「테스트 파일 변경은 `--name-only` 기본값으로 세지 않는다」 한 줄
- 다음 후보: #102 테스트 먼저 단계 판정 4의 같은 이름 바꾸기 구멍 · step 테스트를 쓸 때 「구현이 git mv · 직접 커밋 · index 쓰기 · error 보고로 빠져나가는 길」을 엣지 칸에 넣기
- 지울 후보: 없음
