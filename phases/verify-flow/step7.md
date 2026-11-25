# Step 7: conductor-two-sessions

## 읽어야 할 파일

- `docs/verify-flow-2026-11-25/ADR.md`(ADR-019 C6 · E4 · E5 · E8 · E9 · E10 · G4)
- `skills/conductor/SKILL.md` · `skills/conductor/references/dispatch.md`(「트랙 세션 열기」) · `decisions.md`(§1 결정 이슈 틀 · §2 계약 변경 흐름 · §3 mock 관문) · `doorbell.md`(§8 표) · `seat.md`(「세션 종류」)

## 작업

근거: ADR-019 C6 · E4 · E8 · E9 · E10 · E12 · G4. 선행: 점검 phase 평문 step(같은 스킬 문장의 강조어를 고친다) 머지 뒤. 먼저 `python3 -c "import json;print(next(s['status'] for s in json.load(open('phases/harness-checkup/index.json'))['steps'] if s['name']=='plain-wording'))"`를 돌려 `completed`가 아니면 아무것도 바꾸지 말고 `blocked`(이유: 점검 평문 step 대기)로 끝낸다.

바꾸는 파일:

- `skills/conductor/references/dispatch.md` · `decisions.md` · `doorbell.md` · `seat.md`

- 「트랙 세션 열기」: 나눔 모드면 검증 · 구현 두 세션을 **같은 worktree에서** 연다(worktree 하나 · 브랜치 하나, 차례는 index.json — ADR-019 E12). 명령에 `--effort <high|medium>`을 늘 넘기고(ADR-019 C6 — 플래그 없이 띄우면 낮은 effort로 돈다), 이름은 `<레포>-<트랙>-verify` · `-impl`. FE · BE 기능이면 층마다 둘(ADR-019 E8)
- `seat.md` 「세션 종류」 표에 검증 · 구현 행(effort · 맡는 단계 · 언제 닫나)
- 결정 이슈 틀(§1): PRD는 지휘가 결정 이슈 본문에 쓴다(ADR-019 E4) — 칸에 기능 키워드 표 · API 계약 초안(엔드포인트 · 필드 · 에러, FE · BE 기능일 때)(ADR-019 E9 · E10). 공개 레포면 PRD에도 이름 · 개인 문서 문구를 넣지 않는다. 검증 세션이 원문을 옮기고 의도 되비추기 한 줄을 보내면 지휘가 확인한다
- §2 계약 변경 흐름에 나눔 모드 순서 한 단락(ADR-019 E9): 변경 요청은 누구든 지휘에 → `contract-change` 이슈 → 검증 BE 스펙 PR 먼저 → 검증 FE가 따라간다. 첫 step 배치(검증 BE = 계약 PR · 검증 FE = 스펙으로 MSW 핸들러 · 타입)와 끝까지 확인(검증 FE가 MSW를 끄고 실제 BE로, 머지 전)
- §8 표: 검증 ↔ 구현 알림 두 줄(「step N red 기록」 · 「step N 구현 끝 / blocked」) — 두 세션 사이는 직접 보낸다(같은 트랙 안). 트랙끼리는 지금처럼 지휘 경유. 「step·PR을 끝냈다」 줄에 「지휘 자리의 지식 저장소로 올릴 것」 4칸을 지휘가 자리 쪽으로 넘긴다는 한 줄(ADR-019 G4)
- tdd: false — 지시문 문장 바꾸기다

## Acceptance Criteria

- `bash hooks/test.sh` 통과
- `git grep -n -- '--effort' -- skills/conductor/references/dispatch.md` 출력 있음
- `git grep -n '나눔 모드' -- skills/conductor/references/decisions.md` 출력 있음

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 결정 값(effort 수준 · 세션 수)은 ADR-019 참조로만 적었는지 대조한다(`conductor` 원칙 「지시문에 값을 복사하지 않는다」).
3. 결과를 `phases/verify-flow/index.json`의 step 7에 기록(꼴은 step 6과 같다).

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · 테스트 파일 수정 금지.
- 쌓기만 하는 기록은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다. 지휘 자리 규칙(대기열 · 반영)은 레포 밖이라 적지 않는다.
- push · PR 금지.
