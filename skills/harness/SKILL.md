---
description: SDD PLAN 단계 — docs/{feature-date}/ 설계문서(PRD·ARCHITECTURE·ADR)와 CLAUDE.md를 읽고 사용자와 범위를 합의한 뒤, 자기완결적 step 파일(phases/{task}/index.json + stepN.md)로 분해해줘. Use when 설계가 끝나 구현 계획을 세울 때(harness-run 실행 직전).
disable-model-invocation: false
---

설계문서를 **자기완결적 step**으로 분해해 `phases/{task}/`를 만든다. 실제 구현은 `harness-run` 스킬이 담당하므로, 여기서는 **계획 산출물만** 만든다.

## 0. 대상 기능 확인 (필수)

- 사용자에게 **어느 기능/날짜 폴더**인지 묻는다 → `docs/{feature-YYYY-MM-DD}/`.
- `task` slug를 합의한다(kebab, 예: `article-draft-autosave`). 이것이 `phases/{task}/`·`feat-{task}` 브랜치 이름이 된다.

## 1. 가드레일 로드 (토큰 효율 — 이 파일들만)

- 루트 `CLAUDE.md`
- `docs/{feature-date}/PRD.md`(무엇을·왜) · `ARCHITECTURE.md`(구조·레이어) · `ADR.md`(기술 결정)
- ⚠️ `docs/**`의 다른 문서는 읽지 않는다(컨텍스트 절약).

## 2. 범위 합의 (사람 체크포인트 ①)

- 설계문서에서 **구현 대상 유즈케이스·수용 조건**을 뽑아 bullet로 요약한다.
- 모호·누락은 **추측 말고 질문**한다(karpathy: 가정 명시). 승인 전 step 파일을 쓰지 않는다.

## 3. Step 분해 원칙

- **범위 최소화**: 한 step = 하나의 작동 단위. 순서는 **의존 방향을 따라 아래 계층부터** — 타입/데이터 → 외부 연동 → 상태 → 화면 → 통합. 계층 이름은 프로젝트 규약(`CLAUDE.md` 구조 절·`.claude/rules/`)을 따른다.
- **자기완결성**: step 하나만 읽어도 서브에이전트가 작업 가능해야 한다. 앞 step 결과에 의존하는 부분은 명시.
- **관련 파일 강제 열람**: 따라야 할 기존 패턴 파일 경로를 `## 읽어야 할 파일`에 못박는다.
- **시그니처 수준**: 함수/컴포넌트/타입 시그니처와 계약을 지시하되, 전체 코드를 미리 쓰지 않는다.
- **AC = 실행 가능한 쉘 명령**: 통과 여부를 기계가 판정할 수 있게. 명령은 **지어내지 말고 `.claude/harness.json`의 `verify`에서 가져온다.**
- **TDD 판정**: step마다 `"tdd": true|false`를 정한다. `true`면 `test-writer`(RED) → `feature-builder`(GREEN) 2단으로 돌고, `false`면 **왜 아닌지 한 줄을 step 파일에 적는다**(조용히 건너뛰지 않는다). 판정 기준은 `.claude/rules/testing.md` §0 = `tdd-guard`의 면제 목록과 **같은 표**다.
- **금지사항 명시**: CRITICAL 규칙을 step 안에 재고정.
- step 이름은 **kebab-case**.

## 4. 산출물

### `phases/{task}/index.json`

```json
{
  "project": "<repo-name>",
  "phase": "{task}",
  "steps": [
    { "step": 1, "name": "add-draft-model", "status": "pending", "tdd": true }
  ]
}
```

- `status` ∈ `pending | completed | error | blocked`. 최초 전부 `pending`.
- `summary`·`error_message`·`blocked_reason`·timestamp는 **구현 단계(harness-run)**가 채운다. 여기선 비워둔다.

### `phases/{task}/stepN.md` — 5개 섹션 고정

```markdown
# Step {N}: {kebab-name}

## 읽어야 할 파일

- CLAUDE.md, docs/{feature-date}/{PRD,ARCHITECTURE,ADR}.md
- (따라야 할 기존 패턴 경로 — 유사 entity/feature/훅/스토어)

## 작업

- 시그니처 수준 지시(만들/바꿀 파일 · 레이어 · 타입/함수 계약)
- 고정할 CRITICAL 규칙 — `CLAUDE.md`의 🔴 CRITICAL 절과 해당 `.claude/rules/`에서 **그대로 인용**한다(새로 지어내지 않는다)

## Acceptance Criteria

- `.claude/harness.json`의 `verify.typecheck` 통과
- `verify.test` 통과 (비어 있으면 **그 사실을 step에 명시**한다)
- (필요 시) `verify.build`

## 검증 절차

1. 위 AC 명령을 실제 실행한다.
2. 아키텍처 체크리스트 대조 — `docs/{feature-date}/ARCHITECTURE.md`의 경계 규칙, `.claude/rules/`의 판정, 짝 테스트 존재.
3. 결과를 `phases/{task}/index.json`의 해당 step에 기록:
   - 성공 → `status:"completed"` + `summary`(1~2줄)
   - 실패 → `status:"error"` + `error_message`
   - 판단 불가/차단 → `status:"blocked"` + `blocked_reason`

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · `.claude/rules/`가 금지한 의존 방향 위반 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 step에서) 금지.
```

## 5. 마무리

- 만든 step 목록을 표로 보여주고, 승인되면 **`harness-run` 스킬로 구현**하도록 안내한다.
- 이 스킬은 코드를 수정하지 않는다(계획 전용).

---

## 부록 — 설계문서 템플릿 (`docs/{feature-YYYY-MM-DD}/`)

DESIGN 단계 산출물. 없으면 `why-logictree`로 **PRD부터 만든 뒤** 이 스킬로 돌아온다.

**PRD.md**: 무엇을(한 문장) · 왜(문제·성공지표) · 사용자 시나리오 · 범위(포함/제외) · **수용 조건 체크리스트** ← `test-writer`가 케이스를 뽑는 입력이다.
**ARCHITECTURE.md**: 개요 · 계층 배치와 각 층의 책임 · 데이터 흐름 · 경계·의존 방향 · 상태 관리 규약 · 테스트 전략. **구체 스택 이름은 그 프로젝트의 것을 쓴다.**
**ADR.md**: `ADR-00N` 블록 반복 — 상태 · 맥락 · 결정 · 대안(+버린 이유) · 결과(트레이드오프).
