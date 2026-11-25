## 2026-11-23 — observer-global-ledger

- 숫자: step 6 · 완료 6 · 재시도 0 · error/blocked 0 · 소요 35m (REVIEW 2회차 · 1회차 위반 2 → 수정 step 1개)
- 막힌 지점:
  - worktree 에 `.claude/harness.json` 이 없음 — main clone 에만 있고 `.git/info/exclude` 로 빠져 있어 worktree 가 못 받는다. 러너 `start` 전에 손으로 복사하고, `git.branchPattern` 이 없으면 러너가 `feat-{task}` 브랜치로 옮기려 해서 `{task}` 를 넣어 트랙 브랜치에 머물게 함(손으로 우회)
  - 지휘에 보낸 SendMessage 2건이 권한 모드 차이로 보류 — 1건 만료(ADR 번호 요청, 사용자가 터미널로 전달), 1건은 #35 코멘트로 대체 뒤 늦게 승인
  - REVIEW 🟡: `append` 가 후보 레포 이름이 재료에 있던 것인지 안 봄 → step 6 `--known`
- 원인 축: 도구(worktree 에 안 따라오는 로컬 설정 · 세션 간 메시지 보류) / 검증(모델 출력의 이름을 재료와 대조하는 검사가 계획에 없었음)
- 남긴 자산: `.claude/rules/non-obvious-patterns.md` 한 줄(worktree 하네스 설정) · `.claude/observations.md` 첫 행(세션 간 메시지 보류 재전송, 범위=전역 후보) · `hooks/tests/task-observer-known.sh`
- 다음 후보: plist · install 등록 · weekly 알림 한 줄(레포 밖) · 첫 실제 적재 뒤 `/friction review` 에서 후보 품질 대조
- REFLECT 건너뜀: 이해 증명(설명 리허설) — 사람 거절
