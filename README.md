# claude-harness

신규 프로젝트에 까는 **개인 표준 하네스**. `/harness-init` 한 번이면 그 레포가 하네스를 갖춘 상태가 된다.

> 설계 결론은 [docs/design-notes.md](docs/design-notes.md)에 있다. 이 README는 "무엇이 들었고 어떻게 쓰나"만 적는다.

## 설치

```bash
/plugin marketplace add Egonex-AI/Understand-Anything   # 의존 플러그인의 마켓플레이스 — 없으면 harness가 비활성화된다
/plugin marketplace add jtwjs/claude-harness
/plugin install claude-harness@jtwjs-plugins
/plugin install claude-md-management@claude-plugins-official   # 짝 플러그인 — REFLECT의 세션 학습 회수. 없어도 하네스는 돈다
```

설치 후 대상 레포에서:

```
/harness-init
```

## 무엇이 들었나

| 칸 | 성격 | 내용 |
|---|---|---|
| `skills/` | **부르면** 도는 것 | 26개. 하네스 자체 5(`harness-new`·`harness-init`·`harness-doctor`·`task-observer`·`find-skills`) · 지식 파이프라인 3(`brain-walk`·`brain-intake`·`brain-sync`) · SDD 7(`grilling`·`harness`·`harness-run`·`sdd`·`sdd-review`·`design-brief`·`design-reconcile`) · 품질 2(`systematic-debugging`·`ai-readiness-cartography`) · 마무리 3(`commit`·`changeset`·`pr-write`) · 기획 1(`why-logictree`) · 글쓰기 2(`slack-writing`·`notion-writing`, SDD 밖) · 코드 이해 3(`explain-diff-html`·`explain-diff-notion`·`plannotator-visual-explainer`, 외부 원문 그대로) |
| 의존 플러그인 | 같이 **켜지는** 것 | `understand-anything` — 코드베이스 지식 그래프. 스킬 복사로는 안 돌아서(빌드된 플러그인 루트 필요) `dependencies`로 건다 |
| 짝 플러그인 | **있으면** 쓰는 것 | 공식 `claude-md-management` — `/revise-claude-md`(REFLECT 세션 학습 회수) · `claude-md-improver`(2주 audit). CLAUDE.md 품질 감사는 `harness-doctor`가 **일부러 안 하고 여기로 넘긴다.** `dependencies`가 아니라 **없으면 그 칸만 건너뛴다** |
| `agents/` | 일을 **맡기는** 것 | `test-writer` · `feature-builder` · `code-reviewer` · `root-cause-debugger` |
| `hooks/` | **안 불러도** 도는 것 | 위험 명령 차단 · 포맷 · TDD 가드 · 세션 종료 검증(읽기 전용) · **cadence 환기 4축**(함정 freshness · 지식 자본화 · CLAUDE.md 비대 · readiness 채점 공백). 주기는 날짜가 아니라 **커밋 수·줄 수**로 잰다 |
| `templates/` | 플러그인엔 없고 **프로젝트에 남는** 것 | `CLAUDE.md` · `.claude/{harness.json, README.md, rules/, references/}` · `.github/`(CI 워크플로 · PR 템플릿) · `_brain/`(⑤) · `stacks/`(판정된 팩의 rules) · `.gitignore.append` |
| `incubator/` | 지금은 **자는** 것 | 로드 경로 밖. 필요해지면 `mv` 한 번 |

## 워크플로우

```
grilling(스펙 인터뷰 → PRD) → harness(분해) → 🙋 승인 (빈칸이 많으면 grilling 한 번 더)
  → test-writer(RED) → feature-builder(GREEN) → sdd-review → code-reviewer
  → revise-claude-md(세션 학습 회수) → changeset → commit → pr-write → brain-sync → task-observer
```

**RED/GREEN이 핵심이다** — 테스트는 *실패하는 것을 확인해야* 통과이고, 구현은 *테스트 파일을 건드리면* 실패다.

## 컨텍스트 3층

| 층 | 로드 | 길이 |
|---|---|---|
| `CLAUDE.md` | 항상 | 짧게(~40줄) · CRITICAL + 링크만 |
| `.claude/rules/` + `paths:` | 조건부 **자동** | 짧아야 (매칭되면 전량 로드) |
| `.claude/references/` | **수동** (rules의 ⏬ 트리거) | 길어도 됨 (평소 0토큰) |

> 판정 한 줄: **"이걸 안 읽고 코드를 쓰면 규칙을 어기게 되나?"** → 예면 `rules/`, 아니오면 `references/`.
>
> **폴더 경계도 이 3층 안에서 푼다** — 디렉토리별 `CLAUDE.md`를 두지 않고 `rules/`의 `paths:` glob으로 표현한다. 하위 `CLAUDE.md`는 `harness-doctor` 검사 5(상시 로드량·매칭 폭탄)가 **재는 대상이 아니라** 조용히 자란다.

## 출처

직접 만들지 않은 스킬과 그 원본. 원본 라이선스를 따른다.

| 스킬 | 원본 | 라이선스 |
|---|---|---|
| `plannotator-visual-explainer` | [backnotprop/plannotator](https://github.com/backnotprop/plannotator) 원문 그대로 | MIT (스킬 폴더 `LICENSE`) |
| `find-skills` | [obra/superpowers](https://github.com/obra/superpowers)의 `superpowers-codex find-skills` 서브커맨드를 스킬로 옮김 | MIT (원본) |
| `explain-diff-html` · `explain-diff-notion` | Geoffrey Litt의 gist(`a29df1b5f9865506e8952488eac3d524`) 원문 | ⚠️ 원본에 라이선스 표기 없음 — 공개 배포 전 확인 필요 |
| `ai-readiness-cartography` | `jha0313/skills_repo`의 상위 버전을 바탕으로 | ⚠️ 원본 라이선스 미확인 |
| `systematic-debugging` · `grilling` | 전역 `~/.claude/skills/`에 있던 공개 스킬에서 출발(grilling은 원형 `grill-me`, 이후 전면 재작성) | ⚠️ 원본 저장소 미확인 |

그 밖의 스킬·에이전트·훅·템플릿은 이 레포의 MIT 라이선스(`LICENSE`)를 따른다.
