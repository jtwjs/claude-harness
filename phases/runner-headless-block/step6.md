# Step 6: auto-memory-off

## 읽어야 할 파일

- 이슈 #118 본문 · `phases/runner-headless-block/index.json` step 5 summary(확인 결과: 헤드리스 호출에 auto memory 안내가 실린다)
- `skills/sdd-run/scripts/sdd_runner.py` — `invoke`의 `env`(지금 `SDD_RUNNER_SINCE`만 다룬다) · `HEADLESS_DENY` 옆 상수 자리
- `skills/sdd-run/scripts/test_sdd_runner.py` — `FAKE`(호출마다 `N.env`에 `CLAUDE_CODE_DISABLE_AUTO_MEMORY` 값을 남긴다) · `assert_history_blocked`
- `docs/sdd-runner.md` — 「헤드리스 대화 기록 차단(#75)」 항목

## 의도

- #118: 헤드리스 step 시스템 지시에 대화 기록 폴더 아래 memory 안내가 실려 금지 문구와 부딪치고, 그 메모리 파일 내용이 도구 호출 없이 맥락에 실릴 수 있다. 러너 헤드리스 호출 환경에서 auto memory를 끈다

## 작업

- `invoke`가 만드는 `env`에 `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`을 늘 넣는다. 부모 환경에 다른 값이 있어도 `1`로 덮는다. 변수 이름은 `HEADLESS_DENY` 옆 상수 한 곳에 둔다
- 세션 안 모드(`prompt` · `judge`)는 바꾸지 않는다
- `docs/sdd-runner.md` 차단 항목에 한 줄: 헤드리스 호출은 auto memory도 끈다(`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`) — 메모리 안내가 금지 문구와 부딪치고 메모리 파일 내용이 도구 없이 맥락에 실리는 길(#118). 변수 이름은 CLI 문자열 근거이고 실제로 먹는지는 헤드리스 시험으로 확인한다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 같이 돈다)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_headless_auto_memory_off`
  - 비정상 입력: `test_headless_auto_memory_off_over_parent`
  - 실패 경로: 해당 없음: 끈 효과는 claude 쪽 동작이라 단위 테스트 밖이다(헤드리스 시험)
  - 상태 전이: `test_headless_auto_memory_off_on_retry`
  - 동시성: 해당 없음: 호출 하나의 환경이다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-headless-block-2026-11-28/ARCHITECTURE.md` 「코드 지도」.
3. 결과를 `phases/runner-headless-block/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- 진짜 `claude`를 띄우지 않는다(유료). 테스트는 가짜 claude로만 돈다.
