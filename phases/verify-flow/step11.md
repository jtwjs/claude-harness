# Step 11: step-template-cells

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 A3 · A4 · C1 · C2 · C3 · G6)
- `skills/sdd-plan/SKILL.md`(§3 TDD 판정 · §4 index.json 필드 설명 · stepN.md 템플릿)
- `templates/.claude/rules/testing.md` §2(엣지 5축) · `skills/sdd-run/scripts/sdd_runner.py`(step 5가 넣은 엣지 칸 파서 — 칸 꼴의 정본)
- step 4 · 5 summary(`red` 칸 · 의도 절 판정 · effort 출력 · 엣지 칸 꼴)

## 작업

근거: ADR-019 A3 · A4 · C1 · C2 · C3 · G6. 선행: #55(`sdd-plan`을 고친다) — 그 머지 뒤에 한다. 먼저 이 브랜치 트리에서 `test -f docs/principles/write-for-agents.md`(#55 구현 PR이 만드는 파일)를 돌려 없으면 아무것도 바꾸지 말고 `blocked`(이유: #55 구현이 이 브랜치에 없음 — 기준 브랜치를 받은 뒤 재개)로 끝낸다.

바꾸는 파일:

- `skills/sdd-plan/SKILL.md`

- step 템플릿 6절로: `## 의도`(채우는 수용 조건 번호 `AC-N` · 이유 한 줄)를 「읽어야 할 파일」 다음에(ADR-019 C1 · A3). 「5개 섹션 고정」 문구를 같이 고친다
- 「Acceptance Criteria」에 엣지 5축 칸(ADR-019 G6) — `tdd: true` step만. 아래 꼴을 템플릿에 그대로 둔다(러너 파서와 글자 하나까지 같게, 다르면 새 phase의 tdd step이 전부 멈춘다):

  ```markdown
  - 엣지 5축(축마다 테스트 이름 또는 「해당 없음」 — 비면 러너가 이 step을 돌리지 않는다):
    - 빈 값·경계: `<테스트 이름>`
    - 비정상 입력: 해당 없음: <이유>
    - 실패 경로: `<테스트 이름>`
    - 상태 전이: `<테스트 이름>`
    - 동시성: 해당 없음
  ```

  계획이 축마다 이 step 테스트가 쓸 이름(프레임워크가 허용하는 글자로) 또는 「해당 없음」을 적는다. 축마다 무엇을 묻는지는 `testing.md` §2를 가리키기만 한다(복사하지 않음). 판정 규칙(빈 칸 · 이름 대조)은 러너가 정본이라 템플릿에는 칸 꼴과 「비면 돌지 않는다」 한 구절만
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
- `grep -n '엣지 5축' skills/sdd-plan/SKILL.md` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
1-1. 템플릿 꼴이 러너 파서를 통과하는지: 레포 밖 스크래치 git 레포에 템플릿 그대로(이름만 채운) `tdd: true` step 하나를 만들어 `sdd_runner.py prompt`가 지시문을 내는지(종료 0), 축 하나를 지운 사본은 비0인지 한 번씩 돌려 summary에 명령과 종료 코드를 남긴다.
2. 이 phase의 step 파일들(`phases/verify-flow/step*.md`)은 옛 5절 꼴이다 — 고치지 않는다(쌓기만 하는 기록).
3. 결과를 `phases/verify-flow/index.json`의 step 11에 기록(꼴은 step 6과 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · 테스트 파일 수정 금지.
- 쌓기만 하는 기록(`phases/*/` 포함)은 고치지 않는다.
- push · PR 금지.
