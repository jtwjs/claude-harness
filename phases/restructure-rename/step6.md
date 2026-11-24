# Step 6: rename-table-and-guard

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/harness-init/SKILL.md` 「이름표」
- `hooks/tests/no-brain.sh`(테스트 조각 형식)

## 작업

바꾸는 파일:

- `skills/harness-init/SKILL.md` 이름표
- 새 `hooks/tests/renames.sh`
- `hooks/weekly-readiness-check.sh` 알림 문구 · `skills/harness-score/SKILL.md` 제목과 옛 이름 문장

- 이름표에 행을 더한다: `harness` → `sdd-plan`, `harness-run` → `sdd-run`, `ai-readiness-cartography` → `harness-score`, `plannotator-visual-explainer` → 행 삭제(PR 설명은 `explain-diff`). 「언제」 칸은 다음 릴리스 버전
- 새 `hooks/tests/renames.sh`: `skills` · `agents` · `hooks` · `templates` · `scripts` · `README.md` · `BACKLOG.md`에서 위 옛 이름 4개를 grep 해 0이면 `ok`. 빼는 곳: `hooks/test.sh` · 자기 자신 · `skills/harness-init/SKILL.md`(이름표). PLAN 스킬 옛 이름은 `claude-harness:harness([^-a-z]|$)|skills/harness/` 패턴으로만 센다
- 새 테스트 파일은 `hooks/tests/no-brain.sh`처럼 `hooks/test.sh`가 source 하는 조각이다: `printf '\n[이름] …\n'`로 시작, `$HOOKS` · `$TMP` · `ok` · `bad`를 그대로 쓰고 변수는 파일 고유 접두사(`_xx_`)를 붙인다
- 이름 바꾸기 뒷정리(step 3에서 남은 것): `harness-score`는 이제 사람만 부른다(ADR-016 D5). `hooks/weekly-readiness-check.sh`의 하락 알림 「원하면 harness-score 로 대시보드와 할 일 목록을 만든다」를 사용자에게 `/harness-score`를 안내하는 문장으로 바꾼다. `skills/harness-score/SKILL.md`의 제목 「AI-Readiness Cartography」와 「cartography」라는 이름을 설명하는 문장 2곳을 새 이름에 맞춘다(리포트 파일 이름 `ai-readiness-score.json` · 상태줄 접두사 `ai-readiness — `는 그대로)
- tdd: false — 이름 바꾸기가 앞 step에서 끝나 지금 넣는 검사는 바로 통과한다(회귀 방지용)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `bash hooks/test.sh 2>&1 | grep -F '[renames]'` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-rename/index.json`의 step 6에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
