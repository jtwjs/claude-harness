# Step 4: measure-real-scan

## 읽어야 할 파일

- docs/secret-scan-2026-11-28/{PRD,ARCHITECTURE}.md — ARCHITECTURE 「테스트 전략」 실제 실행 줄
- `templates/.github/workflows/ci.yml` — 단일 형태 `secret-scan` 잡의 `install gitleaks` · `gitleaks scan` 스텝

## 의도

- 채우는 수용 조건: AC-3 · AC-4 · AC-9 — 진짜 gitleaks로 가짜 키 있음 / 없음 두 경우를 돌린 출력과 잡 시간

## 작업

측정만 한다. 레포 파일은 바꾸지 않는다(`kind: measure`).

1. 레포 밖 임시 폴더(세션 스크래치)에 임시 git 레포를 만든다. 기준 커밋 1개 → PR 갈래 둘: 가짜 키 갈래(실행 중에 만든 클라우드 접근 키 꼴 값 1줄을 담은 커밋) · 깨끗한 갈래(키 없는 커밋). 가짜 키 값은 파일 · 로그 어디에도 남기지 않는다(`--redact`)
2. 템플릿 `install gitleaks` 스텝의 `run:`을 그대로 꺼내 `RUNNER_TEMP`를 임시 폴더로 두고 돌린다. 이 머신(macOS arm64)에서는 `linux_x64` 실행 파일이 돌지 않으므로, 내려받기 · 체크섬 대조는 템플릿 그대로 돌리고(통과 출력과 걸린 시간을 잰다), 검사는 같은 버전의 이 머신용 실행 파일을 상류 체크섬 파일로 대조한 뒤 쓴다. 가능하면 `docker run --platform linux/amd64 ubuntu`로 템플릿 두 스텝을 그대로 돌린다(되면 그 출력을 우선)
3. 템플릿 `gitleaks scan` 스텝의 `run:`을 두 갈래에서 `BASE_SHA` · `HEAD_SHA`를 넣어 돌린다
4. 잴 것: 가짜 키 갈래 출력 끝부분과 종료 코드(1 기대) · 깨끗한 갈래 출력 끝부분과 종료 코드(0 기대) · 내려받기+대조 시간 · 검사 시간
5. `summary`에 실행한 명령(백틱)과 결과(종료 코드 · `leaks found` / `no leaks found` · 시간)를 남긴다. 실제 GitHub Actions 실행 시간은 재지 않는다 — `미측정: 템플릿으로 만든 레포의 첫 PR / 다음 업그레이드 트랙`

## Acceptance Criteria

- `bash hooks/test.sh` 통과(phase 마지막 step이라 러너가 전체 verify를 돈다)
- `summary`에 백틱 명령과 결과가 있다

## 검증 절차

1. 위 측정을 실제 실행한다.
2. 결과를 `phases/secret-scan/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(명령 · 결과)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다.
- 가짜 키든 실제 키든 키 꼴 값을 레포 · 커밋 · PR · 메시지에 넣지 않는다.
