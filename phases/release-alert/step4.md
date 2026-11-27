# Step 4: measure-before-after

## 읽어야 할 파일

- docs/release-alert-2026-11-27/{PRD,ARCHITECTURE}.md — PRD 비기능(비포 1.98 · 2.23 · 2.42초) · AC-9 · AC-12
- `hooks/conductor-context.sh`

## 의도

- 채우는 수용 조건: AC-9 · AC-11 · AC-12 — 실제 대상 레포로 돌린 지휘 현황 before/after와 훅 시간 애프터를 남긴다(설계서 비기능 「바꾸기 전후로 잰다」). 코드 변경 없음(`kind: measure`)

## 작업

다음을 재서 `summary`에 명령(백틱)과 결과를 남긴다. 파일은 바꾸지 않는다.

1. 지휘 자리 폴더에서 이 worktree 훅을 3번 돈다. 설치본은 실제 설치본 폴더로 준다: `cd <지휘 자리> && CLAUDE_PLUGIN_ROOT=<설치본 폴더> /usr/bin/time -p bash <worktree>/hooks/conductor-context.sh </dev/null` — real 초 3개
2. 1의 additionalContext를 비포(시작 커밋 a1743ed 훅 출력)와 나란히 PR 「사람이 볼 것」 재료로 남긴다. 기대: 하네스 설정이 있는 대상 레포 하나의 줄에 「템플릿 0.34.0 → 설치본 0.43.0」. 하네스 원본 줄은 그때 원격 main에 설치본 뒤 머지가 있으면 「릴리스 안 된 머지 …」, 없으면 꼬리 없음(어느 쪽인지 그대로 적는다)
3. `git diff a1743ed -- hooks/cadence-reminder.sh` 줄 수(0이어야 AC-9)
4. `bash hooks/test.sh` 끝 줄(통과 · 실패 수) · `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 끝 줄

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `summary`에 위 1~4의 명령과 결과가 있다

## 검증 절차

1. 위 명령을 실제 실행한다.
2. 비기능 대조 — 애프터가 훅 전체 마감 25초 안인지, 비포보다 얼마나 늘었는지.
3. 결과를 `phases/release-alert/index.json`의 step 4에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 개인 경로 · 대상 레포 원문 출력을 레포 파일에 쓰지 않는다(공개 레포). 원문은 지휘 보고로만 넘긴다
