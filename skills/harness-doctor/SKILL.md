---
name: harness-doctor
description: 이미 깔린 하네스가 썩었는지 점검한다. 문서와 실제가 어긋난 곳, 존재하지 않는 경로를 가리키는 참조, 비어 있는 축적소, 조용히 자란 컨텍스트 로드량을 찾는다. 주기적으로 또는 "하네스 점검해줘"라고 할 때 실행한다. CLAUDE.md 자체의 품질 감사는 공식 claude-md-management 플러그인이 하므로 여기서 하지 않는다.
allowed-tools: [Read, Bash, Glob, Grep]
---

**하네스 고유 검사 8개만** 한다. CLAUDE.md 품질 감사(등급·압축 제안)는 공식 `claude-md-management`가 하므로 **중복하지 않는다.**

## 0. 버전·스키마 표류

`.claude/harness.json`의 `harness.version` ↔ `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`의 `version`. 다르거나 비어 있으면 ⚠️와 함께 **키 차이**를 두 줄로 보고한다 — ① `${CLAUDE_PLUGIN_ROOT}/templates/.claude/harness.json`에 있는데 레포에 없는 최상위 키 ② 레포에만 있는 키(`$comment` 제외). 고치지는 않는다 — 어느 키를 받아들일지는 사람이 정한다.

> 2026-10-08 실측: 레포 9개의 키 모양이 4종이었다(`git`·`stacks`는 셋만, `docs`·`project`는 둘만, `brainSync.sensitivePolicy`는 하나만·템플릿에 없음). 버전 키가 없어서 이게 표류인지 의도인지 아무도 몰랐다.

## 1. verify drift

`CLAUDE.md`에 적힌 검증 명령 ↔ `.claude/harness.json`의 `verify`가 같은가.

> 이 둘은 **의도적으로 중복**돼 있다(사람도 봐야 하므로). 그래서 어긋날 수 있고, 그걸 잡는 게 이 검사의 존재 이유다. 정본은 `harness.json`.

`verify`가 **앱별**(`{"<root>": {…}}`)이면 root마다 대조하고, 키가 `stacks.packs[].root`와 1:1인지도 본다(root 폴더가 실재하는지 포함). 단일 앱 키와 앱별 키가 섞여 있으면 ⚠️ — 훅은 앱별만 읽는다.

**1-b. CI 워크플로** — `.github/workflows/ci.yml`이 있으면 네 가지를 본다. ① 플레이스홀더(`grep -E '\{\{[A-Z_]+\}\}'`)가 남아 있는가(남아 있으면 🔴 — 워크플로가 통째로 무효다. `${{ github.… }}`는 세지 않는다) ② 각 `run:` 값이 `verify.*` 중 하나와 같은가(`verify`가 바뀌었는데 CI가 옛 명령을 돌리는 drift). 앱별이면 잡의 `working-directory`로 root를 찾아 `verify["<root>"]`와 대조 ③ `verify.test`가 비었는데 test 스텝이 없거나 `ci.test`가 `"deferred"`가 아닌가 ④ 앱별인데 단일 잡 하나이거나, 앱 잡이 있는데 `ci-gate`가 없는가. 이 검사가 **harness-init §4 표가 안 지켜진 것을 잡는 유일한 자리**다.

## 2. 참조 무결성 (양방향)

- **정방향**: `CLAUDE.md`·`.claude/rules/`·`.claude/README.md`에 적힌 **경로가 실재하는가**. 없는 파일·스킬·명령을 가리키면 그건 **모델이 그대로 믿는 거짓말**이다.
- **역방향**: `.claude/references/`의 모든 파일이 `rules`나 `CLAUDE.md`에서 **트리거되는가**. 아무도 안 여는 references는 **죽은 문서**다.

## 3. 빈 축적소

`.claude/rules/non-obvious-patterns.md`가 **비어 있는가.** 0.10.0부터 플러그인이 심는 「시드」 절 2줄은 세지 않는다 — `---` 아래만 본다.

> 비었다는 것은 아직 아무 함정도 안 겪었거나, **겪고도 안 적었다**는 뜻이다. 후자면 이 레포에서 같은 사고가 반복된다.

## 4. 라우팅 1:1

`.claude/README.md`의 라우팅 표에 적힌 스킬·에이전트가 **실재하는가**(정방향만). 설치돼 있는데 표에 없는 것은 세지 않는다 — 플러그인 스킬(2026-10-11 기준 24개)을 전부 표에 올리는 것이 목적이 아니라, 표가 거짓을 가리키지 않는 것이 목적이다. (2026-10-08: 양방향으로 두니 init 직후부터 항상 ⚠️였다)

## 5. 🔴 컨텍스트 로드량 (두 축)

이 하네스에서 **유일하게 숫자를 보는 검사**다. 나머지 넷은 통과하면 조용하지만, **로드량은 조용히 자란다.**

| 축 | 재는 것 | 임계 | 넘으면 |
|---|---|---|---|
| **상시 로드량** | `paths:` frontmatter가 **없는** `rules/*.md`의 **합계 바이트** | ≈10KB | `paths:`를 안 붙인 파일을 지목 |
| **매칭 폭탄** | `rules/*.md` **개별 파일** 크기 | ≈10KB | **`references/`로 내리라고 권고** |

> ⚠️ **두 번째 축이 핵심이다.** `paths:`를 붙였다고 안심하면 안 된다 — **매칭되면 그 파일은 통째로** 들어온다. 조건부는 *빈도*를 줄이지 *크기*를 줄이지 않는다.
>
> 실측 사례: 한 레포는 rules 7개가 frontmatter 없이 **160KB ≈ 40,000토큰**을 매 세션 로드하고 있었다. 구조가 없어서가 아니라 **아무도 재지 않아서**다.

**교차 확인**: `claude plugin details <plugin>`의 `Always-on` 값도 함께 보고한다. **컴포넌트당 ≤180토큰**(`docs/design-notes.md` §3)을 넘으면 ⚠️ — 넘긴 컴포넌트를 `always-on` 내림차순 상위부터 지목한다. always-on을 키우는 것은 본문이 아니라 **`description` 길이**뿐이므로, 지목 대상은 description이다.

## 6. 반복 계수 (`task-observer`)

`.claude/observations.md`를 열고 **3회에 닿은 행**이 있으면 승격 판정을 같이 돈다. 파일이 없으면 "아직 안 셌다"로 **보고만** 한다 — 만드는 것은 `task-observer` 몫이다(이 스킬에는 Write가 없다).

> 검사 3(빈 축적소)과 다르다 — 저기는 *비어 있나*를 보고, 여기는 *찬 것을 안 옮겼나*를 본다. 3회를 넘긴 행이 방치되면 계수기를 둔 값이 없어진다.

## 7. 설정 ↔ 실재

**7-a. 스택 팩**: `harness.json.stacks.packs` ↔ 실제 빌드 파일(`${CLAUDE_PLUGIN_ROOT}/templates/stacks/README.md` 판정표) ↔ `.claude/rules/`에 깔린 팩 규칙. 셋이 어긋나면 ⚠️ — 빌드 파일은 있는데 팩이 없거나, 팩은 적혀 있는데 규칙 파일이 없거나, 모노레포 팩 규칙의 `paths:`가 앱 디렉터리를 안 붙여 0개 파일에 매칭되는 경우.

**7-b. 릴리스**: `release.tool`이 `"changesets"`인데 `.changeset/config.json`이 없거나, 반대로 `.changeset/`은 있는데 `release.tool`이 `null`이면 ⚠️ — `changeset` 스킬이 0단계에서 잘못 skip 하거나 잘못 돈다.

**7-c. gitignore**: 루트 `.gitignore`에 `.claude/.last-*`가 없으면 ⚠️ — 훅 stamp 가 매 세션 untracked 로 뜬다(`${CLAUDE_PLUGIN_ROOT}/templates/.gitignore.append` 미적용). `_brain/`이 있으면 `_brain/internal/`도 같이 본다.

**7-d. `_brain/`**(있을 때만): `_brain/wiki/index.md`에 적힌 노드 ↔ 실제 `.md` 파일이 1:1인가. 비밀값 패턴 grep은 `_brain/CLAUDE.md`의 명령 그대로 한 번 돌려 0건인지 본다.

## 출력

각 검사에 **✅ / ⚠️ / 🔴** 하나와 근거 한 줄. 수치가 있는 것은 수치를 적는다.

마지막에 **가장 먼저 고칠 것 하나**만 고른다 — 전부 나열하면 아무것도 안 고친다.

**금지**: 자동으로 고치지 않는다. 진단하고 제안까지만.
