## 2026-11-27 — runner-gate

- 숫자: step 7 · 완료 7 · 재시도 0 · error/blocked 0 · 소요 1h13m (`phases_status.py --retro runner-gate`. step 3의 blocked 1회는 재판정 뒤 completed로 닫혀 합계에 안 남는다)
- 막힌 지점
  1. step 3 구현 blocked 「테스트가 틀렸다」 — 검증 세션이 쓴 테스트가 임시 레포 브랜치를 `main`으로 단언했는데, 같은 테스트 앞의 `start`가 이미 `feat-t1`로 옮겼다. 재판정(ADR-019 E3) → 테스트만 고친 커밋 → 워크트리의 `rejudge`(만드는 중) 실사용 1 → 손 정리 1(step 4 전이라 구현 judge 판정 5가 「red 뒤 변경 없음」으로 질 것이 확실). #77 첫 실제 사례
  2. 리뷰 1회차 🟡 관문 오탐 — PRD 「남은 ⚠️」 아래 「- 없음 (…)」을 열린 항목으로 셌다. 레포 docs 15개에 `gate`를 돌려 찾았다(단위 테스트 밖) → step 7
- 원인 축: 검증(테스트) — 둘 다 테스트 · 실데이터로 잡혔고, 1은 테스트 쪽 가정, 2는 규칙이 실제 문서 꼴을 다 덮지 못함
- 남긴 자산: `rejudge` 진입점 · 판정 5 바뀜(이 PR) · step 7(「없음」 항목) · `.claude/rules/non-obvious-patterns.md` 「러너 단위 테스트 임시 레포의 브랜치」 한 줄 · `.claude/observations.md` 「sdd-run 서브에이전트 지시 ↔ 워커 서브에이전트 금지」 +1
- 다음 후보: 관문 파서가 코드 펜스 안 표 · 제목도 센다(레포 docs에선 오탐 0) · `docs/sdd-runner.md` 검증 상태 개수(123 → 125)
- 지울 후보: 없음
