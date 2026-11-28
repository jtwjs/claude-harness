# Step 5: auto-memory-check

## 읽어야 할 파일

- 이슈 #118 본문(사용자 결정: PR #117 안에서 확인)
- `skills/sdd-run/scripts/sdd_runner.py` — `HEADLESS_DENY` · `invoke`

## 의도

- #118 확인: 러너 헤드리스 호출(`claude -p`)에 auto-memory 안내 · 메모리 파일 내용이 실리는지 유료 1회로 본다. 켜져 있으면 끄는 step을 더하고, 꺼져 있으면 출력만 남긴다
- kind: measure — 바꿀 파일이 없다. 검증 세션이 돈다

## 작업

- 지휘가 대조한 명령 그대로 1회(가장 싼 모델): 러너 헤드리스와 같은 인자에 `--model haiku`, stdin은 `/dev/null`
- 지시문: 도구를 쓰지 않고 시스템 지시만 보고 두 줄 — 1줄 auto memory 안내가 있으면 그 디렉터리 경로만(없으면 「없음」), 2줄 메모리 파일 내용이 실렸으면 「실림」(없으면 「없음」), 내용은 옮기지 않음
- 출력 원문은 스크래치에만. summary에는 「안내 있음/없음 · 내용 실림/없음 · total_cost_usd」와 명령(백틱)만 — 경로에 사용자 이름이 들어가 옮기지 않는다

## Acceptance Criteria

- summary에 명령(백틱)과 세 값이 있다(측정 step 판정)

## 검증 절차

1. 위 명령을 실제 실행한다(지휘 대조 받음).
2. 1줄이 경로면 켜짐 → 끄는 step 추가 / 둘 다 「없음」이면 꺼짐.
3. 결과를 `phases/runner-headless-block/index.json`의 해당 step에 기록한다.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- 승인받은 1회를 넘기지 않는다
