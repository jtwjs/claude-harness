# Step 13: review-fixes

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md (ADR-003 개정 · ADR-004 · ADR-005 · ADR-007)
- hooks/lib/verify_busy.py · hooks/block-dangerous-bash.sh · hooks/conductor-context.sh · hooks/test.sh [7-b]·[7-c]·[7-f]
- skills/harness-run/scripts/test_sdd_runner.py

## 작업 (REVIEW 1회차 🟡 1·2·3·4·5·6·9)

- verify_busy: 명령은 「명령 자리」(줄 머리 · `;&|(` 뒤 · `-c ` 뒤 · `/` 뒤 · `node ` 뒤)에서만 맞는다. 조상 중 하나라도 검사면 세지 않는다(중간 turbo 줄이 고리를 끊지 않게). ALWAYS 에 `pnpm run verify`. `is_verify` 도 TRIVIAL 제외 + 같은 매칭
- block-dangerous-bash: 지휘 자리 -R 검사를 gh 명령 조각마다(`&&`·`;`·`|`로 나눈 각 조각). 쓰기 동사에 `label create|edit|delete|clone` · `pr ready` (ADR-003 개정). 운영 DB: 명령 머리 레포에 harness.json 이 없으면 cwd 레포로 다시 판정
- conductor-context: tracks_status 실패(None)는 `(조회 실패)`, 빈 출력만 「손댈 것 없음」. 전체 마감 `CLAUDE_CONDUCTOR_DEADLINE`(기본 25초) — 넘으면 남은 레포는 `(시간 초과 — 건너뜀)`. `CLAUDE_CONDUCTOR_TS` 로 tracks_status 대체(테스트)
- test_sdd_runner: 빈 가짜 ps(`CLAUDE_VERIFY_PS`)로 격리 — 테스트 쪽이라 RED 커밋에 넣는다

## Acceptance Criteria

- `bash hooks/test.sh` 전부 통과 · `python3 -m unittest skills/harness-run/scripts/test_sdd_runner.py` 통과

## 검증 절차

1. 위 두 명령을 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다(ADR-003 개정 줄은 「상태」·「결과」에 덧붙이기만).
- 지휘 설정이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다.
