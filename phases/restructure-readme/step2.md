# Step 2: readme-rewrite

## 읽어야 할 파일

- `docs/harness-restructure-2026-11-24/PRD.md` · `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` · `docs/harness-restructure-2026-11-24/ADR.md`(ADR-016). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 세 장과 `.claude/rules/non-obvious-patterns.md`
- `README.md` · `hooks/hooks.json` · `.claude-plugin/plugin.json` · `docs/principles/INDEX.md`
- ARCHITECTURE §1 · §2 · `skills/sdd/SKILL.md` 「단계 → 스킬 · 체크포인트」 표
- `phases/restructure-readme/index.json` step 1 summary(숫자 한 줄 재료)

## 작업

바꾸는 파일:

- `README.md` · `.claude-plugin/plugin.json`(keywords만)
- 새 `hooks/tests/readme-index.sh`

- 테스트 먼저(`hooks/tests/readme-index.sh`), 넷을 본다
  - README 표의 스킬 이름 집합 = `ls skills`
  - README의 훅 개수 = `hooks.json`에 걸린 고유 스크립트 수
  - README의 에이전트 이름 집합 = `ls agents`(`.md` 뗀 이름)
  - README의 상대 링크(`](...)` 중 `http`로 시작하지 않는 것)가 실제 파일 · 폴더를 가리킨다
  - 새 테스트 파일은 `hooks/tests/no-brain.sh`처럼 `hooks/test.sh`가 source 하는 조각이다: `printf '\n[이름] …\n'`로 시작, `$HOOKS` · `$TMP` · `ok` · `bad`를 그대로 쓰고 변수는 파일 고유 접두사(`_xx_`)를 붙인다
- README 재작성(ADR-016 D1 · REVIEW §1-6 결함 「훅 10개」 · `explain-diff-*`를 고친다). 구성(지휘 메모, 사용자 승인):
  ```
  ├ 첫 화면: 제목 · 한국어 한 줄 · 영어 한 줄("A Korean-language Claude Code plugin …") · [version(동적)] [CI] [MIT]
  │   설치 3줄 → /harness-init → /sdd · mermaid ①~⑤ (🙋는 sdd SKILL.md 체크포인트 표와 같은 자리)
  ├ 왜 만들었나: 문제 | 하네스가 하는 일 | 확인 장치 — 3줄
  ├ 무엇이 들었나: 숫자 한 줄 → 표(종류 | 이름 = SKILL.md 링크 | 언제("~할 때") | 부르는 법(자동 / `/이름`)) · 훅은 <details>(막는 것 / 알리기만)
  ├ 설치하면 생기는 것: 대상 레포 파일 · 레포 밖 설정(gh 계정 파일 · conductor.json 등) · 「모든 레포에서 도는 훅」 vs 「.claude/harness.json 있는 레포에서만」 — 접지 말고 밖에
  ├ 원칙: 한 줄 + docs/principles/INDEX.md 링크(목록을 다시 쓰지 않는다)
  ├ 업데이트 · 끄기: 3줄
  └ 더 보기: 변경 이력(docs/changes/) · 함께 쓰는 레포 2줄 · 가져온 것(외부 MIT 스킬 출처) · 관리자용(접기)
  ```
- 쓰는 규칙
  - 첫 화면에 🙋 개수를 쓰지 않는다 — 「단계마다 정해 둔 🙋에서만 멈춘다」
  - 흐름 그림에 「이해 증명」을 넣지 않는다(step 4가 걷는다)
  - 재구성 Before → After 절을 만들지 않는다(ADR-016 D0) — 이력은 `docs/changes/`
  - 「step마다 테스트 먼저」라고 쓰지 않는다 → 「tdd를 켠 step은 테스트 먼저, 러너가 git 기록으로 확인」
  - 필요한 것: git · python3(없으면 훅 6개가 조용히 꺼짐 — 개수는 `hooks/*.sh`에서 python3를 부르는 훅을 세어 맞춘다) · (선택) gh · (선택) claude-md-management
  - 버전은 shields 동적 JSON 배지(`.claude-plugin/plugin.json`의 `$.version`, 링크는 `docs/changes/`). 본문에 버전 숫자를 쓰지 않는다. CI 배지는 `.github/workflows/ci.yml`의 실제 workflow 배지 URL
  - 숫자 한 줄은 step 1 summary의 실측값. 상시 토큰이 `미측정`이면 숫자 대신 쓰지 않는다(개수만)
  - 공개 레포다. 사람 · 회사 이름, 날짜, 개인 문서 문구를 쓰지 않는다. 사용자는 「사용자」. 「개인 작업 방식 기준이라 골라 쓰길 권한다」 한 줄은 넣어도 된다
- `.claude-plugin/plugin.json` keywords에서 `second-brain`을 뺀다. 다른 키는 그대로
- GitHub About · topics는 이 step에서 바꾸지 않는다(머지 때 지휘 몫)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `bash hooks/test.sh 2>&1 | grep -F '[readme-index]'` 출력 있음
- `! grep -q second-brain .claude-plugin/plugin.json`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/harness-restructure-2026-11-24/ARCHITECTURE.md` 3절(자리) · 5절(경계 규칙), ADR-016이 정한 값은 참조만 했는지.
3. 결과를 `phases/restructure-readme/index.json`의 step 2에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로를 적는다)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/` · design-notes 변경 이력)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `hooks/test.sh`를 고치지 않는다. 새 테스트는 `hooks/tests/*.sh`에만 둔다(`hooks/test.sh`가 source 한다).
- push · PR 금지(러너 밖에서 사람이 한다).
