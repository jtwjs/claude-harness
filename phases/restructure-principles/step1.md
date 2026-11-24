# Step 1: base-branch-script

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `skills/pr-write/SKILL.md` 「기준 브랜치」 줄
- `skills/sdd-review/SKILL.md` · `skills/changeset/SKILL.md` · `skills/harness-init/SKILL.md`의 기준 브랜치 줄(지금 4벌이 어긋난다)
- `hooks/tests/no-brain.sh`(테스트 조각 형식)

## 작업

바꾸는 파일:

- 새 `scripts/base-branch.sh`
- 새 `hooks/tests/base-branch.sh`

- 계약: `bash scripts/base-branch.sh [레포 경로, 기본 .]` → 기준 브랜치 이름 한 줄을 stdout. 순서 ① `.claude/harness.json` `git.baseBranch` ② `git symbolic-ref --short refs/remotes/origin/HEAD`에서 `origin/`을 뗀 값 ③ 둘 다 없으면 stderr 한 줄 + **exit 2**(부른 쪽이 사람에게 묻는다). `main` 하드코딩 금지. JSON은 `python3`로 읽는다(레포 훅과 같은 방식)
- 테스트 먼저(`hooks/tests/base-branch.sh`, `$TMP` 아래 임시 git 레포): baseBranch=`develop` → `develop` · baseBranch 빈 값 + origin/HEAD=main → `main` · harness.json 없음 + origin/HEAD → `main` · 둘 다 없음 → exit 2. 새 테스트 파일은 `hooks/tests/no-brain.sh`처럼 `hooks/test.sh`가 source 하는 조각이다: `printf '\n[이름] …\n'`로 시작, `$HOOKS` · `$TMP` · `ok` · `bad`를 그대로 쓰고 변수는 파일 고유 접두사(`_xx_`)를 붙인다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `bash hooks/test.sh 2>&1 | grep -F '[base-branch]'` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-principles/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
