# Step 5: stop-hook-verify-cap

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴)
- hooks/validate-session-end.sh

## 작업

- 루프 가드 뒤, verify 실행 전: `verify_busy.py busy "$REPO_ROOT"` 이면 systemMessage `⏸ 다른 세션 검사 N개 중 — 건너뜀` 하나만 내고 exit 0. stamp 는 갱신하지 않는다(다음 Stop 에서 다시 시도)
- 🔴 읽기 전용 · non-blocking(exit 0) 규칙 유지

## Acceptance Criteria

- test.sh [7-e]: 가짜 ps 2개 → 건너뜀 메시지 · verify 명령 미실행(실행되면 표식 파일이 생기는 verify 로 확인) · stamp 없음 · 1개 → 지금처럼 실행
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나)

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 지휘 설정(`~/.claude/conductor.json`)이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다(ARCHITECTURE 「경계」).
