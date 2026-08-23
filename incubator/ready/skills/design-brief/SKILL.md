---
description: SDD DESIGN 단계 — docs/{feature-date}/PRD.md를 읽고 Claude Design(claude.ai/design)에 던질 디자인 브리프(DESIGN-BRIEF.md)를 만든다. 화면 목적·상태(loading/empty/error/edge)·재사용 후보 내부 DS 패키지 컴포넌트·제약을 정리하고, 디자인 생성 후 Claude Design 프로젝트 URL을 기록한다. Use when PRD가 확정되어 디자인을 요청하기 직전.
disable-model-invocation: false
---

PRD를 **디자인 브리프**로 압축해 Claude Design에 넘길 입력을 만든다. 코드는 만지지 않는다(문서 산출 전용).

## 0. 입력

- `docs/{feature-YYYY-MM-DD}/PRD.md`. 없거나 모호하면 **추측 말고 질문**.

## 1. 로드 (이 파일들만)

- 루트 `CLAUDE.md` · 대상 `PRD.md`.
- `.claude/process/design-system-map.md`(재사용 후보 탐색용).
- ⚠️ 그 외 docs 미열람(컨텍스트 절약).

## 2. 산출물 — `docs/{feature-date}/DESIGN-BRIEF.md`

| 섹션              | 내용                                                                                                |
| ----------------- | --------------------------------------------------------------------------------------------------- |
| 화면 목적         | 한 문장 + 대상 사용자·진입 경로                                                                     |
| 화면/뷰포트       | 화면 목록, mobile/desktop 여부                                                                      |
| 상태              | **loading · empty · error · edge**(빈 데이터·긴 텍스트·권한없음) 각각 무엇을 보여줄지               |
| 재사용 후보       | `.claude/process/design-system-map.md`·`내부 DS 패키지`에서 맞을 법한 컴포넌트를 bullet(확정 아님, 힌트용) |
| 제약              | 토큰(색/타이포는 `theme.css` 기준)·a11y·i18n·반응형·성능 제약                                       |
| 비목표            | 이번 디자인에서 다루지 않는 것                                                                      |
| Claude Design URL | **작성 시엔 빈칸.** 사람이 디자인 생성 후 알려주는 프로젝트 링크를 되적는다(자동 아님) — §3         |

## 3. 마무리 (DESIGN 루프: 브리프 → 디자인 생성 → URL 회수)

- **브리프 작성 시 `Claude Design URL` 칸은 비워둔다**(플레이스홀더). 이 시점엔 디자인이 아직 없어 URL도 없다.
- 브리프를 사용자에게 보여주고, **사용자가 직접 claude.ai/design 웹에 붙여넣어 디자인을 생성**하도록 안내한다. ⚠️ **디자인 생성은 웹 UI에서 사람이 하는 단계** — 에이전트/MCP가 브리프로 화면을 뽑아내지 않는다.
- 생성이 끝나면 **사용자가 프로젝트 URL을 알려주고**, 그 값을 브리프의 `Claude Design URL` 칸에 되적는다. ⚠️ **자동으로 붙지 않는다** — claude.ai/design ↔ Claude Code의 MCP(DesignSync) 연결은 디자인 파일 **읽기/푸시**용이지, 이 로컬 브리프에 URL을 심어주는 기능이 아니다.
- 다음: **`design-plan` 스킬**로 진행 — design-plan이 그 URL의 `projectId`로 DesignSync를 호출해 디자인 파일을 읽는다.
