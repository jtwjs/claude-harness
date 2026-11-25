# Step 11: step-template-cells

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 A3 · A4 · C1 · C2 · C3)
- `skills/sdd-plan/SKILL.md`(§3 TDD 판정 · §4 index.json 필드 설명 · stepN.md 템플릿)
- step 4 · 5 summary(`red` 칸 · 의도 절 판정 · effort 출력)

## 작업

근거: ADR-019 A3 · A4 · C1 · C2 · C3. 선행: #55(`sdd-plan`을 고친다) — 그 머지 뒤에 한다. 먼저 `gh pr view 55 -R jtwjs/claude-harness --json state -q .state`를 돌려 `MERGED`가 아니면 아무것도 바꾸지 말고 `blocked`(이유: #55 대기)로 끝낸다.

바꾸는 파일:

- `skills/sdd-plan/SKILL.md`

- step 템플릿 6절로: `## 의도`(채우는 수용 조건 번호 `AC-N` · 이유 한 줄)를 「읽어야 할 파일」 다음에(ADR-019 C1 · A3). 「5개 섹션 고정」 문구를 같이 고친다
- 「금지사항」 아래 선택 한 줄: 그 step만의 멈춤 조건이 있을 때만(예: 데이터가 있으면 멈춤). 공용 조건은 러너 지시문이 정본이라 다시 적지 않는다(ADR-019 C3)
- §4 「구현 단계가 채운다」 필드 목록에 `red`(나눔 모드에서 검증 세션이 `judge --red`로 적는 테스트 커밋)(ADR-019 A4)
- §3 TDD 판정의 「한 호출 안에서 테스트 먼저 → 구현」에 나눔 모드 한 구절(테스트는 검증 세션 `judge --red`, 구현은 구현 세션)
- 평문 · 검사(ADR-019 G5): §3 「시그니처 수준」의 「멱등성 · 보안 · 데이터 무결성 … 반드시 명시」를 뜻 그대로 평문으로. §4 `docs` 필드의 「반드시 채운다」는 평문으로 바꾸고, 러너 `start`가 `docs`가 비면 멈추는지 확인해 안 멈추면 summary에 「기계 검사 후보」로 남긴다(이 step에서 러너는 고치지 않는다)
- effort 칸은 만들지 않는다 — `model` 칸 설명 옆에 「effort는 세션 역할이 정한다(ADR-019 C2)」 한 구절
- tdd: false — 템플릿 문장 바꾸기다

## Acceptance Criteria

- `bash hooks/test.sh` 통과
- `grep -n '## 의도' skills/sdd-plan/SKILL.md` 출력 있음
- `grep -n '5개 섹션 고정' skills/sdd-plan/SKILL.md` 출력 없음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 이 phase의 step 파일들(`phases/verify-flow/step*.md`)은 옛 5절 꼴이다 — 고치지 않는다(쌓기만 하는 기록).
3. 결과를 `phases/verify-flow/index.json`의 step 11에 기록(꼴은 step 6과 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · 테스트 파일 수정 금지.
- 쌓기만 하는 기록(`phases/*/` 포함)은 고치지 않는다.
- push · PR 금지.
