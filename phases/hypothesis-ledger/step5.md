# Step 5: sdd-reflect-stages

## 읽어야 할 파일

- CLAUDE.md, docs/desk-hypothesis-gate-2026-11-12/PRD.md · ARCHITECTURE.md · ADR.md · SDD-SIDE.md (줄 형식·판정 기준·계산 규칙의 정본)
- skills/sdd/SKILL.md (④ REFLECT 절 — 산출물 넷의 형식과 출구 조건) · skills/sdd/references/design.md

## 작업

`skills/sdd/SKILL.md` 의 REFLECT 에 단계 둘을 더한다. 기존 산출물 넷의 순서·출구 조건은 바꾸지 않고, 두 단계는 회고 1장 **앞**에 둔다.

1. **적중 판정**(AC14, ADR-007): `ledger.py pending-hits <repo> <task>` 로 대상 `ts` 를 모은다 → 모델이 각각 `right|partial|wrong` 을 제안 → 사람이 정정하면 `hit ... finn`, 그대로 두면 `hit ... model` 로 쓴다. 대상이 없으면 한 줄 보고하고 넘어간다.
2. **게이트 보정**(AC17, ADR-008): `ledger.py pending-gates <repo> <task>` 로 모은다 → 모델이 이번 diff 와 대조해 후보를 보인다 → 사람이 확정한 것만 `gate-fix <ts> <gate>` 로 쓴다. 대상이 없으면 한 줄 보고하고 넘어간다. 줄을 프롬프트에 대응시킬 수 없으면(압축 등) 그 줄은 건너뛰고 한 줄 보고한다.
- `task=null`(sdd 밖) 작업은 두 단계 모두 대상이 아니다(PRD 「하지 않을 것」).
- 사람 체크포인트 목록(「사람 체크포인트」 ④ REFLECT)에 두 단계의 정정·확정을 넣는다(`이 목록 밖에서 멈췄다면 스킬 쪽이 틀린 것` 규칙).
- 문서 변경이라 `tdd: false`(사유: 스킬 본문은 테스트 대상이 아니다. `tdd-guard` 면제 목록과 같은 판정).

## Acceptance Criteria

- `grep -n "pending-hits" skills/sdd/SKILL.md` 와 `grep -n "pending-gates" skills/sdd/SKILL.md` 가 각각 REFLECT 절 안에서 1건 이상 나온다.
- `bash hooks/test.sh` 전부 통과(회귀 없음 — 이 레포는 SKILL.md 구조를 검사하는 케이스가 있을 수 있다).

## 검증 절차

1. 위 grep 과 `bash hooks/test.sh` 를 실제 실행한다.
2. REFLECT 출구 조건(회고 1장 · 남긴 자산 · 건너뜀 표기)이 그대로인지 대조한다.
3. `phases/hypothesis-ledger/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 사용자의 실제 원장(`~/.claude/hypothesis-ledger.jsonl`)을 테스트에서 건드리지 않는다(환경 변수로 임시 경로를 지정한다).
- 원장에 이름 · 프롬프트 원문 · 코드를 넣지 않는다(허용 칸 목록 밖은 거부 — AC10).
- 이름·경로를 바꾸는 step 이 아니다. REFLECT 의 다른 단계 문구는 고치지 않는다.
