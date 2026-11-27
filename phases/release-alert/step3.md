# Step 3: seat-doc-line

## 읽어야 할 파일

- docs/release-alert-2026-11-27/{PRD,ARCHITECTURE}.md — ARCHITECTURE 「결정」 D4. 이 레포는 루트 `CLAUDE.md`가 없다
- `skills/conductor/references/seat.md:11` — 바꿀 줄
- `hooks/conductor-context.sh` — step 1 · 2가 더한 두 꼬리(실제 글)

## 의도

- 채우는 수용 조건: 없음(D4, 지휘 판정) — 지휘가 읽는 설명이 훅 실제 출력과 같아야, 「릴리스 안 된 머지」 줄을 보고 다음 행동(사용자에게 릴리스 질문 · 그 레포 업그레이드 트랙 판단)을 문서에서 찾는다
- tdd 아님: 문서 한 구절이라 실행 동작이 없다(`.claude/rules/testing.md` §0 「테스트하지 않는다」 — 상수 · 문서)

## 작업

- `seat.md:11`의 「레포마다 트랙 한 줄과 열린 지휘 이슈를 넣는다」 문장에 한 구절을 더한다: 레포 줄 끝에 「릴리스 안 된 머지 n건 …」(하네스 원본 · 설치본 뒤 원격 main 머지) · 「릴리스 확인 실패」 · 「템플릿 X → 설치본 Y」가 붙을 수 있고, 앞의 둘은 사용자에게 릴리스를 물을 신호, 뒤의 것은 그 레포 업그레이드 트랙을 판단할 신호다
- 그 줄 밖은 고치지 않는다. 사람 이름 · 개인 경로를 넣지 않는다(공개 레포)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test` — 문서 인덱스 · 원칙 검사 케이스가 같이 돈다)
- `git diff <BASE> -- skills/conductor/references/seat.md`가 11번 줄 하나만 바꾼다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — ARCHITECTURE D4(한 구절).
3. 결과를 `phases/release-alert/index.json`의 step 3에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- 코드 파일은 고치지 않는다
