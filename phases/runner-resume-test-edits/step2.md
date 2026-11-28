# Step 2: test-edits-doc-resume

## 읽어야 할 파일

- docs/runner-resume-test-edits-2026-11-28/{PRD,ARCHITECTURE}.md — ADR 없음
- `docs/sdd-runner.md` — `test_edits` 칸 항목(「칸은 진행 중 index.json이 아니라 BASE 커밋의 계획에서 읽는다(T6)」 문장) · 테스트 개수 줄(`python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` — N개 통과)
- `skills/sdd-run/SKILL.md` §4 「재개 절차」 문단(「고친 index.json은 커밋하지 않은 채로 와도 된다」 문장)
- `skills/sdd-run/scripts/sdd_runner.py` `align_test_edits`(step 1이 더한 동작 — 문서가 이것과 같아야 한다)

## 의도

- 채우는 수용 조건: AC-6 · AC-8 — 문서가 바뀐 동작(멈춤 · 완료 기록 때 칸 맞추기)과 막지 못하는 한계를 말하게

## 작업

- tdd: false 이유: 문서 문장만 바꾼다. 동작은 step 1 테스트가 덮는다
- `docs/sdd-runner.md` `test_edits` 항목에서 「step 도중 더한 칸은 계획을 커밋해도 남은 재시도에는 안 먹고, 멈춘 뒤 재개(새 BASE)부터 적용된다」 부분을 아래 뜻으로 바꾼다(문장은 이 파일 꼴에 맞춰 다듬어도 된다)
  - 러너는 멈춤(blocked · error) · 완료를 기록해 index.json을 커밋하기 전에 모든 step의 칸을 그 판정 BASE의 계획 값으로 맞춘다. BASE에 계획이 없으면 칸을 뺀다(#116)
  - 값을 바꿨으면 「step N test_edits 되돌림: <전> → <계획 값>」 한 줄을 출력한다
  - 재개하며 칸을 더하려면 index.json을 커밋한 뒤 재개한다(다음 BASE에 들어가야 먹는다)
  - 한계: 구현 세션이 판정 뒤 · 다음 BASE 고정 전에 index.json을 직접 커밋하면 러너는 사람 커밋과 가를 수 없다
- 테스트 개수 줄의 숫자를 실제 `Ran N`으로 고치고, 괄호 목록 맨 앞에 이번 phase 몫(#116 runner-resume-test-edits 5개: blocked 재개 · error 멈춤 · 뒤 step 칸 · 계획 칸 유지 · BASE에 계획 없음)을 더한다
- `skills/sdd-run/SKILL.md` §4 재개 절차의 「고친 index.json은 커밋하지 않은 채로 와도 된다.」 뒤에 한 구절만 더한다: 「`test_edits` 칸을 더하려면 index.json을 커밋한 뒤 재개한다」. 평이한 문장으로 쓰고(굵은 글씨 · 대문자 경고 없이), 그 문단의 범위 · 보고 형식 · 재시도 상한 · 기본값 문장은 건드리지 않는다
- 다른 문장은 바꾸지 않는다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `grep -c '멈춘 뒤 재개(새 BASE)부터 적용된다' docs/sdd-runner.md` → 0
- `grep -c 'test_edits 되돌림' docs/sdd-runner.md` → 1 이상
- `grep -c 'test_edits. 칸을 더하려면 index.json을 커밋한 뒤 재개한다' skills/sdd-run/SKILL.md` → 1

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-resume-test-edits-2026-11-28/ARCHITECTURE.md` 「불변 규칙」.
3. 결과를 `phases/runner-resume-test-edits/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.
- `docs/changes/**`(릴리스 몫)는 고치지 않는다.
