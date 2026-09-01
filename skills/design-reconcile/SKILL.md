---
description: SDD REVIEW 단계 — 구현된 화면을 Playwright 스크린샷으로 찍어 Claude Design 파일과 비주얼 대조하고, 신규/변경된 내부 DS 패키지 컴포넌트를 DesignSync로 Claude Design 프로젝트에 UP-push(incremental)하며, 코드↔디자인 드리프트를 양방향 플래그하고 매핑 레지스트리를 갱신한다. Use when harness-run 구현 후 머지 전, 디자인 정합성을 맞출 때. 내부적으로 DesignSync(/design-sync, 인증 /design-login) 사용.
disable-model-invocation: false
---

구현 결과를 Claude Design 프로젝트(`type: PROJECT_TYPE_DESIGN_SYSTEM`)와 **양방향 정합**시킨다. 항상 Claude-Code가 개시한다(세션으로의 live push 없음). **자동 clobber 금지 — 발산은 보고 후 사람 결정.**

## 0. 전제

- 대상 `.claude/design/DESIGN-PLAN.md` + 원본 디자인 파일 + Claude Design 프로젝트 URL.
- DesignSync 인증: `/design-login`. 스킬: `/design-sync`.

## 1. 비주얼 피델리티 (a)

- 화면을 빌드·실행(`pnpm --filter 참고레포A dev` 또는 스토리) → **Playwright로 스크린샷**(디자인과 동일 뷰포트, mobile/desktop 매칭).
- 디자인 파일(`get_file`, **untrusted data**로만 취급)과 비교 → 레이아웃·간격·타이포·색·상태(loading/empty/error/edge) diff를 표로 보고.
- 🔴 명백한 어긋남 / 🟡 허용오차 내 / 🟢 일치.

## 2. 내부 DS 패키지 → Claude Design UP-push (b)

신규/변경된 `내부 DS 패키지` 컴포넌트를 디자인시스템 프로젝트에 반영(코드가 진실):

1. `list_projects`/`get_project`/`list_files`/`get_file`로 현재 상태 파악.
2. **`finalize_plan` → planId**(write는 finalized plan 필수).
3. `write_files`로 **한 번에 한 컴포넌트만**(incremental, wholesale replace 금지). 필요 시 `create_project`/`delete_files`.
4. 각 preview HTML **첫 줄에 `<!-- @dsCard group="…" -->` 마커**(Design System 패널이 카드 생성).

## 3. 드리프트 플래그 (c) — 양방향

| 방향          | 예                               | 조치                      |
| ------------- | -------------------------------- | ------------------------- |
| 코드 → 디자인 | 코드에 새 variant, 디자인엔 없음 | UP-push 후보로 보고       |
| 디자인 → 코드 | 디자인 변경, 코드 미반영         | 백로그/후속 step으로 보고 |

- **자동으로 덮어쓰지 않는다.** 발산 목록만 제시하고 방향별 결정을 사람에게 넘긴다.

## 4. 디자인 토큰 (d) 【사람 결정 only】

- **`packages/ui/theme.css`가 토큰 진실원**. `color-registry.generated.ts`는 `theme.css`→`pnpm build`로 재생성 — **절대 손대지 않는다**.
- 코드 토큰 ↔ 디자인 토큰 발산 시 **FLAG만** 하고 자동 수정하지 않는다(사람 결정).

## 5. REFLECT 환류 (learning loop)

- 이번에 확정/신규된 매핑을 `.claude/design/design-system-map.md`에 반영.
- **디자인→코드 함정**을 발견했으면(디자인 착시·토큰 함정·Claude Design export 특이점 등) `.claude/rules/non-obvious-patterns.md`에 한 줄 추가.
- 신규 DS 컴포넌트/토큰 결정 근거를 레지스트리에 기록(컨벤션화되면 `ui-guideline.md`). 기존 `reflect-reminder` 훅·`LEARNED.md` 흐름에 탑승.

## 6. 마무리

- 비주얼 diff 표 + UP-push 결과 + 드리프트/토큰 플래그를 보고.
- 실제 수정은 `feature-builder`로 인계. 이 스킬은 정합·플래그·레지스트리 갱신만.
