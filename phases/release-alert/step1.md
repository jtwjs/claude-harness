# Step 1: template-drift-line

## 읽어야 할 파일

- docs/release-alert-2026-11-27/{PRD,ARCHITECTURE}.md — ADR 없음. 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `hooks/conductor-context.sh` — 바꿀 파일. 레포 줄은 `:58` `lines.append(f"- {r.name} — {track}")`
- `hooks/cadence-reminder.sh:85-98` — 레포 세션 버전 알림. 같은 두 값(`.claude/harness.json` `harness.version` · 설치본 `.claude-plugin/plugin.json` `version`)을 읽는 기존 꼴. 이 파일은 고치지 않는다
- `hooks/tests/template-drift.sh` — 이 step의 테스트(검증 세션이 이미 커밋했다)
- `hooks/test.sh:646-669` — 기존 7-f 케이스(지휘 현황 바꿔 끼우기 꼴)

## 의도

- 채우는 수용 조건: AC-8 — 지휘 자리에는 하네스 설정이 없어 레포 세션 버전 알림이 안 뜬다. 지휘 현황의 각 대상 레포 줄에 「템플릿 X → 설치본 Y」를 붙인다

## 작업

- `hooks/conductor-context.sh`의 python 블록 안에서:
  - 설치본 폴더 = 환경변수 `CLAUDE_PLUGIN_ROOT`, 없으면 훅 폴더의 상위(`here.parent`). 설치본 버전 = 그 폴더 `.claude-plugin/plugin.json`의 `version`(문자열이고 비지 않을 때만). 레포 루프 전에 한 번 읽는다. step 2가 같은 파일의 `name`도 쓴다
  - 레포마다(트랙 줄을 만든 뒤, `top` = 그 레포 git 최상위): `top/.claude/harness.json`의 `harness.version`(문자열 · 비지 않음)을 읽는다. 설치본 버전과 둘 다 있고 다르면 레포 줄 끝에 ` · 템플릿 {레포 값} → 설치본 {설치본 값}`을 붙인다
  - 붙이지 않는 경우(조용히): 하네스 설정 없음 · JSON 깨짐 · `harness` 키 없음 · 값이 비었거나 문자열 아님 · 같음 · 설치본 버전을 못 읽음
- 줄은 하나로 남는다: `- {이름} — {트랙} · 템플릿 X → 설치본 Y`. 「열린 지휘 이슈」 줄은 그대로
- 읽기 실패가 훅 전체를 죽이지 않는다(그 레포만 건너뜀). 표준 라이브러리만 쓴다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `template_same_no_suffix` · `template_empty_version_no_suffix`
  - 비정상 입력: `template_broken_json_no_suffix`
  - 실패 경로: `template_installed_unreadable_skips`
  - 상태 전이: `template_differs_suffix` · `template_no_harness_config_no_suffix`
  - 동시성: 해당 없음: 훅은 파일을 읽기만 하고 레포마다 차례로 돈다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/release-alert-2026-11-27/ARCHITECTURE.md` 「지키는 것」(레포 세션 알림 `hooks/cadence-reminder.sh` 무변경 · 원격 조회 없음).
3. 결과를 `phases/release-alert/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 이 step은 릴리스 줄(원격 조회 · gh 호출 추가)을 만들지 않는다(step 2). `hooks/cadence-reminder.sh` · `hooks/lib/conductor.py` · `hooks.json`은 고치지 않는다
