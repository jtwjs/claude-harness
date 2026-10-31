# Step 1: conductor-config-lib

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴)
- hooks/lib/prod_db.py (lib 형식) · hooks/lib/active-repo.sh

## 작업

- 새 `hooks/lib/conductor.py` — CLI + import 둘 다.
  - `load() -> dict|None`: `CLAUDE_CONDUCTOR_CONFIG`(테스트용) 또는 `~/.claude/conductor.json`. 없거나 JSON 깨짐 → None
  - `seat() -> Path|None`, `repos() -> list[Path]`(`~` 펼침, 순서 유지)
  - `is_seat(cwd) -> bool`: cwd 의 git toplevel(git 아니면 cwd, resolve)이 seat 와 같으면 True — ADR-002
  - CLI: `conductor.py is-seat <cwd>` → exit 0/1 · `conductor.py repos` → 한 줄에 하나

## Acceptance Criteria

- test.sh 새 케이스 [7-a]: 설정 없음 → is-seat 1 · 깨진 JSON → 1 · seat 폴더 → 0 · 하위 폴더(git toplevel 이 seat) → 0 · repos 순서·`~` 펼침
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나)

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 지휘 설정(`~/.claude/conductor.json`)이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다(ARCHITECTURE 「경계」).
