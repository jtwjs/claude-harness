---
name: harness-init
description: 레포에 하네스를 깐다 — 진단하고 검증 명령을 실제로 돌려 본 뒤, 기계가 모를 것만 인터뷰해 CLAUDE.md·.claude/{harness.json,rules,references}·CI를 만든다. 새 프로젝트나 첫 적용 때 한 번. 이미 깔린 레포면 업그레이드 모드("하네스 업그레이드해줘"). 점검만은 harness-doctor.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
disable-model-invocation: true
---

레포를 진단해 **사실로 채우고**, 기계가 모르는 것만 묻는다. **추측으로 빈칸을 채우지 않는다.**

> 🔴 **이 스킬의 유일한 실패 모드는 "돌지 않는 명령을 적는 것"이다.** 명령은 전부 **실제로 실행해 보고 통과한 것만** 기록한다.

## 0. 이미 깔린 레포: 업그레이드 모드

`.claude/harness.json`·`.claude/README.md` 중 하나라도 있으면 아래만 하고 끝낸다. 진단·명령 실측·인터뷰·CI는 다시 하지 않는다(그건 사람이 고친 것을 덮는다). 손대는 것은 **템플릿이 주인인 사본**뿐이고, 스택 팩 규칙은 덮지 않고 **고르게** 한다.

| 대상 | 어떻게 |
|---|---|
| 지운·바뀐 스킬 이름 | 이름표 `${CLAUDE_PLUGIN_ROOT}/skills/harness-init/references/renames.tsv`(옛 이름 · 지금 · 언제, 한 줄에 옛 이름 하나)대로 그 자리만 고친다 |
| `.claude/README.md` 라우팅 표 | `${CLAUDE_PLUGIN_ROOT}/templates/.claude/README.md` 표와 대조해 빠진 행만 넣는다. 레포가 직접 넣은 행은 둔다 |
| 레포의 옛 팀 위키 폴더(`_brain/`) | 지우지 않는다. 하네스는 더 이상 깔지도 쓰지도 않는다는 것(ADR-013)과 `rules/brain.md`가 있으면 그 규칙도 안 쓴다는 것을 한 줄 안내만 한다. 지울지는 레포 주인이 정한다 |
| `harness.json` | `harness.version`을 `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 버전으로. 템플릿에만 있는 최상위 키는 목록만 보여 주고 넣지 않는다(`harness-doctor` §0과 같은 판정) |
| `.gitignore` | `${CLAUDE_PLUGIN_ROOT}/templates/.gitignore.append`의 줄 중 빠진 것만 |
| `.claude/settings.json` | `${CLAUDE_PLUGIN_ROOT}/templates/.claude/settings.json`의 `permissions.deny` 중 빠진 줄만 보여 주고 🙋 승인 뒤 합친다. 파일이 없으면 템플릿을 깐다 |
| 스택 팩 규칙 (`.claude/rules/`) | `stacks.packs`의 팩마다 3방향으로 diff 한다 — 기준 = 레포 `harness.version` 판 템플릿, 새 판 = 지금 템플릿, 그리고 레포 사본. 레포 사본과 새 판만 비교하면(2방향) 어느 쪽이 바뀌었는지 몰라 「템플릿에만 / 레포에만」을 가를 수 없다. 기준 판은 마켓플레이스 clone(`~/.claude/plugins/marketplaces/<marketplace>`, git 저장소)에서 `git log -1 --format=%H -S'"version": "<harness.version>"' -- .claude-plugin/plugin.json` 커밋의 `templates/stacks/<pack>/rules/*.md`로 꺼낸다. 못 찾으면 2방향으로 하고 표 머리에 「기준 없음 — 템플릿에만 / 레포에만 구분 불가」를 적는다. 세 판 모두 비교 전에 템플릿 `paths:`에 그 팩의 `root` 접두를 붙인 판으로 맞춘다(§4 「스택 팩」과 같은 규칙. 접두가 빠지면 그 규칙은 어느 파일에도 안 걸린다). 결과를 `파일 · 템플릿에만 있음 / 레포에만 있음 / 둘 다 바뀜`으로 보여 주고 파일마다 🙋 「템플릿으로 · 레포 판 유지 · 줄 단위로 합치기」를 고르게 한다. 레포에 없는 팩 규칙 파일은 새로 깔지 묻는다. 덮어쓰지 않는다 — 레포가 일부러 고친 줄이 섞여 있다 |
| 새로 맞는 팩 | §1-b 스택 판정을 빌드 파일로 다시 돌려 `stacks.packs`에 없는 팩이 나오면 목록만 보여 준다(예: init 뒤에 생긴 팩). 넣으면 위 행대로 규칙을 깔고 `stacks.packs`에 더한다 — 🙋 승인 뒤 |

- 전체 diff를 보여 주고 🙋 승인을 받은 뒤 쓴다. 커밋은 `chore: harness <버전> 업그레이드` 한 건, push는 하지 않는다.
- 작업 트리가 더럽거나 기능 브랜치 위면 기본 브랜치에서 `git worktree add`로 따로 만들어 한다.
- `harness.json`이 없는 레포는 있는 사본만 고친다. `harness.json`을 새로 만들면 훅이 켜지는 전체 설치가 되므로, 끝에 "전체 설치는 이 스킬을 처음부터"라고 한 줄 안내한다.
- 끝나면 옛 이름 grep 0건과 `harness.version`을 확인한다.

## 1. 진단 (7축)

읽어서 판정한다. 없는 것은 **없다고 적는다.**

| 축 | 보는 것 |
|---|---|
| CLAUDE.md 정합성 | 있는가 · 적힌 명령이 실재하는가 |
| 도메인 맥락 | 이 서비스가 뭔지 아는 문서가 있는가 |
| 구조 지도 | 진입점·의존 방향을 알 수 있는가 |
| 검증 경로 | 무엇을 돌리면 통과인지 정해져 있는가 |
| 자동 게이트 | 훅·CI가 실제로 막는가 (경고만 하면 **없는 것으로 친다**) |
| 결정 기록 | 왜 그렇게 했는지가 어딘가 남는가 |
| 작업 단위 | 일을 쪼개는 규약이 있는가 |

## 1-b. 스택 판정

`${CLAUDE_PLUGIN_ROOT}/templates/stacks/README.md`의 표대로 **빌드 파일로만** 판정한다. 모노레포면 앱 디렉터리마다 따로. 결과는 `harness.json.stacks.packs`에 적는다.

⛔ **스택을 추측하지 않는다.** 빌드 파일이 없거나 표에 없는 조합이면 묻는다.

고른 팩의 `pack.md` 머리에 「미실측」이 있으면 사람에게 한 줄 알리고 그대로 진행한다(막지 않는다): 「<pack> 팩은 미실측이다 — 검증 명령 후보를 아직 어느 레포에서도 돌려 보지 않았다. §2에서 실제로 돌려 본 결과로 플러그인 레포의 `templates/stacks/<pack>/pack.md`를 고쳐 주세요」.

## 2. 명령 실측 ⭐

`package.json` scripts·Makefile·CI 설정, 그리고 **판정된 팩의 `pack.md` 후보표**에서 후보를 뽑고 **하나씩 실제로 실행한다.**

- **통과한 것만** `harness.json.verify`에 적는다. 실패하면 **뺀다**(고치려 들지 않는다).
- **앱이 둘 이상**(모노레포 · `stacks.packs`에 root가 여럿)이면 앱별 형태로 적는다: `{"apps/api": {"test": "…"}, "apps/web": {…}}`. 키는 `stacks.packs[].root`와 같은 값이고, 명령은 **그 폴더에서** 실행해 본다(`cd <root> && …`). 앱별이면 단일 앱 키(`format`·`lint`…)는 지운다. `validate-session-end`·`loop-lock` 훅과 `harness-doctor`가 두 형태를 다 읽는다
- `verify.format`에는 **읽기 전용(`--check` 계열)만** 넣는다. 포맷 적용은 `auto-format` 훅이 편집 직후에 한다.
- 없는 키는 **비워 둔다.** 지어내지 않는다.
- `git.baseBranch` ← `bash "${CLAUDE_PLUGIN_ROOT}/scripts/base-branch.sh"` 출력(harness.json이 비어 있으면 `origin/HEAD`로 떨어진다). exit 2면 사람에게 묻는다. `git.commitScope`는 기존 커밋 이력에 `type(scope):`가 쓰이는지 보고 제안한다. `git.branchPattern`은 최근 원격 브랜치 이름(`git branch -r`)·`CLAUDE.md`·rules의 브랜치 규칙을 보고 `{task}`를 넣은 형태로 제안한다(예: `feature/{task}`). 규칙이 안 보이면 비운다(러너 기본 `feat-{task}`). `verify`가 앱별이면 `verifyAffects`(경로 glob → 같이 돌릴 앱)를 제안한다 — 트랙 표의 계약 경로, CI `paths` 필터, 앱끼리 import 하는 공유 경로를 보고. 확신이 없으면 비운다(마지막 step 전체 verify가 잡는다). 테스트가 오래 걸리면 앱별 `$step.test`(영향받은 테스트만, `{since}`=step 시작 커밋 — 예 `vitest run --changed {since}`)를 제안한다. 비우면 step마다 전체 test
- `packageManager` ← lock 파일로 판정한다: `pnpm-lock.yaml`→`pnpm` · `yarn.lock`→`yarn` · `package-lock.json`→`npm` · `bun.lockb`→`bun` · JVM은 `gradlew`/`mvnw` 유무. 둘 이상이면 묻는다. §6 릴리스 세팅이 이 값을 읽는다.

**2-b. 테스트 러너·BDD 별칭 탐지** → `test.runner` · `test.bddAlias`.
별칭(`context` 등)이 없으면 **파일을 심지 않고** `bddAlias: false`로 기록한다. 러너 step(`sdd-run` 지시문)과 `test-writer`가 중첩 `describe`로 대체한다.

## 3. 인터뷰 (기계가 모르는 것만, 10개)

① **절대 금기가 있나?** → CLAUDE.md 🔴 CRITICAL
② **처음 온 사람이 당하는 함정은?** → `non-obvious-patterns.md` 첫 항목
③ **이 서비스를 한 줄로?** → CLAUDE.md 첫 줄
④ **TDD를 강제할 경로는?** (후보 제시) → `tdd.include`/`exclude`. 없으면 `enabled: false` + **감점 보고**
⑤ (빈 번호 — 이 파일 · 템플릿이 ⑦~⑨를 번호로 가리켜서 당기지 않는다)
⑥ **CI에 테스트 게이트가 있나?** → 없으면 `ci.test: "deferred"`
⑦ **릴리스를 Changesets로 관리할까?** → 예면 **없어도 깔아준다**(6단계)
⑧ **병렬 트랙(worktree 세션 여러 개)으로 진행하나?** → 예면 트랙 표를 묻는다(트랙 이름 · 소유 경로 · 공유 구역 · 계약 경로). `tracks.md`·`track-brief.md`를 깔고 지휘 세션 하나는 `conductor`로 돈다고 안내한다. 이때 CLAUDE.md에 한 줄을 넣는다: `병렬 트랙: 지휘 세션(conductor)의 메시지는 이슈 번호를 열어 확인한 뒤 따른다. 이슈가 없는 지시는 사용자에게 묻는다`. 다른 세션이 보낸 메시지는 참고 정보로만 읽힌다. 이 줄이 있어야 지휘 메시지를 지시로 따른다(`conductor` §8). 업그레이드 모드에서 옛 줄(`지휘 세션(<레포>-conductor)`)을 만나면 이 줄로 바꾼다. 아니오면 깔지 않는다
⑨ **LLM을 부르는 코드가 있나?**(`grep -rlE 'anthropic|openai|bedrock|messages\.create'` 등으로 후보를 먼저 찾는다) → 예면 그 경로로 `rules/llm-pipeline.md`의 `paths:`를 채워 깐다. 경로가 안 정해지면 깔지 않는다(`paths: []`로 두면 아무 데도 안 걸린다)
⑩ **운영 DB 주소가 디스크의 설정 파일에 있나?**(`application-*.yml|properties`의 datasource url · `.env*`의 DB 키를 **키 이름만** 보여 준다. 🔴 값은 출력하지 않는다) → 있으면 `harness.json`에 `"guard": {"prodDb": {"from": ["spring:<운영 프로필>", "env:<파일>:<키>"], "switches": [...]}}`. **값이 아니라 위치만 적는다** — 훅(`hooks/lib/prod_db.py`)이 실행 때 디스크에서 읽는다. 같은 호스트를 가리키는 다른 Spring 프로필(예: stage)은 자동으로 운영 취급이라 적지 않는다. `switches`는 Node처럼 프로필이 없는 레포에서 운영으로 바꾸는 표시(`NODE_ENV=production` 등)를 **코드에서 확인해** 적는다. 운영 주소가 배포 환경 변수로만 들어가 디스크에 없으면 적지 않는다 — 에이전트도 붙을 정보가 없고, 적으면 세션마다 '꺼짐' 알림이 뜬다. 막는 것: 운영 DB에 쓰기 SQL·SQL 파일 실행, 운영 프로필·스위치로 실행. 조회(SELECT)는 막지 않는다

## 4. 생성

**기본 7**
- `CLAUDE.md` — ~40줄. **CRITICAL + 링크만.** 검증 명령은 적되 정본은 `harness.json`. 이미 있으면 덮지 않고 기존 줄(예: Next의 `@AGENTS.md`)을 보존한 채 더한다
- `.claude/harness.json` — `harness.version` ← `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`의 `version`(어느 플러그인 버전으로 깔았는지. `harness-doctor` 검사 0이 읽는다)
- `.claude/README.md` — 라우팅 ~10줄
- `.claude/rules/non-obvious-patterns.md` — 플러그인 시드 2줄(셸 함정) + ②의 답 한 줄. 레포 항목은 `---` 아래부터
- `.claude/rules/testing.md` — `tdd-guard`의 판정 근거. **훅 면제 목록과 같은 표를 보게** 맞춘다
- `.claude/references/implementation-patterns.md` — 구현 패턴 6개
- `.claude/settings.json` — `${CLAUDE_PLUGIN_ROOT}/templates/.claude/settings.json`의 `permissions.deny`(훅이 꺼진 환경에서도 막히게). 이미 있으면 덮지 않고 빠진 deny 줄만 보여 주고 🙋 승인 뒤 합친다

**조건부**: TS면 `rules/{typescript,functional-programming}.md`(React면 `rules/react-components.md`도) · Kotlin이면 `rules/functional-programming.md` · ⑨면 `rules/llm-pipeline.md` · Dependabot(`${CLAUDE_PLUGIN_ROOT}/templates/.github/dependabot.yml` — 판정된 팩의 블록만 남기고 `directory`를 root로. 기준 브랜치가 기본 브랜치와 다르면 `target-branch`를 푼다. 레포에 이미 있으면 덮지 않는다) · ⑦이면 Changesets · ⑧이면 `.claude/references/{tracks,track-brief}.md`(`${CLAUDE_PLUGIN_ROOT}/templates/.claude/references/` — 트랙 표는 인터뷰 답으로 채우고, CLAUDE.md에 「트랙」 절 한 줄 + ⏬ 링크. 라벨은 `conductor` 첫 실행이 만든다) · CI 워크플로(`${CLAUDE_PLUGIN_ROOT}/templates/.github/workflows/ci.yml`) + PR 템플릿(`${CLAUDE_PLUGIN_ROOT}/templates/.github/PULL_REQUEST_TEMPLATE.md` — `pr-write`는 이 템플릿이 있으면 그 절 구조를 채운다. 레포에 이미 있으면 덮지 않는다)

**스택 팩**: 판정된 팩마다 `${CLAUDE_PLUGIN_ROOT}/templates/stacks/<pack>/rules/*.md`를 `.claude/rules/`에 복사하고, `pack.md`의 CI 셋업 스텝으로 `ci.yml`의 `{{SETUP_STEPS}}`를 채운다. 모노레포면 `paths:`의 **모든 glob** 앞에 그 팩의 `root`를 붙인다(`**/controller/**` → `apps/api/**/controller/**`, `src/**/*.test.tsx` → `apps/web/src/**/*.test.tsx`). 손으로 고르지 않는다 — 하나라도 빠지면 그 규칙은 조용히 안 걸린다. 팩 규칙과 기존 규칙이 같은 파일명이면 덮지 말고 보고한다. 기존 레포(코드가 이미 있는 레포)면 `testing-fe.md` · `e2e.md`의 「이 레포 현황」 절을 진단으로 채운다 — 렌더 헬퍼 · MSW · e2e 폴더가 실제로 있는지 파일로 확인하고, 「새 코드는」 칸만 묻는다. kit으로 시작한 레포면 그 절을 지운다.

**CI 워크플로 플레이스홀더** — 복사한 `.github/workflows/ci.yml`을 스크립트로 채운다. 하나라도 남기면 `run:`이 빈 스텝이 되어 GitHub Actions가 워크플로 자체를 거부한다. 팩이 있으면 `{{SETUP_STEPS}}`부터 위 「스택 팩」대로 채운 뒤 부른다.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/harness-init/scripts/fill_ci.py" .claude/harness.json .github/workflows/ci.yml
```

- exit 0이 될 때까지 끝난 것이 아니다. exit 1이면 stderr에 남은 플레이스홀더와 이유가 나온다 — 기준 브랜치를 못 정했으면 사람에게 묻고, 나머지는 이유대로 고친 뒤 다시 돌린다.
- `verify`가 **앱별**이면 스크립트는 `VERIFY_*`를 건드리지 않는다. `jobs` 전체를 `ci.yml` 맨 아래 주석 블록 형태로 바꾸고(앱마다 잡 · `paths` 필터 · `ci-gate`. 브랜치 보호 필수 체크는 `ci-gate` 하나) 다시 돌린다.

**`.gitignore` 보강** — `${CLAUDE_PLUGIN_ROOT}/templates/.gitignore.append`의 내용을 **기존 `.gitignore`에 덧붙인다**(덮어쓰지 않는다). 훅이 남기는 `.claude/.last-*`와 리포트가 매번 untracked로 뜨는 것을 막는다.
⚠️ `.claude/`를 통째로 ignore하지 않는다 — `harness.json`·`rules/`·`references/`는 **커밋되어야 자산**이다(안 그러면 dotfiles다).

⚠️ **`rules/`는 `paths:` frontmatter를 반드시 단다**(`non-obvious-patterns.md`만 예외 — 상시). 붙이지 않으면 매 세션 전량 로드된다.

## 5. 심지 않는 것

- **구조 지도 파일** — 새로 만들지 않고 `CLAUDE.md` 안에 진입점·의존 방향을 적는다. 레포가 커지면 그때 분리
- **ADR 폴더 구조** — 이미 굴러가는 관행이 있으면 그것을 쓰고, 없으면 `docs/{feature-YYYY-MM-DD}/ADR.md` 한 줄만 안내
- **하위 CLAUDE.md** — `.claude/rules/` + `paths:`가 1순위다. 하위 CLAUDE.md는 코드가 import하지 않는 폴더일 때만

## 6. 릴리스 세팅 (⑦이 예일 때만)

**쓰는 법만이 아니라 없으면 깔아준다.** 레포 고유값은 **자동 추출**한다 — 지어내지 않는다.

| 단계 | 하는 일 | 자동 추출 |
|---|---|---|
| 의존성 | `@changesets/cli` + changelog 플러그인 | 패키지 매니저는 `harness.json` |
| init·패치 | `.changeset/config.json` 생성 후 수정 | `repo` ← `git remote get-url origin`<br>`baseBranch` ← `bash "${CLAUDE_PLUGIN_ROOT}/scripts/base-branch.sh"` 출력<br>`access` ← private면 restricted<br>`ignore` ← private 워크스페이스 |
| scripts | `package.json`에 2줄 | — |
| CI | PR에 changeset 추가가 있는지 검사 | 🔴 **없으면 exit 1로 차단**한다. 코멘트만 남기는 게이트는 없느니만 못하다. 우회는 `skip-changeset` 라벨 |

## 7. 검증 (필수)

`verify` 전체를 돌려 **red/green을 그대로 보고**한다.

마지막에 **비어 있는 칸을 명시**한다 — `verify.test` 없음 / `ci.test: deferred` / `tdd.enabled: false` / `release.tool: null` / `stacks.packs: []`(팩 없음).

> 🔴 **비었다는 사실을 말하지 않으면 조용히 죽는다.** 채우라고 강요하지는 않되, **매번 보이게** 남긴다.
