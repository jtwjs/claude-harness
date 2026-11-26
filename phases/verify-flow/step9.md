# Step 9: review-gates

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 A2 · A3 · B1 · B2)
- `skills/sdd-review/SKILL.md`(§1 기준 로드 · §3 「테스트 존재」 축 · §4 출력 · 「위임」) · `skills/sdd/SKILL.md` ③ 행(37행 「escalate 판정에 따라」) · `skills/sdd/references/design.md` 「설계문서 3장」 PRD 항목 · `skills/conductor/references/decisions.md` §1 결정 이슈 틀 · `templates/.claude/harness.json` · `skills/harness-doctor/SKILL.md`(템플릿 키 대조가 있으면)
- step 6 · 7 summary(같은 파일을 앞서 고쳤다)

## 작업

근거: ADR-019 A2 · A3 · B1 · B2. 선행: #55(`design.md`를 고친다) · 점검 phase 평문 step(같은 스킬 문장의 강조어를 고친다) 머지 뒤. 먼저 이 브랜치 트리에서 `test -f docs/principles/write-for-agents.md`(#55 구현 PR이 만드는 파일)를 돌려 없으면 아무것도 바꾸지 말고 `blocked`(이유: #55 구현이 이 브랜치에 없음 — 기준 브랜치를 받은 뒤 재개)로 끝낸다. 이어서 `python3 -c "import json;print(next(s['status'] for s in json.load(open('phases/harness-checkup/index.json'))['steps'] if s['name']=='plain-wording'))"`를 돌려 `completed`가 아니면 아무것도 바꾸지 말고 `blocked`(이유: 점검 평문 step이 이 브랜치에 없음 — 기준 브랜치를 받은 뒤 재개)로 끝낸다. 두 확인 모두 원격이 아니라 이 브랜치 트리를 본다 — 원격만 보면 통과해도 고칠 파일은 옛 상태다.

바꾸는 파일:

- `skills/sdd-review/SKILL.md` · `skills/sdd/SKILL.md`(③ 행 한 구절) · `skills/sdd/references/design.md`(PRD 수용 조건 항목) · `skills/conductor/references/decisions.md`(결정 이슈 틀) · `templates/.claude/harness.json`

- `code-reviewer`를 부르는 조건(ADR-019 A2): 변경이 `harness.json` `review.gatePaths`(계약 · 마이그레이션 · 권한 경로 glob 목록)에 닿음 / `pr-write` Risk가 자동 머지 기준을 넘음(값은 `pr-write` 참조, 복사하지 않음) / `sdd-review`에 「확인 필요」가 남음 — 셋 중 하나면 부른다. 안 부르면 출력에 `code-reviewer 건너뜀: <이유>`. 목록이 비면 세션 판단 + 이유. 이 조건은 나눔 모드 검증 세션의 것이다 — 세션 하나 모드는 step 6이 넣은 「`sdd-review` 뒤 새 맥락 `code-reviewer` 1회」(ADR-019 A1)가 그대로 앞선다(두 문장이 서로 다른 답을 내지 않게). `sdd` ③ 행 「escalate 판정에 따라」 → 이 절을 가리키는 구절
- `templates/.claude/harness.json`에 `review.gatePaths: []` + `$comment` 한 줄(무엇을 넣나 · 비면 어떻게 되나). `harness-init` 인터뷰는 바꾸지 않는다
- 수용 조건 번호(ADR-019 A3): `design.md` PRD 항목과 `conductor` 결정 이슈 틀에 「수용 조건마다 `AC-N` 번호 + 맡는 쪽(BE 몫 · FE 몫 · 끝까지 확인 몫, 층이 하나면 생략) + 사람이 볼 것이면 `👤 <기준 한 구절>`(ADR-019 B1)」
- `sdd-review` 「테스트 존재」 축 → 「수용 조건 대조」로 넓힌다: PRD를 늘 읽고(§1 「필요 시」 삭제) 번호별 테스트 위치 표(번호 · 테스트 파일:줄 · 통과 여부). 이 세션 몫인데 빈 번호는 🟡. 번호가 없는 옛 PRD는 지금처럼 짝 테스트 존재만 보고 「번호 없음」 한 줄
- CRITICAL 축(ADR-019 G5): 「hook 미우회(--no-verify)」 대조를 「deny 규칙(템플릿 `settings.json` permissions.deny, 점검 #57)이 막는다 — 리뷰는 deny가 깔렸는지만 본다」로
- 최종 판정(ADR-019 B2): `👤` 번호만 「사람이 볼 것」 체크리스트로 낸다. 없으면 칸 생략
- tdd: false — 지시문 문장 바꾸기다

## Acceptance Criteria

- `bash hooks/test.sh` 통과
- `git grep -n 'escalate 판정에 따라' -- skills` 출력 없음
- `git grep -n 'gatePaths' -- skills/sdd-review templates/.claude/harness.json` 출력 2줄 이상
- `git grep -n 'AC-' -- skills/sdd/references/design.md skills/conductor/references/decisions.md skills/sdd-review/SKILL.md` 각 파일 1줄 이상

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 증명 규칙(의도 되비추기 · 근거 · 「확인 필요」)은 `code-reviewer.md` 정본을 가리키기만 했는지 대조한다.
3. 결과를 `phases/verify-flow/index.json`의 step 9에 기록(꼴은 step 6과 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · 테스트 파일 수정 금지.
- 쌓기만 하는 기록은 고치지 않는다.
- push · PR 금지.
