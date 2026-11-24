# Step 2: conductor-issues-script

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/conductor/SKILL.md` §4 graphql 명령 묶음
- `skills/conductor/scripts/tracks_status.py`(같은 폴더 스크립트 형식)
- `hooks/test.sh`의 `CLAUDE_CONDUCTOR_GH` 가짜 gh 쓰는 방식

## 작업

바꾸는 파일:

- 새 `skills/conductor/scripts/issues.py`
- 새 `hooks/tests/conductor-issues.sh`

- `issues.py block <이슈> <막는 이슈>` · `sub <부모> <자식>` · `ready [--repo R]`: §4에서 복사해 쓰던 graphql 호출을 감싼다. `gh` 경로는 환경 변수로 바꿀 수 있게(테스트용)
- 테스트 먼저(`hooks/tests/conductor-issues.sh`): 가짜 `gh`(인자를 파일에 적는 셸)로 각 하위 명령이 넘기는 graphql 인자를 확인. 새 테스트 파일은 `hooks/tests/no-brain.sh`처럼 `hooks/test.sh`가 source 하는 조각이다: `printf '\n[이름] …\n'`로 시작, `$HOOKS` · `$TMP` · `ok` · `bad`를 그대로 쓰고 변수는 파일 고유 접두사(`_xx_`)를 붙인다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `bash hooks/test.sh 2>&1 | grep -F '[conductor-issues]'` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-trim/index.json`의 step 2에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
