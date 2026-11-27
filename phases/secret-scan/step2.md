# Step 2: app-form-job

## 읽어야 할 파일

- docs/secret-scan-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `templates/.github/workflows/ci.yml` — step 1이 넣은 단일 형태 `secret-scan` 잡, 맨 아래 앱별 주석 블록(`# jobs:` ~ `ci-gate`)
- `hooks/tests/secret-scan.sh` — 이 step의 테스트(검증 세션이 먼저 커밋)

## 의도

- 채우는 수용 조건: AC-5 — 앱별 형태를 펼쳤을 때도 비밀값 검사 잡이 있고 `ci-gate`가 그 결과를 모은다

## 작업

- 앱별 주석 블록에 단일 형태와 같은 `secret-scan` 잡(같은 `if` · `env` · 스텝 이름 · `run:`)을 주석으로 더한다. 블록의 다른 줄과 같은 꼴(`# ` + 들여쓰기)로 써서, 앞의 `# `를 벗기면 YAML로 읽혀야 한다
- 이 잡은 `changes` 잡의 paths 필터를 거치지 않는다(`needs: changes` · `if: needs.changes…` 없음) — 어느 앱이 바뀌어도 돈다
- `ci-gate`의 `needs`에 `secret-scan`을 더한다(`changes` · `api` · `web`은 그대로). `ci-gate`의 jq 판정 줄은 바꾸지 않는다 — skipped(push)는 통과, failure는 막힘
- 블록 위 설명 주석에 비밀값 검사 잡이 paths 필터 밖이라는 한 구절을 더해도 된다
- 지킬 것: 템플릿 플레이스홀더를 늘리지 않는다 · 단일 형태 잡과 값이 갈라지지 않게 같은 값을 쓴다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」):
  - 빈 값·경계: `ss-app-gate-skipped-ok`
  - 비정상 입력: 해당 없음: 입력이 없는 고정 템플릿 글이다
  - 실패 경로: `ss-app-gate-fails-on-scan-failure`
  - 상태 전이: 해당 없음: 상태를 가진 것이 없는 CI 잡이다
  - 동시성: 해당 없음: `ci-gate`는 `needs`로 다른 잡이 끝난 뒤에만 돈다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/secret-scan-2026-11-28/ARCHITECTURE.md` 「바뀌는 층」 앱별 주석 블록 행.
3. 결과를 `phases/secret-scan/index.json`의 step 2에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다.
- 이 레포 자신의 CI(`.github/workflows/ci.yml`) · `fill_ci.py`는 고치지 않는다.
