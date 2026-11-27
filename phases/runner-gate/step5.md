# Step 5: runner-docs-entry-lines

## 읽어야 할 파일

- docs/runner-gate-2026-11-26/{PRD,ARCHITECTURE,ADR}.md — ADR-023 전체(R1 · R2 · R3 · 결과의 「장치로 못 막는 갈래」)
- 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 위 문서와 `.claude/rules/non-obvious-patterns.md`
- `docs/sdd-runner.md` — 사용 예(`:10-14`) · 나눔 모드 절(`:58-71`) · 검증 상태(`:107-109`)
- `skills/sdd-run/SKILL.md` §2-b(`:49-58`) · `skills/sdd-plan/SKILL.md` §0(`:9-12`)
- `skills/sdd-run/scripts/sdd_runner.py` — step 1~4가 만든 `gate` · `start` 관문 · `rejudge` · 판정 5 동작(문서가 코드와 같아야 한다)

## 의도

- 채우는 수용 조건: AC-2(장치로 못 막는 갈래를 문서에 글 한 줄 + 이유) — 그리고 두 진입점을 부르는 자리에 안내를 둔다(PRD 범위 「`docs/sdd-runner.md` 나눔 모드 절 · `sdd-run` 안의 진입점 안내 한 줄」, ADR-023 R2의 `sdd-plan` §0 한 줄)
- tdd: false — 문서 · 스킬 안내 문장만 바꾼다(테스트로 잡을 동작이 없다. 문장은 AC의 grep으로 확인)

## 작업

- `docs/sdd-runner.md`
  - 종료 코드 줄 · 사용 예에 `gate` · `rejudge`를 넣는다
  - 새 굵은 글머리 항목 「구현 시작 관문(ADR-023 R1 · R2)」: 무엇을 세나(ADR 「결정할 것」 표 주체 빈 행 · PRD 「남은 ⚠️」 첫 단 항목, `→ 결정:` · `막지 않음:` 줄 제외) · 어디서(`gate` · `start` 부작용 전 · `run`은 `start`를 거침) · 종료 0/2 · 문서 없으면 통과. **장치로 못 막는 갈래** 한 줄 + 이유: 「결정할 것」 표 없이 옛 ADR 블록 꼴로만 썼거나 결정이 ARCHITECTURE 한 줄로만 남은 일은 셀 칸이 없어 통과한다 — 그 갈래는 `design.md` Readiness 6(사람 · 지휘 확인)이 받는다
  - 나눔 모드 항목의 「재판정이 「테스트 고침」이면 지금은 사람이 … 정리한다 — 진입점은 #77」 문장을 `rejudge` 설명으로 바꾼다: 부르는 때 · 확인 둘(테스트만 고친 커밋 · BASE 위 실패) · 기록(`red` 옮김 · pending · BASE 유지 · `rejudged`) · 두 번째 막힘은 종료 2(사용자, ADR-019 E3) · 판정 5 바뀜. 차례 표 blocked 행의 「부르는 것」 칸에 `rejudge`를 더한다
  - 「검증 상태」의 러너 단위 테스트 개수를 실제 `python3 -m unittest …` 출력 숫자로 고치고 이번에 더한 테스트를 한 구절로 적는다
- `skills/sdd-run/SKILL.md` §2-b 검증 세션 줄 뒤에 한 줄: 구현이 blocked면 재판정(E3) — 「테스트가 틀렸다」면 테스트만 고쳐 커밋한 뒤 `rejudge {task} --step N`(정본은 `docs/sdd-runner.md` 나눔 모드)
- `skills/sdd-plan/SKILL.md` §0에 한 줄(지휘 경로 예외 — 이 한 줄만): 폴더를 정하면 `python3 "${CLAUDE_PLUGIN_ROOT}/skills/sdd-run/scripts/sdd_runner.py" gate docs/{feature-YYYY-MM-DD}` — 종료 2면 열린 항목을 닫기 전에는 step 파일을 쓰지 않는다(나눔 모드는 지휘에, 혼자면 사람에게 묻는다)

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`)
- `python3 -m unittest skills/sdd-run/scripts/test_sdd_runner.py` 통과
- `grep -n "진입점은 #77" docs/sdd-runner.md` 0줄 · `grep -c "rejudge" docs/sdd-runner.md skills/sdd-run/SKILL.md` 각 1 이상 · `grep -c "sdd_runner.py\" gate" skills/sdd-plan/SKILL.md` 1

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/runner-gate-2026-11-26/ARCHITECTURE.md` 「바뀌는 층」 문서 · 스킬 행.
3. 결과를 `phases/runner-gate/index.json`의 step 5에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 이름 · 경로를 일괄 바꿀 때도 고치지 않는다. 「옛 이름 grep 0」은 이 파일들을 빼고 센다.
- `skills/conductor/**` · `skills/sdd/SKILL.md` · `skills/sdd/references/design.md` · `docs/principles/**`는 건드리지 않는다(옆 트랙). `skills/sdd-plan/SKILL.md`는 위 한 줄만
