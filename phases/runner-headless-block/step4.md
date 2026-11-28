# Step 4: deny-rule-exact

## 읽어야 할 파일

- docs/runner-headless-block-2026-11-28/{PRD,ARCHITECTURE}.md — AC-1 · AC-5
- `skills/sdd-run/scripts/test_sdd_runner.py` — `assert_history_blocked`
- `skills/sdd-run/scripts/sdd_runner.py` — `HEADLESS_DENY`
- `docs/sdd-runner.md` — 「헤드리스 대화 기록 차단(#75)」 항목

## 의도

- 채우는 수용 조건: AC-1 · AC-5 — REVIEW 1회차 새 맥락 리뷰 🟡: 단위 테스트가 규칙이 좁아지는 변이(`Bash(.claude/projects*)` · `Read(~/.claude/projects)`)를 통과시킨다. 헤드리스 시험(step 3)에서 거부를 확인한 규칙 글자를 테스트가 그대로 단언하게 한다
- tdd: false — 이미 통과하는 동작의 테스트를 조이는 일이라 red를 만들 수 없다. 바꾸는 기존 테스트 파일은 `test_edits`에 적었다

## 작업

- `assert_history_blocked`의 규칙 확인을 「차단 목록 == step 3에서 확인한 네 글자(`Bash(*.claude/projects*)` · `Read(~/.claude/projects/**)` · `Grep(~/.claude/projects/**)` · `Glob(~/.claude/projects/**)`)」 하나의 단언으로 바꾼다. 상수를 import해 비교하지 않는다(같은 값끼리 비교가 돼 회귀를 못 잡는다)
- `docs/sdd-runner.md` 차단 항목 끝에 반대쪽 한계 한 줄: 셸 규칙은 글자 매칭이라 레포 상대 경로 · 문서 검사 명령(`grep '.claude/projects' docs/…`)도 막힌다
- 확인: 스크래치 복사본에서 `HEADLESS_DENY`의 Bash 규칙 앞 `*`를 지운 변이로 테스트 3개가 실패하는지 본다(레포 파일은 바꾸지 않는다)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 변이 확인 출력(`FAILED`)을 summary에 적는다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-headless-block-2026-11-28/ARCHITECTURE.md` 「테스트 전략」.
3. 결과를 `phases/runner-headless-block/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지. 이 step은 검증 세션이 `test_edits`에 적은 한 파일만 고친다.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- 진짜 `claude`를 띄우지 않는다.
