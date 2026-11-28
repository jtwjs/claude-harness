# Step 3: headless-trial

## 읽어야 할 파일

- docs/runner-headless-block-2026-11-28/{PRD,ARCHITECTURE}.md — AC-2 · 성공지표
- `skills/sdd-run/scripts/sdd_runner.py` — `invoke` · 차단 규칙 상수(step 1 결과)

## 의도

- 채우는 수용 조건: AC-2 — step 1 인자로 띄운 진짜 `claude -p`에서 대화 기록 읽기가 거부되고 레포 안 읽기는 되는지 출력으로 확인한다. 성공지표 애프터(장치로 막힌 길 n/4)를 잰다
- kind: measure — 바꿀 파일이 없다. 검증 차례(검증 세션)가 돈다

## 작업

- 유료 실행이다. 돌리기 직전에 지휘에 횟수 · 명령 · 모델을 적어 묻고, 답을 받은 것만 돌린다
- 러너 상수에서 인자를 그대로 뽑아(손으로 다시 쓰지 않는다) `claude -p --dangerously-skip-permissions --disallowedTools <규칙…> --output-format json --model <지휘가 정한 모델> -- <시험 지시문>`을 이 레포 루트에서 1회 돌린다
- 시험 지시문은 도구 호출 다섯을 차례로 하고 각 결과(거부 · 성공 · 오류 문구 첫 줄)만 보고하게 한다. 대화 기록 내용이 출력에 나오지 않게, 막히지 않았을 때도 내용을 찍지 않는 꼴로 쓴다:
  1. 셸: `grep -rqs zzprobe ~/.claude/projects; echo rc=$?`
  2. Read: `~/.claude/projects/__no_such_probe__.txt`
  3. Grep 도구: 패턴 `zzprobe`, 경로 `~/.claude/projects`, 출력 꼴 개수
  4. Glob 도구: `~/.claude/projects/*.zzprobe`
  5. 레포 안 Read: `README.md` 첫 줄
- 출력 원문은 스크래치(레포 밖)에만 둔다. summary에는 명령(백틱)과 항목별 결과 · 애프터 n/4만 적는다

## Acceptance Criteria

- summary에 실행한 명령(백틱)과 결과 다섯 줄 · 성공지표 애프터가 있다(측정 step 판정)
- 1~4 거부 · 5 성공이면 AC-2 통과. 하나라도 어긋나면 status `blocked` + 어긋난 항목(규칙을 고치는 수정 step이 필요하다)

## 검증 절차

1. 지휘 답을 받은 뒤 위 명령을 실제 실행한다.
2. 출력과 PRD AC-2를 대조한다.
3. 결과를 `phases/runner-headless-block/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 명령 백틱 포함)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- 지휘 답 없이 `claude`를 띄우지 않는다. 답에 적힌 횟수를 넘기지 않는다
