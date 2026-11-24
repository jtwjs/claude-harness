# 하네스 재구성 1단계 리뷰

| 항목 | 값 |
|---|---|
| 이슈 | jtwjs/claude-harness#39 (하네스 재구성 1단계: 리뷰) |
| 기준 | 하네스 `eca41a4`(0.40.0) · PStack `cursor/plugins` `9e278fe`(2026-11-24, `gh api`로 읽음) |
| 점검표 | 볼트 `2_LLMWiki/wiki/ai/harness/짧게 쪼개고 경로로 잇는 스킬 설계.md` §6 점검표 · §5 가져오면 안 되는 것 · §7 흡수 후보(예비) |
| 작성 | 2026-11-24 · 트랙 `restructure` · 리뷰만 했다(고친 스킬 · 훅 · 템플릿 0) |
| 결정 | 이 문서는 고르지 않는다. 판정은 전부 추천이고, 「정할 것」은 2단계에서 지휘가 사용자와 정한다(ADR-014) |

## 한눈에

- 스킬 23개 추천 판정(하네스 21 + 사용자가 만든 개인 스킬 2): 유지 11 · 고침 10 · 합침 1 · 삭제 1
- 흡수 후보: PStack 작업 스킬 35 · 원칙 24 · 서브에이전트 2 · 자동화 3을 전부 봤고, 가져올 만한 것 9건(필수 3건 포함)을 따로 적었다
- 레포 구성 제안 12건. 가장 큰 것은 레포 자체에 CI가 없다는 것(`.github/` 없음, 대상 레포에는 `ci.yml`을 까 주면서)
- Before: SKILL.md 21개 · 줄 수 중앙값 97 · 최대 320(`conductor`)으로 지휘 측정과 같다. 줄 수가 못 잡는 긴 줄이 있어 바이트 · 상시 토큰을 같이 쟀다(5절)
- 리뷰 중 확인한 결함 5건(낡은 참조 · 개수 표기 어긋남 · 번호 순서 등, 1-6)
- 정할 것 12건(맨 아래 「정할 것」)

## 0. 근거와 한계

| 재료 | 어떻게 봤나 | 한계 |
|---|---|---|
| 점검표 판정 | SKILL.md 21개 + 개인 스킬 2개 본문을 다 읽고 §6 항목 7개를 스킬마다 판정 | 판정은 읽기 기반이다. 항목마다 근거 줄 번호를 단다 |
| 최근 사용 기록 | `docs/design-notes.md` 「워크플로우 리뷰」 방식대로 `~/.claude/projects/*/*.jsonl`(서브에이전트 기록 포함)에서 `Skill` 도구 호출을 세고, 사람이 친 `<command-name>`도 따로 셌다. 볼트 세션은 원래 방식대로 빼고, 개인 스킬 판정용으로 따로 셌다 | 🔴 이 머신에는 레포 세션 기록이 2026-11-11~11-24(14일, 21세션)만 있다. 30일 창을 걸었지만 실효는 14일이다. 회사 레포 기록이 없어서 `slack-writing` · `notion-writing` · `changeset`의 0회는 「안 쓴다」가 아니라 「이 머신에서 안 보인다」다 [확인 필요: 회사 머신 로그] |
| 경로 실재 | 스킬이 가리키는 플러그인 내부 경로(`skills/` · `hooks/` · `docs/` · `templates/` · `references/`)를 스크립트로 대조하고, 옛 이름(`_brain` · `tables.md` · `explain-diff-` 등)을 grep | 대상 레포 쪽 경로(`.claude/…` · `docs/{feature}`)는 레포마다 달라 여기서 못 본다 |
| 훅 | `scripts/hook-usage.sh 30` · `hooks/hooks.json` | 발화 기록은 2026-11-11부터만 있다 |
| 상시 비용 | `claude plugin details claude-harness@jtwjs-plugins`(설치본 0.40.0) | CLI 추정치다 |
| PStack | `gh api repos/cursor/plugins/contents/pstack/...`로 SKILL.md 59 · `agents/` 2 · README · `automations/benny` 목록을 받음 | 플레이북 22개 · 가이드는 제목만 봤다 |

## 1. 스킬 리뷰표

### 1-1. 판정 말의 뜻

| 판정 | 뜻 |
|---|---|
| 유지 | 구조를 그대로 둔다. 문장 몇 줄 정리는 재구성 PR에서 같이 해도 판정은 유지다 |
| 고침 | 구조를 바꾸는 손질이 필요하다: 쪼개기 · 배경 걷기 · 스크립트로 옮기기 · 낡은 참조 고치기 |
| 합침 | 다른 스킬에 내용을 넣고 이 스킬은 없앤다 |
| 삭제 | 넣을 곳 없이 없앤다 |

### 1-2. 점검표 판정 (스킬마다)

점검표 7항목: ① description이 언제 · 무슨 말에 뜨는지 말함 ② 결정을 안 바꾸는 문장(배경 · 이력)이 적음 ③ 다른 스킬과 같은 절차를 다시 쓰지 않음 ④ 범위 · 보고 형식 · 재시도 상한 · 애매할 때 기본값 ⑤ 판정이 실행 증거를 요구 ⑥ 두 번째로 적힌 같은 지시가 없음(있으면 린트 · 훅 · 스크립트 후보) ⑦ 사람 호출 / 모델 호출이 맞고 description이 안 겹침. 표기: ✓ 됨 · △ 일부 · ✗ 안 됨 · – 해당 없음.

| 스킬 | ① | ② | ③ | ④ | ⑤ | ⑥ | ⑦ |
|---|---|---|---|---|---|---|---|
| `sdd` | ✓ | ✗ | △ | ✓ | ✓ | ✓ | ✓ |
| `harness` | ✓ | △ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `harness-run` | ✓ | △ | △ | ✓ | ✓ | ✓ | ✓ |
| `sdd-review` | ✓ | ✓ | △ | ✓ | ✓ | △ | △ |
| `design-brief` | ✓ | △ | ✓ | △ | ✓ | ✓ | ✓ |
| `design-critique` | ✓ | △ | ✓ | ✓ | △ | ✓ | ✓ |
| `design-reconcile` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `why` | ✓ | △ | ✓ | ✓ | △ | ✓ | ✗ |
| `conductor` | ✓ | ✗ | △ | ✓ | ✓ | ✗ | ✓ |
| `harness-init` | ✓ | △ | ✓ | ✓ | ✓ | △ | ✓ |
| `harness-doctor` | ✓ | △ | ✓ | ✓ | ✓ | ✓ | △ |
| `harness-gaps` | ✓ | △ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `project-new` | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ai-readiness-cartography` | ✓ | ✓ | ✓ | △ | ✓ | ✓ | △ |
| `commit` | △ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `changeset` | △ | △ | △ | ✓ | – | △ | ✓ |
| `pr-write` | △ | △ | △ | ✓ | △ | △ | ✓ |
| `slack-writing` | △ | ✗ | △ | ✓ | △ | ✗ | ✓ |
| `notion-writing` | △ | △ | △ | ✓ | △ | ✗ | ✓ |
| `explain-diff` | ✓ | ✓ | △ | △ | – | ✓ | △ |
| `plannotator-visual-explainer` | ✗ | ✓ | △ | △ | ✓ | ✓ | △ |
| 개인 `grill-me` | △ | ✓ | ✓ | – | – | ✓ | ✓ |
| 개인 `why-logictree` | ✓ | ✓ | ✗ | △ | △ | ✓ | ✗ |

### 1-3. 추천 판정과 근거

14일 호출 = 레포 세션에서 모델이 부른 `Skill` 호출(볼트 세션 호출은 괄호). 사람이 슬래시로 친 것은 따로 적었다(`harness-doctor` 2회만 있었다). 줄 = `wc -l`(frontmatter 포함).

| 스킬 | 줄 | 14일 호출 | 추천 판정 | 근거 |
|---|---|---|---|---|
| `sdd` | 91 | 9 (+1) | 고침 | 총괄 길잡이라 자리는 맞다. 다만 줄 수에 안 보이는 긴 줄이 있다: 44번 줄 「빈틈 3곳」 한 줄이 2,019자이고 형식 정본 `docs/learning-level.md` §5를 다시 풀어 쓴다(③). 13번 줄 · 89~91번 줄은 이력이다(②). REVIEW 수렴 규칙(47번 줄)은 `sdd-review` §2 · §4와 같은 내용이다(③). 쪼개면 단계 → 스킬 · 체크포인트 표만 남고 절차는 `references/`로 간다(2-3) |
| `harness` | 120 | 7 | 고침 | 범위 합의 · step 원칙은 좋다. 실측 괄호(34 · 67 · 69번 줄 등 날짜 6줄)가 규칙 문장 안에 섞여 있다(②). 근거는 `references/` 또는 design-notes로 내리고 규칙만 남긴다 |
| `harness-run` | 61 | 5 | 유지 | 규칙 정본이 `sdd_runner.py` 하나이고 판정이 git 기록 · verify 실행이다(⑤ 가장 강함). 56번 줄 재개 절차가 「`sdd` 「재개」와 같은 문장」이라고 스스로 밝힌 중복이라 한쪽만 남긴다(③) |
| `sdd-review` | 47 | 7 | 유지 | 「verify 통과는 동작 증거가 아니다」(30번 줄)로 실제 동작을 요구한다(⑤). 회차 규칙이 `sdd`와 겹친다(③). 기준 브랜치 규칙(18번 줄)은 `pr-write` 11 · `changeset` 19 · `harness-init` 72와 같은 지시 네 번째다(⑥). `code-reviewer` · 기본 `/code-review`와 이름 · 쓰임이 가깝다(⑦, 4-1 `interrogate`와 연결) |
| `design-brief` | 112 | 2 | 고침 | 시안 전 결정 · 실렌더 확인이 있다. 캔버스 규칙(§4)을 `design-critique` · `design-reconcile`이 「`design-brief` §4」로 가리키는데, 디자인 3스킬 공용 규칙이라 `references/canvas.md` 한 장으로 빼는 편이 경로가 짧다. 보고 형식이 없다(④) |
| `design-critique` | 78 | 2 | 유지 | 독립 병렬 · 질문 상한 5 · 체크포인트 틀이 있다. 평가자 대부분이 의견이고 수치는 레퍼런스 실측뿐이다(⑤ △) |
| `design-reconcile` | 51 | 5 | 유지 | Playwright 스크린샷 대조 · 자동 덮어쓰기 금지 · 보고 형식. 7항목 다 됨 |
| `why` | 78 | 2 (+3), `grill-me` 경유 별도 | 유지 | 「질문 규칙」 정본으로 `sdd` · `harness` · `design-brief`가 경로로 가리킨다(③ ✓). 원칙(질문 규칙)과 절차(탐구 · 검증 모드)가 한 파일에 섞였다(2-3 쪼개기 후보). 개인 `why-logictree`와 트리거가 겹친다(⑦ ✗) |
| `conductor` | 320 | 1 (+1) | 고침 | 최장(바이트 29,894). 「왜」 표(9~26번 줄)는 배경이다(②). §4 graphql 명령 묶음(168~204번 줄)은 매번 복사해 쓰는 명령 묶음이라 `harness-gaps`의 「반복 절차」 정의에 맞는 스크립트 후보다(⑥). 「주의 · 금지」 번호가 1 · 2 · 3 · 5 · 4 순이다(310~316번 줄). §5 「새 규칙 → 기존 코드 정리」 한 줄이 track-brief 템플릿 「금지」에도 있다고 스스로 적는다(③). on-invoke 약 13.5k 토큰으로 가장 비싸다 |
| `harness-init` | 145 | 0 | 고침 | 레포당 1회라 0회가 정상이다. 옛 이름표(26~37번 줄)는 업그레이드 모드의 데이터인데, 같은 목록이 `hooks/test.sh` 587번 줄 grep에도 따로 있다(⑥). CI 플레이스홀더 7개 표 + 「grep 0」 확인(105~115번 줄)은 기계가 할 수 있는 채우기다(⑥ 스크립트 후보) |
| `harness-doctor` | 75 | 사람이 침 2 | 유지 | 검사 8개 · 「먼저 고칠 것 하나」 · 자동 수정 금지. 4번 검사 「2026-10-12 기준 25개」(38번 줄)처럼 낡는 개수가 남아 있다(②). `ai-readiness-cartography`와 둘 다 「레포 점검」이라 description이 가깝다(⑦ △) |
| `harness-gaps` | 115 | 0 | 고침 | 7번 줄 첫 문단은 생긴 이력이다(②). REFLECT 「하네스 되돌림」의 반복 칸 자리인데 14일 0회다. 같은 기간 `.claude/observations.md` 행이 2026-11-23에 갱신됐으니 스킬을 안 부르고 손으로 적었을 수 있다 [추정]. PStack `correct`의 교정 위계를 흡수할 자리다(4-1) |
| `project-new` | 52 | 0 | 유지 | 새 프로젝트 때만 쓴다. kit · ref를 레포에서 읽게 하고 덮어쓰기 전에 멈춘다. 7항목 다 됨 |
| `ai-readiness-cartography` | 158 | 0 | 고침 | 주 1회 훅 `weekly-readiness-check`가 `score.py`를 직접 돌리므로 모델 호출 스킬로 둘 이유가 약하다. 사람 호출 전용(`disable-model-invocation: true`) 또는 `harness-doctor`에 합침(정할 것 D5) |
| `commit` | 46 | 3 | 유지 | 짧고 verify를 먼저 돈다. description이 「~해줘」로 무엇만 말하고 언제는 sdd ⑤에 기댄다(① △) |
| `changeset` | 122 | 0 | 유지 | 0단계 스스로 skip이 있고 사용자 언어 규칙이 구체적이다. 12번 줄 이력 괄호(②), 기준 브랜치 규칙 반복(⑥). 이 머신에 changesets 레포가 없어 0회는 판단 근거가 안 된다 [확인 필요] |
| `pr-write` | 196 | 10 (+1) | 고침 | 가장 많이 불린 스킬. 🔴 196번 줄 결과 보고에 `tables.md 반영|없음`이 남아 있다. 4.95단계는 이제 PR 절에만 쓰고(107번 줄) `tables.md`가 있던 `_brain`은 ADR-013으로 없어졌다. 4.9 이해 게이트는 `learning-level.md` 형식을 다시 요약하고(③), 라벨 표 · Risk · 스크린샷 · 스키마 단계가 한 파일에 있어 on-invoke 약 6.4k다. 단계별 `references/`로 쪼갤 후보 |
| `slack-writing` | 198 | 0 | 고침 | 「출처」 절(190~198번 줄)은 근거 이력이다(②). 「기계 검사」(181번 줄)는 em dash · 볼드 · 인사말을 모델이 세게 하는 지시인데 `notion-writing` 83번 줄과 같은 종류다(⑥ 스크립트 후보). 「12살 설명 금지」 · AI 티 목록이 `notion-writing`과 겹친다(③) |
| `notion-writing` | 97 | 0 | 고침 | 위와 같은 짝. 공용 글 규칙을 한 파일로 빼고 형식별 규칙만 남긴다(2-3) |
| `explain-diff` | 31 | 1 | 유지 | 짧다. Quiz 줄(17번 줄)이 beginner 기술 카드 형식을 영어로 다시 풀어 쓴다(③, `learning-level.md` 경로만 남기면 된다). 대상 변경이 안 정해졌을 때 기본값이 없다(④) |
| `plannotator-visual-explainer` | 113 | 0 | 삭제 | 사람 호출 전용(유일한 `disable-model-invocation: true`)이고 0.27.0에서도 0회였는데 남겼다(design-notes 0.27.0). PR 설명 경로가 `explain-diff`와 겹치고, 나머지 경로는 외부 스킬 `nicobailon/visual-explainer`를 그 자리에서 설치한다(98~101번 줄). description이 무엇만 말한다(①). 정할 것 D3 |
| 개인 `grill-me` | 7 | 2 (+4) | 유지 | `claude-harness:why`로 넘기는 사람 호출 별칭이다. PStack의 「사람이 짧은 진입점을 치면 경로로 넘긴다」 모양 그대로다. 14일 6회로 `why` 직접 호출(5회)보다 많다 |
| 개인 `why-logictree` | 68 | 0 (+0) | 합침 | `why`와 같은 절차(WHY → 3질문 → 로직트리 → So What/Why So)를 따로 쓴다(③ ✗). description이 「기획서라는 단어를 쓰지 않아도 반드시 사용할 것」이라 `why` 트리거와 겹친다(⑦ ✗). `harness-init` 이름표에는 2026-10-16 「합침 → 삭제」로 적혀 있는데, dotfiles `fc1e9ce`(2026-11-13)에서 개인 스킬로 다시 들어왔다. 정할 것 D4 |

판정 개수: 유지 11(`harness-run` `sdd-review` `design-critique` `design-reconcile` `why` `harness-doctor` `project-new` `commit` `changeset` `explain-diff` `grill-me`) · 고침 10(`sdd` `harness` `design-brief` `conductor` `harness-init` `harness-gaps` `ai-readiness-cartography` `pr-write` `slack-writing` `notion-writing`) · 합침 1(`why-logictree`) · 삭제 1(`plannotator-visual-explainer`).

### 1-4. 개인 스킬: 판정 대상과 뺀 것

`~/.claude/skills/` 16개 중 사용자가 직접 만든 것은 2개로 봤다. 근거는 dotfiles(`~/dev/jtwjs/claude-dotfiles`) README 「내 스킬: grill-me」와 `sync.sh`의 개인 스킬 복사 목록이다.

| 스킬 | 판정 | 뺀 근거 |
|---|---|---|
| `grill-me` · `why-logictree` | 판정 대상 | dotfiles `claude/skills/`에 있는 사용자 작성본 |
| `aside-browser` · `find-skills` · `notion-cli` · `svg-logo-designer` | 제외 | `~/.agents/skills/` 심볼릭 링크(이슈 지시). `~/.agents/.skill-lock.json`에 출처 저장소가 적혀 있다 |
| `plannotator` · `plannotator-annotate` · `-inbox` · `-last` · `-review` | 제외 | plannotator 설치본(같은 시각 2026-11-23 13:40에 깔림). dotfiles에는 사본이 있지만 작성자가 아니다 |
| `graphify` | 제외 | 도구가 깐 것(`.graphify_version` 파일) |
| `notebooklm` | 제외 | 본문 첫 줄 `<!-- notebooklm-py v0.8.6 -->` |
| `zotero-cli` | 제외 | `zotero-cli` 명령의 동봉 스킬 [추정: 사용자 작성 흔적 없음] |
| `teach-me` | 제외 | 플러그인 디렉터리의 외부 배포본 `ahmed3bead/teach-me`와 이름 · 설명이 같다 [추정, 확인 필요]. dotfiles 「내 스킬」에 없다 |
| `synced` | 제외 | claude.ai 계정 동기화 폴더(dotfiles `MY_SKILL_SKIP`) |

### 1-5. 묶음 전체 점검

| 점검 | 판정 | 근거 |
|---|---|---|
| 원칙과 절차가 한 파일에 섞였나 | ✗ 섞였다 | `why`(질문 규칙 + 두 모드) · `sdd`(흐름 표 + 빈틈 3곳 · REFLECT 절차) · `conductor`(지휘 원칙 + 라벨 · graphql · 세션 열기) · `slack-writing`/`notion-writing`(공용 글 원칙 + 형식). 쪼개기 안은 2-3 |
| 분류가 이름 접두사나 총괄 표로 보이나 | △ | README 「무엇이 들었나」 표와 6축 표가 카테고리 역할을 한다. 접두사는 `harness-*` · `design-*`만 있고, `harness`(PLAN)는 이름만으로 단계를 알 수 없다 |
| README가 진입점 1~2개부터 말하나 | ✗ | 「세 레포의 관계」 → 「빠른 시작」(설치 명령) → 「무엇이 들었나」 순이다. 「기존 레포는 `/harness-init`, 새 프로젝트는 `/project-new`」가 설치 문단 안에 한 줄로 묻혀 있고 「기능 작업은 `/sdd`」는 흐름도 아래에 있다 |

### 1-6. 리뷰 중 확인한 결함

고치지 않았다. 재구성 PR에서 같이 고칠 목록이다.

| 자리 | 현상 | 확인 |
|---|---|---|
| `skills/pr-write/SKILL.md:196` | 결과 보고에 `tables.md 반영|없음`. `_brain`은 ADR-013으로 없어졌고 4.95단계 본문도 `tables.md`를 쓰지 않는다 | grep |
| `README.md:37` | 「훅 10개」. `hooks/hooks.json`에 걸린 스크립트는 12개다(`conductor-context` · `hypothesis-gate`가 표에 없음) | `hooks.json` 파싱 |
| `README.md:72` | 「축 밖」 칸에 `explain-diff-*`. 0.27.0에서 `explain-diff` 하나로 합쳤다 | grep |
| `skills/conductor/SKILL.md:310-316` | 「주의 · 금지」 번호가 1 · 2 · 3 · 5 · 4 | 본문 |
| `docs/design-notes.md` §3 | 「스킬을 늘리거나 줄인 릴리스마다 표에 한 줄」인데 표가 0.23.0에서 멈췄다. 지금 값은 21 + 4 · 약 3,442토큰(5절) | CLI |

## 2. 카테고리 안

### 2-1. 묶는 방식 (정할 것 D1)

| 안 | 모양 | 고르면 굳는 것 | 비싸지는 것 |
|---|---|---|---|
| A. 이름 접두사로 묶기 | `sdd-plan` `sdd-run` `sdd-review` · `write-slack` `write-notion` … | 메뉴에서 이름만 보고 묶음이 보인다 | 이름을 바꾼 스킬마다 `harness-init` 이름표 행 · 대상 레포 `.claude/README.md` 라우팅 사본 · 습관이 된 `/harness` 입력이 다 바뀐다 |
| B. 이름은 두고 총괄 표 · README로 묶기 (추천) | `sdd`가 흐름 스킬 표를, README가 카테고리 표를 든다. 이름이 단계를 못 말하는 것(`harness`)만 개명 후보로 따로 묻는다 | 지금 레포 사본 · 습관이 그대로 간다 | 메뉴에서는 묶음이 안 보인다 |
| C. 폴더로 묶기 | `skills/sdd/plan/SKILL.md` | 파일 트리가 정리된다 | 플러그인 스킬은 `skills/<이름>/SKILL.md` 한 단계에서 읽힌다 [확인 필요]. PStack도 평평한 폴더다 |

### 2-2. 카테고리와 각 스킬의 자리 (B안 기준)

| 카테고리 | 스킬 | 진입점 |
|---|---|---|
| 흐름(SDD) | `sdd`(총괄) · `harness`(PLAN) · `harness-run` · `sdd-review` | `/sdd` |
| 디자인 트랙 | `design-brief` · `design-critique` · `design-reconcile` | `sdd`가 화면 작업이면 부른다 |
| 생각 도구 | `why` · 개인 `grill-me`(별칭) | `/grill-me` 또는 `/why` |
| 하네스 관리 | `project-new` · `harness-init` · `harness-doctor` · `harness-gaps` · `ai-readiness-cartography` | `/harness-init` |
| 병렬 지휘 | `conductor` | 「지휘 맡아」 |
| 마무리 | `commit` · `changeset` · `pr-write` | `sdd` ⑤가 부른다 |
| 글 · 설명 | `slack-writing` · `notion-writing` · `explain-diff` | 사람이 부른다 |
| 에이전트 | `test-writer` · `feature-builder` · `code-reviewer` · `root-cause-debugger` | 스킬이 부른다 |

### 2-3. 원칙과 절차 쪼개기 안 (안만)

| 스킬 | 남길 것(절차 · 길잡이) | 뺄 것 | 빼서 갈 자리 |
|---|---|---|---|
| `sdd` | 단계 → 스킬 · 체크포인트 표, 트랙 판단, 출구 조건 | 빈틈 3곳 절차(44번 줄) · REFLECT 4단계 상세 · 이력 블록 | `skills/sdd/references/gap3.md` · `reflect.md`(이미 있는 `design.md`와 같은 방식) · 이력은 design-notes |
| `why` | 탐구 · 검증 두 모드 | 질문 규칙(한 번에 한 질문 · 추천 표시 · 반박 · 이유 체인) | 원칙 그릇(2-4). `sdd` · `harness` · `design-brief`는 그 경로를 가리킨다 |
| `conductor` | 지휘 원칙 10줄 안팎(디스패치 · 판정 · 기록만, 번호는 한 곳, 메시지는 초인종) + 상황 → 절 표 | 「왜」 표 · 라벨 표 · graphql 명령 · 세션 열기 · 초인종 상세 | `skills/conductor/references/*.md` · graphql은 `scripts/issues.py`(block · sub · ready) |
| `slack-writing` · `notion-writing` | 형식별 골격 · 상한 · 출력 | 공용 금지(지어내지 않음 · 해석 문장 · em dash · 12살 설명 · AI 티) · 「출처」 이력 · 기계 검사 지시 | 공용 글 규칙 한 파일(PStack `unslop`처럼 번호를 붙여 다른 스킬이 번호로 인용) + `scripts/prose_check.py` |
| `pr-write` | 1~6단계 순서 | 라벨 표 · Risk 축 · 이해 게이트 형식 | 이미 있는 `references/risk-score.md` 옆에 `labels.md` · 이해 게이트는 `docs/learning-level.md` 경로만 |
| `harness-init` | 진단 · 실측 · 인터뷰 · 생성 순서 | 옛 이름표 · CI 플레이스홀더 채우기 | 이름표는 데이터 파일 하나(`hooks/test.sh` grep도 읽게), CI 채우기는 스크립트 |

### 2-4. 원칙을 담는 그릇 (정할 것 D2)

| 안 | 모양 | 고르면 굳는 것 | 비싸지는 것 |
|---|---|---|---|
| A. PStack처럼 원칙 하나 = 짧은 스킬 하나 | `skills/principle-ask-one-question/SKILL.md` … + 총괄 표 | 메뉴에서 원칙을 직접 부를 수 있다 | 스킬마다 상시 비용이 붙는다. `disable-model-invocation: true`인 `plannotator-visual-explainer`도 CLI 추정 상시 약 100토큰이다. 메뉴가 원칙 수만큼 늘어난다 |
| B. 원칙은 참조 파일, 스킬이 경로로 가리킴 (추천) | `docs/principles/<이름>.md`(스킬 아님) + 각 스킬에 「적용하는 원칙: 경로」 한 줄 | 상시 비용 0. 메뉴가 그대로다 | 사람이 원칙을 슬래시로 못 부른다. 「읽지 않고 인용 금지」 규칙을 따로 적어야 한다 |
| C. 지금처럼 각 스킬 안에 둔다 | 그대로 | 손댈 것 없음 | 같은 원칙이 여러 스킬에 복사돼 한쪽만 고쳐지는 일이 계속된다(지금 `why` 질문 규칙은 경로 위임이 되지만 글 규칙 · 기준 브랜치 규칙은 복사본이다) |

## 3. 레포 구성 리뷰

| # | 자리 | 현상(확인함) | 제안 | 안 하면 |
|---|---|---|---|---|
| R1 | CI | 레포에 `.github/`가 없다. `hooks/test.sh`는 `scripts/release.sh` 사전 확인에서만 돈다. 대상 레포에는 `ci.yml`을 까 준다 | PR마다 `bash hooks/test.sh` · `test_sdd_runner.py` · README 개수 검사를 도는 워크플로 하나 | 1-6처럼 README 개수 · 낡은 참조가 머지 뒤에 사람 눈으로만 잡힌다 |
| R2 | README | 진입점이 설치 문단에 묻혀 있고(1-5) 훅 · 스킬 개수가 손으로 적혀 어긋났다 | 첫 절을 「처음엔 `/harness-init`, 기능 작업은 `/sdd`」로. 개수는 R1 검사가 `hooks.json` · `skills/`와 대조 | 새로 보는 사람(미래의 나 포함)이 21개 중 어디서 시작할지 모른다 |
| R3 | 훅 3개 판단 | 0.27.0에서 「숫자가 쌓인 뒤 사람이 판단, 첫 재측정 2026-10-29」로 정했다. 30일 집계(실효 2026-11-11~): `loop-lock` seen 244 · blocked 0, `todo-warn` clean 268 · warn 0, `validate-session-end` 기록 0줄 | `validate-session-end`는 기록을 남기는 분기(skip · busy · ok · fail)에 닿기 전에 끝나는 경로가 기록되지 않는다 [추정]. 측정부터 의심해 끝나는 모든 경로에 기록을 넣은 뒤 판단. 정할 것 D11 | 막은 적 없는 훅이 매 Bash 호출마다 돈다. 반대로 숫자 없이 끄면 0.27.0 결정을 근거 없이 뒤집는다 |
| R4 | 의존 플러그인 | `plugin.json` · `marketplace.json`이 `understand-anything`을 의존으로 선언하고 README가 「없으면 harness가 비활성화된다」고 적는다. 스킬 · 에이전트 · 훅 어디에서도 쓰지 않는다(`git grep -i understand` 0건, 0.3.0에서 들어옴) | 의존 선언 제거. 정할 것 D12 | 새 맥 · 새 사용자가 쓰지도 않는 플러그인을 먼저 깔아야 한다 |
| R5 | `docs/design-notes.md` §9 | 변경 이력 107줄 중 대부분이 한 버전 한 줄의 긴 문단이다. 하네스 자신의 규칙 「쌓기만 하는 기록은 한 건 = 파일 하나」(`sdd` ④-1)와 어긋난다 | 이력은 `docs/changes/<버전>.md` 또는 PR 본문으로, design-notes는 1~8절 원칙만 | 병렬 트랙이 이 파일을 같이 고치면 2026-10-21과 같은 판단 없는 충돌이 다시 난다 |
| R6 | `scripts/release.sh` | 사전 확인 · 반영 확인은 좋다. 버전 올리기(`plugin.json` · `marketplace.json` 두 곳)는 손으로 하고, design-notes §3 상시 비용 표는 릴리스마다 적게 돼 있는데 멈췄다 | `release.sh`가 `claude plugin details`의 Always-on 값을 출력하고 표 한 줄을 제안 | 상시 비용이 다시 아무도 안 재는 숫자가 된다(이미 0.23.0 뒤 0.40.0까지 미기록) |
| R7 | `hooks/test.sh` | 736줄 한 파일. 새 테스트는 `hooks/tests/*.sh`에만 두라는 규칙이 있다(러너 판정이 `hooks/test.sh`를 테스트 파일로 못 알아봐서) | 근본은 러너 판정(`sdd_runner.py`의 테스트 파일 판별)이 `hooks/test.sh`도 알아보게 고치는 쪽. 옮기기만 하면 같은 함정이 남는다 | 2시간 넘게 막힌 함정(`non-obvious-patterns.md`)이 다음 사람에게도 그대로 |
| R8 | 옛 이름 목록 두 벌 | `harness-init` 이름표(26~37번 줄)와 `hooks/test.sh` 587번 줄 grep 목록이 따로 관리된다 | 이름표를 데이터 파일 하나로, 둘 다 그 파일을 읽게 | 이름을 하나 바꿀 때 두 곳 중 하나를 빠뜨린다 |
| R9 | `incubator/` | 비어 있고 이력만 있다 | 폴더를 지우고 이력은 design-notes 한 줄로(되살릴 때 git 이력) | 비어 있는 폴더가 README · 구조 설명에 계속 자리를 차지한다(작은 문제) |
| R10 | `agents/code-reviewer.md` | 근거를 「실제 diff 라인」으로 요구하지만 실행 증명은 요구하지 않는다. PRD · 의도를 읽는 단계가 없다(볼트 리뷰 조각 ⑨ ⑩: 리뷰 에이전트 과적합 · 제품 맥락) | 4-1 `interrogate` 흡수안과 같이 정한다 | 지적이 많을수록 REVIEW 루프 수렴(0.26.0)이 어려워진다 |
| R11 | `templates/stacks/nestjs` | `pack.md`가 스스로 「미실측 팩(2026-10-20)」이라고 적는다 | 쓰는 레포가 생길 때까지 그대로 두되 `harness-init` 스택 판정에서 고를 때 「미실측」을 사람에게 한 줄 알림 | 첫 레포에서 돌지 않는 명령이 깔릴 수 있다(`harness-init`의 유일한 실패 모드) |
| R12 | 스킬 길이 지표 | 줄 수 중앙값 97은 긴 줄을 못 잡는다(`sdd` 91줄이 19,186바이트) | 재구성 Before/After를 줄 수와 함께 바이트 · on-invoke 토큰으로도 잰다(5절) | 줄을 합쳐 줄 수만 줄이는 가짜 개선이 숫자에 안 걸린다 |

## 4. 흡수 후보표

PStack을 가져올 때는 「복사해서 고친다」(PStack `reflect`, README "fork it")이고, 볼트 노트 §5의 네 줄(설계 결정은 묻지 않고 프로토타입으로 정하기 · 바깥 행동 자동 진행 · 이유 생략 문체 · Cursor 전용 이름)은 가져오지 않는다는 전제로 본다.

### 4-1. 본 후보 (가져올 만한 것 9건, 필수 3건 포함)

| PStack | 겹치는 하네스 스킬 | 새로 생기는 능력 | 고칠 방식 안 | 가져오지 말 이유 | 추천 |
|---|---|---|---|---|---|
| `no-comments` + 에이전트 `comment-sicko` (필수) | stack-kits 린트 `local/no-comments`(`react-vite` · `fullstack/apps/web`) · `code-reviewer` 축 1(주석은 안 봄) | 「바꾸지 마라 · 지우지 마라」 같은 제약 주석을 타입 · 런타임 검사 · 테스트 · 린트로 옮기자고 제안하는 단계. 찾는 쪽(성격 고정 서브에이전트)과 판정하는 쪽(메인)을 나눔. 거절한 보고는 한 번만 다시 돌림 | (a) 린트에 맡기고 스킬은 안 가져옴 (b) `skills/no-comments` + `agents/comment-sicko.md`로 가져와 사람 호출 전용, REVIEW 앞 선택 단계 (c) `code-reviewer`에 「주석 → 구조」 항목만 | 막는 일은 린트가 이미 한다(FE 킷만). Cursor `Task subagent_type` → Agent 도구로 바꿔야 한다 | (b). D6 |
| `interrogate` (필수) | `sdd-review` · `code-reviewer` · 기본 `/code-review` | 「실행으로 증명된 지적만 남긴다」. 의도를 먼저 되비춤(`in-your-own-words`). 버린 지적 수와 이유를 보고(Dropped) | (a) 새 스킬로(적대자 병렬 + worktree 격리, `arena` 대신 자체 fan-out) (b) `code-reviewer` · `sdd-review`에 증명 규칙과 의도 단계만 넣음: 지적마다 명령 · 출력, 못 돌린 지적은 「확인 필요」로 강등 (c) `sdd-review`의 escalate 대상을 `interrogate`로 교체 | `arena` Phase A · B · F에 기댄다(안 가져오면 다시 써야 함). 다중 모델 패널은 Cursor 모델 slug. 적대자 N개 × worktree 비용 | (b). D7 |
| `statechart` (필수) | 없음(`design-brief` 「상태」 칸은 화면 상태 목록뿐) | TLA+ 모델 검사로 규칙이 깨지는 최단 경로 + Mermaid 상태 차트. 버그 경로를 실제 코드에 다시 돌려 확인 | (a) 그대로 반입(`scripts/statechart.ts` + mise로 Java · TLC 설치) (b) 반입하되 사람 호출 전용, ARCHITECTURE에 상태 흐름이 있을 때만 `sdd`가 제안, 스크래치 폴더에서만 실행 (c) 안 가져오고 BACKLOG 승격 조건으로 | Java · TLC · mise · TS 런타임 의존, 첫 실행에 네트워크. 상태 전이 버그가 실제로 몇 건이었는지 기록이 없다 [확인 필요] | (b). D8 |
| `correct` | `harness-gaps` · `sdd` REFLECT 「하네스 되돌림」 | 교정 위계(구조 → 타입 → 에러가 대신 쓸 것을 말하는 린트 → 테스트 → 문서는 마지막) · 「규칙 ↔ 막는 장치」 표 · 새 검사가 실제 과거 실수에서 실패함을 증명 | `harness-gaps` §4 종착지 표를 이 위계로 바꾸고 `non-obvious-patterns.md`에 「막는 장치」 칸 | PStack은 「두 번이면 센다」, 하네스는 3회 규칙. 하네스 3회를 유지한다 | `harness-gaps`에 흡수(새 스킬 없음). D9 |
| `reflect` | `sdd` REFLECT · `revise-claude-md` · `harness-gaps` | 남기는 문턱 3개(6개월 뒤에도 맞음 · 다음 행동을 바꿈 · 이번 세션에 쓴 스킬로 감) · 낡는 값(SHA · 버전 · 개수) 버림 | `sdd` REFLECT 「하네스 되돌림」에 문턱 3줄 | 별도 스킬은 REFLECT와 같은 자리 | REFLECT에 흡수. D9 |
| `blast-radius` | 없음(`sdd-review` 「실제 동작」 축이 가까움) | diff 밖 영향 · 안전 근거 하나를 실행으로 증명 · 확신 5단계(말만 → 줄 지목 → 못 일어남을 보임 → 돌림 → 앱에서 재현) | `interrogate` (b)와 같은 자리에 확신 5단계로 | 원리가 `interrogate`와 같다(실행 증명) | `interrogate` 흡수와 묶음. D9 |
| `create-verification-skill` · `maintain-verification-skill` | `harness-init`(verify 명령 실측) · `sdd-review` 「실제 동작」 축 · 기본 `run` 스킬 | 레포 전용 「앱을 사용자처럼 돌려 증거(스크린샷 · 출력)를 남기는」 스킬을 만들고 코드가 바뀌면 다시 맞춤(볼트 리뷰 조각 ⑥ ⑧) | (a) `harness-init`에 「verify-<앱> 스킬 생성」 선택 단계 (b) BACKLOG 승격 조건: PR 본문 「리뷰 심각도: 미실행」 또는 「실제 동작 미실행」 3건 | 지금 `run` 스킬 · Playwright(`design-reconcile`)로 일부 된다. 레포마다 스킬이 하나씩 늘어난다 | (b). D10 |
| `unslop` · `technical-writing` | `slack-writing` · `notion-writing` | 규칙에 고정 번호를 붙여 다른 스킬이 번호로 인용 | 원문(영어 규칙)은 안 가져오고 「공용 글 규칙 한 파일 + 번호」 방식만(2-3) | 한국어 글 규칙은 이미 사용자 관찰 기록 기반으로 더 구체적이다 | 방식만 흡수(2-3과 같은 결정) |
| `benchmark-checklist` · `principle-explain-the-number` | 사용자 전역 지침(출처 없는 숫자 금지 · 숫자와 감이 어긋나면 측정부터 의심) | 숫자를 믿기 전 점검 7항목(무엇이 숫자를 제한하나 · 반복성 · 실제로 일이 일어났나 등) | 원칙 그릇(2-4)에 한 장 | 숫자 원칙은 전역 지침에 이미 있다 | 낮음. 원칙 그릇을 만들면 그때 |

### 4-2. 나머지 작업 스킬 (35개 중 위에 없는 24개)

| PStack | 하네스 쪽 | 판정 | 이유 |
|---|---|---|---|
| `poteto-mode` · `poteto-help` | `sdd`(총괄) · README | 구조만(2절) | 총괄 표 · 「읽은 원칙만 인용」 규칙은 2-4로. 자율 규칙(바깥 행동 자동 진행)은 §5 충돌 |
| `setup-pstack` | step `model` 필드 · 에이전트 `model` | 안 가져옴 | 역할별 모델 규칙 파일은 하네스가 step 단위로 이미 한다. 모델 slug가 Cursor 것 |
| `in-your-own-words` · `bro` · `sharpen` · `reframe` | `why` 탐구 1단계(들은 것 / 빈칸) · 사용자 응답 형식 지침 | 안 가져옴 | 되비추기는 사용자 협업 규칙 · `why`에 있다. `interrogate`의 의도 단계로만 쓴다 |
| `why` | 하네스 `why`(이름 같음, 일이 다름) | 한 줄만 | PStack `why` = 커밋 · PR 기록에서 결정 근거 찾기. 하네스 `why` 검증 모드에 「코드 결정이면 git log · PR부터」 한 줄. 이름 충돌 주의 |
| `how` · `teach` | `explain-diff` · Explore 에이전트 · (외부 `teach-me`) | 안 가져옴 | 하네스 `explain-diff`가 배경 → 직관 → 코드 순회를 한다 |
| `architect` | `harness` §3 시그니처 수준 지시 · ARCHITECTURE | 안 가져옴 | 같은 자리 |
| `arena` · `swarm` | Agent 병렬 · `design-critique` 독립 병렬 | 안 가져옴 | 다중 모델 패널이 Cursor 전용. `interrogate`를 (a)로 고르면 그때 필요한 부분만 |
| `figure-it-out` | `sdd` · `harness` | 안 가져옴 | 큰 작업 계획은 ① 계획이 한다 |
| `tdd` | `harness-run` 러너 · `test-writer` | 안 가져옴 | 「싼 테스트 길이 없으면 억지로 안 만든다」는 `harness`의 `tdd: false` + 이유 한 줄과 같다 |
| `recall` · `ketchup` · `ketchup-video` | `conductor-context` 훅 · `tracks_status.py` · daily-hub · 판정함 | 안 가져옴 | 「사용자 몫 결정만 추천과 함께」 형식은 `decision-inbox`가 한다 |
| `show-me-your-work` | `phases/*/index.json`(attempts · summary) · ADR · 회고 | 안 가져옴 | 결정 TSV를 더하면 기록 자리가 둘이 된다 |
| `automate-me` | 사용자 응답 형식 · 작업 원칙 지침 · task-observer | 안 가져옴 | 작업 방식 → 모드 스킬은 dotfiles · 볼트 영역이다 |
| `create-formal-verification-skill` · `maintain-formal-verification-skill` | 없음 | 안 가져옴 | `statechart` 결과를 본 뒤. 더 무겁다 |
| `typescript-best-practices` | `templates/.claude/rules/typescript.md` | 안 가져옴 | 같은 자리, 하네스는 `paths:` 규칙 |
| `make-bot-ui` | 없음 | 안 가져옴 | Grok Bot 웹훅 · Tailscale 전용 |

### 4-3. 원칙 24개

| 원칙 | 하네스 쪽 자리 | 상태 |
|---|---|---|
| `laziness-protocol` | 전역 karpathy 단순함 · REFLECT 「더하기만 금지」 | 있음 |
| `foundational-thinking` | `harness` §3 「타입 · 데이터부터 아래 계층부터」 | 있음 |
| `redesign-from-first-principles` | 없음 | 낮음 |
| `attack-the-premise` | `root-cause-debugger` 가설 하나씩 · 사용자 작업 원칙(되돌리기 비싼 결정은 전제부터 확인) | 일부 |
| `subtract-before-you-add` | REFLECT 「더하기만 금지」(순서가 반대: 넣은 뒤 하나 지움) | 일부 |
| `minimize-reader-load` | `code-reviewer` 축 3 | 있음 |
| `outcome-oriented-execution` | `harness` 이동 리팩터 3 step | 일부 |
| `experience-first` | 없음(제품 판단은 사용자 몫) | 안 가져옴 |
| `exhaust-the-design-space` | `design-brief` 「구성이 갈리는 화면만 저충실 A/B」 | 일부 |
| `build-the-lever` | `harness-gaps` 「반복 절차 → scripts/」 | 일부(하네스는 반복 3회, PStack은 사소함이 기준) |
| `model-the-domain` | `templates/stacks/kotlin-spring/rules/domain.md` · FP/OOP 표 | 있음 |
| `boundary-discipline` | `templates/.claude/rules/functional-programming.md` 함수 3층 | 있음 |
| `type-system-discipline` | `templates/.claude/rules/typescript.md` | 있음 |
| `make-operations-idempotent` | `harness` §3 「멱등성 · 보안 · 데이터 무결성은 반드시 명시」 | 일부 |
| `migrate-callers-then-delete-legacy-apis` | `conductor` 「새 규칙 → 기존 코드 정리」(ADR-010) | 일부 |
| `separate-before-serializing-shared-state` | `sdd` ④-1 「한 건 = 파일 하나」 · `conductor` 겹침 판정 | 있음 |
| `prove-it-works` | `sdd-review` 「실제 동작」 · 전역 「검증」 | 있음 |
| `fix-root-causes` | `root-cause-debugger` · 전역 karpathy | 있음 |
| `sequence-verifiable-units` | `harness` step = 검증 가능한 작동 단위 | 있음 |
| `test-behavior-not-implementation` | `sdd-review` 테스트 축 「동작 기준」 · `rules/testing.md` | 있음 |
| `explain-the-number` | 사용자 전역 지침 | 있음(4-1 마지막 행) |
| `guard-the-context-window` | design-notes §3 로드 예산 · `harness-doctor` 검사 5 | 있음 |
| `never-block-on-the-human` | 사용자가 설계를 고르는 협업 규칙 · 승인 경계와 충돌(볼트 노트 §5) | 안 가져옴(실행에만) |
| `encode-lessons-in-structure` | `harness-gaps` · `correct` 흡수안 | 일부(하네스 3회 · PStack 두 번째) |

새로 생기는 것보다 이미 있는 것이 많다. 가져올 값은 원칙 내용이 아니라 「원칙 하나 = 짧은 문서 하나 + 총괄 표가 경로로 가리킴」 구조다(2-4).

### 4-4. 서브에이전트 · 자동화

| PStack | 하네스 쪽 | 판정 |
|---|---|---|
| `agents/comment-sicko.md` | 없음 | `no-comments`와 묶음(D6) |
| `agents/poteto-agent.md` 「시작 지시 첫 줄에 worker.md를 읽어라」 | `harness-run` 지시문 = 가드레일 + `scripts/preamble.md` + stepN.md | 있음 |
| `automations/benny`(`reproduce-and-fix-issues` · `setup-benny` · `triage-issue-reports`) | `harness-gaps` 주 1회 헤드리스 | 안 가져옴(Cursor automations 전용, 슬래시 스킬로 등록되지 않음) |

## 5. Before 측정 재확인

측정 2026-11-24, 이 worktree HEAD `eca41a4`(main과 같음).

| 지표 | 값 | 명령 | 지휘 측정 |
|---|---|---|---|
| 스킬 수 | 21 | `ls skills` | 21 ✓ 같음 |
| SKILL.md 줄 수 중앙값 | 97 (`notion-writing`) | `wc -l skills/*/SKILL.md`(frontmatter 포함) | 97 ✓ 같음 |
| SKILL.md 줄 수 최대 | 320 (`conductor`) | 같음 | 320 ✓ 같음 |
| 사람 호출 전용 스킬 | 1 / 21 (`plannotator-visual-explainer`) | frontmatter `disable-model-invocation: true` | 노트 표와 같음 |

줄 수가 못 잡는 것 때문에 같이 잰 것(재구성 After도 같은 명령으로):

| 지표 | 값 | 명령 |
|---|---|---|
| SKILL.md 바이트 중앙값 · 최대 | 7,417 · 29,894(`conductor`) | `wc -c skills/*/SKILL.md` |
| 가장 긴 한 줄 | 2,019자(`sdd` 44번 줄) | `awk 'NR==44{print length($0)}'` |
| 플러그인 상시 비용 | 약 3,442토큰(스킬 21 + 에이전트 4) | `claude plugin details claude-harness@jtwjs-plugins` |
| on-invoke 스킬 중앙값 · 최대 | 약 3.8k(`design-brief`) · 약 13.5k(`conductor`) | 같은 명령 |
| 14일 호출 0인 하네스 스킬(모델 `Skill` 호출 + 사람이 친 명령) | 8 / 21 | 0절 방식(이 머신 · 14일 하한값) |

PStack 비교(`9e278fe`): 59개 · 줄 수 중앙값 19 · 최대 163(`poteto-help`) · 사람 호출 전용 58/59, 볼트 노트 §0과 같다. 바이트 중앙값은 1,330인데 한글은 UTF-8에서 한 글자 3바이트라 하네스와 바이트로 직접 견주면 안 된다.

## 정할 것 (2단계 입력)

선택은 사용자 몫이다. 추천은 표시만 한다. 설계 결정이 걸린 것(D1 · D2 · D6 · D7)은 고른 이유를 받고 한 번 반박하는 절차가 남아 있다.

### D1. 스킬을 어떻게 묶어 보이게 할까

선택지는 2-1 표. 추천 B(이름은 두고 총괄 표 · README로 묶기).

```
이름을 안 바꾼다 → 레포 사본 · 이름표 · 습관이 그대로 간다
  → 재구성 PR이 「묶음 표 + 쪼개기」에만 집중한다
  → 대상 레포 업그레이드가 이름표 행 없이 끝난다
  → 궁극: 재구성의 목표(짧게 쪼개고 경로로 잇기, 할 일 노트 「끝 기준」)에 이름 바꾸기 비용을 얹지 않는다
```

다음 단계 영향: `harness`처럼 이름이 단계를 못 말하는 스킬은 개명 여부를 따로 한 번 묻는다.

### D2. 원칙을 어디에 담을까

선택지는 2-4 표. 추천 B(참조 파일 + 경로).

```
원칙을 스킬이 아닌 파일로 → 상시 비용이 0이다
  → 원칙을 몇 개로 쪼개도 매 세션 비용이 안 는다
  → 「스킬 하나는 공짜가 아니다」(design-notes §3)와 PStack식 쪼개기가 같이 선다
  → 궁극: 쪼갤수록 비싸지는 구조면 다음 사람이 다시 한 파일에 몰아 쓴다 [추정]
```

다음 단계 영향: `why` 질문 규칙 · 공용 글 규칙이 첫 원칙 파일이 된다. 「읽은 원칙만 인용」 한 줄을 총괄 표에 같이 둔다.

### D3. `plannotator-visual-explainer`를 지울까

| 선택지 | 굳는 것 | 비싸지는 것 |
|---|---|---|
| 삭제 (추천) | PR 설명은 `explain-diff` 하나 | plannotator 테마 HTML이 필요하면 git 이력에서 꺼낸다 |
| `explain-diff`에 테마만 합침 | 출력 하나에 테마 선택지 | `references/` 1,846줄을 `explain-diff`가 떠안는다 |
| 유지 | 그대로 | 외부 스킬을 그 자리에서 설치하는 경로가 남는다 |

추천 이유: 0.27.0 이후 다시 잰 14일에도 0회, PR 설명 경로가 `explain-diff`와 겹친다. 다음 단계 영향: README · 6축 표에서 한 줄 빠진다.

### D4. 개인 `why-logictree`를 하네스 `why`에 합칠까

| 선택지 | 굳는 것 | 비싸지는 것 |
|---|---|---|
| 합침 후 개인본 삭제 (추천) | 이유 탐구 진입점은 `why` · `grill-me` | `why-logictree`만 있던 「기획서 파일로 남기기」는 `why` 끝 표 → `notion-writing`으로 간다 |
| 볼트 전용으로 유지 | 볼트 기획서 작성 자리 하나 | 두 스킬 description이 계속 겹쳐 엉뚱한 쪽이 뜰 수 있다 |
| 그대로 | 없음 | 위와 같음 |

추천 이유: 14일 0회(레포 · 볼트 모두), 절차가 같다. 단 2026-11-13에 사용자가 다시 넣은 이유가 기록에 없다 [확인 필요: 다시 넣은 이유]. 이 스킬은 dotfiles 소유라 고치는 곳은 하네스가 아니다.

### D5. `ai-readiness-cartography`를 어디에 둘까

| 선택지 | 굳는 것 | 비싸지는 것 |
|---|---|---|
| 유지 + 사람 호출 전용 (추천) | 주간 훅이 점수를 자동으로 내고, 대시보드가 필요할 때만 사람이 부른다 | 모델이 「레포 점검」 말에 알아서 부르지 않는다 |
| `harness-doctor`에 합침 | 점검 진입점 하나 | 하네스 고유 검사(doctor)와 범용 루브릭이 한 파일에 섞인다 |
| 그대로 | 없음 | 상시 약 170토큰(스킬 중 최대)을 내고 14일 0회 |

### D6. `no-comments`를 어떻게 가져올까

선택지는 4-1 첫 행. 추천 (b) 스킬 + 서브에이전트, 사람 호출 전용.

```
제약 주석을 장치로 옮기는 제안 → 「바꾸지 마라」가 글이 아니라 검사가 된다
  → 린트가 없는 BE · Kotlin · 하네스 레포에서도 같은 일이 된다
  → 다음 에이전트가 주석을 무시해도 검사가 막는다
  → 궁극: 볼트 리뷰 조각 ② 「강제할 수 없는 지시는 믿을 수 없다」를 구조로 푼다
```

다음 단계 영향: Cursor `Task` 호출을 Agent 도구로, `poteto-mode` 의존(Subagents 절)을 하네스 문장으로 바꿔야 한다. REVIEW 체크포인트 목록(`sdd`)에 한 줄 늘어난다.

### D7. `interrogate`를 어떻게 가져올까

선택지는 4-1 둘째 행. 추천 (b) 기존 리뷰에 증명 규칙과 의도 단계만.

```
지적마다 명령 · 출력을 요구 → 못 돌린 지적은 「확인 필요」로 내려간다
  → 수정 step으로 이어지는 지적 수가 준다
  → REVIEW ↔ 수정 루프가 3회차 상한(0.26.0) 안에서 끝날 가능성이 커진다
  → 궁극: 리뷰가 지적을 쏟기만 하는 과적합(볼트 리뷰 조각 ⑨)을 줄인다
```

다음 단계 영향: 새 스킬 · `arena` 없이 `code-reviewer` · `sdd-review` 두 파일만 바뀐다. 큰 설계 갈림길용 독립 스킬(a)은 BACKLOG 조건으로 미룰 수 있다.

### D8. `statechart`를 어떻게 가져올까

선택지는 4-1 셋째 행. 추천 (b) 반입 + 사람 호출 전용 + 첫 사용 뒤 판정.

```
2026-11-23 사용자가 「흡수」를 이미 정했다 → 남은 건 무게를 어디에 가두나
  → 사람 호출 · 스크래치 폴더 전용이면 상시 비용 · 레포 오염이 0이다
  → 첫 사용 한 번으로 남길지 숫자로 판정한다(30일 0회면 삭제 후보)
  → 궁극: 「혹시 몰라」로 무거운 도구를 상시 경로에 올리지 않는다(사용자 작업 원칙)
```

다른 길(c, BACKLOG 조건)은 「흡수」 결정과 방향이 반대라 근거를 같이 적었다: 상태 전이 버그 실제 건수 기록이 없다.

### D9. `correct` · `reflect` · `blast-radius`를 새 스킬로 둘까, 기존 스킬에 넣을까

| 선택지 | 굳는 것 | 비싸지는 것 |
|---|---|---|
| 기존 스킬에 규칙만 (추천) | `correct` → `harness-gaps` 위계, `reflect` → REFLECT 문턱 3줄, `blast-radius` → D7 증명 규칙 | 사람이 `/correct`처럼 따로 부를 진입점은 없다 |
| 새 스킬 3개 | PStack과 같은 진입점 | 스킬 수 · 상시 비용이 늘고 REFLECT · `harness-gaps`와 자리가 겹친다 |

### D10. 레포 전용 검증 스킬 생성(`create-verification-skill` 계열)을 가져올까

| 선택지 | 굳는 것 | 비싸지는 것 |
|---|---|---|
| BACKLOG 승격 조건으로 (추천) | 조건: PR 본문 「리뷰 심각도: 미실행」 또는 `sdd-review` 「실제 동작 미실행」 3건 | 그 전까지 `run` 스킬 · Playwright로 버틴다 |
| `harness-init`에 생성 단계 | 레포마다 증거를 남기는 길이 처음부터 있다 | 레포마다 스킬 하나 · 유지 스킬 하나가 늘어난다 |

### D11. 훅 3개(`loop-lock` · `todo-warn` · `validate-session-end`)를 어떻게 할까

| 선택지 | 굳는 것 | 비싸지는 것 |
|---|---|---|
| 기록 경로부터 보강 후 다시 잼 (추천) | `validate-session-end` 0줄이 「안 돌았다」인지 「기록 못 했다」인지 가린다 | 판단이 한 번 더 미뤄진다(재측정 기한을 정해야 함) |
| `loop-lock` · `todo-warn` 끄기 | 막은 적 0인 훅 2개가 빠진다 | 14일 · 개인 레포 3곳 숫자로만 판단한다 |
| 그대로 | 없음 | 0.27.0 「숫자 쌓인 뒤 판단」이 계속 미뤄진다 |

### D12. 쓰지 않는 의존 `understand-anything`을 뺄까

| 선택지 | 굳는 것 | 비싸지는 것 |
|---|---|---|
| 의존 선언 제거 (추천) | 설치가 플러그인 하나로 끝난다 | 나중에 다시 쓰면 의존을 다시 건다 |
| 유지 | 그대로 | 쓰지 않는 플러그인 설치가 계속 전제 조건이다 |

## 확인 못 한 것

- 회사 머신 · 회사 레포의 스킬 사용 기록(0절). `slack-writing` · `notion-writing` · `changeset` 판정은 이 기록 없이 했다
- 플러그인 스킬을 `skills/` 아래 하위 폴더에서 읽는지(2-1 C안)
- `teach-me` · `zotero-cli`가 외부 배포본인지(1-4, 둘 다 추정)
- 개인 `why-logictree`를 2026-11-13에 다시 넣은 이유(D4)
- `validate-session-end`가 기록 0줄인 원인(R3, 추정)
- 상태 전이 버그 실제 건수(D8)
- PStack 플레이북 22개 본문 · 가이드(제목만 봤다)
