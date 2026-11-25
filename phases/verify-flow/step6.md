# Step 6: sdd-two-sessions

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 A1 · A5 · E1~E8). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd/SKILL.md`(26행 트랙 하나 = 세션 하나 · ① 표 34~38행 · §③ 51행 · ④ 출구 조건) · `skills/sdd/references/design.md`(Readiness) · `skills/sdd/references/reflect.md` · `skills/sdd-run/SKILL.md` · `skills/sdd-review/SKILL.md` 「위임」
- step 4 summary(러너 나눔 모드 옵션 이름)

## 작업

근거: ADR-019 A1 · A5 · C2 · E5 · E6 · E7 · E12. 먼저 `gh pr view 55 -R jtwjs/claude-harness --json state -q .state`를 돌려 `MERGED`가 아니면 아무것도 바꾸지 말고 `blocked`(이유: #55 대기)로 끝낸다. 이어서 `python3 -c "import json;print(next(s['status'] for s in json.load(open('phases/harness-checkup/index.json'))['steps'] if s['name']=='plain-wording'))"`를 돌려 `completed`가 아니면 아무것도 바꾸지 말고 `blocked`(이유: 점검 평문 step 대기)로 끝낸다.

#55(설계 도구 흡수 구현)가 `design.md`를 고친다. 점검 phase의 평문 step이 같은 파일의 강조어 줄을 고쳤으면 그 문장 위에서 고친다.

바꾸는 파일:

- `skills/sdd/SKILL.md` · `skills/sdd/references/design.md` · `skills/sdd/references/reflect.md` · `skills/sdd-run/SKILL.md` · `skills/sdd-review/SKILL.md`(「위임」 한 구절만)

- `sdd` 26행 「각 트랙 세션은 이 흐름 그대로」 → 갈래: 검증 · 구현 세션 둘이면 검증이 ① · ③ · ④ · ⑤, 구현이 ②만(ADR-019 E6). 세션 하나(작은 작업)면 지금 흐름 그대로
- ① 표 DESIGN 칸에 「PRD를 받았을 때」 갈래(ADR-019 E5): 원문 옮김 + 이슈 링크 → 의도 되비추기 한 줄(지휘 확인) → ARCHITECTURE · ADR만 → Readiness → PLAN. 인터뷰 · 용어 겨루기는 돌지 않는다. `design.md`에는 이 갈래로 들어오면 어디부터 읽는지 한 줄
- 🙋 칸 고침(ADR-019 E7): 나눔 모드에서 Readiness ❌ · step 계획은 지휘 확인(사람 아님), REFLECT 묶음(적중 판정 · 게이트 보정 · 규칙 diff · 출구 조건)은 PR에 실어 사람이 PR 검증 때 보고, harness-gaps 승격만 지휘에 결정 요청. 세션 하나 모드는 지금 칸 그대로. `reflect.md` 체크포인트 문장도 같은 갈래로
- §③ 51행 「같은 세션의 서브에이전트가 한다」 → 갈래(ADR-019 A1): 나눔 모드는 검증 세션이 `sdd-review`를 돈다 · 세션 하나 모드(작은 작업 · 지휘 없이 혼자 도는 작업)는 `sdd-review` 뒤 새 맥락 `code-reviewer` 1회(ADR-019 F2와 같은 이유: 같은 세션 자기 리뷰를 막는다)
- ② 행 「step마다 호출 1번」에 나눔 모드 한 구절(테스트는 검증 세션, 구현은 구현 세션)
- 두 세션의 작업 트리 · 차례(ADR-019 E12)를 나눔 모드 절에 한 단락
- `sdd-run`에 나눔 모드 절: 검증 세션은 `prompt --role test` → 테스트 커밋 → `judge --red`, 구현 세션은 `prompt --role impl` → 구현 → `judge`(옵션 이름은 step 4 summary대로). 통로는 index.json `red` 칸 + 세션 간 메시지(ADR-019 F1)
- `sdd-run` §2 2번 「step에 `model`이 있으면 그 값만 넘긴다」 옆에: 러너가 stderr로 낸 `▶ effort <값>`을 Agent effort로 넘긴다(ADR-019 C2)
- fork 금지 한 구절(ADR-019 A5): `sdd-run` §2 2번(서브에이전트를 띄우는 자리) · `sdd-review` 「위임」(`code-reviewer`를 띄우는 자리)
- tdd: false — 지시문 문장 바꾸기다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `git grep -n '같은 세션의 서브에이전트' -- skills` 출력 없음
- `git grep -n 'PRD를 받았을 때' -- skills/sdd` 출력 있음
- `git grep -n 'fork' -- skills/sdd-run/SKILL.md skills/sdd-review/SKILL.md` 각 1줄 이상

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-019 값은 참조만 했는지, 같은 규칙을 두 파일에 복사하지 않았는지(러너 규칙 정본은 `sdd_runner.py`, 리뷰 증명 규칙 정본은 `code-reviewer.md`) 대조한다.
3. 결과를 `phases/verify-flow/index.json`의 step 6에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · 테스트 파일 수정 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다.
- push · PR 금지.
