# `claude-harness` — 설계 문서

> 상태: **v0.1 설계 확정 (2026-08-23).** 아직 구현 전. 진행 순서는 §9.
> 이 문서는 3차 서브에이전트 리뷰(구조·비대 / 페르소나 / 로스터)를 반영한 최종본이다.

## Context

**목표**: 신규 프로젝트마다 까는 나만의 하네스를 private GitHub repo로 만들고 `/plugin install` 한 줄로 배포. 최종 독자는 나 혼자(개인 표준).

**핵심 목적 하나 더**: 프로젝트 안에 갇히는 지식을 **통합 wiki(이 vault)로 모은다.** `brain-intake`(raw→`_brain/wiki/`)와 `brain-sync`(`_brain/wiki/`→통합 wiki)는 한 파이프라인의 앞뒤이고, 하네스가 깔릴수록 사일로가 아니라 축적이 되게 한다.

**참고 소스 4곳** — ① `wiki/concepts/ai/`(35편)·`ai-design/`(10편)·`system/skills/ai-harness/`(7편) ② `참고레포A`(하네스를 적용한 주 프로젝트, 자체 채점 95/100) ③ 전역 `~/.claude/` ④ `jha0313/skills_repo`(cartography 상위 버전)

**예약돼 있던 다음 단계다** — `참고레포A/.claude/process/portable-assets.md:46`: *"이식이 2~3회 반복되면 → 공유 plugin 추출(별도 marketplace repo + plugin.json)을 검토."*

### ✅ 착수 전 확인 — 완료 (2026-08-23)

`gh auth login`으로 `jtwjs`·`jtw-219` 두 계정 등록 완료. **`jtwjs/personal_wiki` = private 확인.**
→ `brain-sync`가 사내 도메인 지식(`glossary`·`domain`·`decisions`·`voc`)을 그대로 이관하는 §5 설계를 **재설계 없이 유지**한다.

---

## 1. 참고레포A에서 가져오는 설계 판단

| # | 참고할 것 | 왜 |
|---|---|---|
| 1 | SDD 5단계 오케스트레이터 | 사람이 단계를 기억할 필요가 없음 |
| 2 | `harness` ↔ `harness-run` 분리 | 계획/실행 분리가 아니라 **컨텍스트 격리 장치**. `harness-run:38` **"판정 = index.json 재읽기(서브에이전트 stdout 아님)"** — 메인이 서브의 자기보고를 안 믿고 파일을 다시 읽는다 |
| 3 | `systematic-debugging` ↔ `root-cause-debugger` | **유일하게 올바른 스킬↔에이전트 쌍** — `:12` "여기서는 내용을 복제하지 않는다"고 선언하고 실제로 안 함. 다른 둘이 따라야 할 모범 |
| 4 | 훅 3계층 + **정책 데이터 분리** (`deny-patterns.yaml:11`) | 확대 적용할 모범 |
| 5 | `non-obvious-patterns.md`(102KB·커밋 47회·8-20까지 갱신) | **진짜 자산은 여기.** 혼자 잘 살아 있음 |
| 6 | `_brain/` + `brain-intake` | Karpathy LLM Wiki(ingest/query/lint) 구현 |
| 7 | `portable-assets.md` | 이 작업의 직전 단계 |
| 8 | 2번째 레포 실사용 → **3번째부터** BACKLOG 승격 | 3번의 법칙 |

> `docs-app` 관련 4스킬 + `guide-reviewer` **전부 제외**.

### 반면교사 (전부 실측)
- **문서 중복 통제 불능** — SDD 단계표 **5벌**, 체크포인트 4벌, 훅 목록 4벌. 그중 `README.md:34`·`workflow.md:42`는 **같은 오류로 두 벌**(Stop 훅을 "lint&&build&&test"라 설명, 실제는 format→lint --fix→typecheck)
- 같은 레포에서 **에이전트 개수가 4 vs 3**(`CLAUDE.md:96` ↔ `README.md:32`)
- **에이전트에 규칙 인라인** — FSD 금지 **6벌**, 훅 순서 4벌. `.claude/rules` 참조는 feature-builder **0회**
- **훅 ∩ CI 3중복**, 훅 쪽 2개는 쓰기 명령
- 🔴 **테스트를 실행하는 주체가 없다** — `feature-builder:47` 자체점검(`typecheck→format→lint --fix`)·CI matrix·Stop 훅 **전부 test 없음**. 그런데 `feature-builder:33`은 "테스트 선행이 hook hard-block". **안 쓰면 저장이 막히는데 쓴 것을 돌리는 사람이 없다**
- 🔴 **`.claude/rules/` 7개가 frontmatter 0건 = 매 세션 전량 로드.** 합 **160,741 bytes ≈ 40,000토큰**(`non-obvious-patterns.md` 하나가 102,928로 64%). CLAUDE.md가 `📖 [링크]`로 progressive disclosure를 하고 있다고 믿었지만 **이미 전부 로드돼 있어 헛수고**였다. `@_brain/wiki/` 15,000토큰 누수의 **2.7배** (§3-1)
- 죽은 자산 — 고아 `agent-memory/` **5개**(3개는 86일간 파일 0), 참조 0건 `.claude/workflows/review-code.js`

> 🔴 **별건**: `.npmrc`가 git 추적 + Tiptap Pro 토큰 평문. 로테이션 + untrack 권장.

### `_brain/` = Karpathy LLM Wiki — 확인 완료
`second-brain.md:31`(Forte PKM → **Karpathy LLM Wiki 2026-04이 전환점**) → `:44-50`(3-Layer) → `:66-76`(팀 `_brain/`) → 실제 구현이 `참고레포A/_brain/CLAUDE.md`("Second Brain (**LLM Wiki** + Obsidian)"). 결정적 증거는 **3-operation** — "ingest·query·lint 세 동작으로 자라는 살아있는 아티팩트". 이 vault의 `/ingest`·`/query`·`/lint`와 같은 뿌리.

---

## 2. 서브에이전트 리뷰 4건으로 바로잡은 것

### 2-A. 구조·비대 리뷰

| # | 지적 | 조치 |
|---|---|---|
| 1 | 🔴 **`@_brain/wiki/` = 33파일 72,371B ≈ 15,000토큰 매 세션** (설계에 숫자 없었음) | `@_brain/wiki/index.md` **1파일만** import. **−14,000토큰**. `brain-sync`가 배출구라 계속 가벼움 |
| 2 | 🔴 **E1 자기위반** — `/update-claudemd`가 템플릿 예정 파일 6곳에서 호출되는데 제외 목록 | 고유 검사를 `harness-doctor`로 흡수 + **참조 6곳 제거** |
| 3 | 🔴 **`claude-md-improver` fork 취소** — 745줄 fork해 3항목 더하고 업스트림 영구 포기 | 공식 **그대로 유지**. 고유 검사는 `harness-doctor`(~30줄) |
| 4 | 🔴 `weekly-readiness-check.sh:18`이 `.claude/skills/…/score.py` **레포 상대경로** 하드코딩 → 스캐폴드 레포에선 항상 exit 0 | `${CLAUDE_PLUGIN_ROOT}` 기준 |
| 5 | 🔴 `incubator/spec/` 6장이 `BACKLOG.md`와 중복 | spec 삭제 → BACKLOG 6줄 |
| 6 | 🔴 evals 5케이스 — 01·02·05는 **기계 판정 불가라 게이트가 못 됨** | `hooks/test.sh` 2케이스 |
| 7 | 🔴 SDD 단계표 5중 중복 | 정본은 `sdd/SKILL.md`. 프로젝트엔 `process/workflow.md` **안 심음** |
| 8 | 2번째 레포 실사용 → **3번째부터** BACKLOG 승격 | 3번의 법칙 |
| 9 | 🟡 `why-logictree`는 코딩 하네스 무관 + 이미 2벌 | ~~플러그인 제외~~ → **2026-08-23 뒤집음.** 코어 트랙의 DESIGN이 비어 있어(PRD를 만드는 주체 부재) 무관하지 않다 → **DESIGN 게이트로 배선** (§8-d) |
| 10 | 🟡 `CODEBASE_MAP.md`·`docs/adr/000-template.md` 실물 0. ADR은 `docs/{feature-date}/ADR.md`로 **7개 실제 축적** | **작동하는 관행을 따름**(§4) |
| 11 | 🟡 nested CLAUDE.md 충돌(`feature-cohesion.md §5.1`) | `.claude/rules/` **`paths:` frontmatter** 1순위(§3-1·§4). ⚠️ 2026-08-23 키 이름 정정 — `globs:`는 Cursor `.mdc` 것이고 Claude Code는 **`paths:`** 다 |
| 12 | 🟡 `typescript.md` 깨진 문장 2곳·`functional-programming.md` 37%가 lodash 전용 | 수정·삭감 후 이식 |
| 13 | 사실 정정 | 고아 `agent-memory/` 6 → **5** |
| 14 | 🟡 Stop 훅 `lint --fix`도 쓰기 명령 | 읽기 전용 `lint` |

### 2-B. 에이전트 리뷰 (페르소나 + 로스터)

| # | 지적 | 조치 |
|---|---|---|
| 15 | 🔴 **테스트 실행 주체 부재** — 4곳 전부 없음(위 반면교사). Stop 훅만 고치면 절반 | **(2026-08-23 강화)** `feature-builder` 자체 점검을 1차 게이트로 두는 것에 더해, **RED/GREEN 2단 step**(§8-e)으로 *테스트가 실패하는 것*까지 확인해야 넘어가게 했다. 테스트 396개가 있는데 돌리는 주체가 없던 것이 원인이므로, 실행 자체를 step 통과 조건으로 올린다 |
| 16 | 🔴 **`memory:` 프론트매터 제거** — `.gitignore:52,55` + 추적 0건 = `team.md:63` 기준 **"자산이 아니라 dotfiles"**. stray `.claude/` 2곳 실측(`docs-app/`, `apps/<app>/src/`). 지식 종착지 3중화 | 3개 에이전트의 `## 에이전트 메모리` 절 **삭제(−1,100자)**. 종착지를 `non-obvious-patterns.md` **하나로** |
| 17 | 🔴 **`model:` 유지로 되돌림** (내가 "상속" 제안했던 것) | 세션이 Sonnet이면 **Evaluator가 Generator보다 약해져 리뷰가 통과 도장**이 된다. `claude-code-best-practices.md:71`·`harness-engineering.md:71`("검토 Opus, 작성 Sonnet")대로 **sonnet/opus/opus 유지** |
| 18 | 🔴 **`<example>` 삭제만 하면 트리거가 죽는다** — 남는 첫 문장이 SDD 용어뿐이고, feature-builder는 하드코딩 제거까지 겹쳐 "프로젝트 컨벤션을 따라 코드를 씁니다"만 남음 | **description 전면 재작성**(§7) |
| 19 | 🔴 **hallucinated skill 4건** — `sdd/SKILL.md`가 `changeset`·`commit`·`pr-write`·`design-reconcile` 참조하는데 스킬 목록에 없었음. **E1 자기위반 재발** | 앞 셋은 **이식**(skills 11→14), `design-reconcile` 참조는 §9 삭감표에 추가 |
| 20 | 🔴 **`memory-reminder.sh:5`가 참고레포A 절대경로 하드코딩** → 새 레포마다 첫날부터 오탐. `autonomous-pr-reviewer.md:62` "오탐 1건 = 신뢰 10건 손실" | 병합 시 수정 |
| 21 | 🔴 **`grilling` 배선 0건** + 유일한 호출자(`grill-me`)를 내가 폐기 | **PLAN 🙋 승인 앞 게이트로 배선**(`technic.md:162`가 자리를 지목). 발화 조건 필요 |
| 22 | 🟡 **"인계한다"가 3개 전부** → 서브가 서브를 띄우는 오해(`claude-code-subagents.md:86` 중첩 비효율) | **"인계 대상을 보고에 적는다(호출은 메인)"** |
| 23 | 🟡 **`sdd-review`↔`code-reviewer` 계약이 수신 측에만** — `code-reviewer:17`이 "결과를 입력으로 받아"라는데 `sdd-review:39`엔 넘기라는 말이 없음 → 실제론 빈손으로 시작해 4축 재검사 | **escalate 3줄 + 규칙 5줄**(§8) |
| 24 | 🟡 **harness-run 복귀 경로 없음** — debugger가 원인을 찾은 뒤 `error → pending` 되돌릴 주체 부재 | 1줄 추가(§8) |
| 25 | 🟡 `feature-builder:47` ↔ `harness-run:50` 커밋 전 검증 **2벌** | 메인 1회로 통일 |
| 26 | 🟡 **`✓ Good` 부재 + 적대적 프레이밍 부재 + 등급 재조정 절차 부재** | §7 문안 |
| 27 | 🟡 BACKLOG 승격 조건이 **관측 불가** ("놓친 사례 3건"을 누가 세나) | **"리뷰 통과 후 `fix:` 커밋 3건"** — `git log --grep='^fix:'`로 셈 |
| 28 | 🟡 템플릿 CLAUDE.md가 "에이전트 4"를 물려받으면 안 됨 | **개수를 아예 안 적는다.** 라우팅은 `.claude/README.md` 한 곳만 |

**리뷰가 "유지"로 판정한 것**: `harness`↔`harness-run`(컨텍스트 격리) · `systematic-debugging`↔`root-cause-debugger`(모범) · `brain-intake`↔`brain-sync` · `sdd-review`↔`code-reviewer`(**입력 집합이 다름** — 전자는 `docs/{feature}/ARCHITECTURE·ADR`, 후자는 `.claude/rules/`) · 에이전트 3개 유지 → **2026-08-23에 4개로 늘어남**(아래).

**리뷰 전제가 틀렸던 것 1건**: `brain-sync`를 "대상 1개"로 제외 권고했으나, **이 하네스의 목적이 모든 신규 프로젝트에 `_brain/`을 까는 것**이므로 대상은 harness-init을 돌리는 모든 레포다. 없으면 하네스가 깔릴수록 사일로가 늘어난다. **유지.**

**빠진 에이전트 → 없음** *(2026-08-23 정정: 1건 있었다)*. 서브에이전트를 두는 정당한 사유는 셋뿐이고(**컨텍스트 격리 / 편향 격리 / 탐색 격리**) 로스터가 1:1로 채운다고 판정했다. 후보 5개(스펙 인터뷰어·**테스트 전용**·brain-intake 에이전트화·마이그레이션·진단)를 전부 기각했다.

### 🔄 2026-08-23 뒤집힌 판정 2건

| 기각했던 것 | 왜 뒤집나 |
|---|---|
| **테스트 전용 에이전트** | 기각 근거가 *"편향 격리는 code-reviewer가 이미 채운다"* 였는데, **편향 격리에는 방향이 둘 있다.** code-reviewer는 *이미 만든 것을 안 봤어야* 하고(사후), test-writer는 *아직 만들 것을 몰라야* 한다(사전). 사후 격리는 사전 격리를 대신하지 못한다 — 구현을 본 뒤에 쓰는 테스트는 그 구현이 통과하도록 케이스가 굽는다. **네 번째 사유는 있었고, 내가 3개를 세면서 사후 하나만 셌다** |
| **스펙 인터뷰어** | 기각 근거(*"인터뷰는 사람과 왕복인데 서브는 사용자와 직접 대화 불가"*)는 **지금도 맞다.** 그래서 여전히 에이전트로 만들지 않는다 — 대신 **메인 세션에서 도는 스킬**(`why-logictree`)로 그 자리를 채운다(§8-d). 판정이 아니라 형식이 틀렸던 것 |

**결과: 에이전트 4개 / 사유 4개.** 다섯 번째 사유가 없으므로 다섯 번째 에이전트도 없다.

---

## 3. 최종 구조

**두 계정 모두에 private repo 생성** — `jtwjs/claude-harness`(개인) · `jtw-219/claude-harness`(회사).
`plugin.json` + `marketplace.json` 자체 마켓플레이스. 버저닝 **Latest**(main 추적).

**운영 규칙 — 로컬 1개, remote 2개(미러)**
```bash
git remote add origin git@github.com:jtwjs/claude-harness.git
git remote set-url --add --push origin git@github.com:jtwjs/claude-harness.git
git remote set-url --add --push origin git@github.com:jtw-219/claude-harness.git
# git push 한 번에 두 곳으로
```
- **upstream 정본은 `jtwjs`(개인)** — pull은 항상 여기서. `jtw-219`는 회사 머신 설치용 미러이고 여기서 pull하지 않는다(양쪽에서 편집하면 갈라진다)
- 설치는 머신에 맞는 쪽으로: 개인 `/plugin marketplace add jtwjs/claude-harness` · 회사 `… jtw-219/claude-harness`

> 🔴 **두 계정에 두는 것의 대가 — 일반화가 "품질 요구"에서 "보안 요구"로 격상된다.**
> 개인 계정 repo에 회사 고유 정보(org명 `<org>`·내부 도메인·서비스명·사내 규칙)가 한 줄이라도 들어가면 그건 사내 정보를 개인 계정으로 옮긴 것이 된다.
> §9 3단계의 완료 판정에 **회사 org명·레포명·내부 패키지명·내부 도메인 grep 0건**을 추가한다. (검색할 실제 문자열은 이 문서에 적지 않는다 — 적는 순간 그 자체가 위반이다.)

```
claude-harness/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/                          ← 15개
│   ├── harness-init/                ⭐ 본체 (§4)
│   ├── harness-doctor/              ⭐ ~30줄, fork 대체 (§6)
│   ├── brain-intake/  brain-sync/   ⭐ 지식 파이프라인 (§5)
│   ├── ai-readiness-cartography/    GitHub판(score.py 34KB + template.html 43KB)
│   ├── why-logictree/               ← DESIGN 게이트 (§8-d, 제외 판단 뒤집음)
│   ├── slack-writing/  notion-writing/  ← 공유 글쓰기 (SDD 밖, 2026-09-02)
│   ├── grilling/                    ← PLAN 게이트로 배선
│   ├── systematic-debugging/
│   ├── sdd/  harness/  harness-run/  sdd-review/
│   └── changeset/  commit/  pr-write/    ← REFLECT
├── agents/{test-writer, feature-builder, code-reviewer, root-cause-debugger}.md  ← 4개 (§7)
├── hooks/
│   ├── hooks.json                   ${CLAUDE_PLUGIN_ROOT} 배선
│   ├── block-dangerous-bash.sh      ← 유일하게 항상 동작
│   ├── deny-patterns.yaml           6규칙
│   ├── auto-format.sh  loop-lock.sh  todo-warn.sh  tdd-guard.sh
│   ├── validate-session-end.sh      format:check → lint → typecheck → test (전부 읽기전용)
│   ├── cadence-reminder.sh          ← reflect + memory 병합, 하드코딩 경로 제거
│   ├── weekly-readiness-check.sh    ← score.py 경로 수정
│   └── test.sh                      ← 훅 exit code 2케이스
├── templates/                       ← 기본 6 + `references/` 배출구 + 조건부
│   ├── CLAUDE.md.tmpl               (에이전트 개수 안 적음)
│   ├── .claude/{harness.json, README.md(라우팅 10줄)}
│   ├── .claude/rules/{non-obvious-patterns.md, testing.md}  ← `paths:` 필수 (§3-1)
│   ├── .claude/references/implementation-patterns.md  ← 구현 패턴 6개 (§3-1)
│   ├── .github/{PULL_REQUEST_TEMPLATE.md, workflows/ci.yml(15줄)}
│   ├── [TS면] .claude/rules/{typescript, functional-programming}.md
│   └── [승인시] _brain/{CLAUDE.md, raw/.gitkeep, wiki/{index,log,overview}.md}
├── incubator/ready/skills/design-{brief,plan,reconcile}/   ← 로드 안 됨
└── BACKLOG.md  DESIGN.md  README.md
```

**제외 확정**: `claude-md-improver` fork · `commands/` · `memory-reminder.sh`(병합) · `.claude/process/workflow.md` · `docs/CODEBASE_MAP.md` · `docs/adr/000-template.md` · `.github/ISSUE_TEMPLATE/` · `incubator/spec/` · `evals/` 5케이스
**🔴 절대 금지**: `~/.claude/settings.json`의 `autoMode.environment`(GitHub org `<org>`·private repo명·S3 버킷·프로덕션 도메인·AWS 시크릿 이름 평문) · `.credentials.json` · Slack webhook · MCP `env` · orca 훅 · `afplay` 훅 · 절대경로 `additionalDirectories`

### 3-1. 컨텍스트 3층 — 🔴 실측으로 전제가 바뀐 곳

**Claude Code 2.1.241 번들 실측** (문자열 직접 확인):

> *"`.claude/rules/`… **These are loaded automatically alongside CLAUDE.md** and can be scoped to specific file paths using **`paths` frontmatter**."*
>
> `InstructionsLoaded` 훅 정의 — *"`load_reason` (**session_start**, nested_traversal, **path_glob_match**, include, compact), globs (optional — **the `paths:` frontmatter patterns that matched**)"*

#### 3층 (정본: [[system/skills/ai-harness/technic|technic.md]]:310 *"넘치면 주제별로 쪼개 조건부 로드, **그래도 남으면** 길만 알려준다"*)

| 층 | 로드 | 길이 | 담는 것 |
|---|---|---|---|
| **CLAUDE.md** | 항상 | **짧게** | CRITICAL + **링크만** (긴 내용 금지) |
| **`.claude/rules/` + `paths:`** | 조건부 **자동** | **짧아야** | 그 경로를 만질 때 **반드시 지킬 규범** |
| **`.claude/references/`** | **수동 `Read`** | **길어도 됨** | 배경·전체 설명·긴 표·이력 |

**가르는 축은 "조건부냐"가 아니라 "길이냐"다.** `paths:`가 붙어도 **매칭되면 그 파일은 통째로** 들어온다 — 부분 로드는 없다. 긴 문서를 `rules/`에 두면 **조건부일 뿐 폭탄은 그대로**다(`**/auth/**` 파일 하나만 건드려도 27KB 전량).

**`references/`가 자동 로드되지 않는 것은 결함이 아니라 존재 이유다** — 평소 비용이 **0토큰**이라 길이 제약이 사라진다. Claude Code 번들에 문자열이 0건인 것은 *"인식하지 않는다"* 가 맞고, **그게 정확히 이 층에 필요한 성질**이다.

> 판정 한 줄: **"이걸 안 읽고 코드를 쓰면 규칙을 어기게 되나?"** → 예면 `rules/`(짧게 줄여서), 아니오면 `references/`. **어겨선 안 되는데 길면 → 판정 규칙만 `rules/`, 설명은 `references/`로 쪼갠다.**

#### 실측 — 지금은 3층이 아니라 1층이다

**참고레포A의 rules 7개 전부 frontmatter 0건 → 160,741 bytes ≈ 40,000토큰이 매 세션 전량 로드.**

| 파일 | bytes | 3층 배치 |
|---|---|---|
| `non-obvious-patterns.md` | **102,928** (64%) | **분할** — 한 줄 규칙만 `rules/`(상시), 상세·재현은 `references/` |
| `fsd-architecture.md` | 27,363 | **`references/`** + 경계 판정 몇 줄만 `rules/` |
| `testing.md` | 9,045 | **분할** — §0 대상 기준(판정)은 `rules/`, §3~5 도구·디렉토리 관례는 `references/` |
| `feature-cohesion.md` | 9,015 | `references/` + 판정 `rules/` |
| `ui-guideline.md` | 7,346 | `references/` |
| `functional-programming.md` · `typescript.md` | 2,825 · 2,219 | `rules/` + `paths:` (짧아서 그대로) |

⚠️ **키 이름은 `paths:`다.** `globs:`·`alwaysApply:`는 **Cursor `.mdc`** 것이라 Claude Code에서 아무 일도 하지 않는다(번들의 그 문자열들은 Bun이 넣어둔 `.cursor/rules/*.mdc` 템플릿에서 나온 것). Cursor에서 이식하면 **조용히 죽는다** — `feature-cohesion.md:4`의 링크 텍스트가 아직 `[004-project-arhitecture.mdc]`인 것이 흔적이다.

**그래서 CLAUDE.md의 `📖 [fsd-architecture.md](…)` 링크는 헛수고였다.** progressive disclosure를 한다고 믿었지만 대상이 **이미 전부 컨텍스트에 있었다.** 절약한 토큰은 0이다. *쪼개기와 스코핑은 다른 일이고, 조건부는 **빈도**를 줄이지 **크기**를 줄이지 않는다.*

#### 🔑 `rules` → `references` 트리거 — 3층이 실제로 작동하게 만드는 배선

**`references/`의 유일한 실패 모드는 "안 읽히는 것"이다.** 자동 로드가 안 되므로 에이전트가 열지 않으면 없는 것과 같다. [[claude-md-operations]]:155가 이미 경고한다 — *"길 안내만 남기면 안 읽힐 위험이 실재한다… 안 열면 '~할 때'라는 **상황 조건을 더 또렷하게** 쓴다."*

그래서 **트리거를 `rules/`에 박는다.** rules는 자동 로드되므로 그 지시가 **항상 컨텍스트에 있다.**

```markdown
<!-- .claude/rules/functional-programming.md (자동 로드, 짧게) -->
---
paths: ["src/**/*.ts", "src/**/*.tsx"]
---
## 판정 (6개, 각 1줄)
…

## ⏬ 아래 중 하나에 걸리면 `.claude/references/implementation-patterns.md`를 **읽고 시작한다**
- 액션과 계산이 한 함수에 섞여 있다
- 중첩 데이터를 수정해야 한다
- 목(mock)이 2개 이상 필요해 보인다
- 도메인 규칙과 인덱스·반복문이 같은 함수에 있다
```

| | rules에 두는 것 | references에 두는 것 |
|---|---|---|
| 성격 | **판정** — 위반인지 아닌지 | **변환** — 그래서 어떻게 고치나 |
| 길이 | 1줄 | Before/After 코드 포함 |
| 예 | *"액션을 부르는 함수는 액션이 된다"* | *"함수형 코어 + 가변 쉘로 가르는 절차 5줄 + 예시"* |

**판정은 항상 보이고, 변환은 걸렸을 때만 연다.** 이게 "길만 알려준다"의 실전 형태다.

#### `references/implementation-patterns.md` — 구현 패턴 카탈로그

`feature-builder`가 **코드를 쓰기 전에 여는** 문서. 형식은 §7의 *예시→절차 승격*과 같다 — 각 패턴이 **증상(언제) → 변환(Before/After) → 검증(어떻게 확인)** 3단.

| # | 패턴 | 증상(트리거) |
|---|---|---|
| 1 | **함수형 코어 + 가변 쉘** | 테스트에 목이 2개 이상 필요해 보인다 |
| 2 | **암묵적 입력 승격** | 함수 안에서 전역·설정·`new Date()`를 읽는다 |
| 3 | **암묵적 출력 격리** | 함수가 로깅·저장·이벤트 발행을 한다 |
| 4 | **카피-온-라이트** | 중첩 데이터를 수정해야 한다 |
| 5 | **추상화 수준 정렬** | 도메인 규칙과 인덱스·반복문이 한 함수에 |
| 6 | **실패를 값으로** | `try/catch`가 실행 흐름을 바꾼다 |

**6개로 시작하고 늘리지 않는다.** 늘릴 때는 `BACKLOG.md` 승격 조건을 통과해야 한다(§11).

⚠️ **고아 references 금지** — `references/`의 모든 파일은 `rules/` 또는 `CLAUDE.md`에 **트리거가 걸려 있어야** 한다. 트리거 없는 references는 **죽은 문서**이고, `harness-doctor` 검사 2가 잡는다.

#### 하네스가 심는 것
```
.claude/
├── rules/                        ← 짧게. paths: 필수 (예외 1개)
│   ├── non-obvious-patterns.md   상시(paths 없음) — 함정은 *어느 파일을 만질지 알기 전에* 필요
│   ├── testing.md                paths: 테스트 경로 — 판정 기준만
│   └── [TS면] typescript.md · functional-programming.md   paths:
└── references/                   ← 자동 로드 안 됨. rules의 ⏬ 트리거로만 열린다
    └── implementation-patterns.md  구현 패턴 6개 (증상→변환→검증)
```
`.claude/README.md`(라우팅) 한 줄에 **"references/는 자동 로드되지 않는다 — 링크로만 연다"** 를 적는다. 새 파일을 더 만들지 않는다.

### 3-3. 🔴 자기위반 1건 — 설계 문서 자신이 규칙을 어겼다

§3의 경고는 *"개인 계정 repo에 회사 고유 정보가 한 줄이라도 들어가면 사내 정보를 개인 계정으로 옮긴 것"* 이었다. **그런데 이 DESIGN.md 자신에 회사 org명·레포명·내부 패키지명이 45건 있었고, 1단계에서 그대로 push됐다.**

- 발견 시점: 3단계 완료 판정을 돌리다가. **완료 판정이 자기 문서를 검사 대상에서 빼고 있었다**
- 조치: 전부 익명화(`참고레포A`·`<org>`·`내부 DS 패키지`). **실측 수치와 판정 근거는 그대로 살아 있다** — 설계 문서의 값은 레포 이름이 아니라 *"40,000토큰"·"396개"·"102,928 bytes"* 쪽이다
- 규칙 보강: **완료 판정의 검사 범위에 문서 자신을 포함한다.** `.git` 외 전부다

> **일반화가 코드에만 적용되고 문서에는 적용되지 않는다고 믿은 것이 원인**이다. E1(hallucinated path)이 *"문서에 적힌 경로가 실재하는가"* 를 코드와 문서 양쪽에 물었던 것과 같은 실수를 반대편에서 했다.
>
> ⚠️ **남은 것: git 히스토리.** 1·2단계 커밋에 원문이 남아 있다. private repo라 긴급하지는 않지만, 지우려면 history rewrite가 필요하다 — **사용자 판단 사항.**

### 3-2. 프로젝트에 심어지는 실물 — `CLAUDE.md` · `rules/` · `references/`

> ⚠️ **플러그인 repo 구조(§3)와 다르다.** skills 15 · agents 4 · hooks는 **플러그인에 남고 프로젝트로 복사되지 않는다**(`${CLAUDE_PLUGIN_ROOT}`에서 동작). 프로젝트에 생기는 것은 아래뿐이다 — 이것이 `team.md:69` 판정 ①*"한 패키지인가"*를 지키는 방식이다.

```
<프로젝트>/
├── CLAUDE.md                         ⭐ ~40줄. CRITICAL + 링크만
├── .claude/
│   ├── harness.json                  ⭐ 스위치·정본 (§3)
│   ├── README.md                     라우팅 ~10줄 (어떤 상황에 무엇을)
│   ├── rules/                        ← 자동 로드 (paths: 로 스코핑)
│   │   ├── non-obvious-patterns.md     상시 · 빈 파일로 시작
│   │   ├── testing.md                  paths: 테스트+소스 · 판정만
│   │   ├── typescript.md              [TS면] paths: **/*.ts(x)
│   │   └── functional-programming.md  [TS면] paths: src/**/*.ts(x)
│   └── references/                   ← 수동 · rules의 ⏬ 트리거로만 열림
│       └── implementation-patterns.md  구현 패턴 6개
├── docs/{feature-YYYY-MM-DD}/        DESIGN 산출물 (PRD·ARCHITECTURE·ADR)
├── phases/{task}/                    PLAN 산출물 (index.json + stepN.md)
├── .github/{PULL_REQUEST_TEMPLATE.md, workflows/ci.yml}
└── [승인 시] _brain/{CLAUDE.md, raw/, wiki/}
```

#### `CLAUDE.md` 템플릿 (~40줄)

```markdown
# <프로젝트명>
<서비스 한 줄>                                    ← 인터뷰 ③

## 🔴 CRITICAL — 어기면 사고
- <인터뷰 ① 금기들>                                ← 사람만 아는 것
- **테스트 선행**: 구현 파일에 짝 테스트가 없으면 tdd-guard가 차단한다.
  무엇을 테스트/안 하는지는 → `.claude/rules/testing.md` §0
- 자동 생성물(<경로>)은 직접 수정하지 않는다 — 재생성으로만

## 검증
<verify 명령 나열>
> 정본은 `.claude/harness.json`. 여기와 어긋나면 `harness-doctor` 검사 1이 잡는다.

## 구조
<진입점·의존 방향 — 진단으로 자동 생성 (4-b)>

## 결정 기록
아키텍처 결정은 `docs/{feature-YYYY-MM-DD}/ADR.md`

## 규칙·참고
`.claude/rules/`(자동) · `.claude/references/`(⏬ 트리거로 열림) · 라우팅은 `.claude/README.md`
```

**여기 없는 것이 설계다**: 에이전트 개수(2-A #28) · SDD 단계표(정본은 `sdd/SKILL.md`) · 훅 목록 · FSD/스택 상세 규칙 · 긴 설명. **CLAUDE.md는 링크판이지 내용판이 아니다.**

> 🔴 **검증 명령만은 예외로 CLAUDE.md에 적는다.** 사람도 봐야 하기 때문이다. 대신 정본을 `harness.json`으로 못박고 **doctor 검사 1이 drift를 잡는다** — 검사 1의 존재 이유가 정확히 이 중복이다.

#### `rules/` 4개 — 전부 "판정"만, 각 1줄

| 파일 | `paths:` | 담는 것 | 왜 이 스코프 |
|---|---|---|---|
| `non-obvious-patterns.md` | **없음(상시)** | 사고를 낸 비명백 규칙 한 줄씩 | 함정은 *어느 파일을 만질지 알기 전에* 필요 |
| `testing.md` | `**/*.test.*`, `**/*.spec.*`, `src/**` | §0 **테스트 대상 기준**(무엇을 테스트/안 함) + BDD 3계층 | tdd-guard 면제 목록과 **같은 표**를 봐야 한다 |
| `typescript.md` | `**/*.ts`, `**/*.tsx` | `type` vs `interface`, `any` 금지 | TS 파일 전반 |
| `functional-programming.md` | `src/**/*.ts(x)` | FP 판정 6개 + **⏬ 트리거 4개** (§3-1) | 설정·스크립트는 제외 |

> **paths를 넓게 잡아도 되는 조건은 "짧다"이다.** `testing.md`가 `src/**`까지 걸어도 안전한 이유는 판정만 남겨 1~2KB이기 때문이다. 길어지는 순간 그 스코프가 폭탄이 된다 — 그때 `references/`로 내린다(doctor 검사 5).

#### `references/` — 지금은 1개

| 파일 | 열리는 조건 | 형식 |
|---|---|---|
| `implementation-patterns.md` | `functional-programming.md`의 **⏬ 트리거 4개** 중 하나 | 패턴 6개 × (증상 → 변환 Before/After → 검증) |

**늘리지 않는다.** 추가는 `BACKLOG.md` 승격 조건을 통과할 때만(§11). 고아 references는 doctor 검사 2가 잡는다.

#### 로드 비용 예산

| | 언제 | 목표 |
|---|---|---|
| CLAUDE.md | 항상 | ~40줄 |
| `rules/` 상시분 | 항상 | **≤10KB** (= `non-obvious-patterns.md` 하나) |
| `rules/` 개별 | 매칭 시 | **≤10KB/파일** |
| `references/` | 트리거 시 | 제한 없음 |
| `_brain/wiki/index.md` | 항상 | ~900토큰 |

> 참고레포A의 **40,000토큰**과 대조된다(§3-1). 예산을 문서에 적어두는 이유는 **재는 주체를 만들기 위해서**다 — doctor 검사 5가 이 표를 본다.

### `.claude/harness.json`
```json
{
  "packageManager": "pnpm",
  "verify": { "format": "…", "lint": "…", "typecheck": "…", "test": "…", "build": "…" },
  "ci":      { "test": "deferred" },
  "tdd":     { "enabled": true, "include": ["src/features/**"], "exclude": ["**/*.stories.*"] },
  "test":    { "runner": "…", "bddAlias": true },
  "release": { "tool": "changesets" },
  "brainSync": { "wikiPath": "…", "targetFolder": "wiki/projects/<name>" }
}
```
- `harness-init`이 **실제로 돌려보고 통과한 것만** 기록 → 거짓말 불가. **없는 키는 skip**
- `release.tool`이 `null`이면 `changeset` 스킬은 스스로 skip
- `test.runner`·`test.bddAlias`는 **`harness-init`이 실제로 탐지한 것만** 적는다. `bddAlias`가 false면 `test-writer`가 별칭 파일을 새로 심지 않고 중첩 `describe`로 3계층을 만든다 (없는 경로를 만들지 않기 위함 — E1)
- **`deferred` 패턴** — `ci.test`·`tdd.include`·`release.tool`이 비면 cartography·weekly가 **매번 감점 보고**. 조용히 죽지 않게
- 근거: `practice.md:116` "명령을 돌려서 판정한다" · `diagnosis.md:81` "**검증이 실패하는데 아무도 모르는 상태**"

### 훅 규칙
- 첫 줄 `[ -f .claude/harness.json ] || exit 0`. **예외: `block-dangerous-bash.sh`만 항상 동작**
- `${CLAUDE_PLUGIN_ROOT}` 기준 + 스크립트 첫 줄 `cd "$(git rev-parse --show-toplevel)"`
- **Stop 훅은 전부 읽기 전용** (`practice.md:110` "세션 끝에 64파일을 조용히 다시 쓴다")
- **절대경로 하드코딩 금지** — `memory-reminder`가 그랬고, `weekly-readiness-check`가 그랬다. 이식 시 전수 점검

---

## 4. `harness-init` (본체)

```
/harness-init  (대상 레포에서 1회)
 ├ 1. 진단 — diagnosis.md 7축 (정본은 vault, 여기선 인용)
 ├ 2. 명령 실측 — 후보 추출 → **실제 실행** → 통과한 것만 harness.json
 │     2-b. **테스트 러너·BDD 별칭 탐지** → `test.runner`·`test.bddAlias`.
 │          별칭이 없으면 **파일을 심지 않고** false로 기록 (test-writer가 중첩 describe로 대체)
 ├ 3. 인터뷰 7개 (기계가 모르는 것만)
 │     ① 절대 금기? → CLAUDE.md CRITICAL   ② 처음 온 사람이 당하는 함정? → non-obvious 첫 항목
 │     ③ 서비스 한 줄?                      ④ tdd-guard 경로? (후보 제시, 없으면 enabled:false + 감점)
 │     ⑤ `_brain/`?                          ⑥ CI에 test? (아니면 deferred)
 │     ⑦ 릴리스를 Changesets로? (없으면 깔아준다 — §4-1)
 ├ 4. 생성 (기본 6 + 조건부) — §3 templates
 ├ 4-b. 구조 지도 — **새 파일 안 만듦.** CLAUDE.md 안에 진입점·의존 방향을 자동 생성.
 │       레포가 커지면 그때 분리 (참고레포A는 `.claude/process/modules.md` 138줄이 이 역할)
 ├ 4-c. ADR — **새 구조 안 심음.** 작동 중인 관행(`docs/{feature-date}/ADR.md`, 7개 축적)을 CLAUDE.md 한 줄로
 ├ 4-d. 계층 — **3층 배치**(§3-1): CLAUDE.md는 링크만 / `rules/`는 짧고 `paths:` / 긴 것은 `references/`.
 │       하위 CLAUDE.md는 코드가 import하지 않는 폴더일 때만
 ├ 4-e. 릴리스 세팅 (Changesets) — 인터뷰 ⑦에서 예일 때만 (§4-1)
 ├ 4-f. **`testing.md` 심기 — tdd-guard의 판정 근거.** 훅 면제 목록과 문서 §0이
 │       **같은 표를 보게** 맞춘다 (어긋나면 막는 것과 적힌 것이 달라진다)
 └ 5. 검증 — verify 전체를 돌려 red/green 보고
```

### 4-1. Changesets 세팅 — **쓰는 것만이 아니라 구축까지 한다**

인터뷰 ⑦ *"릴리스를 Changesets로 관리할까요?"* 가 예이면 `harness-init`이 **없는 프로젝트에 처음부터 깔아준다.** 참고레포A 실측 구성에서 범용 부분만 가져오고, 레포 고유값은 **git remote·브랜치에서 자동 추출**한다.

| 단계 | 하는 일 | 자동 추출하는 값 |
|---|---|---|
| ① 의존성 | `<pm> add -D -w @changesets/cli @changesets/changelog-github` | 패키지 매니저는 `harness.json.packageManager` |
| ② 초기화 | `npx changeset init` → `.changeset/config.json` 생성 후 **패치** | ↓ |
| ③ config 패치 | `changelog: ["@changesets/changelog-github", { repo }]`<br>`baseBranch`<br>`access`<br>`ignore` | `repo` ← `git remote get-url origin`에서 `owner/name`<br>`baseBranch` ← `git symbolic-ref refs/remotes/origin/HEAD`<br>`access` ← private 레포면 `"restricted"`<br>`ignore` ← 워크스페이스 중 `"private": true`인 패키지 목록 (모노레포일 때만) |
| ④ scripts | `package.json`에 `"changeset": "changeset"`, `"version": "changeset version"` 2줄 | — |
| ⑤ 문서 | `.changeset/README.md` — 릴리즈 흐름 일반형 (언제 changeset을 쓰나 / 버전 규칙 / Release PR 흐름) | — |
| ⑥ CI (기본) | `.github/workflows/check-changeset.yml` — PR에 `.changeset/*.md` 신규 추가가 있는지 검사 | 브랜치명 ← `baseBranch` |
| ⑦ CI (선택) | `.github/workflows/changeset-release.yml` **최소형** — `changesets/action`으로 Release PR 생성·태그까지만 | 🙋 별도 승인 |
| ⑧ 기록 | `harness.json`에 `"release": { "tool": "changesets" }` | — |

**⚠️ 개선해서 이식하는 것 1건** — 참고레포A의 `check-changeset.yml`은 changeset이 없어도 **봇 코멘트만 남기고 CI를 fail시키지 않는다.** `diagnosis.md:78`("non-blocking 게이트는 없느니만 못하다")에 걸리므로, 플러그인판은 **exit 1로 차단**하되 `skip-changeset` 라벨을 우회로로 남긴다. 라벨이 있으면 통과.

**🔴 가져가지 않는 것** — `changeset-release.yml` 180줄 중 **guide-sync 디스패치·EC2 SSH 배포·`참고레포A/prod/v*` 태그 규약·RELEASE_TOKEN PAT 분기**. 그 레포의 배포 파이프라인이고, 신규 프로젝트에 심으면 동작하지 않는 워크플로가 첫날부터 red로 뜬다. 최소형은 **Release PR 생성 + 태그 발행까지만**이고, 배포 연결은 프로젝트가 직접 잇는다.

**Changesets를 안 쓰는 프로젝트**: `harness.json.release.tool = null` → `changeset` 스킬이 **스스로 skip**하고, cartography가 "릴리스 관리 도구 없음"을 감점 항목이 아니라 **정보**로만 보고한다(모든 프로젝트에 릴리스 관리가 필요한 건 아니므로).
```

## 5. `brain-sync` — 지식이 프로젝트에 갇히지 않게

**왜 핵심인가**: `_brain/`을 깔수록 지식이 각 레포에 갇힌다. 통합 wiki로 흘려보내야 축적이 되고, **부수 효과로 프로젝트의 `_brain/wiki/`가 계속 가벼워진다** — 참고레포A가 33파일 72KB까지 자란 것이 배출구가 없었기 때문이다.

- **트리거**: SDD REFLECT 마지막(`changeset → commit → pr-write → brain-intake → brain-sync`) + 수동. 🙋 사람 확인 후
- **입력**: 통합 wiki 경로 + 대상 폴더. `harness.json.brainSync`에 캐시
- **대상**: `wiki/projects/<프로젝트>/`. `_brain/wiki/` 8카테고리 유지
- **12살 이해법**: 한 파일 안에 정식 서술 + `## 쉽게 말하면 (12살 기준)`
- **원본**: `_brain/wiki/`는 남긴다(복사). 정리는 `_brain/CLAUDE.md:30` 6개월 무참조 archive가 담당
- **민감정보**: `_brain/internal/`은 **스킬이 거부**
- **⚠️ 폴더명 충돌**: `work/projects/`(이력서) ↔ `wiki/projects/`(도메인 지식). 양쪽 index에 서로를 가리키는 한 줄 + vault CLAUDE.md에 역할 차이 명시

## 6. `harness-doctor` (~30줄) — fork 없이 고유 검사만

공식 `claude-md-management`는 **그대로 쓴다**(disable 안 함). 745줄 fork 대신 4개만:
1. CLAUDE.md 검증 명령 ↔ `harness.json.verify` **drift**
2. 문서에 적힌 **경로가 실재하는가** (E1을 CLAUDE.md·rules에도) **+ 역방향: `references/`의 모든 파일이 `rules`·CLAUDE.md에서 트리거되는가** — 고아 references는 죽은 문서다 (§3-1)
3. `non-obvious-patterns.md`가 **비어 있는가**
4. `.claude/README.md` 라우팅 표 ↔ 실제 스킬 **1:1** (`update-claudemd` 고유 검사 흡수)
5. 🔴 **`.claude/rules/` 로드량 계측 — 두 축** (§3-1)
   - **상시 로드량**: `paths:` 없는 파일들의 **합계**. 임계 ≈10KB 초과 → `paths:` 미부착 파일을 지목
   - **매칭 폭탄**: **개별 파일** 크기. 임계 ≈10KB 초과 → **`references/`로 내리라고 권고**(조건부여도 매칭되면 전량이므로)

> 검사 5가 이 하네스에서 **유일하게 숫자를 보는 검사**다. 나머지 넷은 존재/일치 판정이라 통과하면 조용하지만, 로드량은 **조용히 자란다.** 참고레포A가 40,000토큰까지 자란 원인은 구조가 아니라 **아무도 재지 않은 것**이다.

---

## 7. `agents/` 설계

### 페르소나 한 문장씩
- **`test-writer`** — *구현을 보지 않은 채 스펙만 읽고, 이 기능이 **어떻게 깨지는지**부터 세는 사람. 행복한 경로는 한 줄로 끝내고 남은 시간을 전부 경계에 쓴다.*
- **`feature-builder`** — *이미 빨간 테스트를 초록으로 만드는 것이 일의 정의인 구현자이자, **무엇을 순수하게 남길지부터 정하는 함수형 설계자.** 액션을 바깥으로 밀고 계산을 안쪽에 모은다. **테스트를 고쳐서 통과시키면 실패**이고, 정하는 일은 사람에게 돌려준다.*
- **`code-reviewer`** — *통과시키려고 온 게 아니라 문제를 찾으러 온 깐깐한 남의 눈. 다만 잘한 것 하나는 반드시 짚고, 자기가 매긴 등급을 스스로 한 번 더 의심한다.*
- **`root-cause-debugger`** — *고치기 전에 왜인지를 증거로 확정하는 사람. 아무것도 기억하지 못한 채 도착하므로, 추측 대신 레포가 이미 적어둔 함정 목록부터 읽는다.*

### 격리 사유 — 4개인 이유는 숫자가 아니라 사유다
```
컨텍스트 격리(비용)     → feature-builder      (harness-run:6,64)
편향 격리 · 사후(품질)  → code-reviewer        (harness-engineering:71)
편향 격리 · 사전(품질)  → test-writer          ← 신설
탐색 격리(비용+오염)    → root-cause-debugger  (technic:200)
```

**`test-writer`의 격리 사유는 "무지의 유지"다.** code-reviewer는 *이미 만든 것을 안 봤어야* 하고, test-writer는 *아직 만들 것을 몰라야* 한다. 같은 컨텍스트에서 테스트를 쓰면 머릿속에 구현을 그린 뒤 **그 구현이 통과하도록** 케이스를 고르게 되고, TDD의 red가 형식만 남는다. 이건 프롬프트로 막을 수 없고 **컨텍스트로만** 막힌다.

**다섯 번째 사유가 없으므로 다섯 번째 에이전트도 없다.**

### `model:` — 유지하되 test-writer는 opus
| | model | 근거 |
|---|---|---|
| `test-writer` | **opus** | 엣지케이스를 세는 일은 생성이 아니라 **탐색**이다. 여기가 얕으면 red가 얕고, 그 뒤 전부가 얕아진다 |
| `feature-builder` | sonnet | 정해진 것을 만드는 일 |
| `code-reviewer` | opus | 검토는 작성보다 세게 (`claude-code-best-practices.md:71`) |
| `root-cause-debugger` | opus | 가설 탐색 |

### 프론트매터 (영어, `<example>` 없음, `memory:` 없음, `model:` 유지)
4개 합 **≈2,080자** (현행 3개 2,757자 대비 **−677자**). test-writer가 450자를 새로 쓰는데도 총량이 줄어드는 것은 `<example>` 1,739자를 지웠기 때문이다.

각 description에 반드시 포함할 4요소: **① 언제 부르나(구체 상황) ② 무엇을 하나 ③ 무엇은 안 하나(다른 에이전트 이름 명시) ④ 어디서 멈추나**. `claude-code-subagents.md:58`의 "하면 안 되는 작업 명시형"을 **본문이 아니라 description에** 적용 — 본문은 트리거 판정 시점에 안 읽힌다.

### 예시 → 절차 승격 (일반화해도 페르소나가 안 밋밋해지는 방법)
**페르소나를 만드는 것은 고유명사가 아니라 태도와 절차다.** 하드코딩 59줄을 걷어내면서 태도 문장을 0줄 추가하면 정말로 밋밋해진다.

| 지금 (예시 — 지우면 빈다) | 바꿀 것 (절차 — 지워도 안 빈다) |
|---|---|
| "TipTap `parseHTML: () => null` attrs 덮어쓰기" | **"서드파티 확장 포인트의 기본 구현을 덮어쓴 곳"** |
| "figcaption 구분자 `\" / \"` — 단일 `/` split 금지" | **"구분자·인코딩 규약이 쓰는 쪽과 읽는 쪽에서 다른 곳"** |
| "재마운트 시 `article_images` 빈배열 직렬화" | **"재마운트·재초기화 시점에 상태가 초기값으로 직렬화되는 곳"** |
| "임시저장 draft 중복" | **"자동 저장과 수동 저장이 같은 레코드를 쓰는 곳"** |
| "`color-registry.generated.ts` 직접 수정 금지" | **"헤더 주석·`.gitattributes`·harness.json이 자동 생성물로 표시한 파일"** |
| "`pnpm typecheck → format → lint --fix`" | **"`.claude/harness.json`의 `verify` 명령을 순서대로"** |

왼쪽은 *"이런 게 있었다"*, 오른쪽은 *"이런 걸 찾아라"*. 원본은 `non-obvious-patterns.md`로 이주하므로 **손실이 아니라 이사**다.

### 7-1. `test-writer` 상세 — 스펙에서 케이스로

**입력**: step 파일 + `docs/{feature}/PRD.md`의 수용 조건 + `templates/.claude/rules/testing.md`. **구현 파일은 열지 않는다**(있어도 읽지 않는다 — 그게 격리의 전부다).

**절차**
1. **러너·별칭 확인** — 테스트 러너와 BDD 별칭(`context` 등)이 있는지 본다. **없으면 만들지 말고** 중첩 `describe`로 같은 3계층을 세운다 *(파일을 새로 심으면 E1 위반)*
2. **수용 조건 → 케이스 목록** — 문장 하나당 케이스 1개 이상. 여기까지는 코드를 쓰지 않는다
3. **엣지 5축을 강제로 훑는다** (아래 표) — 축마다 "해당 없음"이면 **그렇게 적는다.** 조용히 건너뛰지 않는다
4. **BDD 3계층에 배치** — `describe`=전제 / `context`=조건 / `it`=기대 결과만
5. **red 확인** — `verify.test`를 돌려 **실패하는 것을 눈으로 본다.** 통과해 버리면 그 테스트는 아무것도 안 잡고 있다

**엣지 5축 (필수 훑기)**
| 축 | 묻는 것 | 짝 |
|---|---|---|
| **빈 값·경계** | 0 / 빈 배열 / null / 최대치 / 첫·마지막 | — |
| **비정상 입력** | 타입 위반·형식 위반·예상 밖 값 | — |
| **실패 경로** | 에러 응답·타임아웃·권한 없음 | — |
| **상태 전이** | 초기화·재진입·중복 실행 | debugger 5경계 *직렬화·생명주기* |
| **동시성** | 두 경로가 같은 것을 쓸 때 | debugger 5경계 *동시성·캐시* |

> 뒤 2축은 **`root-cause-debugger`의 우선 의심 5경계와 일부러 같은 축**이다. 실제로 터지는 자리를 테스트가 미리 노리게 된다.

**금지**: 구현 파일을 열지 않는다 · 스펙에 없는 동작을 지어내 단언하지 않는다(`⚠️ 스펙 확인 필요`로 남긴다) · **테스트를 통과시키려고 구현을 건드리지 않는다**(그건 feature-builder 몫이다).

**출력**: 작성한 케이스 수 · **축별 훑기 결과(해당 없음 포함)** · red 확인 결과 · `⚠️ 스펙 확인 필요` 목록.

### 7-2. `feature-builder` — 함수형 설계자 절

**왜 이 페르소나가 장식이 아닌가**: [[unit-testing-principles]]:87 — 테스트 3종의 우열이 **출력 기반(함수형) > 상태 기반 > 통신 기반(목)** 순이고, 그 등급을 정하는 것은 테스트를 쓰는 쪽이 아니라 **구현이 순수한가**다. 즉 **feature-builder가 FP를 못 하면 test-writer의 RED가 아무리 좋아도 목투성이 취약한 테스트가 된다.** FP 절은 §8-e RED/GREEN을 실제로 작동하게 만드는 조건이다.

| 절 | 요지 | 근거 |
|---|---|---|
| **액션·계산·데이터 3분류** | 코드를 쓰기 전에 셋으로 가른다. **구현 순서는 데이터 → 계산 → 액션**(모양 먼저, 그걸 다루는 계산, 마지막에 액션으로 감쌈) | [[functional-programming]] |
| **판별 한 줄** | *"언제 호출하는지·몇 번 호출하는지에 따라 결과가 달라지면 **액션**"* — `new Date()`·`Math.random()`·가변 객체 프로퍼티 읽기 전부 해당 | 동 |
| **액션 전염 차단** | **액션을 부르는 함수는 액션이 된다.** 계산 안에서 액션을 부르지 않는다. 액션은 **가장 바깥으로** 민다 | 동 |
| **암묵적 입출력 승격** | 암묵적 **입력**(외부 스코프·전역·설정 읽기) → **인자로**. 암묵적 **출력**(전역 변경·로깅·저장) → **반환값으로 바꾸고 호출부로**. *실무에서 제일 자주 쓰는 판별 기준* | 동 |
| **숨은 입출력 3종** | 사이드이펙트 · **예외(`try/catch`)** · 내외부 상태 참조. **예외가 여기 들어가는 게 의외 포인트** — 실패는 던지지 말고 **값으로 반환**하는 쪽을 먼저 검토 | 동 |
| **카피-온-라이트** | 쓰기를 읽기로 바꾼다. ⚠️ **중첩 전체가 불변이어야** 불변이다 — 최상위만 `const`인 것은 불변이 아니다 | [[immutability]] |
| **추상화 수준 섞임 금지** | 한 함수에 **도메인 규칙과 배열 인덱스 조작이 같이 있으면** 분리한다. *"쓰는 쪽에서 어떤 자료구조인지 알아야 한다면 낮은 계층"* | [[layered-function-design]] |
| **함수형 코어 + 가변 쉘** | 결정하는 부분(순수)과 작용하는 부분(부수효과)을 나눈다. **⭐ test-writer와의 접점** | [[unit-testing-principles]]:91 |
| **⚠️ 도구가 목적이 아니다** | `map`/`filter`/`reduce`를 아무리 써도 *"사람 생각에 가까운 코드"*가 안 되면 FP의 이점은 없다. **특정 유틸 라이브러리 강제 금지** | [[functional-programming]] |

#### 절차에 박는다 — "참고하면 좋다"가 아니라 **순서**

선택으로 두면 안 읽힌다. `feature-builder` 절차의 **1번**으로 고정한다:

```
1. step 파일 + 실패 중인 테스트를 읽는다
2. rules의 ⏬ 트리거 중 걸리는 것이 있으면
   → .claude/references/implementation-patterns.md 의 해당 패턴을 읽는다
3. 데이터 → 계산 → 액션 순으로 구현한다
4. verify 실행 (테스트 파일은 건드리지 않는다)
5. 보고
```

**관측 가능하게** — 보고에 `참고한 패턴: 1(코어/쉘), 4(카피온라이트)` 또는 `참고한 패턴: 없음 (해당 트리거 없음)` **한 줄을 반드시 적는다.** `harness-run`이 이 줄로 *"references가 실제로 열리는가"* 를 셀 수 있다.

> 🔴 **이 한 줄이 없으면 3층 전체가 검증 불가다.** wiki가 경고한 *"참조로 뺀 문서를 agent가 실제로 여는지 확인해야 한다"* 의 확인 수단이 바로 이것이고, 없으면 references는 **읽히는 척하는 폴더**가 된다. `deferred` 패턴·`⚠️ 정량화 필요`와 같은 계열 — **조용히 죽지 않게 한다.**

**`test-writer`에 붙는 짝 규칙 1줄**: *"출력 기반으로 쓸 수 없어 **목이 여러 개 필요하면**, 그건 테스트의 문제가 아니라 **구현이 액션에 오염된 신호**다 — 케이스를 억지로 짜지 말고 보고에 적는다."*

> 이 한 줄이 FP 위반을 **RED 단계에서 잡는 장치**가 된다. 리뷰까지 안 가고 테스트를 쓰는 순간 드러난다.

### 각 에이전트에 넣을 절
| 절 | 어디에 | 요지 |
|---|---|---|
| **자세** | code-reviewer | "통과가 목표가 아니라 문제를 찾는 게 목표. 근거를 못 대면 지적이 아니라 `⚠️ 확인 필요`. **오탐 1건 = 신뢰 10건 손실**" |
| **✓ Good** | code-reviewer 출력 3번 | "실제로 잘 처리된 것 1~3줄을 `파일:라인`과 함께. '특별히 없음'은 답이 아니다" |
| **등급 재조정** | code-reviewer 자기검증 | "4축을 다 본 뒤 등급을 다시 매긴다. 축을 하나씩 볼 때는 **기본적으로 부푼다**. 🔴는 '머지하면 사고'에만. 🔴가 3개 넘으면 다시 고른다" |
| **판단 경계** | feature-builder | "우선순위·트레이드오프·새 의존성·**규칙의 예외**·새 레이어·모호한 명세 → **멈추고 묻는다.** 고르고 진행한 뒤 '확인 사항'에 적는 것은 위반이다 — 그건 통보다" |
| **🔴 테스트 불가침** | feature-builder | "**테스트 파일을 수정하지 않는다.** 테스트가 틀렸다고 판단되면 고치지 말고 **멈추고 보고한다** — 스펙 해석 충돌은 사람 판단 영역이다. 통과가 안 되는 것은 성실한 실패지만, 통과하게 테스트를 고치는 것은 **게이트 무력화**다" |
| **패턴 참조** | feature-builder | "rules의 ⏬ 트리거에 걸리면 `references/implementation-patterns.md`를 **읽고 시작한다**(절차 2번). 보고에 **`참고한 패턴:` 한 줄 필수** — 없으면 '없음'이라고 적는다" |
| **함수형 설계** | feature-builder | **§7-2 전체.** 액션/계산/데이터 → 구현 순서 데이터→계산→액션 → 액션은 바깥으로. "이 함수를 목 없이 출력만으로 검증할 수 있나"가 자기 점검 질문 |
| **목이 여럿이면 보고** | test-writer | "출력 기반으로 못 쓰고 **목이 여러 개 필요하면** 구현이 액션에 오염된 신호 — 억지로 짜지 말고 보고" (§7-2) |
| **자체 점검** | feature-builder | "`verify` 명령을 **실제로 실행하고 출력을 확인한다.** `verify.test`는 건너뛰지 않는다. 비어 있으면 그 사실을 **출력에 명시**한다. 여기까지는 기계 판정이고 주관 판정은 `code-reviewer`" |
| **무지 유지** | test-writer | "**구현 파일을 열지 않는다.** 어떻게 만들지 궁금해도 열지 않는다 — 열는 순간 내가 여기 따로 있는 이유가 사라진다. 스펙이 모자라면 추측 대신 `⚠️ 스펙 확인 필요`" |
| **red 확인** | test-writer | "테스트를 쓰고 끝내지 않는다. **실행해서 실패하는 것을 확인**하고 그 출력을 보고에 적는다. 전부 통과하면 잡는 게 없다는 뜻이다" |
| **우선 의심 순서** | root-cause-debugger | 스택 무관 5경계: **직렬화 / 생명주기 / 캐시 / 동시성 / 환경**(간헐적 실패는 거의 항상 여기). "버그는 모듈 **안**이 아니라 모듈 **사이**에서 난다" |
| **컨텍스트 복구** | root-cause-debugger | "나는 앞선 대화를 모른다. 부족하면 추측 말고 `non-obvious-patterns.md` → CLAUDE.md CRITICAL → `git log`를 **직접 읽는다.** 읽어도 재현이 안 잡히면 증거 부족이 아니라 **입력 부족**이니 되묻는다" |
| **회귀 환류** | root-cause-debugger | "원인을 확정했으면 **그 원인을 재현하는 테스트 케이스 1줄을 보고에 적는다.** 작성은 `test-writer`가 한다(호출은 메인) — 같은 버그가 두 번 나면 그건 테스트의 실패다" |
| **인계 문구** | 4개 전부 | "인계한다" → **"인계 대상을 보고에 적는다(호출은 메인이 한다)"** |
| **지식 종착지** | 4개 전부 | "새로 발견한 비명백 함정은 `non-obvious-patterns.md` 추가 후보로 **한 줄 보고**" — `memory:` 절은 삭제 |

---

## 8. 경계 계약

> **이번 변경으로 확정된 한 줄 흐름** (단계표는 만들지 않는다 — 정본은 `sdd/SKILL.md`, 5중 중복이 반면교사):
> `why-logictree`(스펙) → `harness`(분해) → `grilling`(빈칸) → 🙋 → **`test-writer`(RED) → `feature-builder`(GREEN)** → `sdd-review` → `code-reviewer` → REFLECT
>
> 사용자 워크플로우 **스펙 → 테스트 → 구현**이 굵은 글씨 구간이고, 그 앞 두 게이트가 스펙을 실제로 존재하게 만든다.


### 8-a. `sdd-review`(스킬) ↔ `code-reviewer`(에이전트)
**유지 판정은 맞다 — 단 지금 형태로는 게이트가 아니다.** 조건이 `sdd-review:39` *"깊게 볼 필요가 있으면"* 이라 기분이지 판정이 아니고, 계약이 수신 측에만 있어 실제론 code-reviewer가 빈손으로 4축을 재검사한다.

`sdd-review` 출력에 **고정 3줄** 추가 (파일·스키마 신설 0):
```
ESCALATE: yes | no
SCOPE:    src/features/portal-pv-report/** , packages/ui/**
CHECKED:  architecture=pass adr=pass tests=pass critical=pass build=unsure
```
**escalate 규칙 5줄** (기계 판정):
1. `CHECKED`에 `unsure` 1개+ → **yes**
2. 🔴 1개+ → **no** (이미 결론. 바로 feature-builder로. **비싼 opus를 판정 난 것에 안 쓴다**)
3. 🟡 3개+ → **yes** (흩어진 위반은 구조 문제 신호)
4. 변경 파일 10개 초과 → **yes** (체크리스트는 넓은 diff에 약하다)
5. `**/auth/**`·`**/*.generated.*`·DS 패키지에 걸림 → **yes**
6. **어느 것도 아니면 부르지 않는다** ← 이게 게이트의 값

`code-reviewer` 절차 1번: *"메인이 넘긴 `SCOPE`·`CHECKED`를 먼저 읽는다. 없을 때만 diff를 직접 뜬다. `pass`인 축은 재판정 금지."*

> JSON 리포트 파일은 **지금 안 만든다**(`habit.md:78` 3번부터). "세 번째 레포에서 순환 재검증이 실제로 일어난 뒤" BACKLOG에서 승격.

### 8-b. `harness-run` 복귀 경로 (지금 비어 있음)
`harness-run:40`이 "3회 초과 시 중단… 근본 원인성 실패면 debugger로 전환"이라 쓰는데 **판정 주체도 복귀 경로도 없다.** 1줄 추가:
> *"debugger가 최소 수정안을 냈고 사람이 승인하면, **메인이** 해당 step status를 `pending`으로 되돌리고 `error_message`에 근본 원인 1줄을 남긴 뒤 루프를 재개한다."*

**파일 1개(`index.json`)로 3자 인계가 닫힌다. 새 장치 0개.**

### 8-c. `root-cause-debugger` ↔ `code-reviewer`
양방향이지만 순환이 아니라 **에스컬레이션 사다리**. 종료 조건이 이미 규율에 있다 — `:13` **3-Fix 규칙**("3회+ 실패 시 아키텍처 의심"). 다만 `:13`과 `:35`(구조적 결함)가 같은 것이라고 안 쓰여 있으니 **1줄 추가**: *"3-Fix 발동 = 구조 축 판정 대상. `code-reviewer` 축3으로 넘긴다(호출은 메인)."*

### 8-d. 계획 게이트 2개 — `why-logictree`(DESIGN) · `grilling`(PLAN)

**체크 결과: 지금 둘 다 연결이 0건이다.**
- `why-logictree`는 **이 vault의 `.claude/skills/`에만** 있다. 참고레포A에도 전역에도 없다 (실측: `~/.claude/skills/` = `grill-me`·`grilling`·`systematic-debugging` 3개뿐)
- `harness/SKILL.md`의 PLAN 단계에 두 스킬 호출이 **한 줄도 없다.** `:22` *"모호·누락은 추측 말고 질문한다"* 가 전부인데 이건 스킬 호출이 아니라 **지시문**이다
- 그리고 **1차 설계에서 내가 `why-logictree`를 명시적으로 제외했었다**(2-A #9 "코딩 하네스 무관"). **이 판단을 뒤집는다** — 아래 이유로 무관하지 않다

**왜 뒤집나 — 코어 트랙의 DESIGN이 비어 있다.** `sdd/SKILL.md:1`의 DESIGN은 `design-brief`(UI 트랙)뿐이고, 비UI 작업은 `docs/{feature}/PRD.md`가 **이미 있다고 전제**한다(`harness/SKILL.md:1` 가드레일 로드가 그 파일들을 읽기만 한다). 워크플로우 1단계가 **스펙 작성**인데 **그 스펙을 만드는 주체가 코어 트랙에 없다.** `why-logictree`의 description이 정확히 "기획서·제안서·**문제정의서**"다.

| 게이트 | 자리 | 발화 조건 | 산출 |
|---|---|---|---|
| `why-logictree` | **DESIGN 진입** | 과제가 막연하거나 PRD가 아직 없을 때 | WHY→3질문→로직트리→So What/Why So → **`docs/{feature-YYYY-MM-DD}/PRD.md`** |
| `grilling` | **PLAN 승인 직전** | step 파일에 `⚠️`·`TBD`·미해결 가정 3개+ 또는 사람이 요청 | 선 계획의 빈칸을 캐물음 (`technic.md:162`가 자리를 지목) |

**둘은 겹치지 않는다** — 앞은 *"무엇을 왜 만드나"*(아직 정답이 없음), 뒤는 *"정한 것에 빈칸이 있나"*(정답이 있는데 덜 적힘).

⚠️ **`why-logictree`는 파일을 임의로 쓰지 않는다** — `SKILL.md:5` *"파일 저장 여부·위치는 항상 사용자에게 먼저 확인한다"*. 이식판도 이 규칙을 유지하되 **기본 제안 경로만** `docs/{feature-YYYY-MM-DD}/PRD.md`로 준다.

> 이 게이트가 **테스트 앞단을 먹여 살린다.** `test-writer`의 입력이 수용 조건인데, PRD가 없으면 셀 케이스도 없다. 스펙→테스트→구현에서 **스펙이 가장 먼저 비는 칸**이었다.

### 8-e. `test-writer` ↔ `feature-builder` — RED/GREEN 2단 step

**분리하면 새 위험이 하나 생긴다: 구현자가 막히면 테스트를 고친다.** 성실한 실패가 아니라 게이트 무력화이고, 프롬프트만으로는 못 막는다. **기계로 닫는다.**

`harness-run`의 step 루프를 2단으로:

| 단계 | 호출 | 통과 조건 | 실패 처리 |
|---|---|---|---|
| **RED** | `test-writer` | `verify.test`를 돌려 **실패해야 통과** | 전부 통과 = 아무것도 안 잡는 테스트 → **step 실패** |
| **GREEN** | `feature-builder` | `verify` 전체 green **AND** diff에 테스트 파일 없음 | 테스트 파일이 diff에 있으면 **즉시 실패** |
| **commit** | 메인 | — | — |

**RED 확인이 이 설계의 값이다.** 참고레포A의 실측 결함은 *"테스트가 396개인데 돌리는 주체가 없다"* 였다. 여기서는 **테스트가 실패하는 것까지 확인해야** 다음 칸으로 못 넘어간다.

**모든 step에 테스트가 붙지는 않는다.** `harness`가 분해 시 step마다 `"tdd": true|false`를 판정하고, `false`면 **이유를 step 파일에 적는다**(조용히 건너뛰지 않게 — `deferred` 패턴과 같은 철학). 판정 기준은 `templates/.claude/rules/testing.md` §0 = `tdd-guard.sh` 면제 목록으로 **같은 표를 본다**(둘이 어긋나면 훅이 막는 것과 문서가 말하는 것이 달라진다 — 참고레포A는 `testing.md §0`에 *"tdd-guard 면제 목록과 정합한다"* 고 명시해 이걸 막았다).

**새 파일 0개** — `index.json`의 step에 `kind`("test"/"impl")·`tdd`(bool) 키 2개만 늘어난다. 3자 인계가 파일 하나로 닫히는 8-b의 구조를 그대로 따른다.

### 8-f. 팀 아키텍처
현재 = **Pipeline + Supervisor + (REVIEW 구간만) Producer-Reviewer** 3조합. Fan-out(차원별 병렬 리뷰)은 `technic.md:191`("팀부터 꾸리지 않는다") + **오탐 데이터 0**이라 BACKLOG 유지.

---

## 9. 진행 순서

| 단계 | 내용 | 완료 판정 |
|---|---|---|
| **0** | **설계 문서 확정** ← 이번 세션 | 문서 + team.md 상태 갱신 + log.md |
| ~~0.5~~ | ~~`gh auth login` → wiki 공개 여부~~ | ✅ **완료** — 두 계정 등록, vault는 private → §5 유지 |
| ~~1~~ | ~~repo 생성 + 골격 + remote 2개~~ | ✅ **완료 (2026-08-23)** — 양쪽 private 생성, `git push` 한 번에 양쪽 반영, `claude plugin marketplace add jtwjs/claude-harness` → **파싱·설치 성공** |
| ~~2~~ | ~~자산 이식 + 훅 재배선~~ | ✅ **완료 (2026-08-23)** — skills 12·agents 3·hooks 8+hooks.json. 절대경로 **0건**, 회사 고유정보 **0건**. 하네스 없는 레포에서 7개 훅 전부 exit 0·무출력 / 위험명령만 exit 2 / tdd-guard 3케이스(차단·면제·범위밖) 통과 / Stop 훅 작업트리 무변화 |
| ~~3~~ | ~~일반화 + 예시→절차 승격~~ | ✅ **완료 (2026-08-23)** — skills 12개 스택 고유명사 **0건**, hallucinated 참조 정리(design 3종 → `incubator/`), description 삭감(cartography −579자·why-logictree −181자). 🔴 **회사 고유정보 grep 0건 — 단 DESIGN.md 자신이 위반이어서 45건 익명화**(§3-3) |
| 3.5 | **hallucinated 참조 정리** — `sdd/SKILL.md`의 `design-reconcile`(:10,:18)·guide-*(:19), 에이전트 전체의 "인계한다" | `harness-doctor` 검사 2·4가 green |
| ~~4~~ | ~~에이전트 4개 재작성 + 신규 스킬 3개 + templates~~ | ✅ **완료 (2026-08-23)** — Skills **15** · Agents **4** · Hooks **3** · templates **10파일**. 로드 예산 전부 준수(상시 1,158B / 개별 최대 3,452B / CLAUDE.md 44줄) |
| 4-b | **RED/GREEN 배선**(§8-e) — `harness`에 `kind`·`tdd` 키, `harness-run`에 2단 루프 | **red 실검증**: 통과하는 테스트만 넣은 step이 **실패로 잡히는가** |
| 4.5 | `incubator/ready/` 3개 + `BACKLOG.md` 6줄 | `/context`로 incubator 미로드 확인 |
| ~~5~~ | ~~설치 검증~~ | ✅ **완료 (2026-08-23)** — 로컬 등록을 지우고 **GitHub에서 순수 설치**: marketplace add → install → Skills 15·Agents 4·Hooks 3 인식, Always-on **3,218** |
| ~~6~~ | ~~일반화 검증 + `hooks/test.sh`~~ | ✅ **부분 완료 (2026-08-23)** — `hooks/test.sh` **16/16 green**, 테스트베드 실측. ⏳ `harness-init` 실제 실행은 그 레포 세션에서(회사 레포이므로 사용자가 직접) |
| ~~7~~ | ~~전역 `~/.claude` 정리~~ | ✅ **완료 (2026-08-23)** — 백업 후 제거 7 + 수리 6. settings.json 유효·죽은 참조 0건·ccstatusline 1회. **제거 전에 설치본 훅을 직접 실행해 차단이 도는 것을 확인**했다 |
| 8 | 2번째 레포 실사용 → **3번째부터** BACKLOG 승격 | 3번의 법칙 |

**🔎 1단계에서 발견한 CLI 검증 수단** (슬래시 명령 없이 셸에서 판정 가능)

| 명령 | 쓰는 곳 |
|---|---|
| `claude plugin marketplace add <owner/repo>` | 1단계 완료 판정. **SSH 실패 시 HTTPS 자동 폴백**을 확인함(SSH 키가 `jtw-219`에만 있어도 `jtwjs` 클론이 된다) |
| `claude plugin details <name>` | **`Projected token cost — Always-on`을 실측한다.** §12의 description 비용(≈1,900토큰)이 지금까지 추정치였는데 **이제 잴 수 있다** → 5단계 판정 ③으로 승격 |
| `claude plugin eval` | 공식 eval 러너. 2-A #6에서 evals 5케이스를 *"기계 판정 불가"*로 뺐는데, **공식 러너가 있으므로 BACKLOG에서 재검토** |

**3단계 하드코딩 실측**
| 파일 | 하드코딩 | 잘라낼 구간 |
|---|---|---|
| `feature-builder.md` | **17줄 / 46건 (최다)** | 부분 삭감이 아니라 **재작성** |
| `code-reviewer.md` | 12줄 / 25건 | `<example>`×2, `:34` generated 파일명, `:55` TipTap 예시, `:16` rules 7파일 나열 |
| `harness/SKILL.md` | 8줄 / 13건 | **93~99행 부록 전체**(FSD·Zustand·TanStack·`/manage/*`) |
| `sdd-review/SKILL.md` | 5줄 / 11건 | `:22`·`:23`·`:25`·`:26`, **`:27` 비주얼싱크 행 전체** |
| `why-logictree/SKILL.md` | description **270토큰**(트리거 조건 나열) | 트리거는 3~4개로 압축. **범용 스킬이라 하드코딩은 없지만 길다** — 실측으로 드러난 항목 |
| `rules/functional-programming.md` | **lodash-es 절이 37%** + React 훅 순서 | 둘 다 잘라낸다(특정 라이브러리·프레임워크 전용). **대신 wiki 기반 판정 6개로 채운다** — 액션/계산/데이터 · 구현 순서 · 전염 차단 · 암묵적 입출력 승격 · 카피온라이트(중첩) · 추상화 수준 섞임. **분량은 늘리지 않는다**(§3-1: rules는 짧아야 매칭 폭탄이 안 된다) |
| `root-cause-debugger.md` | — | **`:22` 함정 목록 → 5경계 절차로 승격**(§7) |
| `sdd/SKILL.md` | — | **`:19` DOCUMENT 단계 전체**, `:10`·`:18` design-reconcile 참조 |
| `harness-run/SKILL.md` | — | `:43-45` 괄호스코프 해설, **`:61-64` 비용 메모**(DESIGN.md 소속) |

**7단계 — 제거 4 + 수리 6**: 제거 `skills/{grilling, grill-me, systematic-debugging}`·`agents/root-cause-debugger.md`·`hooks/{block-dangerous-bash, auto-format}.sh`·`deny-patterns.yaml` / 수리 ① 끊어진 `skills/briefing/` allow ② 구 이름 `mcp__claude_ai_Atlassian__*` 2건 ③ **`ccstatusline --hook` 4중 등록(매 호출 2배 실행)** ④ 빈 `rules/` ⑤ 빈 `agent-memory/root-cause-debugger/` ⑥ 사장된 `statusline-command.sh`

**되돌리기 어려운 지점은 7단계뿐이다.** → ✅ 완료. 백업: `~/.claude/backups/pre-harness-cleanup-<타임스탬프>/`

### 7단계 실행 기록 (2026-08-23)

**제거 7** — 플러그인이 대체하는 것: `skills/{grilling, grill-me, systematic-debugging}` · `agents/root-cause-debugger.md` · `hooks/{block-dangerous-bash, auto-format}.sh` · `deny-patterns.yaml`

**수리 6** — ①죽은 훅 참조 2건(방금 지운 파일을 부르던 등록) ②`ccstatusline --hook` **중복 그룹 2개 제거**(같은 matcher·같은 명령이 두 벌 → 매 호출 2배 실행이 1배로) ③빈 `rules/` ④빈 `agent-memory/root-cause-debugger/` ⑤죽은 allow 3건 ⑥사장된 `statusline-command.sh`

🔴 **제거 전 안전 확인을 먼저 했다** — 전역 `block-dangerous-bash.sh`를 지우면 그 보호가 사라지므로, **설치본 훅을 직접 실행해** 위험 명령 exit 2·정상 명령 exit 0을 확인하고 `enabledPlugins`에 활성인 것을 본 뒤에 지웠다.

⚠️ **하지 않은 것**: Atlassian allow 2건은 **제거만** 했다(구 이름이라 매칭 안 됨). 현재 이름으로 다시 허용할지는 **권한 확대**이므로 사용자가 정한다. orca 훅·`afplay` 알림·`additionalDirectories`·`statusline-5hr-segment.sh`는 **건드리지 않았다** — 하네스와 무관한 사용자 도구다.

---

## 9-1. 🔴 미러 운영 함정 — lease 옵션은 두 번째 remote에 안 통한다

**실측**: 히스토리 재작성 후 강제 push했더니 `jtwjs`는 갱신됐는데 `jtw-219`는 옛 커밋에 멈춰 있었다.

**원인**: remote-tracking ref는 `origin/main` **하나뿐이고 그건 첫 번째 remote 기준**이다. lease 옵션은 그 ref를 기준으로 삼으므로, 실제 상태가 다른 두 번째 remote에 대해서는 **"예상과 다르다"로 거부**한다.

| | 동작 |
|---|---|
| 일반 push | 두 remote 모두 정상 |
| lease 옵션을 붙인 강제 push | **첫 번째만** 적용 |
| 해결 | 두 번째 remote를 **URL로 직접 지정**해 개별 실행 |

> 강제 push가 필요한 일은 드물다. 한 번 맞춰 놓으면 이후 일반 push는 계속 양쪽으로 간다.

## 9-2. 🔴 실전에서 발견한 훅 오탐 — `deny-patterns.yaml` 개선 대상

**증상 2건** (둘 다 실제로 겪음):
1. **강제 push가 아닌 일반 push**가 "보호 브랜치 강제 push 금지"로 차단됐다 — 같은 셸 명령 안의 **커밋 메시지 본문**에 그 문자열이 있었다.
2. **push가 아예 없는 명령**(문서 편집 스크립트)도 차단됐다 — 작성하려던 **문서 내용에 그 명령이 예시로 적혀** 있었다.

**원인**: 훅이 **명령 전체 문자열을 한 덩어리로 grep**한다. 그래서 *"명령을 실행하는 것"*과 *"명령을 텍스트로 언급하는 것"*을 구분하지 못한다.

**왜 중요한가**: `autonomous-pr-reviewer.md:62` — *"오탐 1건 = 신뢰 10건 손실."* 안 위험한 것을 막는 훅은 곧 꺼진다. 그리고 이 훅은 **이 하네스가 모든 레포에 심는 것**이므로 오탐이 그대로 퍼진다. 2번 증상은 특히 나쁘다 — **하네스 문서를 쓰는 일 자체를 막는다.**

**개선안** (이식판에 반영):
- 패턴을 **명령 토큰 기준**으로 좁힌다. `git push` 뒤의 **옵션 자리**에서만 강제 플래그를 찾는다.
- `-m` 인자·heredoc·따옴표 안의 **본문은 검사 대상에서 제외**한다.
- 여러 명령이 `&&`로 이어진 경우 **해당 절만** 떼어 본다.

> 지금은 **훅을 끄지 않고** 우회했다(내용을 파일로 분리해 전달). 오탐이라도 규칙 자체는 옳고, 끄는 순간 진짜 사고를 못 막는다.

## 10. 일반화 검증 — 테스트베드

`참고레포B`. 참고레포A와 정반대: **yarn** 단일 앱 / **Next.js 16** / 테스트 **0개** / CI **없음** / Changesets **없음** / CLAUDE.md 없음.

1. yarn 프로젝트에서 `pnpm`을 한 번도 부르지 않는다
2. 테스트 0개 → `verify.test` **비워 두고** `ci.test:"deferred"`·`tdd.enabled:false` 기록
2-b. **Changesets 세팅 실검증** — 이 레포엔 Changesets가 없으므로 §4-1이 실제로 구축되는지 본다: `changelog.repo`가 git remote에서 `<org>/참고레포B`로 자동 추출되는가 · `baseBranch`가 `master`(이 레포는 main이 아니다)로 잡히는가 · 단일 패키지라 `ignore`가 빈 배열인가 · `yarn`으로 설치하는가(`pnpm` 아님)
3. ✅ **실측 완료** — `yarn lint`가 exit 1로 실패한다. Next 16에서 `next lint`가 제거돼 `lint`를 **디렉토리 인자로 해석**한다(`Invalid project directory provided`). **`package.json`에 스크립트가 있는데도 안 돈다** — 문서만 읽고 `verify.lint`에 넣었으면 첫날부터 red다. 2단계(명령 실측)가 필요한 이유의 교과서적 사례
4. 생성 직후 verify 전체 green + `hooks/test.sh` 2케이스 통과
5. **`feature-builder`가 `verify.test`가 비었다는 사실을 출력에 명시**한다 (조용히 넘어가지 않음)
5-b. **테스트 0개 레포에서 RED/GREEN이 어떻게 되나** — 러너가 없으면 `tdd.enabled:false`로 기록되고 `harness`가 모든 step을 `tdd:false`로 내되 **이유를 step 파일에 적는다.** `test-writer`는 호출되지 않는다. ⚠️ **여기서 조용히 넘어가면 실패다** — cartography가 `ci.test:"deferred"`와 같은 축으로 매번 감점 보고해야 한다
5-c. **BDD 별칭이 없는 레포**(이 레포는 `shared/test/bdd.ts`가 없다) — `test.bddAlias:false`로 기록되고, 테스트를 쓰게 되면 `test-writer`가 **파일을 새로 심지 않고** 중첩 `describe`로 3계층을 만드는지 확인
6. 하네스 안 깐 제3의 레포에서 훅이 전부 조용하고 `rm -rf ~` 류만 차단

---

## 11. `BACKLOG.md` + `incubator/ready/`

**`incubator/ready/`** — `mv` 한 번이면 도는 것: `design-brief`(35줄)·`design-plan`(75줄)·`design-reconcile`(51줄). 로드 경로 밖(superpowers가 `docs/`·`scripts/`·`tests/`를 그렇게 두는 것으로 확인).

**`BACKLOG.md`** — 승격 조건만. **셀 수 있는 조건으로.**

| 항목 | 승격 조건 |
|---|---|
| `review-code` 차원별 병렬 | **리뷰 통과 후 머지된 diff에서 나온 `fix:` 커밋 3건** (`git log --grep='^fix:'`로 셈) |
| `build-rules` | PR 100개+ 누적 후 (**repo 첫날 실행 금지**) |
| `security-scan` | 프로덕션 트래픽이 붙은 레포가 생겼을 때 |
| `improve-token-efficiency` | 월 비용이 신경 쓰일 때 |
| `oncall-agent` | 운영 알림·CI 권한을 받았을 때 |
| `references/testing-patterns.md` (통합 셋업·POM 관례) | `test-writer` 보고에 **`⚠️ 스펙 확인 필요`가 아닌 "셋업을 몰라서 못 씀"이 3회** 누적됐을 때 |
| `implementation-patterns.md` 7번째 패턴 | 같은 종류의 지적이 `code-reviewer` 리뷰에서 **3회** 반복됐을 때 (`git log --grep` 대신 리뷰 보고를 센다) |
| design 3종 + `DESIGN.md` 템플릿 | UI 비중 큰 프로젝트 착수 시 |
| `review-{task}.json` 리포트 계약 | 3번째 레포에서 순환 재검증이 실제로 일어난 뒤 |

---

## 12. 삭감 결과

| | 1차 설계 | 최종 |
|---|---|---|
| 스킬 | 12 | **15** (−claude-md-improver +harness-doctor +commit +pr-write +changeset, **why-logictree 복귀** §8-d) |
| commands | 1 | **0** |
| 에이전트 | 3 | **4** (+`test-writer` — 편향 격리가 사전/사후 둘로 갈림 §7) |
| description 비용 | ~~≈2,780토큰 추정~~ | 🔴 **실측 3,828토큰** (2026-08-23 `claude plugin details`). 추정이 틀렸다 — 목표를 실측 기반 **≤2,500**으로 다시 세운다 (§12-1) |
| 심는 파일 | 17 | **기본 6 + 조건부** (`testing.md` 추가) |
| repo 파일 | — | **−13개** |
| **프로젝트 세션 비용** ① | `@_brain/wiki/` **≈15,000토큰** | `index.md` 1파일 **≈900토큰 (−14,000)** |
| **프로젝트 세션 비용** ② | `.claude/rules/` frontmatter 0건 = **≈40,000토큰 전량 로드**(1층) | **3층 배치**(§3-1) — CLAUDE.md 링크 / `rules/` 짧게+`paths:` / 긴 것은 `references/`(평소 **0토큰**). doctor 검사 5가 두 축으로 계측 |
| 에이전트 `memory:` 잔해 | 레포마다 3~5개 디렉토리 | **0** |

> `harness-engineering.md:100` — *"좋은 하네스는 시간이 갈수록 단순해져야 정상이다. 규칙·도구가 계속 늘어난다면 과설계 신호."*

### 12-1. 🔴 실측 Always-on 비용 — 추정이 틀렸다

`claude plugin details claude-harness` (2단계 직후, 삭감 **전**):

```
Always-on: ~3,828 tok   added to every session
```

| 컴포넌트 | always-on | 처분 |
|---|---|---|
| `ai-readiness-cartography` | **680** | 3단계 −633자 삭감 → ~350 예상 |
| `code-reviewer` | **630** | `<example>` 제거 → ~300 |
| `feature-builder` | **560** | 재작성 → ~300 |
| `root-cause-debugger` | **530** | 삭감 → ~280 |
| `why-logictree` | **270** | ⚠️ **새로 발견** — description에 트리거 조건을 길게 나열. ~120으로 |
| 스킬 9개 (70~150씩) | ~1,140 | 유지 (개별로는 싸다) |
| **hooks 8개** | **0** | *"harness-only — no model context cost"* |

**목표 재설정: ≤2,500** → 🔴 **다시 정정: 최종 실측 3,218** (4단계 완료 시점, Skills 15 + Agents 4).

| 시점 | 구성 | Always-on |
|---|---|---|
| 2단계 직후 | 12 skills + 3 agents | **3,828** |
| 3단계 후 | 12 + 3 | 3,509 |
| **4단계 후** | **15 skills + 4 agents** | **3,218** |
| 2026-09-06 (0.1.1) | 20 skills + 4 agents | **4,600** |
| 2026-09-06 (0.2.0) | **21 skills + 4 agents** | **4,732** |
| **2026-09-06 (0.2.1)** | 21 + 4 | **4,370** (−362, §13-6) |
| 2026-09-18 (0.2.2 설치본) | 21 + 4 | **4,412** (slack-writing 개정분) |
| **2026-09-18 (0.3.0)** | **24 + 4** | **4,650** (+238, §14) |

> 아래 세 행은 **2026-09-06 재계측**이다. 그 사이 14일간 계측이 없었고 목표를 넘긴 시점을 못 봤다 → §13-5. 마지막 행이 그 처분이다 → **§13-6**.

**(4단계 시점 해석) 컴포넌트가 4개 늘었는데 총량은 610 줄었다.** 에이전트 4개 합(1,160)이 이전 3개(1,770)보다 적다 — `<example>` 블록 제거의 효과다.

| 에이전트 | before | after |
|---|---|---|
| `code-reviewer` | 650 | **270** |
| `feature-builder` | 570 | **270** |
| `root-cause-debugger` | 550 | **350** |
| `test-writer` | — | **270** (신규) |

**≤2,500은 12+3 기준으로 세운 목표였고, 15+4에는 맞지 않는다.** 컴포넌트당 169토큰이 현재 값이고, 이 아래로 내리려면 **스킬을 빼야 한다.** 실측 없이 세운 숫자를 지키려고 기능을 버리는 것은 본말전도이므로 **목표를 컴포넌트당 ≤180토큰**으로 바꾼다.

> **배운 것**: 스킬 하나당 70~150토큰이 **고정비**로 붙는다. 15개면 그것만 ~1,600이다. *"스킬을 늘리는 것은 공짜가 아니다"* — 개수 통제(§12 자기 점검표)의 근거가 추정에서 **실측으로** 바뀌었다.

### ⚠️ 이번(2026-08-23) 증가분에 대한 자기 점검
스킬 14→**15**, 에이전트 3→**4**, 템플릿 5→**6**. 위 인용과 정면으로 부딪히므로 근거를 남긴다.

| 늘어난 것 | 신규 발명인가 | 무엇을 대신하나 |
|---|---|---|
| `test-writer` | ❌ | `feature-builder`에서 **테스트 책임을 덜어낸다.** 총량 +1이지만 각각은 더 단순해진다(구현자는 "빨간 걸 초록으로", 작성자는 "어떻게 깨지나"만) |
| `why-logictree` | ❌ | **이미 존재하던 스킬의 배선.** 만든 게 아니라 비어 있던 DESIGN 칸에 꽂았다 |
| `testing.md` | ❌ | **누락 수리.** `tdd-guard.sh`가 이미 있는데 판정 근거가 없었다 — 없던 걸 더한 게 아니라 있던 게이트의 빠진 절반 |

**신규 발명 0개.** 늘어난 3개 전부가 *이미 있는 것을 옮기거나, 이미 있는 것의 빠진 짝을 채운 것*이다. 과설계 신호는 **"새로 지어낸 규칙이 느는 것"**이지 개수 자체가 아니다 — 다만 다음 증가부터는 이 표를 채울 수 있는지 먼저 본다.


---

## 13. `task-observer` — 원본 커스터마이즈 (2026-09-06)

원본: `iamneilroberts/claude-skills` `skills/task-observer/SKILL.md`. 세션을 상시 관찰해 패턴·교정·방법론을 로그에 쌓고 스킬 생성을 제안하는 메타 스킬.

### 13-1. §12 자기 점검표 — 이번 증가분

스킬 20→**21**. §12가 *"다음 증가부터는 이 표를 채울 수 있는지 먼저 본다"*고 했으므로 채운다.

> ⚠️ **§12의 실측(15 skills)은 이미 낡았다.** 그 뒤 `slack-writing`·`notion-writing`·design 3종이 들어와 계측 없이 **20**이 돼 있었다. 이 표를 채우는 관행이 2026-08-23 이후 한 번도 안 지켜졌다는 뜻이다.

| 늘어난 것 | 신규 발명인가 | 무엇을 대신하나 |
|---|---|---|
| `task-observer` | ❌ | **`BACKLOG.md`가 이미 요구하던 "세는 주체".** 서두는 *"세는 주체가 없는 조건은 쓰지 않는다"*고 선언했는데 3행(`evals/`·`testing-patterns.md`·`implementation-patterns.md` 7번째)이 세는 주체 없이 남아 있었다. `testing.md`와 같은 유형의 **누락 수리** — 없던 걸 더한 게 아니라 **있던 규칙의 빠진 절반** |

**신규 발명 0개.** 세는 규칙(`habit.md:78` "3번부터")도 승격 경로(§1 #8 "2번째 레포 실사용 → 3번째부터")도 이미 있던 것이고, 이 스킬은 그 둘을 잇는 계수기다.

### 13-2. 원본에서 고친 6가지

| # | 원본 | 여기 | 근거 |
|---|---|---|---|
| 1 | `skill-observations/` 3종 신설(로그·원칙·archive) | **`.claude/observations.md` 1파일** | 축적소를 늘리지 않는다. `rules/` 밖이라 상시 로드 아님 |
| 2 | 세션마다 관찰을 append | **패턴 1개 = 행 1개, `횟수`를 올린다** | append면 파일이 자라고, 자라면 안 읽는다. §12 "빈 축적소"의 반대 실패 |
| 3 | 발견하면 스킬을 제안 | **기본 종착지가 `rules/` 한 줄.** 스킬은 여러 단계를 매번 같은 순서로 밟을 때만 | §12 실측 — 스킬 하나당 **70~150토큰 고정비**. 한 줄로 끝날 것을 스킬로 만들면 매 세션 비용을 낸다 |
| 4 | 7일 주기 자동 주간 리뷰 | **자동 주기 없음.** SDD REFLECT 끝 + `harness-doctor` 호출 시 | 새 주기 장치를 만들지 않는다. 회수 지점이 이미 둘 있다 |
| 5 | CLAUDE.md에 트리거를 박아 상시 관찰 | **상시 관찰 안 함.** 되짚기 방식 | `CLAUDE.md.tmpl` 주석이 *"항상 로드되므로 여기 한 줄은 매 세션 비용"*이라고 스스로 선언했다. 되짚기가 놓치는 게 확인되면 훅으로 → `BACKLOG.md`에 승격 조건 등재 |
| 6 | open-source / internal 스킬 분류 + CC BY 4.0 | 삭제. 대신 **🔴 회사 정보 스크럽** | 개인용이라 라이선스 분류가 무의미. 진짜 제약은 `README.md`의 *"개인 계정 repo이므로 회사 고유 정보 한 줄도 금지"* — `BACKLOG.md`로 올릴 때만 걸린다 |

**원본에서 그대로 가져온 것 1개**: *"번호는 로그 파일을 실제로 읽어서 매긴다, 기억으로 매기지 않는다."* 3회 규칙이 도는 유일한 근거라 규율째 유지했다.

### 13-3. 관찰 대상을 3종으로 좁힌 이유

원본은 패턴·교정·"잘 된 방법"까지 담는다. **"잘 된 것"을 빼고** 재지시·재교정·불발 3종만 남겼다 — 칭찬이 섞이면 계수기가 회고록이 되고, 회고록은 열어봐야 할 이유가 없어진다. 이 vault의 실측 실패(빈 칸 과다)와 같은 계열이다.

### 13-4. 컨텍스트 비용

`description` **128자** — `harness-doctor`(189)·`brain-sync`(188)보다 짧고, §12가 문제로 지목한 `why-logictree`(289)의 절반 이하.

실측: **always-on ~100 tok · on-invoke ~1.9k**. 21개 스킬 중 세 번째로 싸다(`commit`·`pr-write` ~80 다음). 본문은 부를 때만 로드된다.

### 13-5. 🔴 재계측 결과 (2026-09-06) — 목표가 이미 깨져 있었다

`claude plugin details claude-harness` 실측. **task-observer 때문에 깨진 게 아니라, 재기 전부터 깨져 있었다.**

| 시점 | 구성 | Always-on | 컴포넌트당 |
|---|---|---|---|
| §12 마지막 기록 (2026-08-23) | 15 + 4 | 3,218 | 169 |
| **재계측 직전** (0.1.1) | 20 + 4 | **4,600** | **192** ❌ |
| task-observer 설치 후 (0.2.0) | 21 + 4 | **4,732** | **189** ❌ |

**계측 공백 14일에 +1,382이 조용히 늘었다.** `slack-writing`·`notion-writing`·design 3종이 §12의 자기 점검표를 채우지 않고 들어왔고, 그 사이 **목표(≤180)를 넘긴 시점을 아무도 못 봤다.** §12가 예고한 실패가 그대로 일어났다 — *"조용히 자란다"*.

`task-observer` 자신은 **~100 always-on**(21개 스킬 중 3번째로 쌈. `commit`·`pr-write` ~80 다음)이라 컴포넌트당 평균을 **192 → 189로 내렸다.** 늘리면서 평균을 낮춘 유일한 방법은 평균보다 싼 것을 넣는 것이고, 그건 우연이 아니라 §13-2 #1·#5(1파일·상시 관찰 없음)의 결과다.

**가장 큰 덩어리는 스킬이 아니라 에이전트다** — 4개가 **1,370**으로 전체의 29%다.

| 상위 | always-on |
|---|---|
| `root-cause-debugger` | ~410 |
| `ai-readiness-cartography` | ~330 |
| `code-reviewer` · `test-writer` · `feature-builder` | 각 ~320 |
| `design-plan` | ~270 |

> 🙋 판단 대기였고 **2026-09-06 ②로 결정됐다 → §13-6.**

> **다음부터**: 스킬을 늘린 커밋에서 `claude plugin details`를 돌리고 §12 표에 1행 추가한다. 이 규칙 자체가 3회 안 지켜지면 `task-observer`의 **불발** 관찰 대상이다.

### 13-6. ✅ 결정 (2026-09-06) — ② 상위 6개 삭감. 목표 ≤180 유지

**①(목표 상향)을 택하지 않았다.** §12의 근거는 *"기능을 버리는 것은 본말전도"*인데 **②는 버리는 기능이 0**이라 그 논리의 전제가 성립하지 않는다. 그리고 §12 때는 초과 원인이 **설계 결정**(12+3→15+4)이었지만 이번 원인은 **감시 실패**라, 목표를 실측에 맞추면 그 실패를 사후 승인하게 된다.

**깎은 것은 `description`뿐이고, 그중에서도 라우터가 안 쓰는 몫이다.**

always-on을 키우는 변수는 `description` 길이 **하나**다 — 25개 컴포넌트의 description 글자수 순위가 always-on 순위와 완전히 일치한다(본문 길이는 무관. 그쪽은 on-invoke로만 든다). 상위 6개에는 세 종류가 섞여 있었다.

| 종류 | 라우터가 쓰나 | 처분 |
|---|---|---|
| 트리거 — 언제 부르나 | ✅ | 유지 |
| 경계 — `Does NOT x (other-agent)` (§8 경계 계약) | ✅ | 유지 |
| **자기 지시 — 부른 뒤 무엇을 읽나** | ❌ | **제거** |

세 번째는 라우터가 절대 안 읽는데다 **6개 전부 본문에 같은 내용이 이미 있었다** (대조: `root-cause-debugger.md:18-21` · `feature-builder.md:18` · `test-writer.md:20-22` · `code-reviewer.md:16,20,22` · `ai-readiness-cartography/SKILL.md:37,141` · `design-plan/SKILL.md:6,36,61`). §12가 `<example>` 블록을 걷어낸 것과 **같은 유형** — description에서 body 재료를 빼는 것이다.

**실측.** 설치본을 건드리지 않으려고 25개를 복제한 임시 플러그인으로 원본·삭감본을 각각 쟀고, 배포 후 실제 값으로 확인했다.

| | 원본 | 삭감본 | 델타 |
|---|---|---|---|
| 상위 6개만 (복제본) | 1,344 | 982 | **−362** |
| 25개 전체 (복제본) | 4,837 | 4,475 | **−362** |
| **실제 플러그인 0.2.0 → 0.2.1** | **4,732** | **4,370** | **−362** |

세 측정의 델타가 같다. **4,370 / 25 = 컴포넌트당 174.8** → 목표 ≤180 통과.

| 컴포넌트 | before | after |
|---|---|---|
| `root-cause-debugger` | 420 | **290** |
| `ai-readiness-cartography` | 330 | **260** |
| `code-reviewer` | 320 | **300** |
| `test-writer` · `feature-builder` | 각 320 | 각 **270** |
| `design-plan` | 270 | **180** |

> ⚠️ 개별 값은 총량이 줄며 재정규화돼 표시된다 — 비교는 **총량**으로 한다.

**목표에 검사 주체를 붙였다.** ≤180이 14일간 깨져 있던 원인은 숫자가 틀려서가 아니라 **그 숫자를 보는 주체가 없어서**다. `harness-doctor` 검사 5는 `Always-on`을 **보고만 하고 판정하지 않았다** → 임계 판정을 붙였다(초과 시 ⚠️ + `always-on` 상위 description 지목). `BACKLOG.md` 서두의 *"세는 주체가 없는 조건은 쓰지 않는다"*를 **목표 수치에도** 적용한 것이다.

### 13-7. 실제 동작 검증 (2026-09-06) — 만든 것과 도는 것은 다르다

배포해놓고 한 번도 안 돌려봤던 것을 돌렸다. 대상은 하네스가 실제로 깔린 유일한 레포(`harness.json` + `rules/` 5개).

| 확인 | 결과 |
|---|---|
| 이름으로 호출되나 | ✅ 플러그인 캐시에서 정상 해석 |
| `.claude/observations.md`가 §2의 2표 구조로 생성되나 | ✅ `열린 것` / `닫힌 것` |
| §3 "기억이 아니라 파일을 읽어서 센다" | ✅ 재호출 시 기존 행을 찾아 **횟수를 올린다**(새 행 추가 아님) |
| SDD REFLECT 끝에서 자동으로 불리나 | ⏳ 아직 셀 수 없다 — 아래 |

**실제 반복 1건을 잡았다** — 재교정 **6회**로 3회 기준 초과. *"브라우저에서만 드러나는 결함을 스펙(jsdom·스토리북)이 원리적으로 못 잡아 눈으로 발견한 뒤 고친다."* 기본 종착지(`rules/` 한 줄)가 **이미 6번 소진**됐는데 계열이 계속 재발한다 — 개별 한 줄은 인스턴스를 막고 **클래스를 못 막는다**. 스킬은 승격 제안 3줄을 내고 멈췄다(§금지 *"판정까지다"*). 설계대로다.

**자동 트리거 불발 카운트는 1이 아니라 0이다.** 배포가 `a39ea9c`(2026-09-06 16:29)인데 그 레포 마지막 커밋은 2026-09-04 19:22 — **배포 이후 REFLECT가 한 번도 안 돌아 불발할 기회가 없었다.** 사건이 없는데 1로 적으면 수치 창작이므로 `observations.md`에 **횟수 0 · 예약 관측**으로 남겼다. 다음 실무 REFLECT가 첫 관측 시점이다.

**검증하다 결함 1건.** §13-2 #4가 회수 지점을 둘로 정했는데(`REFLECT 끝` + `harness-doctor`) **뒤쪽에 배선이 없었다** — `sdd/SKILL.md:44`에만 있고 `harness-doctor` 검사 1~5 어디에도 없었다. **검사 6**으로 배선했다. `/lint`가 말하는 *"선언과 실재의 불일치"*가 이 플러그인 자신에게서 나온 것이다.

**별건 카운트**: §12의 *"스킬 늘린 커밋에서 계측하고 1행 추가"* 관행 불발 = **2/3** (`be61bfb` 글쓰기 2종 · `e6252f5` design 3종. `a39ea9c`에서는 지켰다). 3에 닿으면 §13-5의 예고대로 `task-observer`의 불발 대상이 된다.

---

## 14. 코드 이해 3종 반입 + `understand-anything` 의존 (2026-09-18)

출처 발표: Geoffrey Litt, *Understanding is the new bottleneck* (AI Engineer World's Fair 2026). 요지는 **검증은 에이전트에 넘겨도, 다음 루프에 참여하기 위한 이해는 못 넘긴다**는 것이다. 이 플러그인의 REVIEW 단계에는 검증(`sdd-review`·`code-reviewer`)만 있고 **사람이 변경을 이해했는지 확인하는 칸이 없었다.**

### 14-1. §12 자기 점검표 — 이번 증가분

스킬 21→**24**, 의존 플러그인 0→**1**.

| 늘어난 것 | 신규 발명인가 | 무엇을 대신하나 |
|---|---|---|
| `explain-diff-html` · `explain-diff-notion` | ❌ 발표자 gist 원문 그대로 (`geoffreylitt/a29df1b5f9865506e8952488eac3d524`, 2026-09-17본) | **대신하는 것 없음 — 순수 추가.** 배경 → 직관 → 코드 워크스루 → 퀴즈 5문항. 퀴즈를 못 풀면 리뷰 요청을 안 한다는 게이트 |
| `plannotator-visual-explainer` | ❌ `backnotprop/plannotator` 원문 그대로 (MIT·Apache-2.0 이중 라이선스 → `LICENSE`에 MIT 동봉) | 대신하는 것 없음. 같은 칸의 시각화판(파일 투어·위험 지도·집중할 곳) |
| `understand-anything` (`dependencies`) | ❌ 외부 플러그인 | 복사가 불가능해서 의존으로 걸었다 — 스킬이 빌드된 플러그인 루트(`packages/core/dist`, pnpm)를 찾는다 |

**신규 발명 0개. 다만 §12·§13-1과 달리 "이미 있던 것의 빠진 짝"이라고 부를 근거는 없다.** 사용자 요청으로 들인 **기능 추가**다. 과설계 신호(지어낸 규칙 증가)는 0이지만 개수는 늘었다.

### 14-2. 원문을 건드리지 않은 이유와 대가

- 세 스킬의 본문과 `description` 모두 **무수정**. 원문 갱신을 diff로 따라가기 위해서다. 대가로 `plannotator-visual-explainer`의 description은 §13-6 기준이면 삭감 대상(자기 지시 섞임)인데 그대로 뒀다
- 제외한 파일 1개: plannotator `SKILL.test.ts` — 원 레포의 bun 테스트용이고 스킬 실행과 무관
- 🔴 **런타임 의존은 플러그인이 설치하지 않는다.** `plannotator-visual-explainer`는 결과를 `plannotator annotate`로 띄우므로 바이너리가 없으면 전달 단계에서 멈춘다(`curl -fsSL https://plannotator.ai/install.sh | bash -s -- --minimal` — 바이너리만). `explain-diff-notion`은 Notion MCP가 있어야 한다
- explain-diff gist에는 **라이선스 표기가 없다.** 이 레포가 private이라 들였다 — 공개로 바꾸면 이 항목부터 재검토한다

### 14-3. `understand-anything` 의존

`plugin.json` `dependencies`에 `{ name, marketplace: "understand-anything" }`, `marketplace.json`에 `allowCrossMarketplaceDependenciesOn`. 버전 제약은 걸지 않았다(마켓플레이스 최신을 따른다).

| 대가 | 내용 |
|---|---|
| 컨텍스트 | harness를 켜면 UA도 켜진다. 스킬 9 · 에이전트 10 · always-on **~1,146** (2.9.7 실측). **아래 §14-4 harness 합계에는 안 잡힌다** — `harness-doctor` 검사 5가 보는 숫자 밖이다 |
| 로드 실패 | UA 마켓플레이스가 등록 안 된 환경에서는 `dependency-unsatisfied`로 **harness 자체가 비활성화**된다 → README 설치 절 첫 줄에 마켓플레이스 추가를 올렸다 |
| 훅 | UA 훅 2개(PostToolUse·SessionStart)는 `.understand-anything/config.json`에 `autoUpdate: true`가 있는 레포에서만 동작한다. 그 외에는 조건문에서 끝난다 |

### 14-4. 컨텍스트 비용

| | 구성 | Always-on | 컴포넌트당 |
|---|---|---|---|
| 0.2.2 설치본 (`claude plugin details`) | 21 + 4 | 4,412 | 176.5 |
| 0.3.0 로컬 (`claude --plugin-dir . plugin details claude-harness@inline`) | 24 + 4 | **4,650 (+238)** | **166.1** |

목표 ≤180 통과. 3개를 늘리고도 평균이 내려간 건 추가분 평균(~79)이 기존 평균보다 싸서다. 개별 값은 총량에 따라 재정규화돼 표시되므로(§13-6 ⚠️) 스킬별 기여는 적지 않는다.

**§12 관행("스킬 늘린 커밋에서 계측하고 1행 추가")은 이번에 지켰다** — 불발 카운트 2/3 유지.

---

## 15. `find-skills` 이식 (2026-09-19)

출처: superpowers 의 **Codex CLI 서브커맨드** `superpowers-codex find-skills`. 6.3.0 에 커맨드 실물은 남아 있지 않고 `RELEASE-NOTES.md` 의 기술만 있다 — *"키워드로 스킬을 찾아 Read 도구에 바로 붙일 수 있는 SKILL.md 전체 경로를 출력"*, 그리고 *"double skills/ prefix 버그 수정"*. 그 기술을 기준으로 재구현했다.

### 15-1. §12 자기 점검표 — 이번 증가분

스킬 24→**25**.

| 늘어난 것 | 신규 발명인가 | 무엇을 대신하나 |
|---|---|---|
| `find-skills` | ❌ superpowers Codex 서브커맨드 이식 (원문 소실 → RELEASE-NOTES 기술 기준 재구현) | **대신하는 것 없음 — 순수 추가.** Claude Code 는 세션에 스킬 **목록**을 주입하지만 **원문 경로**는 주지 않는다 |

🔴 **중복 우려를 남겨 둔다.** 원본이 Codex 용인 이유는 거기엔 스킬 목록 자동 주입이 없어서다. Claude Code 에서 이 스킬이 버는 것은 "원문을 읽으러 갈 경로" **하나뿐**이다. 사용자가 그것을 알고 원본 이식을 선택했다. 불려서 값을 못 내면 `task-observer` **불발 계수** 대상이다.

### 15-2. 이식하며 고친 것 — 원본에 없던 Claude Code 고유 함정 3개

전부 이 머신에서 실측했다(2026-09-19). 셋 다 **조용히 누락되는** 종류라 안 고치면 도구가 거짓말을 한다.

| # | 함정 | 안 고치면 | 고친 것 | 스캔 수 |
|---|---|---|---|---|
| 1 | 캐시에 옛 버전이 그대로 남는다 (`claude-harness` **7개**) | 같은 스킬이 7번 나오고 6개가 죽은 경로 | `installed_plugins.json` 으로 켜진 버전 1개만 (cwd 포함 project > user > 첫 항목) | 179 → 53 |
| 2 | `~/.claude/skills/*` **13개가 심볼릭 링크** (`~/.agents/skills/`) | `isDirectory()` 가 false → 통째로 누락 | 링크를 따라가는 `statSync` | 53 → **66** |
| 3 | anthropic 계열 **12개**가 `skills/synced/<uuid>/<skill>/` **두 겹** 아래 | 누락 | SKILL.md 없는 폴더는 깊이 2까지 하강 | 66 → **78** |

**남은 한계**: 디스크에 없는 **내장 스킬**(`code-review`·`dataviz`·`artifact-*` 등, CLI 에 실려 배포)은 못 잡는다. SKILL.md 에 명시했다.

**경로 해석**: `CLAUDE_PLUGIN_ROOT` 는 **훅에만** 주입되고 Bash 도구 환경에는 안 들어온다(실측). 그래서 SKILL.md 가 `ls -d ~/.claude/plugins/cache/*/claude-harness/*/... | sort -V | tail -1` 로 푼다 — 함정 1과 같은 이유다.

### 15-3. 컨텍스트 비용

`claude --plugin-dir . plugin details claude-harness@inline` 실측.

| | 구성 | Always-on | 컴포넌트당 |
|---|---|---|---|
| 0.3.0 | 24 + 4 | 4,650 | 166.1 |
| 0.4.0 | 25 + 4 | **4,822 (+172)** | **166.3** |

`find-skills` 개별: always-on **~130** · on-invoke ~1.1k. 목표 ≤180 통과.

### 15-4. BACKLOG 승격 후보

| 항목 | 승격 조건 |
|---|---|
| `hooks/test.sh` 에 find-skills 회귀 케이스 | 스캔 수가 **조용히 0 또는 급감한 사례 1건** — 15-2 의 세 함정이 전부 무출력 실패라 사람이 못 본다. 1건이면 바로 넣는다(3의 법칙 예외: 실패가 침묵이다) |

---

## 16. step 단위 모델 오버라이드 + `retries` 계수기 (2026-09-19)

사용자 질문에서 나왔다 — *"feature-builder 모델은 opus로 안 올려도 됨?"*. §7 의 배정(`feature-builder` = sonnet, 나머지 셋 = opus)은 **"정해진 것을 만드는 일 vs 탐색"** 으로 갈랐고 그 판단은 유지한다. 다만 **판단을 바꿀 근거를 세는 장치가 없었다.**

### 16-1. 왜 지금 안 올리나

| | |
|---|---|
| 근거 | §7 — sonnet 전제는 **step 이 자기완결적이고 테스트가 먼저 빨갛다**(§8-e). 전제가 지켜지면 충분하다 |
| 비용 | `harness-run` 은 **step 마다** 띄운다. 네 에이전트 중 유일하게 N배로 곱해지는 자리다 |
| 실측 | 0건. bv-builder 는 `phases/` 가 아직 없어 구현 step 을 한 번도 안 돌렸다 |

**느낌으로 올리지 않는다.** 모델을 올려야 풀리는 step 은 대개 **분해가 덜 된 step** 이고, 그때 고칠 것은 모델이 아니라 step 파일이다.

### 16-2. 넣은 것 2개

| # | 무엇 | 어디 |
|---|---|---|
| 1 | `index.json` step 에 **선택 `model`** — 그 step 만 다른 모델로. 없으면 에이전트 정의값 | `harness` §4 (스키마) · `harness-run` §3-2 (Agent 도구 `model` 로 전달) |
| 2 | **`retries` 영속화** — 재시도할 때 +1 해서 index.json 에 남긴다 | `harness-run` §3-3 |

🔴 **2번이 1번보다 중요하다.** `harness-run` 은 이미 retry 를 세고 있었지만 **어디에도 남기지 않아** 루프가 끝나면 사라졌다. BACKLOG 규칙(*"조건은 셀 수 있어야 한다 — 세는 주체가 없는 조건은 쓰지 않는다"*)을 지키려면 계수기가 파일에 있어야 한다.

### 16-3. FE/BE 중립성 — 같은 질문에서 확인한 것

`feature-builder` 본문에 FE/BE 고유어 **0건**. 도메인 판정은 전부 `.claude/{harness.json,rules,references}` 로 위임돼 있고, 이는 §1 반면교사(*"에이전트에 규칙 인라인 — FSD 금지 6벌"*)를 고친 결과다. **에이전트는 손댈 것이 없다.**

대신 **BE 레포에 깔 때 rules 가 비는 자리 3곳**을 `harness-init` 인터뷰 후보로 남긴다.

| 빈 곳 | 지금 | BE 에서 필요한 것 |
|---|---|---|
| "상태를 전부 처리" 목록 | 로딩·에러·빈 값·경계 | 트랜잭션 경계 · 멱등성 · 부분 실패 · 동시성 |
| `verify` | format·lint·typecheck·test·build | 마이그레이션 · DB 띄우는 통합테스트 |
| `functional-programming.md` 의 `paths:` | `apps/*/src/**`·`packages/*/src/**` | `server/`·`internal/` 구조면 **매칭 자체가 안 된다** |

---

## 17. `/revise-claude-md` REFLECT 배선 (2026-09-27)

CLAUDE.md 유지 도구는 **주기가 둘**이다 — 2주(`claude-md-improver`)와 세션마다(`/revise-claude-md`). 하네스는 앞쪽을 이미 위임 선언해 뒀지만(`harness-doctor` description: *"CLAUDE.md 자체의 품질 감사는 공식 claude-md-management 플러그인이 하므로 여기서 하지 않는다"*) **뒤쪽은 어디에도 배선이 없었다.** §13-7이 잡은 것과 같은 유형이다 — 회수 지점을 둘로 정하고 한쪽만 배선한 것.

### 17-1. §12 자기 점검표 — 이번 증가분

스킬 **25 유지**. 신규 컴포넌트 0 · `description` 변경 0.

| 늘어난 것 | 신규 발명인가 | 무엇을 대신하나 |
|---|---|---|
| REFLECT의 `revise-claude-md` 호출 | ❌ 외부 공식 플러그인 명령을 부르는 한 줄 | 하네스가 이미 위임을 선언한 짝의 **빠진 절반.** 새 파일·새 스킬·새 주기 장치 0 |

**always-on 델타 0.** 재계측은 하지 않았다 — 근거는 §13-6 실측(*"always-on을 키우는 변수는 `description` 길이 하나. 본문 길이는 무관"*)이고 이번 변경은 본문·README·템플릿뿐이다.

### 17-2. 하드 의존(`dependencies`)으로 걸지 않았다

`understand-anything`은 `dependencies[]`지만 이건 아니다. `README:10`이 그 대가를 적어 뒀다 — *"없으면 harness가 비활성화된다."* **CLAUDE.md 한 줄을 못 건지는 손실과 하네스 전체가 죽는 손실을 맞바꾸지 않는다.** 형식은 `changeset`의 자기 skip과 같게 했다(릴리스 도구가 없으면 스스로 건너뛰고 그 사실을 보고).

### 17-3. 🔴 원본 종착지를 덮은 이유 — 그대로 쓰면 CLAUDE.md가 부푼다

원본 명령(Step 2~3)은 종착지를 `CLAUDE.md` / `.claude.local.md` 둘로만 가른다. 하네스는 CLAUDE.md를 **~40줄(CRITICAL+링크)**로 묶어 놨으므로, 매 세션 한 줄씩 붙으면 **항상 로드되는 가장 비싼 층에 가장 값싼 것이 쌓인다.**

그래서 **호출은 원본대로 두고 종착지 판정만 하네스 것으로 덮었다** — `.claude/README.md`의 판정 한 줄(*"안 읽고 코드를 쓰면 규칙을 어기게 되나?"*) → `rules/non-obvious-patterns.md` 또는 `references/`, CLAUDE.md에는 CRITICAL·링크만.

> 배선하고 종착지를 안 고치는 것이 **안 배선한 것보다 나쁘다** — 2주마다 `claude-md-improver`가 찍을 *"간결성 D"*를 스스로 만드는 배선이 된다.

### 17-4. `commit` **앞**에 둔 이유

`templates/.claude/rules/non-obvious-patterns.md:16`이 이미 *"새 사고가 나면 한 줄 추가한다. **고친 커밋과 같은 PR에서**"*라고 선언했는데, 종전 REFLECT는 그 한 줄 추가를 `commit` **뒤**에 뒀다. 순서를 뒤집어 문서 한 줄이 같은 커밋에 실리게 했다. `brain-intake`·`brain-sync`는 종착지가 `_brain/`·통합 wiki라 커밋과 무관해 자리를 옮기지 않았다.

### 17-5. 세 환류 장치의 경계 (§8 경계 계약)

| 장치 | 무엇을 건지나 | 주기 | 종착지 |
|---|---|---|---|
| `revise-claude-md` | 이 세션에서 **말로 설명하고 흘린 것** (어떻게 일하나) | **매 세션** · 자동 수집 | `rules/` · `references/` · CLAUDE.md(CRITICAL만) |
| `brain-intake` → `brain-sync` | **도메인 지식** (무엇을 아는가) | raw가 쌓였을 때 | `_brain/wiki/` → 통합 wiki |
| `task-observer` | **반복 횟수** (같은 것을 몇 번 다시 시켰나) | REFLECT 끝 · `harness-doctor` | `observations.md` |

앞의 둘은 **줍는** 장치고 뒤는 **세는** 장치다. 겹치지 않는다 — 한 줄로 끝나는 것은 `revise`가 줍고, 그 계열이 3회 재발하면 `task-observer`가 승격을 건다.

### 17-6. 불발은 새 장치 없이 센다

이 배선이 안 돌면 그건 `task-observer` 3종 중 **불발**(스킬이 있는데 안 불린 것)이다. §13-2 #4·#5의 규율대로 **새 검사·새 주기 장치를 만들지 않는다.** 3회에 닿으면 훅 승격 후보로 `BACKLOG.md`에 올린다.

### 17-7. 2주 주기를 사람이 기억하지 않게 — `cadence-reminder.sh` 축 3

짝 플러그인의 나머지 반쪽(`claude-md-improver`, 권장 주기 2주)은 **사람이 호출해야 하는데 그게 잊힌다**는 문제가 남았다. 새 장치를 만들지 않았다 — `hooks/cadence-reminder.sh`가 **이미 그 문제를 푸는 방식으로 돌고 있었다.**

| 축 | 조건 | 환기 | 도입 |
|---|---|---|---|
| 1 함정 freshness | CLAUDE.md·rules 갱신 이후 `fix:` 3건 | `non-obvious-patterns.md` 한 줄 | 2026-08-23 |
| 2 지식 자본화 | `_brain/wiki` 갱신 이후 `feat:`·`refactor:` 5건 | `brain-intake` → `brain-sync` | 2026-08-23 |
| **3 CLAUDE.md 비대** | CLAUDE.md **>80줄** 또는 `.claude/rules/` 합계 **>400줄** | `claude-md-improver` | **2026-09-27** |
| **4 readiness 채점 공백** | 마지막 채점(`.claude/reports/<date>`) 이후 커밋 **20건** | `ai-readiness-cartography` | **2026-09-27** (§18-1) |

**날짜로 재지 않는 이유**는 기존 두 축과 같다 — 커밋 0인 2주는 감사할 것이 없고, 3일에 커밋 40개면 2주를 기다릴 이유가 없다. *"2주"는 위임한 도구의 권장값이지 이 레포의 조건이 아니다.*

**조건을 '낡음'이 아니라 '비대'로 잡았다.** 낡음은 축 1이 이미 재고 있어 겹치고, 무엇보다 §17의 배선으로 `revise-claude-md`가 **매 세션 쌓기 시작했다.** 쌓는 주체를 만들었으면 깎는 주체도 같이 걸어야 한다 — 두 도구는 짝이고 트리거는 *쌓인 양*이어야 인과가 맞는다.

**임계 근거(실측)**: 템플릿 `CLAUDE.md` 45줄(README 목표 ~40) · `rules/` 4개 합계 180줄 → 각각 **2배**. 고치면 임계 아래로 내려가 스스로 조용해진다(self-clearing).

**회귀 케이스를 같이 넣었다**(`hooks/test.sh` 케이스 5, 18개 통과). 임계 검사는 §15-4가 말한 **무출력 실패** 계열이라 — 조용히 안 터져도 아무도 모른다 — 임계 아래(조용)와 초과(환기) 양쪽을 건다.

---

## 18. `ax-framework` 6축 대조 — 공백 3개 메움 (2026-09-27)

기준: 개인 vault의 `wiki/concepts/ai/ax-framework.md`(AX 마인드셋 & 운영 프레임워크, 2026-07-13). 이 플러그인을 6축으로 대조했다.

| 축 | 하네스 실재 | 판정 |
|---|---|---|
| §1 조직 100x | `DESIGN.md` Context *"최종 독자는 나 혼자"* · README 🔴 회사 정보 금지 | **범위 밖(의도).** 결함 아님 |
| §2-a 컨텍스트 부재 | 컨텍스트 3층 | ⚠️ 축이 다름 → **18-3** |
| §2-b AI-hostile | `ai-readiness-cartography` + `understand-anything` | ✅ |
| §3 in → on | 사람 체크포인트 7개 · `harness-run` hands-off | ✅ 구조 / ⚠️ 원장 없음 → **18-2** |
| §4 자산화 | 3층 + `brain-intake`→`brain-sync` | ✅ **ax보다 한 걸음 앞** — 프로젝트 밖으로 배출한다 |
| §5 A2A | PRD 수용 조건 → `test-writer` 입력 · RED/GREEN · `tdd-guard` | ✅ **최강점** |
| §6 지속 개선 | fixer만 있음(`revise-claude-md`·`task-observer`) | 🔴 공백 → **18-1** |

**§5가 ax를 앞선다.** ax는 *"완료가 뭔지를 에이전트 스스로 판단할 수 있어야 한다"*까지만 말하는데, 하네스는 그것을 **실행되는 계약**으로 박았다(`sdd/SKILL.md:27` → RED는 실패해야 통과 → GREEN은 테스트 파일을 건드리면 실패 → `validate-session-end`가 빈 `verify.test`를 고발).

**병렬 A2A는 일부러 안 맞춘다.** ax의 *"에이전트들이 나눠 가짐"*에 맞춰 `harness-run`을 병렬화하면 §1 #2가 밝힌 **의도된 컨텍스트 격리 장치**를 버리게 된다. 문구를 맞추려고 설계를 버리지 않는다.

### 18-1. §6 — 측정이 "비용"에만 있고 "품질"에는 없었다

§12·§13-5·§15-3은 토큰을 집요하게 잰다(재계측으로 −362까지 추적). 그런데 **산출물이 좋아졌는지를 재는 숫자는 0이었다.** ax의 *"측정되지 않는 건 개선되지 않는다"*가 절반만 적용된 상태다.

| 무엇 | 전 | 후 |
|---|---|---|
| 채점기 | `weekly-readiness-check.sh` + `score.py`가 **있는데 `hooks.json`에 없다**(파일 주석: *"아직 cron/CI 에 등록하지 않는다"*) | `cadence-reminder.sh` **축 4**가 공백을 환기 |
| 골든셋 | 없음. `BACKLOG:16`의 `evals/`는 *스킬이 불리나*(트리거 회귀)라 **다른 물건** | `BACKLOG` 1행 추가 — 조건은 `observations.md`의 **`닫힌 것` 5행** |

🔴 **축 4는 채점을 실행하지 않는다.** Stop 훅은 읽기 전용이고(`hooks/test.sh` 케이스 4), `python3` + HTML 생성을 매 턴에 얹지 않는다. **환기만 하고 실행은 사람·모델이 한다.** 회귀 케이스로 *"채점까지 돌리면 실패"*를 박았다(케이스 6).

**골든셋을 새로 만들지 않는 이유**: 실패 사례는 `observations.md`(재교정·불발)와 `phases/*/index.json`(`error_message`)에 **이미 쌓인다.** 새 축적소를 열면 §12가 지목한 *"빈 축적소"*를 또 만든다. 5행이 차면 그 5개가 첫 골든셋이다.

### 18-2. §3 — "못 맡긴 일"이 어디에도 안 쌓였다

ax의 핵심 통찰은 못 맡기는 순간을 잡아 **툴 이슈냐 컨텍스트 이슈냐**로 분류하라는 것이다. 하네스에서 그 순간(`harness-run:40-41`의 `blocked`·3회 실패)은 사람에게 보고하고 끝났고, `blocked_reason`은 그 task의 `index.json` 안에서만 살았다.

`task-observer` 관찰 대상을 **3종 → 4종**으로 넓혔다(**미위임**). §13-3이 3종으로 좁힌 근거는 *"칭찬이 섞이면 계수기가 회고록이 된다"*인데, **미위임은 칭찬이 아니라 실패**라 그 논리에 걸리지 않는다. 오히려 §13-3과 같은 계열이다.

- **세는 주체는 이미 있었다** — `phases/*/index.json`의 `blocked_reason`·`retries`. 새 파일 0.
- **사건 1건이 아니라 같은 사유 3건부터**다. 한 번의 `blocked`는 그 자리에서 사람이 처리했다.
- 종착지가 다른 셋과 다르다 — 분류가 먼저고(툴/컨텍스트), 컨텍스트 부족이면 **step 분해를 다시**다. §16의 판정을 그대로 쓴다.
- 비용: `description` +14자 → always-on **+17 tok** (§18-5에서 실측).

### 18-3. §2-a — 폴더 경계에 판정이 없었다

하네스의 3층은 **로드 방식** 축(항상/조건부/수동)이고 ax가 말하는 계층은 **폴더 경계** 축이다. `rules/`의 `paths:`로 대체된다고 볼 수도 있었지만 **어디에도 그렇게 적혀 있지 않아**, 읽는 사람이 *커버됐다*인지 *빠졌다*인지 판단할 수 없었다. 판정을 적었다(README·`templates/.claude/README.md`).

**판정: 하위 `CLAUDE.md`를 두지 않는다. 폴더 경계는 `paths:` glob으로 표현한다.**
근거는 계측이다 — `harness-doctor` 검사 5는 `rules/*.md`만 잰다. 하위 `CLAUDE.md`는 **재는 대상이 아니므로 조용히 자란다**. §13-5가 당한 실패(*"계측 공백 14일에 +1,382이 조용히 늘었다"*)와 같은 유형을 구조로 막는 쪽을 골랐다.

### 18-4. 이번 변경의 §12 자기 점검표

스킬 **25 유지** · 훅 **신규 0**(기존 `cadence-reminder.sh`에 축 2개 추가) · 새 파일 **0**.

| 늘어난 것 | 신규 발명인가 | 무엇을 대신하나 |
|---|---|---|
| cadence 축 3·4 | ❌ 기존 훅의 축 추가 | 축 1·2와 같은 원리(**날짜가 아니라 커밋 수·줄 수**) |
| `task-observer` 미위임 | ❌ 관찰 대상 확장 | `index.json`에서 죽던 `blocked_reason`의 종착지 |
| `BACKLOG` 골든셋 1행 | ❌ 조건만 등재 | 아직 만들지 않는다. 세는 주체는 `task-observer` |

회귀 테스트 `hooks/test.sh` **21 통과 · 0 실패**(케이스 5·6 추가).

### 18-5. 컨텍스트 비용 (실측 2026-09-27)

`claude plugin details claude-harness` (배포 후 설치본).

| | 구성 | Always-on | 컴포넌트당 |
|---|---|---|---|
| 0.4.0 | 25 + 4 | 4,822 | 166.3 |
| **0.5.0** | **25 + 4**(불변) | **4,839 (+17)** | **166.9** ✅ |
| **0.6.0** | **26 + 4**(`brain-walk` 합류) | **5,074 (+235)** | **169.1** ✅ |

늘어난 17은 전부 `task-observer` description의 4종화(+14자)다. 스킬·에이전트 수는 그대로고 훅은 모델 컨텍스트 비용이 0이다(`Hooks (3) — harness-only`). 목표 **≤180** 통과.

> §13-5가 만든 관행(*"스킬을 늘린 커밋에서 계측하고 1행 추가"*)을 이번엔 지켰다. 직전 기록은 **2/3 불발**이었다.

## 19. 스택 팩 + `brain-walk` 합류 (0.6.0, 2026-09-27)

**왜**: `harness-init`은 사실상 TS 전용이었다(조건 분기 "TS면" 하나, 훅은 prettier·`.test.ts` 짝만). Kotlin/Spring 레포에 깔면 규칙·검증 후보·훅이 전부 비었다. 보일러플레이트(코드 뼈대)는 별도 레포 `jtwjs/stack-kits`가 맡고, 하네스는 **AI 환경의 정본**만 맡는다 — 코드 뼈대는 스스로 CI로 검증되고 의존성이 갱신돼야 해서 플러그인 캐시에 둘 수 없다.

**BE/FE 플러그인을 나누지 않은 이유**: 절차 스킬(sdd·harness-run·리뷰)은 스택과 무관하게 공통이고, 템플릿은 상시 컨텍스트 비용이 0이다. 분리 트리거는 여전히 "동료가 설치하겠다고 할 때"(9/26 결정). 팩이 디렉터리 단위라 그때 `git mv` 한 번이다.

| 무엇 | 어디 |
|---|---|
| 판정 표(빌드 파일 기준, 추측 금지) | `templates/stacks/README.md` — `harness-init` §1-b와 `brain-walk` §0이 **같은 표**를 본다 |
| 팩 | `templates/stacks/{kotlin-spring,nextjs}/` = `pack.md`(verify 후보·tdd 제안·CI 셋업) + `rules/*.md`(전부 `paths:`) |
| 기록 | `harness.json.stacks.packs` = `[{pack, root}]`. 모노레포는 `root`마다 팩, 규칙 `paths:` 앞에 root |
| 정합 검사 | `harness-doctor` §7 |
| 훅 | `auto-format`: `.kt`는 `ktlint` CLI가 있을 때만(gradle은 편집마다 느림) · `tdd-guard`: `src/main/…/Foo.kt` ↔ `src/test/…/FooTest.kt` |

- TS 규칙 두 파일(`typescript`·`functional-programming`)은 **옮기지 않았다** — 이 문서와 `implementation-patterns.md`가 현재 경로를 참조한다. `nextjs` 팩은 그 위에 Next 전용만 더한다
- `nextjs` 팩은 Next 16 기준: `next lint` 제거·`next build`가 린트 안 함(v16 업그레이드 문서, context7 확인)
- `brain-walk`(코드→`_brain` 5장)를 스킬로 합류시켰다. 스킬 수 25 → 26

**검증**: `hooks/test.sh` **27 통과 · 0 실패**(케이스 3-b Kotlin 짝 5 · 3-c ktlint 부재 1 추가). `viewus-cms-consumer` 사본: 판정 kotlin-spring, `ktlintCheck`·`spotlessCheck`·`detekt` = 태스크 없음(→ 비움), `compileKotlin compileTestKotlin`·`build -x test` 통과.
