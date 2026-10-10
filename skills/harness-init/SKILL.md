---
name: harness-init
description: 이 레포에 하네스를 깐다. 레포를 진단하고, 검증 명령을 실제로 돌려보고, 기계가 모를 것만 인터뷰한 뒤 CLAUDE.md·.claude/{harness.json,rules,references}·CI를 생성한다. 신규 프로젝트를 시작할 때나 기존 레포에 처음 하네스를 적용할 때 한 번 실행한다. 이미 harness.json이 있으면 이 스킬 대신 harness-doctor 를 쓴다.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

레포를 진단해 **사실로 채우고**, 기계가 모르는 것만 묻는다. **추측으로 빈칸을 채우지 않는다.**

> 🔴 **이 스킬의 유일한 실패 모드는 "돌지 않는 명령을 적는 것"이다.** 명령은 전부 **실제로 실행해 보고 통과한 것만** 기록한다.

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

## 2. 명령 실측 ⭐

`package.json` scripts·Makefile·CI 설정, 그리고 **판정된 팩의 `pack.md` 후보표**에서 후보를 뽑고 **하나씩 실제로 실행한다.**

- **통과한 것만** `harness.json.verify`에 적는다. 실패하면 **뺀다**(고치려 들지 않는다).
- **앱이 둘 이상**(모노레포 · `stacks.packs`에 root가 여럿)이면 앱별 형태로 적는다: `{"apps/api": {"test": "…"}, "apps/web": {…}}`. 키는 `stacks.packs[].root`와 같은 값이고, 명령은 **그 폴더에서** 실행해 본다(`cd <root> && …`). 앱별이면 단일 앱 키(`format`·`lint`…)는 지운다. `validate-session-end`·`loop-lock` 훅과 `harness-doctor`가 두 형태를 다 읽는다
- `verify.format`에는 **읽기 전용(`--check` 계열)만** 넣는다. 포맷 적용은 `auto-format` 훅이 편집 직후에 한다.
- 없는 키는 **비워 둔다.** 지어내지 않는다.
- `git.baseBranch` ← `git symbolic-ref --short refs/remotes/origin/HEAD`(`origin/` 제거). 리모트가 없으면 비우고 보고한다. `git.commitScope`는 기존 커밋 이력에 `type(scope):`가 쓰이는지 보고 제안한다
- `packageManager` ← lock 파일로 판정한다: `pnpm-lock.yaml`→`pnpm` · `yarn.lock`→`yarn` · `package-lock.json`→`npm` · `bun.lockb`→`bun` · JVM은 `gradlew`/`mvnw` 유무. 둘 이상이면 묻는다. (§6 릴리스 세팅이 이 값을 읽는데 채우는 단계가 없었다 — 2026-10-08)

**2-b. 테스트 러너·BDD 별칭 탐지** → `test.runner` · `test.bddAlias`.
별칭(`context` 등)이 없으면 **파일을 심지 않고** `bddAlias: false`로 기록한다. `test-writer`가 중첩 `describe`로 대체한다.

## 3. 인터뷰 (기계가 모르는 것만, 9개)

① **절대 금기가 있나?** → CLAUDE.md 🔴 CRITICAL
② **처음 온 사람이 당하는 함정은?** → `non-obvious-patterns.md` 첫 항목
③ **이 서비스를 한 줄로?** → CLAUDE.md 첫 줄
④ **TDD를 강제할 경로는?** (후보 제시) → `tdd.include`/`exclude`. 없으면 `enabled: false` + **감점 보고**
⑤ **`_brain/`을 둘까?** → 팀 위키·인수인계용(코드가 raw, `brain-walk`가 첫 다섯 장). 개인 학습 폴더 `_learn/`은 묻지 않는다 — `learn-setup` 훅이 harness.json 있는 레포에 자동으로 만들고 `.git/info/exclude`로 뺀다. 예면 「사실을 바꾸는 코드 경로」(마이그레이션 · 컨트롤러 · 스케줄러 · 설정 · 라우트 · CI)를 후보로 보여 주고 `rules/brain.md`의 `paths:`와 표를 채운다
⑥ **CI에 테스트 게이트가 있나?** → 없으면 `ci.test: "deferred"`
⑦ **릴리스를 Changesets로 관리할까?** → 예면 **없어도 깔아준다**(6단계)
⑧ **병렬 트랙(worktree 세션 여러 개)으로 진행하나?** → 예면 트랙 표를 묻는다(트랙 이름 · 소유 경로 · 공유 구역 · 계약 경로). `tracks.md`·`track-brief.md`를 깔고 지휘 세션 하나는 `conductor`로 돈다고 안내한다. 아니오면 깔지 않는다
⑨ **LLM을 부르는 코드가 있나?**(`grep -rlE 'anthropic|openai|bedrock|messages\.create'` 등으로 후보를 먼저 찾는다) → 예면 그 경로로 `rules/llm-pipeline.md`의 `paths:`를 채워 깐다. 경로가 안 정해지면 깔지 않는다(`paths: []`로 두면 아무 데도 안 걸린다)

## 4. 생성

**기본 6**
- `CLAUDE.md` — ~40줄. **CRITICAL + 링크만.** 검증 명령은 적되 정본은 `harness.json`. 이미 있으면 덮지 않고 기존 줄(예: Next의 `@AGENTS.md`)을 보존한 채 더한다
- `.claude/harness.json` — `harness.version` ← `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`의 `version`(어느 플러그인 버전으로 깔았는지. `harness-doctor` 검사 0이 읽는다)
- `.claude/README.md` — 라우팅 ~10줄
- `.claude/rules/non-obvious-patterns.md` — 플러그인 시드 2줄(셸 함정) + ②의 답 한 줄. 레포 항목은 `---` 아래부터
- `.claude/rules/testing.md` — `tdd-guard`의 판정 근거. **훅 면제 목록과 같은 표를 보게** 맞춘다
- `.claude/references/implementation-patterns.md` — 구현 패턴 6개

**조건부**: TS면 `rules/{typescript,functional-programming}.md` · ⑤면 `_brain/`(`${CLAUDE_PLUGIN_ROOT}/templates/_brain/`를 복사 — 빈 카테고리 폴더는 만들지 않는다. 첫 채움은 `brain-walk`) + `rules/brain.md` · ⑨면 `rules/llm-pipeline.md` · Dependabot(`${CLAUDE_PLUGIN_ROOT}/templates/.github/dependabot.yml` — 판정된 팩의 블록만 남기고 `directory`를 root로. 기준 브랜치가 기본 브랜치와 다르면 `target-branch`를 푼다. 레포에 이미 있으면 덮지 않는다) · ⑦이면 Changesets · ⑧이면 `.claude/references/{tracks,track-brief}.md`(`${CLAUDE_PLUGIN_ROOT}/templates/.claude/references/` — 트랙 표는 인터뷰 답으로 채우고, CLAUDE.md에 「트랙」 절 한 줄 + ⏬ 링크. 라벨은 `conductor` 첫 실행이 만든다) · CI 워크플로(`${CLAUDE_PLUGIN_ROOT}/templates/.github/workflows/ci.yml`) + PR 템플릿(`${CLAUDE_PLUGIN_ROOT}/templates/.github/PULL_REQUEST_TEMPLATE.md` — `pr-write`가 있으면 그 구조를 따른다. 레포에 이미 있으면 덮지 않는다)

**스택 팩**: 판정된 팩마다 `${CLAUDE_PLUGIN_ROOT}/templates/stacks/<pack>/rules/*.md`를 `.claude/rules/`에 복사하고, `pack.md`의 CI 셋업 스텝으로 `ci.yml`의 `{{SETUP_STEPS}}`를 채운다. 모노레포면 `paths:` 앞에 앱 디렉터리를 붙인다(`apps/api/**/controller/**`). 팩 규칙과 기존 규칙이 같은 파일명이면 덮지 말고 보고한다.

**CI 워크플로(`${CLAUDE_PLUGIN_ROOT}/templates/.github/workflows/ci.yml`) 플레이스홀더 — 7개 전부 이 표로 채운다.** 하나라도 남기면 `run:`이 빈 스텝이 되어 GitHub Actions가 워크플로 자체를 거부한다(2026-10-08 리뷰에서 `{{SETUP_STEPS}}`만 적혀 있었다).

| 플레이스홀더 | 출처 (`harness.json`) | 비어 있을 때 |
|---|---|---|
| `{{BASE_BRANCH}}` | `git.baseBranch` | `origin/HEAD`에서 다시 뽑고, 그것도 없으면 묻는다 |
| `{{SETUP_STEPS}}` | 판정된 팩의 `pack.md` CI 셋업 스텝 | 팩이 없으면 주석 줄째 삭제 |
| `{{VERIFY_FORMAT}}` `{{VERIFY_LINT}}` `{{VERIFY_TYPECHECK}}` `{{VERIFY_BUILD}}` | `verify.format` · `lint` · `typecheck` · `build` | **그 `- name:` 스텝을 통째로 삭제** (ci.yml 머리 주석 "비어 있는 단계는 넣지 않는다") |
| `{{VERIFY_TEST}}` | `verify.test` | 스텝을 지우지 않는다. `ci.test`가 `"deferred"`면 `run: echo "test deferred — .claude/harness.json ci.test 참고"` |
| (형태) | `verify`가 **앱별**이면 | `jobs` 전체를 `ci.yml` 맨 아래 주석 블록 형태로 바꾼다 — 앱마다 잡(`working-directory: <root>`, 스텝은 `verify["<root>"]`로 위 규칙대로) + `paths` 필터 + `ci-gate`(needs 전부, skipped 허용). 브랜치 보호 필수 체크는 `ci-gate` 하나 |

채운 뒤 `grep -cE '\{\{[A-Z_]+\}\}' .github/workflows/ci.yml`이 **0**이어야 한다. (`${{ github.… }}`는 GitHub 식이라 세지 않는다. 0.10.0에서 `concurrency`가 들어가 옛 검사 `grep -c '{{'`는 항상 0이 아니다)

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
| init·패치 | `.changeset/config.json` 생성 후 수정 | `repo` ← `git remote get-url origin`<br>`baseBranch` ← `git symbolic-ref refs/remotes/origin/HEAD`<br>`access` ← private면 restricted<br>`ignore` ← private 워크스페이스 |
| scripts | `package.json`에 2줄 | — |
| CI | PR에 changeset 추가가 있는지 검사 | 🔴 **없으면 exit 1로 차단**한다. 코멘트만 남기는 게이트는 없느니만 못하다. 우회는 `skip-changeset` 라벨 |

## 7. 검증 (필수)

`verify` 전체를 돌려 **red/green을 그대로 보고**한다.

마지막에 **비어 있는 칸을 명시**한다 — `verify.test` 없음 / `ci.test: deferred` / `tdd.enabled: false` / `release.tool: null` / `stacks.packs: []`(팩 없음).

> 🔴 **비었다는 사실을 말하지 않으면 조용히 죽는다.** 채우라고 강요하지는 않되, **매번 보이게** 남긴다.
