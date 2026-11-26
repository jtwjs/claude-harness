# Step 10: summary-and-merge-line

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 B3 · B4 · B5 · E7 보탬 · F2)
- `skills/sdd/SKILL.md` ⑤ 마무리(세 줄 요약) · `skills/pr-write/SKILL.md`(4.6 심각도 게이트 · 자동 머지 판정, 5단계 본문 첫머리) · `skills/pr-write/references/body-template.md` · `skills/conductor/SKILL.md` 「사용자에게 올리는 현황」
- step 9 summary(「사람이 볼 것」 체크리스트 꼴)

## 작업

근거: ADR-019 B3 · B4 · B5 · E7(보탬) · F2. 선행: 점검 phase 평문 step(같은 스킬 문장의 강조어를 고친다) 머지 뒤. 먼저 `python3 -c "import json;print(next(s['status'] for s in json.load(open('phases/harness-checkup/index.json'))['steps'] if s['name']=='plain-wording'))"`를 돌려 `completed`가 아니면 아무것도 바꾸지 말고 `blocked`(이유: 점검 평문 step이 이 브랜치에 없음 — 기준 브랜치를 받은 뒤 재개)로 끝낸다. 두 확인 모두 원격이 아니라 이 브랜치 트리를 본다 — 원격만 보면 통과해도 고칠 파일은 옛 상태다.

바꾸는 파일:

- `skills/sdd/SKILL.md`(⑤ 세 줄 요약 한 구절) · `skills/pr-write/SKILL.md` · `skills/pr-write/references/body-template.md` · `skills/conductor/SKILL.md`

- 세 줄 요약 셋째 줄을 `위험: … · 사람이 볼 것 N개`로(ADR-019 B4). 항목 목록은 PR 본문 절이 정본
- PR 본문(ADR-019 B5): 「모델이 검증한 것」(돌린 명령 · 결과) · 「사람이 볼 것」(항목별 `- [ ] AC-N …`, 사람이 ✅ 또는 `건너뜀: <이유(선택)>`) 두 절. `👤` 항목이 없으면 「사람이 볼 것」 절을 넣지 않는다. 건너뛰기는 막지 않고 줄로 남긴다(ADR-019 B3)
- `pr-write` 4.6(ADR-019 F2): 세션 하나 작업은 자동 머지 조건에 「새 맥락 `code-reviewer` 1회를 돌렸다」를 더한다. 안 돌렸으면 심각도 `미실행`(지금 규칙)으로 미충족
- `conductor` 「사용자에게 올리는 현황」에 머지를 물을 때 한 줄 꼴(ADR-019 B4 · E7 보탬): `Risk n · 심각도 · 사람이 볼 것 n개 · 규칙 diff 있음/없음`. 규칙 파일(`CLAUDE.md` · `.claude/rules/**`)이 바뀐 PR은 그 diff를 줄 아래에 붙인다 — 「조건 맞으면 머지」 한 줄 승인으로는 규칙 diff를 실제로 보지 않기 때문
- tdd: false — 지시문 문장 바꾸기다

## Acceptance Criteria

- `bash hooks/test.sh` 통과
- `git grep -n '사람이 볼 것' -- skills/sdd/SKILL.md skills/pr-write skills/conductor/SKILL.md` 각 파일 1줄 이상
- `git grep -n '규칙 diff' -- skills/conductor/SKILL.md` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 세 줄 요약 정본은 `sdd` ⑤ 한 곳 — `pr-write` · track-brief는 가리키기만 하는지 대조한다(ADR-016 D-요약).
3. 결과를 `phases/verify-flow/index.json`의 step 10에 기록(꼴은 step 6과 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · 테스트 파일 수정 금지. 자동 머지를 실제로 켜지 않는다(dry-run 그대로).
- 쌓기만 하는 기록은 고치지 않는다.
- push · PR 금지.
