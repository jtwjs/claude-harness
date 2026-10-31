# Step 3: bash-hook-target-repo

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴)
- hooks/block-dangerous-bash.sh :95-140 (gh 계정 절 · 운영 DB 절)

## 작업

- `block-dangerous-bash.sh`
  - gh 쓰기 절(ADR-003): cwd 가 지휘 자리(`conductor.py is-seat`)이고 `-R`/`--repo` 가 없으면 exit 2 + stderr `지휘 자리에서는 -R <owner>/<repo> 로 대상 레포를 적는다`. `-R` 있으면 지금처럼 그 owner 로 계정 판정
  - 운영 DB 절(ADR-004): 명령이 `cd <경로> (&&|;)` 또는 `git -C <경로>` 로 시작하면 그 경로의 git toplevel 을 REPO_ROOT 로. 경로가 없거나 git 아니면 cwd
  - 🔴 판별이 죽으면 막는다(fail-closed) — 기존 운영 DB 절 규칙 유지

## Acceptance Criteria

- test.sh [7-c]: 지휘 자리 + `-R` 없음 → 2 · 지휘 자리 + `-R` → 계정 판정 · 지휘 아님 → 지금 동작 · `cd <prodDb 레포> && psql -c 'delete …'` → 2 · `git -C` 경로 · 없는 경로 → cwd
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나)

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 지휘 설정(`~/.claude/conductor.json`)이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다(ARCHITECTURE 「경계」).
