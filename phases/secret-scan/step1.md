# Step 1: single-form-job

## 읽어야 할 파일

- docs/secret-scan-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음. ARCHITECTURE 「결정」 S1 · 검증 세션이 정한 기술 세부 목록
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `templates/.github/workflows/ci.yml` — 단일 형태 `jobs.verify`(위쪽)와 머리 주석
- `skills/harness-init/scripts/fill_ci.py` — 템플릿 플레이스홀더 7개를 채우는 스크립트(바꾸지 않는다)
- `hooks/tests/fill-ci.sh` — 템플릿 테스트 꼴 · 플레이스홀더 7개 단언(①)
- `hooks/tests/secret-scan.sh` — 이 step의 테스트(검증 세션이 먼저 커밋)

## 의도

- 채우는 수용 조건: AC-1 · AC-2 · AC-8, AC-3 · AC-4의 잡 동작 부분 — 템플릿 CI 단일 형태에 PR 커밋 범위만 보는 비밀값 검사 잡을 버전 · 체크섬 고정으로 넣는다

## 작업

- `templates/.github/workflows/ci.yml` 단일 형태 `jobs:` 아래, `verify` 잡 옆에 잡 `secret-scan`을 더한다. `verify`와 `needs`로 잇지 않는다(서로 기다리지 않음)
- 잡 계약(테스트가 이 이름 · 꼴로 찾는다):
  - `if: github.event_name == 'pull_request'` — push에서는 건너뛴다(ARCHITECTURE S1)
  - `runs-on: ubuntu-latest`
  - 잡 `env`: `GITLEAKS_VERSION: 8.30.1` · `GITLEAKS_SHA256: 551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb`(상류 `gitleaks_8.30.1_checksums.txt`의 `linux_x64` 값, 검증 세션 실측 일치)
  - 스텝 1: `uses: actions/checkout@v4` + `with: fetch-depth: 0`
  - 스텝 2 `name: install gitleaks`: `curl -sSfL -o <파일> "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"` → `sha256sum -c`로 `GITLEAKS_SHA256`과 대조(다르면 실패, 압축을 풀기 전) → `tar -xzf`로 `gitleaks` 실행 파일을 `$RUNNER_TEMP`에 푼다. 내려받은 파일 · 실행 파일은 `$RUNNER_TEMP` 안에만 둔다(작업 트리를 더럽히지 않음). `curl`은 `-o <파일>` 꼴로 부른다(테스트의 가짜 curl이 `-o` 다음 인자에 파일을 쓴다)
  - 스텝 3 `name: gitleaks scan`: 스텝 `env`에 `BASE_SHA: ${{ github.event.pull_request.base.sha }}` · `HEAD_SHA: ${{ github.event.pull_request.head.sha }}`. `run:`은 `"$RUNNER_TEMP/gitleaks" git --no-banner --redact --log-opts="${BASE_SHA}..${HEAD_SHA}" .` — `run:` 안에 `${{ }}`를 직접 쓰지 않는다
  - 잡 머리에 주석 한 줄: 걸리면 값은 이미 원격에 있으니 폐기가 먼저다
- 스텝 `run:`은 GitHub Actions 기본 셸(`bash -e`)로 돈다. 테스트도 그 셸로 꺼내 돌린다
- 지킬 것: 템플릿 플레이스홀더(`{{대문자}}`)를 늘리지 않는다 · 템플릿에 이 레포 전용 경로 · 이름을 넣지 않는다 · 실제 키 꼴 값을 어디에도 쓰지 않는다
- 앱별 주석 블록은 이 step에서 건드리지 않는다(step 2)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test` — 이 레포 verify는 test 하나)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」):
  - 빈 값·경계: `ss-pr-only`
  - 비정상 입력: `ss-install-sha-mismatch-fails`
  - 실패 경로: `ss-install-download-fails` · `ss-scan-exit-propagates`
  - 상태 전이: 해당 없음: 상태를 가진 것이 없는 CI 잡이다
  - 동시성: 해당 없음: 잡 하나 안의 스텝은 차례로 돈다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/secret-scan-2026-11-28/ARCHITECTURE.md` 「바뀌는 층」 단일 형태 행 · 「지키는 것」.
3. 결과를 `phases/secret-scan/index.json`의 step 1에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다.
- 이 레포 자신의 CI(`.github/workflows/ci.yml`) · `fill_ci.py`는 고치지 않는다.
