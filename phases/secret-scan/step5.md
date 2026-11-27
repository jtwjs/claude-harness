# Step 5: review-fixes

## 읽어야 할 파일

- docs/secret-scan-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음. ARCHITECTURE 「결정」 R1~R4 · 「범위 확인」 줄
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `templates/.github/workflows/ci.yml` — 단일 형태 `secret-scan` 잡과 맨 아래 앱별 주석 블록의 같은 잡(둘은 YAML 값이 같아야 한다 — 테스트 `ss-app-same-as-single`)
- `skills/harness-init/SKILL.md` §0 표의 `.github/workflows/ci.yml` 행
- `skills/harness-doctor/SKILL.md` 「1-b. CI 워크플로」 문단(②와 ④)
- `hooks/tests/secret-scan.sh` — 이 step의 테스트(검증 세션이 먼저 커밋)

## 의도

- 채우는 수용 조건: AC-3(범위가 깨져도 조용히 통과하지 않게) · AC-7(앱별 레포 안내가 막는 검사로 이어지게) · AC-8(템플릿을 받은 레포에서 기존 점검이 새 잡을 잘못 잡지 않게) — REVIEW 1회차 🟡 4건과 결정 R1~R4

## 작업

- `templates/.github/workflows/ci.yml` — 단일 형태와 앱별 주석 블록 두 곳에 똑같이:
  - `gitleaks scan` 스텝 `run:`에서 gitleaks를 부르기 전에 `BASE_SHA` · `HEAD_SHA`가 이 레포에 있는 커밋인지 확인한다. 빈 값 · 없는 커밋이면 0이 아닌 종료 코드로 끝나 잡이 실패해야 한다(예: `git cat-file -e "${BASE_SHA}^{commit}"`. `git rev-list "..X"`는 빈 기준을 통과시키니 빈 값을 따로 막는다). `run:` 안에 `${{ }}`는 여전히 쓰지 않는다
  - 잡에 `permissions: contents: read`. checkout 스텝 `with:`에 `persist-credentials: false`(`fetch-depth: 0`은 그대로)
  - 잡 머리 주석에 두 한계를 한 줄씩: ① merge 커밋에서 충돌을 풀며 넣은 값은 못 본다(gitleaks가 merge diff를 보지 않음, R1) ② PR 안의 `.gitleaks.toml` · `.gitleaksignore` · `gitleaks:allow` 주석으로 검사를 끌 수 있으니 리뷰에서 본다(R3)
- `skills/harness-init/SKILL.md` §0 표 CI 행 안내 문구: 「옮기세요」를 「복사하세요」로, 그리고 앱별 형태면 `ci-gate`의 `needs`에도 `secret-scan`을 넣으라는 말을 더한다(사람이 읽는 문구 — PRD AC-7 👤). 행의 나머지(고치지 않는다 · `gitleaks`가 없으면 안내 한 줄)는 그대로
- `skills/harness-doctor/SKILL.md` 1-b: ②(각 `run:` 값이 `verify.*`와 같은가)에 「`secret-scan` 잡 스텝은 대조에서 뺀다」, ④(앱별인데 단일 잡 하나 · `ci-gate` 없음)에 「`secret-scan` 잡은 앱 잡으로 세지 않는다」를 한 구절씩. 그 밖 doctor 문구는 고치지 않는다(#67 · #68 몫)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」):
  - 빈 값·경계: `ss-scan-empty-base-fails`
  - 비정상 입력: `ss-scan-missing-head-fails`
  - 실패 경로: `ss-scan-missing-base-fails`
  - 상태 전이: 해당 없음: 상태를 가진 것이 없는 CI 잡이다
  - 동시성: 해당 없음: 잡 하나 안의 스텝은 차례로 돈다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/secret-scan-2026-11-28/ARCHITECTURE.md` 「결정」 R1~R4 · 「범위 확인」.
3. 결과를 `phases/secret-scan/index.json`의 step 5에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 바뀐 안내 문구 원문 포함)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다.
- `skills/harness-doctor/SKILL.md`는 1-b ② · ④에 한 구절씩만. 이 레포 자신의 CI · `fill_ci.py`는 고치지 않는다.
