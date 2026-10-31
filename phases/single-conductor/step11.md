# Step 11: statusline-seat

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴)
- ~/orca/claude-dotfiles/claude/statusline-sdd.py :95-110

## 작업

- 지휘 자리 판정을 「tracks.md 가 있는 기준 worktree」에 더해 `conductor.py is-seat` 로도. 지휘 자리면 `tracks_status.py --compact`(cwd=seat) 결과를 그대로
- conductor.py 경로는 tracks_status 와 같은 플러그인 캐시에서 찾는다(TRACKS 옆 규칙 그대로)

> tdd: false — 다른 레포(~/orca/claude-dotfiles) — 테스트 장치 없음. 손으로 1회 확인

## Acceptance Criteria

- 손 확인: 설정을 둔 상태로 `echo '{"cwd":"<seat>"}' | python3 statusline-sdd.py` 가 트랙 조각을 낸다 · 설정 없으면 지금과 같은 출력
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나)

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 지휘 설정(`~/.claude/conductor.json`)이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다(ARCHITECTURE 「경계」).
