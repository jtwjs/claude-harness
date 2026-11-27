# Step 5: release-check-fixes

## 읽어야 할 파일

- docs/release-alert-2026-11-27/{PRD,ARCHITECTURE}.md — ARCHITECTURE 「결정」 D1 · D2와 그 아래 AI 판단 불렛. ADR 없음. 이 레포는 루트 `CLAUDE.md`가 없다
- `hooks/conductor-context.sh` — 바꿀 파일. `version_at` · `release_base` · `release_suffix`(step 2)
- `hooks/tests/release-line.sh` — 이 step의 테스트(검증 세션이 이미 커밋했다). 끝의 「step 5」 묶음과 바뀐 느림 케이스
- `phases/release-alert/index.json` `reviews` 1회차 — 이 step이 고치는 지적

## 의도

- 채우는 수용 조건: AC-7 · AC-10 — REVIEW 1회차 지적 고침. 실제 대상에서 거짓 「릴리스 확인 실패」(설치본 0.40.0 → #41 꼴)가 뜨고, 하네스 원본 작업 트리 `plugin.json`이 깨지면 릴리스 꼬리가 조용히 사라진다. 둘 다 「0건과 다른 글로, 거짓 없이」를 어긴다

## 작업

- `release_base`(D2): `origin/main` first-parent 기록에서 「그 커밋 `version` = 설치본 버전 · 첫 부모 `version` ≠ 설치본 버전(또는 첫 부모에 파일 없음 · 부모 없음)」인 **가장 최근 커밋**을 돌려준다. 버전이 같은데 부모도 같은 커밋(버전을 그대로 두고 `plugin.json`의 다른 칸만 고친 머지)은 건너뛰고 **계속 찾는다**. 지금은 그 자리에서 `None`을 돌려 멈춘다
  - 후보를 판정하다 git 읽기가 실패하면(시간 초과 · 오류) 「파일 없음」으로 보지 않는다. 그 경우는 기준점 실패(`None`)로 돌려 「릴리스 확인 실패」가 붙게 한다 — 부모를 못 읽었다고 그 커밋을 기준점으로 쓰면 너무 최근 커밋을 기준점으로 잡아 적게 센다. 「파일 없음」과 「읽기 실패」를 가르는 법은 구현이 정한다(예: `git ls-tree`로 파일 유무를 먼저 보고, 부모 유무는 `git rev-list --parents -n 1`)
- `release_suffix`(D1): 레포 작업 트리에 `.claude-plugin/plugin.json`이 **있는데 읽을 수 없으면**(JSON 깨짐 · 충돌 표시) 「릴리스 확인 실패」를 붙인다. 파일이 없으면 지금처럼 꼬리 없음. 읽히고 이름이 다르면 지금처럼 꼬리 없음
- 꼴 · 다른 동작은 바꾸지 않는다(step 2 테스트가 그대로 지나가야 한다)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `release_base_skips_same_version_edit`
  - 비정상 입력: `release_worktree_plugin_broken_fails` · `release_odd_json_fails_isolated`
  - 실패 경로: `release_gh_slow_fails_within_limit` · `release_installed_unreadable_fails`
  - 상태 전이: `release_base_skips_same_version_edit`
  - 동시성: 해당 없음: 훅은 레포마다 차례로 돌고 원격은 읽기만 한다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/release-alert-2026-11-27/ARCHITECTURE.md` 「지키는 것」(로컬 ref 무변경 · 실패는 0건과 다른 글).
3. 결과를 `phases/release-alert/index.json`의 step 5에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `git fetch` · 로컬 ref 쓰기 금지. `hooks/conductor-context.sh` 밖은 고치지 않는다
