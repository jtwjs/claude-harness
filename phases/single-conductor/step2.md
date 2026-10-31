# Step 2: verify-busy-lib

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴)
- hooks/validate-session-end.sh (harness.json verify 파싱 부분)

## 작업

- 새 `hooks/lib/verify_busy.py` — ADR-007.
  - `verify_cmds(repo_root) -> list[str]`: repo 의 `.claude/harness.json` verify 값(단일·앱별 형태 모두, `$` 키 무시) + `pnpm verify` · `npm run verify`
  - `running(cmds) -> int`: `ps -Ao command` 출력(테스트용 `CLAUDE_VERIFY_PS` 파일이 있으면 그 내용)에서 명령 문자열을 포함하는 줄 수. 자기 자신(verify_busy.py) 줄은 뺀다
  - `limit() -> int`: `CLAUDE_VERIFY_MAX` 정수(기본 2, 1 미만·잘못된 값이면 2)
  - CLI: `verify_busy.py busy <repo_root>` → 상한 이상이면 stdout 에 개수 출력 + exit 0, 아니면 exit 1
  - `match <repo_root> <command>` → 명령이 verify 명령이면 exit 0

## Acceptance Criteria

- test.sh [7-b]: 가짜 ps 파일로 0·1·2·3개 → busy 판정 · MAX=3 · 잘못된 MAX · match 참/거짓 · harness.json 없으면 `pnpm verify` 만
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나)

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 지휘 설정(`~/.claude/conductor.json`)이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다(ARCHITECTURE 「경계」).
