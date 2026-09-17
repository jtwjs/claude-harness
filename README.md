# claude-harness

신규 프로젝트에 까는 **개인 표준 하네스**. `/harness-init` 한 번이면 그 레포가 하네스를 갖춘 상태가 된다.

> 설계 근거·실측·판정 이력은 [DESIGN.md](DESIGN.md)에 있다. 이 README는 "무엇이 들었고 어떻게 쓰나"만 적는다.

## 설치

```bash
/plugin marketplace add Egonex-AI/Understand-Anything   # 의존 플러그인의 마켓플레이스 — 없으면 harness가 비활성화된다
/plugin marketplace add jtwjs/claude-harness
/plugin install claude-harness@jtwjs-plugins
```

설치 후 대상 레포에서:

```
/harness-init
```

## 무엇이 들었나

| 칸 | 성격 | 내용 |
|---|---|---|
| `skills/` | **부르면** 도는 것 | 하네스 자체(`harness-init`·`harness-doctor`·`task-observer`) · 지식 파이프라인(`brain-intake`·`brain-sync`) · SDD 4종 · 품질 3종 · 마무리 3종 · 글쓰기 2종(`slack-writing`·`notion-writing`, SDD 밖) · 코드 이해 3종(`explain-diff-html`·`explain-diff-notion`·`plannotator-visual-explainer`, 외부 원문 그대로) |
| 의존 플러그인 | 같이 **켜지는** 것 | `understand-anything` — 코드베이스 지식 그래프. 스킬 복사로는 안 돌아서(빌드된 플러그인 루트 필요) `dependencies`로 건다 |
| `agents/` | 일을 **맡기는** 것 | `test-writer` · `feature-builder` · `code-reviewer` · `root-cause-debugger` |
| `hooks/` | **안 불러도** 도는 것 | 위험 명령 차단 · 포맷 · TDD 가드 · 세션 종료 검증(읽기 전용) |
| `templates/` | 플러그인엔 없고 **프로젝트에 남는** 것 | `CLAUDE.md` · `.claude/{harness.json, rules/, references/}` · CI |
| `incubator/` | 지금은 **자는** 것 | 로드 경로 밖. 필요해지면 `mv` 한 번 |

## 워크플로우

```
why-logictree(스펙) → harness(분해) → grilling(빈칸) → 🙋 승인
  → test-writer(RED) → feature-builder(GREEN) → sdd-review → code-reviewer
  → changeset → commit → pr-write → brain-sync → task-observer
```

**RED/GREEN이 핵심이다** — 테스트는 *실패하는 것을 확인해야* 통과이고, 구현은 *테스트 파일을 건드리면* 실패다.

## 컨텍스트 3층

| 층 | 로드 | 길이 |
|---|---|---|
| `CLAUDE.md` | 항상 | 짧게(~40줄) · CRITICAL + 링크만 |
| `.claude/rules/` + `paths:` | 조건부 **자동** | 짧아야 (매칭되면 전량 로드) |
| `.claude/references/` | **수동** (rules의 ⏬ 트리거) | 길어도 됨 (평소 0토큰) |

> 판정 한 줄: **"이걸 안 읽고 코드를 쓰면 규칙을 어기게 되나?"** → 예면 `rules/`, 아니오면 `references/`.

## 두 계정 미러

`jtwjs`(개인·정본) / `jtw-219`(회사·미러). 로컬 1개에 push remote 2개를 붙여 한 번에 양쪽으로 보낸다.

🔴 **개인 계정 repo이므로 회사 고유 정보(org명·내부 도메인·서비스명·사내 규칙)는 한 줄도 들어가지 않는다.**
