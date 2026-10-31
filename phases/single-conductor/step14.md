# Step 14: review-fixes-2

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/ADR.md (ADR-003 개정 · ADR-007) · phases/single-conductor/step13.md
- hooks/lib/verify_busy.py · hooks/block-dangerous-bash.sh · hooks/test.sh [7-b]·[7-c]

## 작업 (REVIEW 2회차 🟡 — step 13 이 만든 회귀 2건)

- verify_busy: `./` 로 시작하는 검사 명령(`./gradlew test`)은 공백 뒤도 명령 자리로 본다(`/bin/sh ./gradlew test`)
- block-dangerous-bash: 조각으로 나누기 전에 `\`+줄바꿈 이어 쓰기를 한 줄로 붙인다

## Acceptance Criteria

- `bash hooks/test.sh` 전부 통과 · `python3 -m unittest skills/harness-run/scripts/test_sdd_runner.py` 통과

## 검증 절차

1. 위 두 명령을 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
