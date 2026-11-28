# Step 8: auto-memory-off-check

## 읽어야 할 파일

- `phases/runner-headless-block/index.json` step 5 summary(비포: 안내 있음)
- `skills/sdd-run/scripts/sdd_runner.py` — `HEADLESS_NO_MEMORY`

## 의도

- #118 애프터: step 6이 넣은 `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`이 실제로 auto memory 안내를 빼는지 유료 1회로 본다(사용자 미리 승인, 범위: 가장 싼 모델 1회 · step 5와 같은 지시문 · 러너가 넘기는 환경)
- kind: measure — 바꿀 파일이 없다. 검증 세션이 돈다

## 작업

- step 5와 같은 명령 · 지시문을 러너 `invoke`와 같은 환경(`SDD_RUNNER_SINCE` 뺌 · `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`)으로 1회
- 출력 원문은 스크래치에만. summary에는 명령(백틱)과 「안내 있음/없음 · 내용 실림/없음 · total_cost_usd」만

## Acceptance Criteria

- summary에 명령(백틱)과 세 값이 있다(측정 step 판정)

## 검증 절차

1. 위 명령을 실제 실행한다.
2. 결과를 `phases/runner-headless-block/index.json`의 해당 step에 기록한다.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- 승인받은 1회를 넘기지 않는다
