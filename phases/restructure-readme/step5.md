# Step 5: version-bump

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json` · `docs/changes/` 아무 파일 두 개(모양) · `scripts/release.sh` 사전 확인 절

## 작업

바꾸는 파일:

- `.claude-plugin/plugin.json` · `.claude-plugin/marketplace.json`(이 플러그인 항목의 `version`만)
- 새 `docs/changes/0.41.0.md`

- 버전을 0.40.0 → 0.41.0으로 올린다. 0.x에서 호환이 깨지는 변경은 minor를 올린다(단계 스킬 11개를 모델이 못 부르게 닫은 것이 호환 깨짐). `marketplace.json`의 마켓플레이스 자체 `version`(0.1.0)은 건드리지 않는다
- `docs/changes/0.41.0.md`: `# 0.41.0` 아래 bullet로 하네스 재구성(ADR-016, #40) PR 1~7이 바꾼 것을 사용자 영향 큰 것부터 한 줄씩. 사람 · 회사 이름을 쓰지 않는다. 숫자는 `phases/restructure-*/index.json` summary에 있는 것만
- 릴리스(`scripts/release.sh`)는 돌리지 않는다 — 머지 뒤 사람이 한다
- `scripts/release.sh` 사전 확인이 버전 두 곳 일치 · 변경 이력 파일을 검사하면 그 조건에 맞춘다
- tdd: false — 버전 숫자와 이력 한 장이다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `python3 -c "import json; a=json.load(open('.claude-plugin/plugin.json'))['version']; b=[p['version'] for p in json.load(open('.claude-plugin/marketplace.json'))['plugins'] if p['name']=='claude-harness'][0]; assert a==b=='0.41.0', (a,b)"`
- `test -s docs/changes/0.41.0.md`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-readme/index.json`의 step 5에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
