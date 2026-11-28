# ARCHITECTURE — runner-resume-test-edits

기존 구조 그대로 — 바뀌는 층: 없음. 러너 구조는 [`docs/sdd-runner.md`](../sdd-runner.md)가 정본이다. (← 검증 세션)

## 코드 지도

| 파일 | 이번에 하는 일 | 출처 |
|---|---|---|
| `skills/sdd-run/scripts/sdd_runner.py` 새 메서드(맞추기) | BASE 커밋의 `phases/<task>/index.json`을 한 번 읽어, 진행 중 index의 모든 step `test_edits`를 그 값으로 맞춘다(계획에 없으면 칸을 뺀다). 바꾼 step마다 「step N test_edits 되돌림: <전> → <계획 값>」을 출력한다 | PRD AC-1~5 |
| `sdd_runner.py` `start` (REVIEW 1회차) | 부작용 전에 작업 트리 index.json의 step별 `test_edits`가 HEAD 커밋 값과 다르면 「index.json 을 커밋한 뒤 실행」 종료 1. 맞추기는 번호 + name이 같을 때만 계획 값 | PRD AC-9~11 |
| `sdd_runner.py` `record` 세 자리 | blocked 기록 · error 멈춤 · completed 기록에서 `index.json`을 쓰고 커밋하기 전에 맞추기를 부른다 | PRD AC-1~3 |
| `skills/sdd-run/scripts/test_sdd_runner.py` | 재현 A(blocked · error) · 재현 B · 계획 칸 유지 · BASE에 계획 없음 · 다른 세션이 뒤 step 칸을 고친 경우 | PRD AC-1~5 · AC-7 |
| `docs/sdd-runner.md` `test_edits` 항목 · 테스트 개수 줄 | 새 동작 · 한계 문장 | PRD AC-6 |
| `skills/sdd-run/SKILL.md` §4 재개 절차 | 「`test_edits` 칸을 더하려면 index.json을 커밋한 뒤 재개한다」 한 구절 | PRD AC-8 |

## 불변 규칙

- 판정 4'가 허가를 읽는 곳은 그대로 BASE 계획(`planned_edits`, ADR-024 T6)이다. 이번 고침은 러너 커밋이 구현의 칸을 다음 BASE로 나르지 않게 할 뿐이다 (← #116 결정)
- 재시도(종료 10) 자리는 index를 커밋하지 않으므로 손대지 않는다. 그 사이 칸은 BASE 계획을 읽는 판정 4'가 이미 무시한다 (← 검증 세션)
- 검증 세션 기록(`judge --red` · `rejudge`)과 `start`는 바꾸지 않는다 (← PRD 하지 않을 것)

## 재현 (2026-11-28, origin/main 890cb90, 검증 세션 스크래치)

| # | 경우 | 지금 결과 | 출처 |
|---|---|---|---|
| A | 나눔 모드 tdd:false, 구현이 자기 칸을 써 넣고 blocked → 재개 → 테스트 고침 · completed | 멈춤 judge 2(칸이 커밋됨) → 재개 뒤 judge 0, 테스트는 고친 내용 | 검증 세션 |
| B | step 1 구현이 step 2 칸을 써 넣고 completed → step 2 구현이 테스트 고침 | step 1 judge 0 → step 2 judge 0, 테스트는 고친 내용 | 검증 세션 |

## 테스트 전략

- 나눔 모드(`guard_turn` → `prompt --role impl` → `act` → `judge`)로 A · B를 끝에서 끝까지 돈다. error 멈춤은 헤드리스 `run --max-retries 0`으로 본다(기존 T7 테스트와 같은 길) (← 검증 세션)
- 「고치기 전 실패」 증거는 테스트를 커밋한 뒤 `judge --red`가 본 RED 출력이다 (← 트랙 지시문 완료 조건)

## 배포와 롤백

- 플러그인 릴리스로 나간다. 되돌릴 때는 PR revert 하나다 (← 검증 세션)
