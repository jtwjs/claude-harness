# Step 7: tracks-status-multi-repo

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴)
- skills/conductor/scripts/tracks_status.py · test.sh [2-g]

## 작업

- cwd 가 지휘 자리면 `conductor.repos()` 각각에 대해 지금 표/compact 를 만든다. 레포 이름 접두(`bv-admin:`). 경로 없거나 git 아님 → `<이름> (경로 없음)` 한 줄
- `--compact`(ADR-006): ⛔·💤·`진행N`·겹침만. `끝N` 없음. 겹침은 진행 중(…·⛔·💤) worktree 끼리만. 셋 다 0 → 빈 출력. 지휘 자리면 레포별 조각을 ` · ` 로 잇는다
- 전체 표: 끝난 worktree 는 표 아래 「지울 worktree」 목록으로 따로

## Acceptance Criteria

- test.sh [2-g] 확장: 끝난 worktree 만 → compact 빈 출력 · 끝난 둘의 같은 파일 → 겹침 0 · 진행 중 둘 → 겹침 1 · 지휘 자리 + 레포 2개 → 두 조각 · 없는 경로 → (경로 없음)
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나)

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 지휘 설정(`~/.claude/conductor.json`)이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다(ARCHITECTURE 「경계」).
