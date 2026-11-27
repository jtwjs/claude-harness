## 2026-11-27 — runner-gate-fix

- 숫자: step 6 · 완료 6 · 재시도 0 · error/blocked 0 · 소요 1h01m (`phases_status.py --retro runner-gate-fix`)
- 막힌 지점
  1. 계획 형식 — 엣지 5축 칸 테스트 이름 뒤 괄호 설명 때문에 러너가 step 1 지시문을 거부(계획 고쳐 재개)
  2. step 1 F1 구현의 구멍 둘을 검증이 step 2 red에 보강(「되돌리면 다시 받음」 안 됨 · 테스트만 담은 `wip:` 커밋이 묶음에 섞임) — step 1 테스트가 구현 시도를 늘 「커밋 안 된 채 wip에 담기는」 꼴로만 만들었다
  3. 새 맥락 `code-reviewer` 🔴 1 · 🟡 3 — 묶음 경계를 커밋 제목으로 가르면 구현 세션이 직접 올린 커밋이 섞인다 · 판정 4가 되돌린 파일은 막다른 길. 결정 D4 · D5(사용자) → step 6. 검증 세션 리뷰는 못 찾음
- 원인 축: 검증(테스트) — 테스트가 구현 세션의 「직접 커밋」 경로를 만들지 않았다
- 남긴 자산: `blocked_head` 경계 · `rejudge_split`(이 PR) · `.claude/rules/non-obvious-patterns.md` 「누가 만든 커밋인지는 러너가 기록한 sha로」 한 줄 · `.claude/harness.json` `review.gatePaths`(G1 — 이번 🔴을 찾은 장치)
- 다음 후보: tdd:false step의 기존 테스트 수정 막기(E2, 지휘 · 사용자 결정 대기) · 관문 「장치로 못 막는 갈래」 꼴들
- 지울 후보: 없음
