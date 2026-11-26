# Step 5: runner-intent-effort

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 C1 · C2 · C3 · E1 · E3 · G6)
- `skills/sdd-run/scripts/sdd_runner.py`(`prompt` · `invoke` · `run` · `check` 판정 2 · `main`) · `skills/sdd-run/scripts/preamble.md`(6번 blocked) · `skills/sdd-run/scripts/test_sdd_runner.py` · `docs/sdd-runner.md`
- `templates/.claude/rules/testing.md` §2(엣지 5축 축 이름 — 러너 상수와 같은 글자)
- step 4 summary(나눔 모드 `--role` 옵션 · `judge --red`)

## 작업

근거: ADR-019 C1(의도 칸) · C2(effort는 역할이 정한다) · C3(멈춤 조건은 공용 규칙 한 곳) · G6(엣지 5축 칸).

바꾸는 파일:

- `skills/sdd-run/scripts/sdd_runner.py` · `skills/sdd-run/scripts/preamble.md` · `skills/sdd-run/scripts/test_sdd_runner.py` · `docs/sdd-runner.md`

- 의도 칸(ADR-019 C1): step 파일에 `## 의도` 절이 있는데 본문이 비면 `prompt`가 지시문을 내지 않고 종료 코드 비0 + 이유 한 줄. 절이 없으면(옛 phase) 지시문은 내고 stderr에 경고 한 줄
- effort(ADR-019 C2): `prompt`가 stderr에 `▶ effort <값>`을 낸다 — 세션 안 러너는 이 값을 Agent effort로 넘긴다. 헤드리스 `invoke`는 `claude -p`에 `--effort <값>`을 넘긴다. 값은 역할에서: `--role test` = 검증 역할, `--role impl` = 구현 역할, 세션 안 옵션 없는 1회 모드(`prompt`) = 구현 역할(ADR-019 C7a), 헤드리스 `run` = 검증 역할(ADR-019 C7b — 사람도 검증 세션도 없이 테스트까지 쓴다). 역할 → 값 대응은 ADR-019 E1을 따르되 코드에는 한 곳(상수 하나)에만 둔다. `--effort`로 덮을 수 있다
- 평문(ADR-019 G5): 재시도 · 재개 머리글의 「반드시」 두 곳(`prompt`의 `## ⚠ 이전 시도 실패 — …` · `## ⚠ 이전 실행이 멈춘 원인 — …`)을 뜻 그대로 평문으로
- 멈춤 조건(ADR-019 C3): `preamble.md` 6번 blocked 조건을 「사람만 할 수 있는 일 · 테스트가 수용 조건과 다르다 · 설계 문서에 없는 결정이 필요하다」로 넓힌다. 구현 역할 지시문에는 「테스트는 고치지 않는다 — 막히면 blocked + 이유, 검증 세션이 다시 판정한다」(ADR-019 E3)
- 같은 1회 모드라도 세션 안(`prompt`)과 헤드리스(`run`)의 값이 다르다 — 상수 한 곳에 두 갈래로
- 엣지 5축 칸(ADR-019 G6): 축 이름 다섯(`빈 값·경계` · `비정상 입력` · `실패 경로` · `상태 전이` · `동시성`, `testing.md` §2와 같은 글자)을 코드 한 곳(상수 하나)에 둔다. step 파일 「Acceptance Criteria」 절의 `- 엣지 5축` 줄 아래 하위 줄 `  - <축>: <값>`을 읽는다. 값은 백틱으로 감싼 테스트 이름 하나 이상(` · `로 구분) 또는 `해당 없음`으로 시작하는 글(뒤 `: 이유`는 선택)이다. 그 밖(빈 값 · 백틱 없는 글 · 축 빠짐)은 「칸이 비었다」
- 언제 보나: `tdd: true` step이고 새 꼴(`## 의도` 절이 있음)일 때만. 옛 꼴(의도 절 없음 — 이 phase 포함)은 칸이 없어도 지시문을 내고 stderr에 경고 한 줄. `tdd: false` · `kind: measure`는 보지 않는다. 의도 절(C1)과 같은 함수에서 같이 본다
- 칸이 비면 판정 실패이고 재시도하지 않는다 — 에이전트가 고칠 수 없는 계획 칸이라 재시도 4번을 태우지 않게: 세션 안 `prompt`(옵션 없음 · `--role test`)는 지시문을 내지 않고 비0 + 빈 축 이름 한 줄, 헤드리스 `run`은 `claude`를 부르지 않고 step을 `blocked`(이유: 엣지 5축 칸이 비었다 — <축>, 계획을 고친 뒤 재개)로 두고 종료 2
- 이름 대조: 칸의 테스트 이름이 RED 커밋(1회 모드는 판정 2가 찾은 테스트 커밋, 나눔 모드는 `judge --red`가 보는 커밋)에 담긴 테스트 파일 내용 어딘가에 글자 그대로 있어야 한다. 없으면 `RedFail`(`엣지 5축: <축> 테스트 이름 <이름> 이 테스트 커밋에 없다`) — 지금 RED 위반처럼 시도를 버리고 테스트부터 다시. 러너 출력이 아니라 파일 내용을 보는 이유: 프레임워크마다 테스트 이름 출력 꼴이 달라서
- 지시문: tdd 규칙(1회 모드 4번 · `--role test` 지시문)에 「step 파일 엣지 5축 칸의 테스트 이름을 그대로 테스트 이름에 쓴다」 한 구절
- 판정 4(테스트 파일 무수정)는 그대로 — 엣지 칸 때문에 구현 쪽이 테스트를 고칠 길을 열지 않는다. 커버리지 숫자 게이트는 두지 않는다
- 테스트 메서드 이름에 `intent_effort`를 넣는다(AC의 `-k`). 엣지 칸 테스트는 `edge_axes`
- 테스트 먼저: 빈 의도 절 거부 · 의도 절 없음 경고 · 역할별 effort 출력 · 헤드리스 명령에 `--effort` · `--effort` 덮어쓰기
- 테스트 먼저(`edge_axes`): 새 꼴 tdd step에 칸 없음 → `prompt` 비0 · 빈 축 하나 → 비0 + 그 축 이름 · 다섯 축이 이름 또는 `해당 없음` → 지시문 냄 · 옛 꼴 → 경고만 · `tdd: false` · measure는 안 봄 · 헤드리스에서 칸 빈 step → claude 호출 0번 + `blocked` + 종료 2 · RED 커밋에 칸의 이름 없음 → 시도 버림 / 있음 → 통과(1회 모드 · `judge --red` 둘 다) · 기존 판정 4 테스트(`test_test_file_modified_after_red`) 그대로 통과

## Acceptance Criteria

- `bash hooks/test.sh` 통과
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py -k intent_effort` 통과(`hooks/tests/sdd-runner-unit.sh`와 같은 방식)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py -k edge_axes` 통과

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. effort 값이 코드 한 곳에만 있는지(`git grep -n '"medium"\|"high"' -- skills/sdd-run/scripts/sdd_runner.py`) 대조한다. 엣지 축 이름도 상수 한 곳뿐인지(`git grep -n '상태 전이' -- skills/sdd-run/scripts/sdd_runner.py` 1줄) 대조한다.
3. 결과를 `phases/verify-flow/index.json`의 step 5에 기록(꼴은 step 4와 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지. step 파일에 effort 칸을 만들지 않는다(ADR-019 C2). 이 phase의 step 파일에 엣지 칸을 넣지 않는다(옛 꼴 그대로, 쌓기만 하는 기록).
- 쌓기만 하는 기록은 고치지 않는다.
- push · PR 금지.
