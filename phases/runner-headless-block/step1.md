# Step 1: headless-disallow

## 읽어야 할 파일

- docs/runner-headless-block-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd-run/scripts/sdd_runner.py` — `invoke`(헤드리스 호출, `cmd` 목록) · `EFFORT` 같은 모듈 상수 자리
- `skills/sdd-run/scripts/test_sdd_runner.py` — `test_intent_effort_headless_passes_effort`(가짜 claude 인자 `argv(i)` 꼴) · `FAKE`(지시문은 `sys.argv[-1]`, 나머지는 `N.argv`)

## 의도

- 채우는 수용 조건: AC-1 — 헤드리스 step이 대화 기록(`~/.claude/projects`)을 셸 · Read · Grep · Glob으로 읽지 못하게 러너가 `claude -p` 인자로 기본 차단한다

## 작업

- 모듈 상수 하나(예: `HEADLESS_DENY`)에 차단 규칙 넷을 둔다(PRD 결정 runner-headless-block-const · -tools · -pattern):
  - 셸: `.claude/projects`가 든 명령 전부를 거부하는 `Bash(…)` 규칙 하나(앞뒤 와일드카드)
  - `Read` · `Grep` · `Glob`: 각각 `~/.claude/projects/**` 경로 규칙
- `invoke`의 `cmd`에 `--disallowedTools` 다음 규칙을 하나씩 따로 인자로 넣고, 지시문 바로 앞에 `--`를 넣는다. 지시문은 마지막 인자 하나 그대로(ARCHITECTURE 「확인한 사실」 — 여러 값 옵션이 지시문을 먹지 않게)
- 세션 안 모드(`prompt` · `judge`)는 바꾸지 않는다(PRD 결정 runner-headless-only)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`, 러너 단위 테스트를 같이 돈다)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `test_headless_disallow_with_model`
  - 비정상 입력: 해당 없음: 차단 규칙은 코드 상수라 바깥 입력이 없다
  - 실패 경로: 해당 없음: 거부 결과는 claude 쪽 동작이라 단위 테스트 밖이다(step 3 헤드리스 시험)
  - 상태 전이: `test_headless_disallow_on_retry`
  - 동시성: 해당 없음: 호출 하나의 인자 목록이다

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
- 진짜 `claude`를 띄우지 않는다(유료). 테스트는 가짜 claude(`SDD_RUNNER_CLAUDE`)로만 돈다.
