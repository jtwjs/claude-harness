# Step 2: release-line

## 읽어야 할 파일

- docs/release-alert-2026-11-27/{PRD,ARCHITECTURE}.md — ARCHITECTURE 「결정」 D1~D3과 그 아래 AI 판단 불렛이 규칙의 정본이다. ADR 없음. 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `hooks/conductor-context.sh` — 바꿀 파일. `run()`(`:30-36`, 시간 제한 · 전체 마감) · `slug()`(`:39-42`) · 기존 gh 호출(`:59-60`, 5초) · step 1이 더한 설치본 읽기와 템플릿 꼬리
- `hooks/tests/release-line.sh` — 이 step의 테스트(검증 세션이 이미 커밋했다). 가짜 gh가 받는 인자 꼴과 내는 JSON이 여기 있다
- `scripts/release.sh:60-63` — 버전은 `.claude-plugin/plugin.json` `version`

## 의도

- 채우는 수용 조건: AC-1 · AC-2 · AC-3 · AC-4 · AC-5 · AC-6 · AC-7 · AC-10 — 하네스 원본 줄에 「릴리스 안 된 머지 n건 …」 또는 「릴리스 확인 실패」를 붙여, 머지가 설치본에 없는 것을 사람이 찾지 않아도 보이게 한다. 실패 줄을 같은 step에 둔 이유: 나눠 두면 앞 step 구현이 실패 처리를 먼저 넣어 뒤 step 테스트가 RED에서 실패하지 않는다

## 작업

- `hooks/conductor-context.sh`의 python 블록 안에서, 레포마다(트랙 줄을 만든 뒤) 하네스 원본이면 릴리스 꼬리를 정한다. 꼬리는 레포 줄 끝에 ` · `로 잇고, 템플릿 꼬리(step 1)보다 앞에 둔다
- 하네스 원본 가려내기(D1): 그 레포 `top/.claude-plugin/plugin.json`의 `name`이 설치본 `plugin.json`의 `name`과 같다. 레포에 그 파일이 없거나 이름이 다르면 릴리스 꼬리 없음 · 원격 조회 없음
  - 설치본 `plugin.json`을 통째로 못 읽으면(이름을 모름): `.claude-plugin/plugin.json`이 있는 대상 레포 줄마다 실패 꼬리
  - 이름은 같은데 설치본 `version`이 비었거나 없으면: 실패 꼬리
- 기준점(D2): 그 레포에서 로컬 ref `origin/main`의 first-parent 기록 중, 그 커밋의 `.claude-plugin/plugin.json` `version`이 설치본 버전이고 첫 부모의 값은 다른(또는 파일 없음 · 부모 없음) 가장 최근 커밋. git 호출은 모두 `run()`을 지난다. 못 찾으면 실패 꼬리 · 원격 조회 없음. 로컬 ref를 바꾸지 않는다(fetch 금지)
- 원격 조회(D3): `run([gh, "api", f"repos/{slug}/compare/{기준점 전체 sha}...main"], top, timeout=5)` 1회. `--jq`를 쓰지 않고 stdout JSON을 python에서 읽는다. slug가 없거나 · 호출 실패(`None`) · JSON 아님 · `commits`가 리스트가 아니면 실패 꼬리
- 세기: n = `total_commits`(정수면), 아니면 `len(commits)`. n = 0이면 꼬리 없음
- 꼴(AC-1 · AC-2): PR 번호 = 각 커밋 `commit.message` 첫 줄 끝의 마지막 `(#N)`. 번호 없는 커밋도 n에 센다. `commits` 순서(오래된 것부터) 앞의 번호 5개까지 보인다. m = n − 보인 번호 수
  - m = 0: `릴리스 안 된 머지 {n}건 #A · #B (설치본 {X})`
  - m > 0: `릴리스 안 된 머지 {n}건 #A · #B · #C · #D · #E 외 {m}건 (설치본 {X})`
  - 번호가 하나도 없으면: `릴리스 안 된 머지 {n}건 (설치본 {X})`(번호 0개일 때는 「외」를 쓰지 않는다)
- 실패 꼬리: `릴리스 확인 실패`로 시작한다. 짧은 사유 괄호를 붙여도 된다(예: `릴리스 확인 실패(원격)`). 실패 꼬리가 붙은 줄에는 「릴리스 안 된 머지」가 나오지 않는다
- 한 레포의 실패가 다른 레포 줄을 막지 않는다(그 레포 처리 안에서 예외를 삼킨다). 표준 라이브러리만 쓴다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
  - 빈 값·경계: `release_zero_no_suffix` · `release_five_numbers_no_overflow` · `release_overflow_shows_rest`
  - 비정상 입력: `release_commit_without_pr_number_counted` · `release_bad_json_fails`
  - 실패 경로: `release_gh_error_fails` · `release_base_not_found_fails` · `release_installed_version_empty_fails` · `release_installed_unreadable_fails` · `release_gh_slow_fails_within_limit`
  - 상태 전이: `release_counts_with_numbers` · `release_bump_unreleased_counted` · `release_remote_ahead_of_local_counted` · `release_docs_only_counted` · `release_other_plugin_repo_not_checked` · `release_failure_isolated_to_repo`
  - 동시성: 해당 없음: 훅은 레포마다 차례로 돌고 원격은 읽기만 한다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/release-alert-2026-11-27/ARCHITECTURE.md` 「지키는 것」(원격 조회는 하네스 원본 한 레포만 · `run()` 5초 제한 · 로컬 ref 무변경 · 실패는 0건과 다른 글).
3. 결과를 `phases/release-alert/index.json`의 step 2에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `git fetch` · 로컬 ref 쓰기 금지. `hooks/cadence-reminder.sh` · `hooks/lib/conductor.py` · `hooks.json`은 고치지 않는다
