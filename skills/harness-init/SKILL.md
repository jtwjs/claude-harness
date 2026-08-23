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

## 2. 명령 실측 ⭐

`package.json` scripts·Makefile·CI 설정에서 후보를 뽑고 **하나씩 실제로 실행한다.**

- **통과한 것만** `harness.json.verify`에 적는다. 실패하면 **뺀다**(고치려 들지 않는다).
- `verify.format`에는 **읽기 전용(`--check` 계열)만** 넣는다. 포맷 적용은 `auto-format` 훅이 편집 직후에 한다.
- 없는 키는 **비워 둔다.** 지어내지 않는다.

**2-b. 테스트 러너·BDD 별칭 탐지** → `test.runner` · `test.bddAlias`.
별칭(`context` 등)이 없으면 **파일을 심지 않고** `bddAlias: false`로 기록한다. `test-writer`가 중첩 `describe`로 대체한다.

## 3. 인터뷰 (기계가 모르는 것만, 7개)

① **절대 금기가 있나?** → CLAUDE.md 🔴 CRITICAL
② **처음 온 사람이 당하는 함정은?** → `non-obvious-patterns.md` 첫 항목
③ **이 서비스를 한 줄로?** → CLAUDE.md 첫 줄
④ **TDD를 강제할 경로는?** (후보 제시) → `tdd.include`/`exclude`. 없으면 `enabled: false` + **감점 보고**
⑤ **`_brain/`을 둘까?** → 지식 파이프라인
⑥ **CI에 테스트 게이트가 있나?** → 없으면 `ci.test: "deferred"`
⑦ **릴리스를 Changesets로 관리할까?** → 예면 **없어도 깔아준다**(6단계)

## 4. 생성

**기본 6**
- `CLAUDE.md` — ~40줄. **CRITICAL + 링크만.** 검증 명령은 적되 정본은 `harness.json`
- `.claude/harness.json`
- `.claude/README.md` — 라우팅 ~10줄
- `.claude/rules/non-obvious-patterns.md` — **빈 파일로 시작**(②의 답 한 줄만)
- `.claude/rules/testing.md` — `tdd-guard`의 판정 근거. **훅 면제 목록과 같은 표를 보게** 맞춘다
- `.claude/references/implementation-patterns.md` — 구현 패턴 6개

**조건부**: TS면 `rules/{typescript,functional-programming}.md` · ⑤면 `_brain/` · ⑦이면 Changesets · CI 워크플로

**`.gitignore` 보강** — `templates/.gitignore.append`의 내용을 **기존 `.gitignore`에 덧붙인다**(덮어쓰지 않는다). 훅이 남기는 `.claude/.last-*`와 리포트가 매번 untracked로 뜨는 것을 막는다.
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

마지막에 **비어 있는 칸을 명시**한다 — `verify.test` 없음 / `ci.test: deferred` / `tdd.enabled: false` / `release.tool: null`.

> 🔴 **비었다는 사실을 말하지 않으면 조용히 죽는다.** 채우라고 강요하지는 않되, **매번 보이게** 남긴다.
