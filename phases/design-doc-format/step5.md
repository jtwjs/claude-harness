# Step 5: review-fixes

## 읽어야 할 파일

- docs/design-doc-format-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음. ARCHITECTURE 「결정할 것」 R1(주제 이름) · D3(칸 맞춤) · 「지키는 것 — 불변 규칙」
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `phases/design-doc-format/index.json` `reviews` 1회차 — 이 step이 고치는 지적 목록
- `skills/sdd/scripts/design_doc_check.py` · `skills/sdd/references/design.md` · `skills/sdd-run/scripts/sdd_runner.py` `open_decisions`(읽기만 — ADR 「결정할 것」 표의 주체 칸이 비면 열린 결정으로 센다)
- `hooks/tests/design-doc-{template,check,flow}.sh` — 이 step의 테스트(검증 세션이 먼저 커밋)

## 의도

- 채우는 수용 조건: AC-5 · AC-9 · AC-12 · AC-14 · AC-2 — REVIEW 1회차 지적을 고친다. 출처 칸이 러너 관문을 열지 않게 하고, 비공개 설계서를 이름으로 가리키고, 칸 순서 검사가 옮긴 칸을 정확히 짚게 한다

## 작업

`skills/sdd/scripts/design_doc_check.py`:

- 순서 어긋남(AC-12): 설계서 제목에서 정본 칸마다 맞는 제목 위치를 찾고(맞는 제목이 여럿이면 첫 것), 찾은 칸들의 위치를 정본 순서로 늘어놓아 **가장 긴 증가 부분열**을 구한다. 거기 든 칸은 통과, 찾았지만 거기 안 든 칸만 `순서 어긋남: <칸 이름>`, 못 찾은 칸은 `빠진 칸: <칸 이름>`. 출력 순서는 정본 순서. 칸 하나를 멀리 뒤로 옮기면 출력은 그 칸 한 줄이다. 길이가 같은 부분열이 여럿이면 어느 것이어도 된다
- 칸 이름 경계(D3 좁힘): 번호 뗀 제목이 칸 이름과 같거나, 칸 이름 바로 뒤가 공백 또는 `(`일 때만 맞는다. `### 2. 문제점 메모`는 「문제」가 아니다. `### 우리 칸 (원본 포맷에 없고 …)`은 「우리 칸」이다
- 제목 줄: 앞 공백 0~3칸을 허용한다(4칸부터는 제목이 아니다). `####` 이상은 칸이 아니다(지금 그대로)
- 코드 울타리: 연 줄의 문자(```` ` ```` 또는 `~`)와 길이(3 이상)를 기억하고, **같은 문자 · 그 길이 이상**이고 뒤에 다른 글자가 없는 줄에서만 닫는다. ```` ```` ```` 안의 ```` ``` ```` 줄, ```` ``` ```` 안의 `~~~` 줄은 닫지 않는다. 울타리 줄도 앞 공백 0~3칸 허용
- 파일 읽기: 설계서 · design.md 둘 다 `encoding="utf-8-sig"`(BOM 무시)
- 종료 코드 · 메시지 꼴(`칸 순서 통과: N칸` · `빠진 칸:` · `순서 어긋남:` · `틀 블록을 못 찾음:` · exit 0/1/2)과 틀 블록 찾기(「**설계서 틀**」 다음 첫 ```` ```markdown ````)는 그대로

`skills/sdd/references/design.md`:

- 11행 「「끝」 1번 PRD부터 설계서 원문으로 쓴다」 → 「「끝」 1번 PRD부터 설계서 칸에서 뽑아 쓴다(「설계서와 세 장」)」 꼴
- 「설계서 순서」 1 초안: 「간단히 5칸 + 우리 칸 + 자세히 4칸」 문구가 이미 있다. 그대로 둔다(AC-2 테스트가 지킨다)
- 「화면」 검사 줄에 예외 한 구절: #87 전에 옛 틀로 시작한 설계서는 칸 순서 검사를 돌리지 않는다(옛 틀 그대로 둔다)
- 「설계서와 세 장」 출처 칸 줄에 더한다:
  - 표에서는 출처를 줄 끝이 아니라 따로 둔 「출처」 열에 단다. 표 행 끝에 달면 마지막 열에 들어간다
  - ADR 「결정할 것」 표에는 출처 칸을 달지 않는다 — 마지막 열이 주체라 꼬리표가 들어가면 러너가 사람이 아직 안 고른 결정을 닫힌 것으로 센다. 주체 칸은 사람 답 전까지 비운다
  - 제목 · 표 머리 · mermaid · 코드 블록에는 출처 칸을 달지 않는다
  - 「검증 세션이 … 뽑고」 · 「설계서에 없는 줄은 `(← 검증 세션)`」에 「(혼자 도는 sdd면 그 세션)」을 붙인다
- R1(주제 이름): 설계서 틀의 「고른 안과 버린 안」 안내에 「안마다 주제 이름」을 더한다(블록 제목 줄 글자 · 급 · 순서는 그대로, `←` 뒤 안내만). ADR 정의의 `**설계 문서 링크**(…)` → `**설계 문서 주제**(설계 문서 「고른 안과 버린 안」의 그 행 주제 이름. 비공개 설계서도 있어 링크하지 않는다. 설계서가 없는 작은 일이면 생략)` 꼴. Readiness 10: 「ADR 결정마다 설계 문서 「고른 안과 버린 안」 행의 주제 이름이 있고, 그 이름이 설계서 그 칸에 있다 — 없는 결정이 하나라도 있으면 ❌」 꼴. 「행 링크」라는 말은 남기지 않는다
- Readiness 9 ❌ 예시 「설계서의 범위 밖 항목이 PRD 포함에 들어갔다」 → 「설계서의 비목표가 PRD 포함에 들어갔다」

`.claude/rules/non-obvious-patterns.md`: 맨 끝에 한 줄(지휘 승인, 트랙 예외) — 「**마크다운 표 행 끝에 꼬리표를 달면 마지막 열에 들어간다.** ADR 「결정할 것」 표의 마지막 열은 주체라, 출처 칸 같은 꼬리표가 들어가면 러너가 그 결정을 닫힌 것으로 센다. 표의 출처는 따로 둔 열에 달고 「결정할 것」 표에는 달지 않는다. (design-doc-format REVIEW 1회차 code-reviewer 재현, 2026-11-28)」 꼴

공통: 공개 레포라 사람 · 회사 이름 · 개인 경로 · 개인 기록 문구를 넣지 않는다. 기존 테스트가 찾는 구절(`**ARCHITECTURE.md** — PRD 확정 직후` · ADR 「결정할 것」 표 머리 · 「주체 칸을 비운다」 · `DESIGN-DOC.md`)은 남긴다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test` — 이 레포 verify는 test 하나)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」):
  - 빈 값·경계: `dc-name-boundary` · `dc-indented-heading`
  - 비정상 입력: `dc-bom` · `dc-fence-4backtick` · `dc-tilde-in-backtick`
  - 실패 경로: `dc-far-move-one-cell` · `dc-swap-far` · `dc-h4-not-cell`
  - 상태 전이: 해당 없음: 파일 하나를 읽고 끝나는 스크립트다
  - 동시성: 해당 없음: 쓰는 것이 없다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/design-doc-format-2026-11-28/ARCHITECTURE.md` 「데이터 흐름」 · 「지키는 것 — 불변 규칙」 · 「결정할 것」 R1.
3. 결과를 `phases/design-doc-format/index.json`의 step 5에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- PRD의 사용자 흐름 · 비기능 출처(REVIEW R2)는 사용자 답 대기라 이 step에서 바꾸지 않는다. `skills/sdd-run/**` · `skills/sdd-plan/**` · `docs/sdd-runner.md` · `skills/conductor/**`는 고치지 않는다.
