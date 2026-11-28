# Step 7: memory-test-isolation

## 읽어야 할 파일

- `skills/sdd-run/scripts/test_sdd_runner.py` — `RunnerCase.setUp`의 `self.env` · `test_headless_auto_memory_off*`
- `skills/sdd-run/scripts/sdd_runner.py` — `HEADLESS_NO_MEMORY`

## 의도

- step 6 새 맥락 리뷰 🟡: `setUp`이 부모 환경을 그대로 물려받아, 부모에 `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`이 있으면(step 6 뒤 헤드리스 step 에이전트가 테스트를 돌릴 때) auto memory 테스트가 구현 없이도 통과한다(리뷰어 변이: 「첫 시도에만 설정」이 통과)
- tdd: false — 이미 통과하는 테스트의 격리를 고치는 일이라 red를 만들 수 없다. 바꾸는 기존 테스트 파일은 `test_edits`에 적었다

## 작업

- `setUp`의 `self.env`에서 `CLAUDE_CODE_DISABLE_AUTO_MEMORY`를 뺀다(부모 값과 상관없이 「러너가 넣었는가」만 본다)
- 확인: 스크래치 복사본(새 폴더, 지우지 않음)에서 부모 환경 `=1`로 「첫 시도에만 설정」 변이를 돌려 `on_retry`가 실패하는지 본다. 원본도 같은 조건으로 먼저 OK를 본다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 변이 확인 출력을 summary에 적는다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 결과를 `phases/runner-headless-block/index.json`의 해당 step에 기록한다.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지. 이 step은 검증 세션이 `test_edits`에 적은 한 파일만 고친다.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- 진짜 `claude`를 띄우지 않는다.
