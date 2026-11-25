# Step 8: track-brief-and-tracks

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 C6 · E8 · E9 · E11 · G4 · G5)
- `templates/.claude/references/track-brief.md` · `templates/.claude/references/tracks.md` · 점검 phase step 7 summary(덜기 후보 표) · 지휘가 보낸 점검 PR 덜기 목록(이 step 시작 전에 지휘에 받는다 — 없으면 G5에 적힌 줄만)
- step 7 summary(세션 이름 꼴)

## 작업

근거: ADR-019 C6 · E8 · E9 · E11 · G4 · G5. 선행: 점검 phase 평문 step(같은 템플릿 references를 고침).

바꾸는 파일:

- `templates/.claude/references/track-brief.md` · `templates/.claude/references/tracks.md`

- track-brief 표에 「의도」(이 트랙이 채우는 수용 조건과 이유) · 「effort」(역할 값, ADR-019 E1 참조) · 「세션 역할」(검증 / 구현) 칸(ADR-019 C6)
- 「끝나면 지휘에 보고」에 4번째 묶음 「지휘 자리의 지식 저장소로 올릴 것」: 도메인 사실(코드 · 문서로 확인한 것만, 출처 경로) · 반대 근거 · 남은 문제 · 저장소 쪽 할 일 후보(레포 이슈로 갈 것은 빼고). 칸마다 없으면 「없음」. 지휘에게만, 레포에 쓰지 않는다(ADR-019 G4)
- 덜기(ADR-019 G5): 39행(「진행 방식」과 같은 말) 삭제 · 45~52행 「새 worktree 준비」 삭제(지휘가 `conductor` §5로 만든다) · 지휘가 보낸 목록의 나머지 줄
- tracks.md 「세션 종류」 표에 검증 · 구현 행, 층별 상주 트랙은 유지하고 세로 조각은 층 안에서(ADR-019 E11). §5 「계약 먼저 PR」에 나눔 모드 한 줄 — 검증 BE가 제공, 검증 FE가 소비, 끝까지 확인은 검증 FE(ADR-019 E9)
- tdd: false — 템플릿 문장 바꾸기다

## Acceptance Criteria

- `bash hooks/test.sh` 통과
- `grep -n '지식 저장소로 올릴 것' templates/.claude/references/track-brief.md` 출력 있음
- `grep -n '새 worktree 준비' templates/.claude/references/track-brief.md` 출력 없음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. `harness-doctor`가 템플릿 사본과 대조하는 칸 이름을 바꿨으면 doctor 쪽도 맞는지 `bash hooks/test.sh`로 확인한다.
3. 결과를 `phases/verify-flow/index.json`의 step 8에 기록(꼴은 step 6과 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · 테스트 파일 수정 금지.
- 쌓기만 하는 기록은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구, 지휘 자리 경로를 템플릿에 쓰지 않는다.
- push · PR 금지.
