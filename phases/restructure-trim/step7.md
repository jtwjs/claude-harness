# Step 7: trim-history-flow

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- ADR-016 D0(남길 이유 한 구절의 기준)
- 아래 파일 목록

## 작업

바꾸는 파일:

- `skills/{sdd,sdd-plan,sdd-run,sdd-review,design-brief,design-critique,design-reconcile,why,how,conductor,commit,pr-write,changeset}/SKILL.md`
- 새 `hooks/tests/no-history-flow.sh`

- 테스트 먼저(`hooks/tests/no-history-flow.sh`): 왼쪽 파일들 본문에 날짜(`20[0-9]{2}-[0-9]{2}`) · 버전(`[0-9]+\.[0-9]+\.[0-9]+`) 이력 줄이 없다. 경로 · 형식 예시(`YYYY-MM-DD`)는 숫자가 아니라 걸리지 않는다. 새 테스트 파일은 `hooks/tests/no-brain.sh`처럼 `hooks/test.sh`가 source 하는 조각이다: `printf '\n[이름] …\n'`로 시작, `$HOOKS` · `$TMP` · `ok` · `bad`를 그대로 쓰고 변수는 파일 고유 접두사(`_xx_`)를 붙인다
- `skills/pr-write/SKILL.md` 4.6 심각도: 「`sdd-review`의 `확인 필요`는 🟡로 센다」를 `sdd-review` · `code-reviewer` 둘 다로 넓힌다(ADR-016 Q10). PR 4부터 `agents/code-reviewer.md`도 증명 못 한 지적을 등급 없이 `⚠️ 확인 필요`로 내서, 안 세면 심각도가 「없음」으로 잡혀 자동 머지 판정이 거짓 충족된다. 표기는 띄어 쓴 `확인 필요` 하나로 둔다
- 날짜 · 버전 · 「~에서 바꿨다」 이력과 배경 문단을 지운다. 처음 보는 상황에서 판단을 바꾸는 이유는 한 구절만 남긴다(ADR-016 D0)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `bash hooks/test.sh 2>&1 | grep -F '[no-history-flow]'` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-trim/index.json`의 step 7에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
