## 2026-11-28 — secret-scan

- 숫자: step 5 · 완료 5 · 재시도 0 · error/blocked 0 · 소요 52m(검증 · 구현 왕복 5회, 테스트 판정 대기 포함)
- 막힌 지점:
  1. REVIEW 1회차(새 맥락 code-reviewer) 🟡 4건 → 고침 step 5. ① gitleaks는 `--log-opts` 범위가 깨지면(기준 커밋 없음 · 얕은 clone) ERR 로그만 내고 커밋 0개를 「통과」(exit 0)로 끝낸다 — 가짜 gitleaks 테스트는 이 갈래를 못 봤다(진짜 실행 파일로 재현) ② merge 커밋에서 충돌을 풀며 넣은 값은 gitleaks 기본(`git log -p`)이 못 본다(주석으로 한계, R1) ③ `harness-doctor` 1-b 점검이 새 잡을 drift로 잘못 잡는다 — 템플릿을 바꾸면서 그 템플릿을 읽는 점검 규칙을 같이 안 봤다 ④ 앱별 레포 업그레이드 안내에 `ci-gate` needs가 빠져 막지 못하는 검사로 이어질 수 있었다
  2. 범위 확인 시제품을 `a && b` 한 줄로 썼다가 테스트(`ss-scan-missing-base-fails`)에 걸림 — `bash -e`는 `&&` 목록 앞쪽의 실패에 멈추지 않는다. 구현 세션 알림에 함정으로 넘김
  3. 설계서 문구(「안내 한 줄만 · 파일 자동 수정 없음」)와 기존 업그레이드 `.gitignore` 행이 부딪혀 사용자 결정(S2 = B)으로 설계서를 고침
- 원인 축: 검증(외부 도구를 가짜로 바꾼 테스트는 그 도구의 실패 꼴 — 깨진 범위에서 exit 0 — 을 가린다) / 맥락(템플릿을 읽는 다른 스킬 · 점검의 목록이 없어 바꾼 템플릿의 독자를 놓침)
- 남긴 자산: 템플릿 잡 안 범위 확인 + 회귀 테스트 3개(`hooks/tests/secret-scan.sh` 「⑦」) — 규칙 한 줄 대신 구조로 막음 · `.claude/observations.md` +1 · 같은 세션 2회(위험 명령 훅이 질문 글 · PR 제목 안 `.env` 글자를 비밀 파일 출력으로 오탐)
- 다음 후보: `.env.local` · `.env.*.local` 등(설계서 범위 밖) · 실제 GitHub Actions에서 `base.sha`가 synchronize 때 새로 채워지는지 · ubuntu 러너 실제 실행(템플릿으로 만든 레포의 첫 PR)

REFLECT 건너뜀: 적중 판정 — 대상 없음(`pending-hits` 0줄) · 게이트 보정 — 대상 7줄 모두 지휘 메시지 확인 프롬프트라 후보 없음, `gate-fix` 안 씀(나눔 모드) · `revise-claude-md` — 흘린 규칙 없음(범위 확인 함정은 템플릿 구조 · 테스트로 넣음) · 더하기만 금지 — 지울 후보 없음
