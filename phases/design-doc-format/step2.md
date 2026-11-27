# Step 2: design-doc-check

## 읽어야 할 파일

- docs/design-doc-format-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음. ARCHITECTURE 「데이터 흐름 — 요청 하나 따라가기」 · 「결정할 것」 D1 · D2 · D3 · D5
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `skills/sdd/references/design.md` 「**설계서 틀**」 문단과 바로 아래 ```` ```markdown ```` 블록(step 1이 바꾼 새 틀 — 정본 칸 목록)
- `skills/harness-init/scripts/fill_ci.py` — 이 레포 스킬 스크립트 꼴(python3 표준 라이브러리 · 맨 위 독스트링 · 종료 코드)
- `hooks/tests/design-doc-check.sh` — 이 step의 테스트(검증 세션이 먼저 커밋)

## 의도

- 채우는 수용 조건: AC-10 · AC-11 · AC-12 · AC-13 · AC-19 — 설계서 칸 제목이 정해진 순서대로 다 있는지 기계로 확인해, 같은 설계 문서를 두 번 요청해도 같은 칸 순서인지 잡는다

## 작업

- 새 파일 `skills/sdd/scripts/design_doc_check.py`(python3, 표준 라이브러리만). 실행: `python3 skills/sdd/scripts/design_doc_check.py <설계서.md>`
- 정본 칸 목록(D2): 스크립트 파일 위치 기준 `../references/design.md`를 읽는다(`Path(__file__).resolve().parent.parent / "references" / "design.md"`). 「**설계서 틀**」로 시작하는 줄 다음에 오는 첫 ```` ```markdown ```` 줄부터 다음 ```` ``` ```` 줄 앞까지가 틀 블록이다. 블록 안 `##` · `###` 제목 줄(`#` 하나 줄은 뺀다)이 정본 칸이다. 칸 이름 = 제목 글자에서 `←` 뒤를 버리고 앞뒤 공백을 지우고 맨 앞 번호(`숫자.` + 공백)를 뗀 것. 급(`#` 개수)도 칸의 일부다
- 설계서 제목 줄: `##` · `###` 줄만 본다. 코드 울타리(```` ``` ```` 또는 `~~~`로 시작하는 줄) 안의 줄은 건너뛴다. 맨 앞 번호를 똑같이 뗀다
- 칸 맞춤(D3): 정본 칸을 순서대로 하나씩, 앞 칸이 맞은 자리 뒤에서 「급이 같고 번호 뗀 제목이 칸 이름으로 시작하는」 첫 제목을 찾는다. 정본에 없는 제목은 건너뛴다(사이에 끼어도 된다)
  - 뒤에서 못 찾았는데 앞쪽에 있으면 → `순서 어긋남: <칸 이름>`
  - 어디에도 없으면 → `빠진 칸: <칸 이름>`
  - 문제는 전부 한 줄씩 표준 출력에 내고 exit 1
  - 문제가 없으면 표준 출력 `칸 순서 통과: <정본 칸 수>칸`, exit 0
- 내용은 보지 않는다. 제목만 있고 아래가 비어 있어도 그 칸은 있는 것이다(아주 자세히 3칸 제목만 있는 설계서 통과)
- 크게 실패(AC-19): 틀 블록을 못 찾거나 정본 칸이 0개면 표준 에러 `틀 블록을 못 찾음: <design.md 경로>`, exit 2 — 정본 0개로 아무 설계서나 통과하는 일이 없게. 설계서 파일을 못 읽으면(없음 · 인자 없음) 표준 에러에 이유 한 줄, exit 2
- 공개 레포다. 스크립트 · 메시지에 사람 · 회사 이름 · 개인 경로를 넣지 않는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test` — 이 레포 verify는 test 하나)
- 엣지 5축(축마다 테스트 이름 또는 「해당 없음」):
  - 빈 값·경계: `dc-deep-title-only-passes` · `dc-empty-file`
  - 비정상 입력: `dc-missing-file-exit2` · `dc-template-block-missing-exit2`
  - 실패 경로: `dc-missing-cell` · `dc-swapped-cells`
  - 상태 전이: 해당 없음: 파일 하나를 읽고 끝나는 스크립트다
  - 동시성: 해당 없음: 쓰는 것이 없다

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/design-doc-format-2026-11-28/ARCHITECTURE.md` 「데이터 흐름」 · 「지키는 것 — 불변 규칙」.
3. 결과를 `phases/design-doc-format/index.json`의 step 2에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `design.md`는 이 step에서 고치지 않는다(틀은 step 1, 문구는 step 3). 검사를 맞추려고 틀을 바꾸지 않는다.
