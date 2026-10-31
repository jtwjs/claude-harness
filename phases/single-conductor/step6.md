# Step 6: runner-verify-wait

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴)
- skills/harness-run/scripts/sdd_runner.py (judge 의 verify 실행 부분) · test_sdd_runner.py

## 작업

- judge 가 verify 를 돌리기 전 `verify_busy` 를 import 해 상한 아래가 될 때까지 5초 간격 대기, 최대 600초(넘으면 그대로 진행하고 stderr 한 줄). 대기 간격·한도는 테스트에서 줄일 수 있게 함수 인자로
- 대기 중 stderr `⏸ 검사 대기 — 다른 세션 N개`(처음 한 번)

## Acceptance Criteria

- test_sdd_runner.py: busy→idle 로 바뀌는 가짜 카운터로 대기 후 진행 · 한도 초과 시 진행 · busy 아님이면 대기 0
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나)

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 지휘 설정(`~/.claude/conductor.json`)이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다(ARCHITECTURE 「경계」).
