# Step 3: env-ignore-upgrade-notice

## 읽어야 할 파일

- docs/secret-scan-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음. ARCHITECTURE 「결정」 S2(= B) · 업그레이드 안내 조건 줄
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `templates/.gitignore.append` — 하네스가 레포 `.gitignore`에 덧붙이는 줄
- `skills/harness-init/SKILL.md` §0 업그레이드 모드 표(`| 대상 | 어떻게 |`)와 그 위 문단(「CI는 다시 하지 않는다」)
- `hooks/tests/secret-scan.sh` — 이 step의 테스트(검증 세션이 먼저 커밋)

## 의도

- 채우는 수용 조건: AC-6 · AC-7 · AC-11 — 템플릿 `.gitignore`에 `.env`가 들어가고, 이미 깔린 레포는 CI에 안내 한 줄만 받고 `.env` 줄은 기존 diff 승인 경로로 받는다

## 작업

- `templates/.gitignore.append`에 `.env` 한 줄을 더한다(주석 아님, 줄 전체가 `.env`). 위에 이유 주석 한 줄(비밀값 파일 — 커밋하면 원격에 남는다)을 둔다. 맨 아래 「ignore 하지 않는다」 주석 블록 안에 넣지 않는다
- `skills/harness-init/SKILL.md` §0 표에 CI 행을 더한다. 대상 칸에 `.github/workflows/ci.yml`. 어떻게 칸에 담을 것:
  - 고치지 않는다(파일 자동 수정 없음)
  - 레포 `ci.yml`에 `gitleaks`가 없으면 안내 한 줄을 보인다 — 템플릿 CI에 비밀값 검사 잡 `secret-scan`이 새로 생겼다는 것과, 넣으려면 템플릿 `ci.yml`의 그 잡을 옮긴다는 것
  - 안내 문구는 사람이 읽는다(PRD AC-7 👤) — 짧고 그대로 읽히게
- `.gitignore` 행(`templates/.gitignore.append`의 줄 중 빠진 것만)은 그대로 둔다. `.env` 예외를 넣지 않는다 — `.env`도 다른 빠진 줄처럼 전체 diff 승인 뒤 들어간다(ARCHITECTURE S2 = B)
- §0 위 문단의 「CI는 다시 하지 않는다」 문장은 그대로 둔다(새 CI 행이 그 규칙의 안내 갈래다)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」):
  - 빈 값·경계: `ss-gitignore-env-line`
  - 비정상 입력: 해당 없음: 입력이 없는 고정 템플릿 · 문서 글이다
  - 실패 경로: `ss-upgrade-ci-row`
  - 상태 전이: `ss-upgrade-gitignore-row-unchanged`
  - 동시성: 해당 없음: 문서 · 템플릿 글이다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/secret-scan-2026-11-28/ARCHITECTURE.md` 「바뀌는 층」 `.gitignore.append` · 업그레이드 모드 표 행.
3. 결과를 `phases/secret-scan/index.json`의 step 3에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 안내 문구 원문 포함)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다.
- `skills/harness-init/SKILL.md`는 §0 표의 CI 행 추가만 한다. 다른 절은 고치지 않는다.
