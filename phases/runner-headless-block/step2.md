# Step 2: history-ban-text

## 읽어야 할 파일

- docs/runner-headless-block-2026-11-28/{PRD,ARCHITECTURE}.md — AC-3 · AC-4 · AC-5, 결정 표
- `skills/sdd-run/scripts/preamble.md` — 작업 규칙 7번 「금지:」 줄
- `skills/sdd-plan/SKILL.md` — §3 「Step 분해 원칙」 · §4 step 템플릿의 「금지사항」 두 줄과 「작업」 · 「읽어야 할 파일」
- `docs/sdd-runner.md` — 헤드리스 판정 표 0번 줄 · 「effort」 항목 근처(헤드리스 `run` 인자를 말하는 자리)

## 의도

- 채우는 수용 조건: AC-3 · AC-4 · AC-5 — 금지 문구를 「`~/.claude` 아래 전부」로 분명히 하되 정상 읽기(레포 `.claude/` · 플러그인 스킬 문서)와 부딪치지 않게 하고, 계획이 실제 데이터 대신 가린 샘플을 넘기게 하고, 장치의 한계를 문서에 남긴다
- tdd: false — 지시문 · 스킬 · 러너 문서 글만 바뀐다. 테스트할 동작이 없다

## 작업

- 금지 문구 한 문장(같은 글자로 두 곳에): 「`~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.」
  - `preamble.md` 7번 금지 줄 끝에 이어 쓴다(새 번호를 만들지 않는다)
  - `sdd-plan/SKILL.md` step 템플릿 「금지사항」 둘째 줄 뒤에 셋째 줄로 넣는다. §3 「금지사항 명시」 문장의 「아래 템플릿 「금지사항」 두 줄은 늘 넣는다」를 「세 줄」로 고친다
- 「샘플을 넘긴다」 규칙(`sdd-plan/SKILL.md` §3에 불렛 하나 + 템플릿 「작업」에 자리 한 줄): step이 실제 데이터 꼴(훅 입력 · 로그 · API 응답 등)을 알아야 하면, 계획이 값 · 이름 · 경로를 가짜로 바꾼 가린 샘플을 step 파일에 넣는다. 샘플을 만들 수 없으면 step이 blocked로 지휘(혼자면 사람)에 요청한다. 「실제 데이터에서 찾아라 · 확인하라」는 쓰지 않는다 — 헤드리스 step은 그 데이터가 남은 곳(대화 기록)을 찾아 나선다
- `docs/sdd-runner.md`: 헤드리스 `run`이 `claude -p`에 `--disallowedTools`로 `.claude/projects`가 든 셸 명령과 `~/.claude/projects`의 Read · Grep · Glob을 막는다(세션 안 모드는 대상 아님, 지시문 앞 `--`) 한 항목 + 한계 한 줄 「경로를 나누거나(`cd ~/.claude && grep … projects`) 변수로 숨기는 우회까지는 못 막는다 — 금지 문구가 받는다」
- 쓰는 법: 강조어(전부 대문자 경고 · 굵은 글씨 남발) 대신 평이한 문장. 고치는 줄이 스킬 문서의 범위 · 보고 형식 · 재시도 상한 · 애매할 때 기본값을 흐리게 만들지 않게 한다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `grep -c '아래(대화 기록 · 원장 · 설정)를 읽지 않는다' skills/sdd-run/scripts/preamble.md skills/sdd-plan/SKILL.md` 각 1 이상
- `grep -rc '원장 실물(' skills templates agents docs/sdd-runner.md | grep -v ':0$'` 출력 없음
- `grep -c '가린 샘플' skills/sdd-plan/SKILL.md` 1 이상 · `grep -c '변수로 숨기는 우회' docs/sdd-runner.md` 1 이상

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-headless-block-2026-11-28/ARCHITECTURE.md` 「금지 문구와 장치의 범위」.
3. 결과를 `phases/runner-headless-block/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- 바꿀 파일은 위 셋(`preamble.md` · `sdd-plan/SKILL.md` · `docs/sdd-runner.md`)뿐이다. `templates/.claude/rules/testing.md` · `agents/test-writer.md` · `templates/stacks/**`(옆 트랙) · `docs/changes/**`(릴리스) 금지
