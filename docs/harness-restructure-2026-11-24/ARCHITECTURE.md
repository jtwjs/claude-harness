# ARCHITECTURE — 하네스 재구성 뒤 구조

> 결정 값은 `ADR.md` ADR-016을 참조한다. 여기는 무엇이 어디에 있고, 무엇이 무엇을 부르는지만 적는다.

## 1. 부르는 길

```
사람 ─┬─ 말로 ──────────▶ 자동 입구 (description으로 모델이 부름)
      │                    sdd · why · how · conductor · slack-writing · notion-writing · commit · pr-write
      │                      │
      │                      ├─ 경로로 ──▶ 단계 스킬 SKILL.md (Read 해서 따른다)
      │                      └─ 경로로 ──▶ docs/principles/INDEX.md → 원칙 원문
      │
      └─ /짧은 이름 ────▶ 슬래시 입구 (disable-model-invocation: true)
```

- 자동 입구만 description이 상시 비용을 낸다. 나머지는 `disable-model-invocation: true`.
- 입구가 단계 스킬 · 원칙을 가리킬 때는 `${CLAUDE_PLUGIN_ROOT}/…` 형태로 쓴다. 상대 경로는 다른 레포 세션에서 그 레포 기준으로 풀린다(ADR-016 「결과」 실측).
- 입구 보고에는 「쓴 원칙 · 바뀐 결정」을 한 줄 단다(ADR-016 D0).

## 2. 스킬 자리 (재구성 뒤)

| 종류 | 스킬 | 비고 |
|---|---|---|
| 자동 입구 | `sdd` · `why` · `how` · `conductor` · `slack-writing` · `notion-writing` · `commit` · `pr-write` | ADR-016 D0 · Q1 · Q2 |
| 단계 (입구가 경로로) | `sdd-plan` · `sdd-run` · `sdd-review` · `design-brief` · `design-critique` · `design-reconcile` · `changeset` · `harness-gaps` · `explain` | 사람이 슬래시로도 부를 수 있다. `explain`은 `sdd` 마무리가 학습 카드 재료로 부른다(Q2) |
| 슬래시 입구 (사람만) | `harness-init` · `project-new` · `harness-doctor` · `harness-score` · `no-comments` · `statechart` · `reframe` · `sharpen` | D5 · D6 · D8 · D13 |
| 에이전트 | `test-writer` · `feature-builder` · `code-reviewer` · `root-cause-debugger` · `comment-hunter` | D6 |

## 3. 폴더

| 자리 | 담는 것 | 담지 않는 것 |
|---|---|---|
| `skills/<이름>/SKILL.md` | 그 스킬의 순서 · 판단 · 보고 형식. 처음 보는 상황에서 판단을 바꾸는 이유 한 구절 | 날짜 · 버전 이력 · 배경(D0). 다른 스킬의 절차 복사 |
| `skills/<이름>/references/<주제>.md` | 쪼개다 남은 절차 · 표 · 배경 | 원칙 |
| `skills/<이름>/scripts/` | 그 스킬만 쓰는 스크립트 | |
| `docs/principles/INDEX.md` | 원칙 이름 · 언제 · 경로(목차 안 경로는 INDEX.md가 있는 폴더 기준) | 원칙 본문 |
| `docs/principles/<이름>.md` | 판단 규칙만 | 사실 · 절차(→ 스크립트) |
| `scripts/` | 여러 스킬이 같이 쓰는 사실 · 절차(첫 번째: `base-branch.sh`) | |
| `docs/learning-level.md` | 학습 카드 형식만(D-gate) | 퀴즈 · 게이트 판정 |
| `hooks/tests/*.sh` | 새 테스트 | |
| `docs/<기능-날짜>/` · `docs/retro/` · `phases/*/` · ADR 본문 | 쌓기만 하는 기록 | 이름 바꾸기 때 고치지 않는다 |

## 4. 이름 규칙

ADR-016 D1 이름을 따른다. 옛 이름 → 새 이름은 `skills/harness-init/SKILL.md` 이름표에 한 줄씩 더한다(재구성 중 바뀐 이름: `harness` · `harness-run` · `ai-readiness-cartography` · `explain-diff`).

## 5. 경계 규칙

- 원칙 파일에서 스크립트로 옮길 수 있는 문장(브랜치 이름 · 경로 · 명령)은 스크립트로 옮긴다.
- 같은 규칙을 두 번째 파일에 쓰지 않는다. 두 번째가 필요하면 원칙 파일이나 스크립트로 올리고 둘 다 가리킨다.
- `hooks/test.sh`는 경로 · 문구를 직접 검사하는 줄이 있어 이름 · 위치를 바꾸면 같이 고쳐야 한다. 허용 범위는 ADR-016 「대가」(Q3): 기존 줄을 바뀐 경로 · 문구에 맞추는 것만. 새 케이스는 `hooks/tests/`.
- 원칙 파일 이름은 하는 일을 영어 kebab으로(Q6): `ask-questions` · `write-for-readers` · `attack-the-premise` · `subtract-before-you-add` · `explain-the-number` · `build-the-lever`.
- 쌓기만 하는 기록(3절 마지막 행)은 「옛 이름 grep 0」에서 뺀다.
