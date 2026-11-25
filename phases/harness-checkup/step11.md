# Step 11: eval-frame

## 읽어야 할 파일

- `docs/harness-checkup-2026-11-25/ADR.md`(ADR-018 — A 정할 것 · B 판정표 · 시험 결과). 이 레포는 루트 `CLAUDE.md`가 없다 — 가드레일은 이 ADR과 `.claude/rules/non-obvious-patterns.md`
- `docs/harness-checkup-2026-11-25/evals/`(시험 case 3개) · ADR-018 「시험 결과」 절

## 작업

근거: ADR-018 A1~A4 시험 결과.

바꾸는 파일:

- 새 `evals/`(레포 루트, 플러그인 eval 기본 자리) · `.claude-plugin/plugin.json`이 eval 자리를 따로 적어야 하면 그 키

- ADR-018 A1~A4 결정(사용자 답)대로 case를 둔다. 시험에서 나온 규칙: 턴 상한은 스킬 · 참조를 읽고도 답할 만큼, 턴 상한에 걸린 실행은 무효로 센다, 채점은 하네스 고유 결과(outcome) 우선
- A 결정(ADR-018 A1~A3, 사용자): 채점은 결과 + 실행 비용(턴 · USD · 시간, eval JSON 값) · 과제는 합성으로 시작 · 통째 비교 + 과제마다 그 과제가 기대는 부품 하나를 뺀 변형 1개
- case 최소 구성: 자동 입구 8개마다 떠야 할 과제 1개 + 안 떠야 할 과제 1개(B-15에서 맞춘 정답 기준). 채점기는 기본 모델이 안 하는 하네스 고유 결과(질문을 한 번에 하나 · 추천 표시 · 세 줄 요약 · 결정 기록 파일)로, case마다 outcome 채점기 1개 이상
- 부품 변형: 과제가 기대는 부품(예: `sdd` 과제 → `code-reviewer` 없는 변형)을 case 옆에 적고, 변형을 만드는 법(임시 플러그인 사본에서 그 파일 삭제)을 스크립트로
- 비교 결과에 턴 상한 도달 실행은 「무효」로 따로 센다
- tdd: false — eval 재료다

## Acceptance Criteria

- `bash hooks/test.sh` 통과(`.claude/harness.json` `verify.test`. worktree에는 이 파일이 없어 main clone 사본을 쓴다)
- `claude plugin eval . --help` exit 0 · case마다 outcome 채점기 1개 이상

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. ADR-018이 정한 값은 참조만 했는지 대조한다(값을 step에 복사하지 않는다).
3. 결과를 `phases/harness-checkup/index.json`의 step 11에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄, 뒤 step이 쓸 이름 · 경로. 계획과 다르게 한 것은 「…로 했다(계획은 X, 이유: Y)」)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
- 쌓기만 하는 기록(로그 · 회고 · `docs/`의 지난 설계 · ADR 본문 · `phases/*/` · `docs/changes/`)은 고치지 않는다.
- 사람 · 회사 이름, 개인 문서 문구를 쓰지 않는다.
- push · PR 금지(러너 밖에서 사람이 한다).
