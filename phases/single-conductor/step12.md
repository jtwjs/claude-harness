# Step 12: measure-before-after

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴)
- PRD 성공지표 표

## 작업

- 비포와 같은 명령으로 애프터를 잰다: 대상 레포 `tracks_status.py --compact`(끝N 사라짐) · 지휘 자리에서 `-R` 없는 `gh issue comment` 차단 · 가짜 ps 로 상한 동작
- summary 에 명령(백틱)과 결과

> tdd: false — 측정 전용

## Acceptance Criteria

- summary 에 명령과 결과가 있다
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나)

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 지휘 설정(`~/.claude/conductor.json`)이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다(ARCHITECTURE 「경계」).
