# Step 8: fix-hook-ident-quote

## 읽어야 할 파일

- CLAUDE.md(없으면 건너뜀), docs/desk-hypothesis-gate-2026-11-12/PRD.md · ARCHITECTURE.md · ADR.md · SDD-SIDE.md (결정 표 「작업 식별」·「`task=null` 맡김」)
- hooks/hypothesis-gate.sh · hooks/tests/gate-hook.sh · hooks/test.sh · hooks/lib/ledger.py (`append` 의 repo·task 값 검사 `[A-Za-z0-9._-]{1,100}`)

## 작업

`hooks/hypothesis-gate.sh` 한 파일만 고친다. sdd 리뷰 1회차 🟡 둘이다.

1. **task 고르기**: 지금은 미완료 step 이 있는 `phases/*/index.json` 중 이름순 첫 번째를 고른다. phase 가 둘 이상 열려 있으면 지금 하는 작업이 아닌 phase 가 task 가 된다. 아래 규칙으로 바꾼다(결정 주체: 사용자가 수정을 승인, 규칙은 AI 추천).
   - 미완료 phase 후보를 모은다(지금과 같은 검사).
   - 후보가 하나면 그것. 후보가 둘 이상이면 현재 git 브랜치 이름과 맞는 것: 브랜치 이름의 마지막 `/` 뒤 부분이 `{task}` 로 끝나는 후보 중 이름이 가장 긴 것(러너 브랜치 이름이 `feat-{task}` 또는 `harness.json` `git.branchPattern` 이라서다).
   - 둘 이상인데 맞는 게 없으면 `null`. 모호하면 연속 계산에서 빠지는 쪽(`task=null`)이 다른 작업에 섞이는 것보다 안전하다.
   - 후보가 없으면 `null`(지금과 같다). 브랜치를 못 구해도(`detached HEAD` 등) 죽지 않는다.
2. **경로 따옴표**: 주입 문구 안의 `python3 ${HERE}/lib/ledger.py` 경로를 따옴표로 감싼다(`python3 "${HERE}/lib/ledger.py" ...`). 경로에 공백이 있어도 모델이 그대로 불러 쓸 수 있게 한다. 주입 문구의 나머지 내용은 바꾸지 않는다.

- 어떤 실패에도 exit 0, 프롬프트를 막지 않는다(AC2). 원장에 쓰지 않는다. 새 의존을 만들지 않는다.
- 🔴 **`hooks/test.sh` 는 고치지 않는다.** 러너의 테스트 파일 판정이 이 파일을 못 알아봐서 RED 확인이 깨진다. 새 케이스는 `hooks/tests/gate-hook.sh` 끝에 더한다(`ok`·`bad`·`TMP`·`HOOKS` 그대로). 실제 `~/.claude` 원장은 건드리지 않는다(`CLAUDE_HYPOTHESIS_LEDGER` 로 임시 경로). 임시 git 레포를 만들 때는 `TMP` 아래에 만든다.

## Acceptance Criteria

- 새 케이스(`hooks/tests/gate-hook.sh`): 임시 레포에 미완료 phase 둘(`aaa`, `bbb`)이 있고 브랜치가 `feat-bbb` 면 주입 문구에 `task=bbb` / 브랜치가 둘 중 어느 것과도 안 맞으면 `task=null` / 미완료 phase 가 하나면 브랜치와 무관하게 그 이름 / 후보가 없으면 `task=null` / `HOOKS` 경로에 공백이 있을 때(경로에 공백이 든 폴더에 훅을 복사해 실행) 주입 문구의 `ledger.py` 경로가 따옴표로 감싸져 있다.
- `bash hooks/test.sh` 전부 통과. 테스트 커밋 먼저, 그 시점에 새 케이스가 실패.

## 검증 절차

1. `bash hooks/test.sh` 실제 실행. 기존 훅 케이스 회귀 확인.
2. `phases/hypothesis-ledger/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 사용자의 실제 원장(`~/.claude/hypothesis-ledger.jsonl`)을 테스트에서 건드리지 않는다.
- 주입 문구의 판정 칸 정의(`hyp rec acc why rebut skip gate`)와 `[가설 요구]` 문구를 바꾸지 않는다.
