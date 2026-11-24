# PRD — 하네스 재구성 (짧게 쪼개고 경로로 잇기)

> 결정은 `ADR.md` ADR-016(원문 이슈 #40), 근거는 `REVIEW.md`(#39). 이 문서는 무엇을 · 왜 · 어디까지만 적는다. 값은 ADR을 참조한다.

## 배경

- 스킬 21개 중 20개를 모델이 description으로 부를 수 있다. SKILL.md 줄 수 중앙값 97 · 최대 320, 플러그인 상시 비용 약 3,442토큰(REVIEW §5).
- 같은 원칙이 여러 스킬에 복사돼 있다. 기준 브랜치 규칙 4벌, 글 규칙 2벌, 질문 규칙은 `why` 한 곳이지만 원칙과 절차가 한 파일에 섞여 있다(REVIEW §1-5).
- 날짜 · 이력 · 배경 문장이 규칙 사이에 섞여 있다(REVIEW §1-2 ② 열).
- 막는 이해 관문(빈틈 3곳 · 퀴즈 · draft 강제)이 작업 병목이 됐다. 2026-11-16 이후 머지 PR 12건 동안 학습 카드는 0장이었다(#40).

## 목표

- 사람이 처음에 고를 입구는 몇 개뿐이다. 단계 스킬은 입구가 경로로 부른다(ADR-016 D0).
- 원칙은 `docs/principles/` 한 곳에만 있고, 스킬은 경로로 가리킨다(D2).
- 사실 · 절차는 스크립트가 들고, 스킬 본문에는 판단을 바꾸는 문장만 남는다(D0 · D2).
- 막는 관문 없이 작업이 끝나고, 보고에 세 줄 요약과 학습 카드가 실린다(D-gate · D-요약).

## 수용 조건

| # | 조건 | 확인 방법 |
|---|---|---|
| A1 | 이름 3개가 바뀌고(D1 이름) 옛 이름은 `harness-init` 이름표에만 남는다 | 쌓기만 하는 기록을 뺀 범위에서 옛 이름 grep 0 |
| A2 | `plannotator-visual-explainer` 폴더 · 참조 0(D3), `understand-anything` 의존 선언 0(D12) | grep · `plugin.json` |
| A3 | `docs/principles/INDEX.md`와 첫 원칙 파일이 있고, 입구 스킬이 `${CLAUDE_PLUGIN_ROOT}/docs/principles/INDEX.md`를 가리킨다(D2) | 파일 · grep |
| A4 | 기준 브랜치는 `scripts/base-branch.sh` 한 곳에서 정해지고 4개 스킬이 그것을 부른다(D2) | `hooks/tests/` 테스트 · grep |
| A5 | `sdd` · `pr-write`에 입력을 기다리며 막는 단계가 없다(D-gate). `sdd` 마무리가 세 줄 요약을 낸다(D-요약) | 본문 grep · `hooks/tests/` 문서 정합 테스트 |
| A6 | 흡수 스킬 · 규칙이 들어갔다(D6 · D7 · D8 · D9 · D13), 사람만 부르는 것은 `disable-model-invocation: true` | 파일 · frontmatter |
| A7 | 스킬 본문에 날짜 · 버전 이력 줄이 남지 않는다(D0) | 날짜 · 버전 패턴 grep(쌓기만 하는 기록 제외) |
| A8 | 레포에 CI가 있고 `bash hooks/test.sh` · SDD 러너 단위 테스트를 PR마다 돌린다(REVIEW R1) | `.github/workflows/` |
| A9 | README 첫 절이 입구부터 말하고, 목차와 `skills/` 목록이 맞는다(D1 · REVIEW R2) | README · `harness-doctor` 검사 |
| A10 | After를 Before와 같은 명령으로 잰다 | 아래 「측정」 |

## 측정

Before는 2026-11-24에 쟀다(`REVIEW.md` §5 · 지휘 보고). After는 마지막 PR의 측정 step이 같은 명령으로 잰다.

- SKILL.md 줄 수 중앙값 · 최대 · 스킬 수: `wc -l skills/*/SKILL.md`(frontmatter 포함)
- 상시 토큰: `claude plugin details claude-harness@jtwjs-plugins`의 Always-on
- 자동 입구 발동 정확도: 스킬마다 「떠야 할 말 10 · 안 떠야 할 말 10」 문항 × 3회, 설치본 스킬이 첫 도구 호출로 불리는지(skill-creator 「Description Optimization」 방식을 설치본에 맞게 고침). 문항 · 스크립트 · Before 원자료는 `trigger-eval/`(이 폴더)에 둔다. After가 같은 문항을 다시 돌려야 해서다
- 목표값은 정하지 않았다. After가 Before보다 나빠진 지표는 보고에 그대로 적는다

## 범위 밖

- 레포 밖: 개인 스킬(`~/.claude/skills`, 개인 `why-logictree` 삭제 포함) · 출력 스타일 · 개인 기록(학습 카드 붙이기) · 다른 레포(desk의 README 사본 이름 바꾸기)
- 새 ADR 번호 발급
- `build-the-lever` 문턱 결정(미결, 지휘가 정한다). 그 원칙 문서 step은 대기
