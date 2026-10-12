---
name: pr-write
description: git 변경 내용을 분석해서 PR을 GitHub에 실제로 생성해줘. Reflect 완료 후 PR이 필요할 때 모델이 직접 호출 가능(워크플로우 자동 전환과 정합).
disable-model-invocation: false
---

작성 원칙: 사용자 영향 큰 변경을 두괄식 상단에, 리팩토링·테스트는 후순위, 단순 변수명·구조 변경은 제외. (상세 지침은 아래 "변경 사항" 템플릿 주석 참조 — 중복 서술 금지)

## 1단계: 변경 내용 수집

기준 브랜치: `.claude/harness.json`의 `git.baseBranch`(비었으면 `git symbolic-ref --short refs/remotes/origin/HEAD`에서 `origin/`을 뗀 값. 그것도 없으면 묻는다) = `<base>`.

```bash
git log <base>..HEAD --oneline          # 커밋 목록
git diff --name-only <base>...HEAD      # 변경 파일 목록
git diff <base>...HEAD                  # 전체 diff
git status --short                       # 미커밋 변경 확인
```

미커밋 변경이 있으면 PR 생성 전에 커밋 여부를 사용자에게 확인한다.

**현재 브랜치가 `<base>` 자신이면**(base 에 바로 커밋이 쌓인 경우) `<base>..HEAD` 가 비거나 틀린다 → `references/base-branch-rescue.md` 절차로 작업 브랜치로 옮긴 뒤(사용자 확인 필수) `origin/<base>` 기준으로 계속한다.

## 2단계: 원격 브랜치 푸시

현재 브랜치가 원격에 없거나 뒤처져 있으면 push한다:

```bash
git push -u origin HEAD
```

## 3단계: PR 제목 결정

제목은 커밋 메시지 형식과 같다 — `<type>: 요약`, 괄호 스코프는 `harness.json`의 `git.commitScope`가 `true`일 때만(**정본은 `commit` 스킬**). 예: `feat: 다건 이미지 DnD/paste 업로드 optimistic UI 적용`

## 4단계: Assignee·Label 결정

**Assignee**: `git config user.name` 또는 `gh api user --jq .login`으로 현재 작업자의 GitHub 로그인을 가져와 설정한다.

**Label**: diff와 커밋 내용을 바탕으로 아래 두 축에서 각각 1개씩 선택한다.

먼저 레포에 라벨이 있는지 확인한다 — 없는 라벨을 `--label` 로 넘기면 `gh pr create` 가 실패한다:

```bash
gh label list --limit 100 --json name --jq '.[].name' | grep -E '^(유형|복잡도): '
```

없으면 `--label` 을 빼고 PR 을 만든 뒤 «라벨 없음 — 만들까요?» 로 보고한다. 사용자 확인 없이 라벨을 만들지 않는다.

### 유형 레이블 (1개 선택)

| 레이블               | 선택 기준                                          |
| -------------------- | -------------------------------------------------- |
| `유형: 기능`         | 신규 기능·페이지·컴포넌트 추가 (`feat:` 커밋 포함) |
| `유형: 버그`         | 버그 수정 (`fix:` 커밋 위주)                       |
| `유형: 테스트`       | 테스트 코드만 변경                                 |
| `유형: 다큐멘테이션` | 문서·주석·README만 변경                            |

### 복잡도 레이블 (1개 선택)

| 레이블         | 선택 기준                                                          |
| -------------- | ------------------------------------------------------------------ |
| `복잡도: 쉬움` | 변경 파일 1~2개, diff 50줄 미만, 단순 수정                         |
| `복잡도: 보통` | 변경 파일 3~6개 또는 diff 50~200줄, 로직 변경 있음                 |
| `복잡도: 복잡` | 변경 파일 7개 이상 또는 diff 200줄 초과, 아키텍처·다수 레이어 변경 |

## 4.5단계: Risk Score 산출 (5축 0~100)

`references/risk-score.md`의 5축(보안 30 · 스코프 20 · Breaking 20 · 테스트 15 · 마이그레이션 15)으로 점수를 매겨 PR 본문에 표로 넣는다. **리뷰 강도 안내용이며 자동 머지는 하지 않는다.**

## 4.9단계: 이해 게이트 — 퀴즈 5 (PR 생성 직전)

리뷰를 요청하기 전에 작성자가 이 변경을 이해했는지 확인한다. 못 풀면 리뷰를 요청하지 않는다(draft). 검증은 에이전트에게 맡겨도 다음 작업에 쓸 이해는 맡길 수 없어서 둔다.

- **건너뜀**: 문서·설정만 바뀐 diff(`유형: 다큐멘테이션`). "이해 게이트 건너뜀 — 문서만" 한 줄 보고
- **퀴즈**: diff로 객관식 5문항을 터미널에 낸다. 기준은 `explain-diff-html` Quiz 절과 같다(중간 난이도·함정 X — 왜 이렇게 바꿨나, 바꾸면 무엇이 달라지나). 답은 한 줄로 받는다(`1b 2a 3c 4d 5a`). 정답을 먼저 보여 주지 않는다
- **채점 뒤 해설은 5문항 전부**: 맞힌 문항 ✅ 정답 + 왜 맞나 한 줄 · 틀린 문항 ❌ 정답 + 왜 틀렸나 두 줄. 점수와 상관없이 낸다 — 찍어서 맞힌 것도 이해로 남기려고
- **4/5 이상** → 5단계 그대로
- **3 이하** → 5단계를 `gh pr create --draft`로. `explain-diff-html`(노션이면 `explain-diff-notion`) 한 줄 제안. 다시 풀어 통과하면 `gh pr ready <번호>`
- 결과는 **PR 본문·커밋에 쓰지 않는다**. 틀린 문항은 `_learn/inbox.md`에 `종류: 막힌 질문 · 출처: PR 퀴즈` 카드로 남긴다(없으면 건너뛰고 한 줄 보고)

## 5단계: PR 본문 작성 후 생성

아래 템플릿으로 본문을 작성하고 `gh pr create`로 PR을 생성한다. base 브랜치는 1단계의 `<base>`다.
레포에 `.github/PULL_REQUEST_TEMPLATE.md`가 있으면(harness-init이 CI와 함께 깐다) **그 섹션 구조를 채우고** Risk Score 표만 첫 섹션 아래에 추가한다 — 사람이 만든 PR과 모양이 같아야 리뷰어가 같은 자리를 본다.

```bash
gh pr create \
  --base <base> \
  --title "<PR 제목>" \
  --assignee "<GitHub 로그인>" \
  --label "<유형 레이블>" \
  --label "<복잡도 레이블>" \
  --body "$(cat <<'EOF'
<본문>
EOF
)"
```

### PR 본문 템플릿

기본 구조는 `Summary → Risk Score → 변경 유형 → 변경 사항 → Test plan → 관련 이슈`. PR 성격에 따라 `변경 사항` 안에 원인/배경·동작 변화·머지 후 후속 작업·스크린샷 섹션을 자유롭게 추가한다. 큰 PR은 `### 1️⃣ … ### 2️⃣ …`로 분리.

```markdown
## Summary

<!-- 무엇을 왜 변경했는지 1~3줄, 두괄식으로 -->

## ⚠️ Risk Score: <합계>/100 (<낮음|보통|높음|매우 높음>)

<!-- 5축 표 — references/risk-score.md 의 표를 그대로 -->

## 변경 유형

- [ ] feat: 신규 기능
- [ ] fix: 버그 수정
- [ ] refactor: 리팩토링 (기능 변경 없음)
- [ ] style: 코드 스타일 변경
- [ ] docs: 문서만 변경
- [ ] chore: 기타 작업

## 변경 사항

<!--
주요 변경 내용을 영역별·우선순위 순으로 작성.
- 사용자 영향이 큰 변경부터 상단에
- 큰 PR이면 ### 소제목으로 분리 (예: 1️⃣ … 2️⃣ …)
- 필요 시 추가: 원인/배경 · 동작 변화(전/후 표) · 머지 후 후속 작업 · 스크린샷
-->

## Test plan

- [ ] `.claude/harness.json`의 `verify` 전체 통과 (build · typecheck · lint · test)
  <!-- 문서만 바뀐 PR: verify 대신 포맷 검사(예: format:check) 결과를 적고, verify 를 생략했다고 명시 -->
- [ ] 관련 테스트 통과
- [ ] (UI 변경 시) 스크린샷 첨부

## 관련 이슈

<!-- Jira / Linear / GitHub Issue 링크 -->
```

## 6단계: 결과 출력

PR 생성 후 URL과 함께 적용된 Assignee·Label·이해 게이트 결과(n/5 · draft 여부 · 건너뜀)를 사용자에게 알린다.
