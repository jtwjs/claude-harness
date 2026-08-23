---
description: SDD REVIEW 단계 — 루트 CLAUDE.md + 기능의 ARCHITECTURE.md·ADR.md를 읽고 최근 변경 diff를 아키텍처·기술스택/ADR·테스트·CRITICAL 규칙·빌드/테스트 통과 관점으로 대조해 결과 표와 수정 제안을 낸다. Use when 구현(harness-run) 후 머지·커밋 전에 변경분을 검증할 때. 깊은 리뷰는 code-reviewer 에이전트에 위임.
disable-model-invocation: false
---

`harness-run` 산출 diff를 **설계문서 대비 체크리스트**로 빠르게 판정한다. 심층·다축 리뷰(성능·구조·보안 감사)는 **`code-reviewer` 에이전트**에 위임한다.

## 1. 기준 로드 (이 파일들만)

- 루트 `CLAUDE.md`
- `docs/{feature-date}/ARCHITECTURE.md`(구조·레이어) · `ADR.md`(기술 결정)
- (필요 시 `PRD.md`로 요구사항 대조)

## 2. 변경 수집

- `git diff --name-only develop...HEAD`(또는 `git diff HEAD`)로 변경 파일 파악 → 필요한 파일 맥락 확인. diff가 비면 범위를 한 번 확인.

## 3. 체크리스트 대조

| 축            | 확인                                                                                                                                                |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| 아키텍처 준수 | FSD 레이어 배치·경계(feature→feature import 금지, shared 도메인 로직 금지, 1-depth public API), `/manage/*`, ARCHITECTURE.md와 일치                 |
| 기술스택·ADR  | React19/TS strict·Zustand/TanStack Query·Tailwind·`내부 DS 패키지`·lodash-es named import — ADR 결정과 일치, 미승인 새 의존성 없음                         |
| 테스트 존재   | 변경 구현 `.ts(x)`에 짝 `*.test.ts(x)` 존재, 레이어별 도구(Vitest/RTL/MSW/Playwright), 동작 기준(구현 디테일 아님)                                  |
| CRITICAL 규칙 | hook 미우회, generated 파일 미수정, `내부 DS 패키지` 화살표 함수, 커밋 괄호 스코프 없음                                                                    |
| 빌드·테스트   | `pnpm build` · `pnpm test` (필요 시 `pnpm --filter 참고레포A typecheck`) 실제 실행해 통과 확인                                                    |
| 비주얼 싱크   | 디자인에서 구현한 화면이면 `design-reconcile`로 확정 — Playwright 스크린샷 vs Claude Design 파일 대조해 어긋남(레이아웃·간격·색·상태) 없음(머지 전) |

## 4. 출력 형식

1. **리뷰 범위** — diff 범위·파일 수(1~2줄).
2. **결과 표** — 각 축: `통과 / 위반 / 확인필요` + 근거(파일:라인).
   - 🔴 크리티컬(빌드·타입 붕괴·CRITICAL 위반·명백 버그) / 🟡 경고(규칙·경계·테스트 누락) / 🟢 제안.
3. **수정 제안** — 항목별 `파일:라인 — 문제 — 수정 방향`. 실제 수정은 하지 않고 `feature-builder`로 인계.
4. **다음 단계** — 통과 시 커밋(`commit` 스킬)·changeset·PR 안내. 커밋은 타입만·괄호 스코프 금지·`--no-verify` 금지.

## 위임

- 성능/구조 건강성/보안까지 **깊게** 볼 필요가 있으면 Agent 도구로 **`code-reviewer`** 실행.
- 원인 불명 회귀 → `root-cause-debugger` / `systematic-debugging` 스킬.
- 디자인→구현 변경분은 **`design-reconcile` 스킬**로 비주얼 피델리티·DS 정합 검증(내부적으로 DesignSync/`/design-sync`).
- 이 스킬은 판정만 한다(코드 수정 없음).
