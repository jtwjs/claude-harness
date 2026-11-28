# ADR — 규칙 수명 · 외부 플러그인 흡수 · 비어 있는 안전장치 (lecture-gap 트랙)

> 번호는 지휘(`conductor`)가 발급한다. 결정 원문은 jtwjs/claude-harness 이슈 #64와 지휘 전달이다. 이번 범위는 설계 · 계획까지이고 구현은 사용자 승인 뒤에 한다.

## ADR-021 외부 강의 개념은 3층 · 기계 검사에 흡수하고, 이름만 다른 것은 들이지 않는다

- 상태: 수락(2026-11-26). 후보 1~8 · 스킬 자리 · 조사에서 나온 Q7까지 확정.
- 맥락: 외부 강의의 개념과 하네스를 대조해 #64 후보 8개가 나왔다. 대조표는 강의 내용이라 레포에 두지 않는다. 여기에는 후보 판정과 레포에서 확인한 근거만 적는다.

### 판정 잣대

| 잣대 | 내용 |
|---|---|
| 기계 검사 먼저 | 타입 · 린트 · 테스트 · 훅 · deny로 막을 수 있으면 그쪽. 규칙 줄도 여전히 필요하고, 그래서 지우고 고치는 관리 대상이다 |
| 새 파일 이름 없음 | 쌓이는 판정은 `rules/`, 길면 `references/`, `CLAUDE.md`는 CRITICAL + 링크 |
| 원천 한 곳 | 임계 · 명령 · 목록은 한 곳에만 두고 나머지는 가리킨다 |
| 하나 넣으면 하나 | 후보마다 지울 후보를 적는다. 없으면 「없음」과 이유 |
| 스킬 자리 | 「내가 만든 스킬은 하네스 플러그인, 남이 만든 스킬은 dotfiles에 설치로 유지 — 남이 만든 것들은 좀 더 큰 틀에서 범용적인 것들」(결정 주체: 사용자. AI 추천 A 수용 + 이유). 하네스는 공개 레포라 개인 계정 · 경로에 묶인 값은 빼고 쓴다 |

### 후보 판정

| # | 후보 | 판정 | 근거 · 다음 수 | 지울 후보 | 주체 |
|---|---|---|---|---|---|
| 1 | 규칙 수명 주기 | 일부 있음 → 보강(Q1 = A) | 3회 승격 사다리와 「장치가 생기면 rules 줄을 지우자」는 이미 있다(`skills/harness-gaps/SKILL.md:57-69`). 빈 곳은 한 번 당한 사고 줄이 올라가는 길(`templates/.claude/rules/non-obvious-patterns.md:14-18`, `skills/sdd/references/reflect.md:40`) | `templates/CLAUDE.md.tmpl:12` 「hook 우회 금지(`--no-verify` 등)」를 지우지 않고 줄인다(I3). 훅 패턴(`hooks/deny-patterns.yaml`에 commit-no-verify와 같은 꼴의 push 패턴)과 템플릿 deny를 더하면 `--no-verify`는 커밋 · push 모두 인자 위치와 상관없이 장치가 막지만(템플릿 deny glob은 위치마다 줄이 필요해 한 줄로는 샌다, `templates/.claude/settings.json:4-16`), 「등」에 드는 훅 끄기(`HUSKY=0` · `core.hooksPath` 바꾸기)는 못 막는다. Q1 A의 줄 삭제 조건(장치가 같은 뜻을 막을 때)에 못 미쳐, 장치가 못 막는 것만 남긴다: 「훅 끄기 금지(`HUSKY=0` · `core.hooksPath` 바꾸기 등). `--no-verify`는 deny가 막는다」(판정: 지휘, Q1 A 적용) | 사용자(Q1 참고) |
| 2 | `claude-md-management` 흡수 뒤 의존 제거 | 흡수 | 아래 「후보 2 상세」 | 플러그인 설치 안내 · 선택 의존 · 환기 문구(언급 전부) | 사용자(AI 추천 수용) |
| 3 | `harness-doctor` 주기 알림 | 다르게: 날짜 알림 없이, 쌓인 양 장치가 켜지는 날 새 검사도 먼저 돌림(Q4 = B) | 환기 훅은 날짜가 아니라 쌓인 양을 잰다(`hooks/cadence-reminder.sh:17-20`). fix 커밋이 3건 쌓이면 레포마다 하루 첫 세션에 doctor §2 · §3을 답보다 먼저 돌리게 한다(`:50-67`). 권유가 아니라 먼저 돌리는 장치다. 후보 2에서 비대 환기가 doctor를 가리키면 쌓인 양 알림이 둘(fix 커밋 · 문서 크기)이 된다. 빈 곳: 그 장치는 §2 · §3만 돌려, 새 3축은 사람이 부를 때만 돈다. 외부 도구를 안 쓰게 될까 봐 흡수를 고른 이유가 그대로 남는다. 모델이 바뀔 때의 알림은 #61 몫 | 없음. 새 트리거를 만들지 않고 있는 장치에 얹는다 | 사용자(AI 추천 수용) |
| 4 | 되돌릴 수 없는 작업의 확인받기 | 보강(Q2 = A) | 템플릿 `settings.json`은 `permissions.deny`뿐이다. 확인받기(ask)는 훅의 `gh pr merge` 하나다(`hooks/block-dangerous-bash.sh:134-138`). 운영 DB 쓰기는 같은 훅이 확인이 아니라 차단한다. 업그레이드 모드는 deny 줄만 합친다(`skills/harness-init/SKILL.md` §0) | 없음. 이 확인을 대신하던 지시 줄이 템플릿에 없다 | 사용자(AI 추천 수용) |
| 5 | CI 비밀값 검사 | 보강(Q3 = A) | 템플릿 `ci.yml`은 job `verify` 하나이고 비밀값 검사가 없다. 업그레이드 모드는 CI를 건드리지 않아 이미 깔린 레포에는 가지 않는다 | 없음. 스택 규칙의 비밀값 줄(`nextjs.md:10`, `db.md:41`)은 검사기가 못 보는 노출 · 작성 방식이라 남긴다 | 사용자(AI 추천 수용) |
| 6 | 핵심 테스트와 임시 테스트 구분 | 다르게(Q5 = A): 핵심/임시로 나누지 않고, 쓸모 있는 테스트는 아끼지 않되 엣지를 주 경로에서 요구한다 | 양 제한 줄(`templates/.claude/rules/testing.md:9` 「일단 다 테스트 금지」 · `:15` 「기능당 통합 대개 1개」)을 「쓸모 있는 테스트는 아끼지 않는다. 커버리지는 목표가 아니라 빈 곳을 찾는 신호」로 바꾼다. 「테스트하지 않는다」 목록(`:17-22`)과 원칙은 그대로라 `tdd.exclude` 짝(`:11`)은 안 바뀐다. 엣지 5축(`:43-46`)은 지금 규칙 파일과 `test-writer`(`agents/test-writer.md:30,34-44`)에만 있고, 러너 지시문(`skills/sdd-run/scripts/sdd_runner.py:281-283`) · step 템플릿 AC(`skills/sdd-plan/SKILL.md:93-97`) · 러너 판정(`skills/sdd-run/SKILL.md:41-45`)에는 없다. step 템플릿 수용 조건에 「엣지 5축: 축마다 테스트 이름 또는 해당 없음」 칸을 두고 비면 러너 판정 실패. 커버리지 숫자 게이트는 두지 않는다. 전제: 판정 4(테스트 무수정, `sdd-run/SKILL.md:43`) 유지 | `testing.md` 「원칙 셋」 ①(「테스트하지 않는다」 첫 줄과 겹침) · `test-writer.md:61` 원칙 사본(정본은 `testing.md` §0) · `test-writer.md:34-44` 축별 질문 표는 `testing.md` §2로 옮기고 가리킨다 | 사용자. 이견 요지 「작성 비용이 낮아져 웬만하면 많이, 쓸모 있는 것만, 커버리지는 목표가 아님, 엣지가 중요」를 반영한 재제안 A를 골랐고, 지휘 반박(테스트가 늘면 단언을 약하게 고칠 자리도 넓어지니 러너 「테스트 무수정」 판정 유지가 전제)을 받아들였다 |
| 7 | 레포 단위 설계 · 배포 큰 그림 | 다르게: 관례 한 줄만(Q6 = A) | init은 구조 지도 파일을 만들지 않는다(`skills/harness-init/SKILL.md:112`). 환경이 원천인 것은 베끼지 않는다(`docs/principles/write-for-agents.md` #3). `templates/.claude/README.md` references 설명에 「배포 · 인프라처럼 코드만 읽어서는 안 나오는 것은 references 한 장 + 배포 파일에 걸리는 rules의 ⏬ 트리거」. 파일은 필요해진 레포가 만든다 | 없음. 겹치는 설명이 템플릿에 없다 | 사용자(AI 추천 수용) |
| 8 | 브라우저 작업 스킬 | 보류(사용자, 자주 쓰는 작업이 생기면) | 없음 | 없음 | 사용자 |

### 후보 2 상세

#### 품질 기준 6개의 처리

| 외부 기준 | 처리 | 하네스에서 맡는 자리 | 대조에서 나온 차이 |
|---|---|---|---|
| 명령 · 작업 흐름 | 안 들임 | doctor §1(verify 명령 대조) | §1은 `CLAUDE.md` · `harness.json` · CI의 명령 글자만 본다. 배포 · 작업 흐름 서술은 보지 않는다. 「명령이 지금도 있나」는 아래 최신성이 받는다 |
| 비명백 패턴 | 안 들임 | 템플릿 `rules/non-obvious-patterns.md` 형식(왜 필수) · doctor §3 | §3은 비었는지만 본다. 빠진 함정은 기계로 알 수 없어 그대로 둔다 |
| 간결성 | 안 들임 | doctor §5 · cadence 훅 | §5는 `CLAUDE.md` 크기를 재지 않는다. doctor 안에서는 재지 않고, 비대를 알리는 곳은 훅(80줄 · rules 합 400줄)이고(`harness-score` B1도 줄 수를 채점, 아래) 그 문구가 없어질 플러그인을 가리킨다. 훅을 doctor로 돌리고 §5에 같은 두 숫자를 넣어야 이 처리가 성립한다 |
| 설계 명확성 | 들임 | doctor 새 검사 | 폴더 나열을 요구하지 않는다(`write-for-agents` #3) |
| 최신성 | 들임 | doctor 새 검사 + §2 범위 확장 | 경로 실재는 새 축이 아니라 §2 정방향 범위에 `references/`를 더한다. §0 · §1 · §7과 겹치는 대조도 그 검사에 둔다. 새 축은 경로가 아닌 낡음만 받는다 |
| 실행 가능성 | 들임 | doctor 새 검사 | 「경로가 실재하나」는 §2 · 최신성이 보므로 지시의 구체성만 본다 |

간결성의 질적인 면(군말 · 뻔한 말 · 파일 사이 중복)은 어느 검사도 보지 않는다. `write-for-agents` #3 · #5가 글 원칙으로만 갖고 있다. 이번에는 들이지 않는다.

`harness-score`도 경로 실재(E1) · 문서 낡음(F) · 간결성(B1)을 채점한다(`skills/harness-score/SKILL.md:47-53`). 점수 리포트와 점검은 목적이 달라 이번에는 doctor 쪽만 바꾸고, 두 곳이 같은 경로를 보는 겹침은 남은 문제로 둔다.

#### doctor 새 검사(대상: `CLAUDE.md` · `rules/` · `references/`)

| 축 | ⚠️ 조건 | 보지 않는 것 |
|---|---|---|
| 설계 명확성 | `CLAUDE.md` 「구조」에 진입점 · 의존 방향이 없거나, 대표 import가 적힌 방향과 어긋남. rules · references가 어느 코드에 대한 것인지(`paths` 또는 대상 경로) 없음 | 폴더 목록 · 전체 의존 그래프 |
| 최신성 | 적힌 스크립트 이름 · 의존성 버전이 매니페스트와 어긋남. 지운 기능 설명, 남은 TODO · `{{…}}` 자리표시자 | 경로 실재(§2가 본다) · 명령 실행(검사는 읽기 전용) |
| 실행 가능성 | 지시 줄에 대상(어디)이나 행동(무엇을 하거나 하지 마라)이 없음 | 문체 · 길이 · 점수 |

- 출력은 지금 형식(✅ ⚠️ 🔴, 파일:줄, 먼저 고칠 것 하나)을 따른다. 등급은 들이지 않는다.
- doctor는 읽기 전용으로 남는다. 고치기는 사람이 요청할 때만.
- §5에 `CLAUDE.md` 줄 수와 rules 합계 줄 수를 더한다. 임계 숫자의 원천은 cadence 훅 하나이고 doctor는 복사하지 않고 거기서 읽는다.
- 출처 한 줄: 「개념 출처: Apache-2.0 공개 플러그인 `claude-md-management`의 품질 기준 · 세션 학습 회수. 문장은 옮기지 않았다.」

#### 세션 학습 회수(REFLECT 「흘린 것」)

외부 명령 호출 대신 `reflect.md` 안에 순서로 적는다.

1. 종착지를 3층에서 먼저 고른다(지금 `reflect.md:39`의 판정 한 줄)
2. 한 개념에 한 줄. 「남기는 문턱」 셋을 통과한 것만
3. diff와 왜 한 줄을 보이고 승인 뒤에 적용

안으로 들이는 이유: 외부 명령은 `CLAUDE.md` 계열 파일만 찾고 새 파일을 만들 권한이 없어 3층 종착지와 맞지 않는다.

#### 언급을 바꿀 곳

| 파일 | 지금 | 바꿈 |
|---|---|---|
| `README.md:14,38` | 설치 줄 · 선택 의존 | 지움 |
| `skills/harness-doctor/SKILL.md:3,8` | 「품질 감사는 플러그인이 하므로 하지 않는다」 · 「검사 9개」 | 새 검사를 포함한 설명. description은 doctor 자신의 길이 상한 안 |
| `skills/sdd/SKILL.md:38` | `revise-claude-md` diff 승인 | 「흘린 것」 diff 승인 |
| `skills/sdd/references/reflect.md:39,44` | 외부 명령 · 없으면 건너뜀 | 위 3단계. 건너뜀 문장 삭제 |
| `hooks/cadence-reminder.sh:71-80` | `claude-md-improver` 환기 | `harness-doctor` 환기(축 1과 같은 경로 변수) |
| `hooks/test.sh:329,332` · `hooks/tests/version-drift.sh:49` | 옛 문구를 찾는 테스트 | 새 문구(테스트 먼저) |
| `templates/.claude/README.md:17` | `/revise-claude-md` 행 | `sdd` ④ REFLECT가 줍는다는 행 |
| `skills/harness-init/references/renames.tsv` | 행 없음 | 두 옛 이름 행 추가(깔린 레포는 업그레이드 모드가 고친다) |

옛 이름 검사(`hooks/tests/renames.sh`)는 이름표에 오른 이름이 이름표 밖에 남으면 실패한다. 출처 한 줄에는 플러그인 이름만 쓰고 두 옛 이름은 쓰지 않는다.

### 정할 것

| # | 정할 것 | 선택지(고르면 생기는 일) | 추천 | 주체 |
|---|---|---|---|---|
| Q1 | 사고가 나면 막는 장치를 언제 만드나(사용자 이견 뒤 재제안: 문턱은 횟수가 아니라 사소함, `docs/principles/build-the-lever.md:9-10`) | A 사고를 고치는 PR에서 갈래로 판정: ① 성공 조건을 한 줄로 쓸 수 있고 간단하면 그 PR에서 장치를 만들고 사고 줄 대신 장치를 남긴다 ② 성공 조건은 분명한데 간단하지 않으면(새 훅 · 여러 파일) rules 한 줄로 임시로 막고 장치 이슈(`sdd`)를 연다. 장치가 들어오면 그 줄을 지운다 ③ 성공 조건이 모호하면(판단 필요) `non-obvious-patterns.md` 한 줄 + `harness-gaps`가 센다 ④ 플러그인 · 템플릿을 고칠 때(훅 · 템플릿 deny처럼 모든 레포에 걸리는 장치)는 바로 만들어도 `code-reviewer`를 한 번 거친다(사고 PR이 조금 커진다) · B 모든 사고를 그 PR에서 장치까지(판단이 필요한 것도 장치가 되어 오탐이 는다) · C 지금 그대로(사고는 한 줄, 장치는 3회) | A. 첫 적용 예: `git push --no-verify` deny 한 줄(`-n`은 dry-run이라 넣지 않는다)을 더하고 `CLAUDE.md.tmpl:12`를 장치가 못 막는 훅 끄기만 남게 줄인다(I3) | 사용자. 이견 요지 「사고는 바로 고친다, 3번 참지 않는다, 도구 만드는 기준과 같은 결로」를 반영한 재제안 A를 골랐고, 지휘 반박 둘(사고가 아닌 신호는 반복 관찰 · 모든 레포에 걸리는 장치는 리뷰 1회)을 받아들였다 |
| Q2 | 확인받기 규칙을 어디에 두나 | A 템플릿 `permissions.ask`에 명령 앞부분만으로 갈리는 줄 + 업그레이드 모드가 ask도 합침(인자 변형은 새고, 사람이 없는 러너에서의 동작은 확인 필요) · B 플러그인 훅에 패턴 추가(인자까지 보지만 하네스 없는 레포까지 걸리고 훅이 두꺼워진다) · C 안 함 | A. 레포마다 다른 배포 · 마이그레이션 명령은 `harness-init`이 `verify`처럼 찾아 채운다. 운영 DB 쓰기는 지금 훅 가드에 그대로 둔다 | 사용자(AI 추천 수용) |
| Q3 | CI 비밀값 검사를 무엇으로 하나 | A 템플릿 CI에서 gitleaks CLI를 버전 고정으로 실행(계정 · 키 불필요, 버전을 직접 올려야 하고 상류는 보안 패치만 예고) · B 공식 action(설정이 짧다, 조직 레포는 키가 필요하고 상용 라이선스) · C 호스팅의 비밀값 검사에 맡김(공개 레포는 무료 자동, 조직 비공개 레포는 유료 기능, 개인 비공개 레포는 확인 필요) | A. 검사 범위는 PR 커밋. 걸려도 값은 이미 원격에 있으니 폐기한다. 템플릿 `.gitignore.append`에 `.env` 줄이 없어(하네스 상태 · 리포트 · 디자인 레퍼런스 줄만) 같은 질문에 묶어 묻는다 | 사용자(AI 추천 수용) |
| Q4 | 후보 3 · 새 3축을 누가 돌리나 | A 날짜 알림 안 함, 새 3축은 사람이 부를 때만(흡수해도 안 쓰게 될 걱정이 남는다) · B 날짜 알림 안 함 + 쌓인 양 장치(fix 커밋 3건 · 문서 크기)가 켜지는 날 하루 첫 세션에 새 3축도 먼저 돌림(세션 시작이 길어진다) · C 날짜 알림 추가(볼 것이 없는 주에도 알림) | B. 자동 실행 범위는 `CLAUDE.md` · `paths` 없는 rules · 문서 갱신 뒤 바뀐 파일에 `paths`가 걸리는 rules. 템플릿 그대로면 앞의 둘은 `CLAUDE.md`와 `non-obvious-patterns.md` 두 파일뿐이라(나머지 rules는 팩까지 전부 `paths` 있음) 세 번째가 있어야 rules가 자동 범위에 든다. 걸리는 rules는 모델이 아니라 훅이 골라 목록으로 넘긴다. `references/`는 사람이 부를 때만. 하루 한 번 기록은 지금 장치와 같은 것 하나 | 사용자(AI 추천 수용) |
| Q5 | 후보 6 · 테스트를 얼마나 쓰나(사용자 이견 뒤 재제안) | A 양 제한 줄을 「쓸모 있는 테스트는 아끼지 않는다. 커버리지는 빈 곳을 찾는 신호」로 + 엣지 5축 칸을 step 수용 조건에 두고 비면 러너 판정 실패 + 커버리지 숫자 게이트 없음 · B 지금 그대로(처음부터 적게) · C 커버리지 숫자 게이트 | A | 사용자. 이견 요지 「작성 비용이 낮아져 웬만하면 많이, 쓸모 있는 것만, 커버리지는 목표가 아님, 엣지가 중요」를 반영한 재제안 A를 골랐고, 지휘 반박(테스트가 늘면 단언을 약하게 고칠 자리도 넓어지니 러너 「테스트 무수정」 판정 유지가 전제)을 받아들였다 |
| Q6 | 후보 7 | 관례 한 줄 · init이 초안 생성(`SKILL.md:112`를 뒤집고 낡는 문서가 생긴다) · 안 함 | 관례 한 줄 | 사용자(AI 추천 수용) |
| Q7 | 업그레이드 모드가 공통 rules(`testing.md` 등)도 갱신하나 | A 스택 팩 규칙과 같은 3방향 diff 대상에 템플릿 공통 rules를 더한다(I7 · I3의 템플릿 변경이 깔린 레포에도 간다, `harness-init` §0이 조금 커진다) · B 지금 그대로(공통 rules 변경은 깔린 레포마다 사람이 옮긴다) | A | 사용자(AI 추천 수용) |

- 대안(버린 방법): 외부 플러그인을 선택 의존으로 두기(두 곳에서 같은 파일을 고치고, 3층 종착지를 매번 다시 지정해야 한다). 품질 기준 6개를 점수 · 등급째 옮기기(겹치는 3개가 기존 검사와 두 벌이 된다). 강의의 파일 이름을 템플릿에 들이기(3층과 원천이 두 벌이 된다).
- 대가: doctor가 모델 판단이 필요한 검사를 갖게 되어 실행이 길어지고 결과가 회차마다 다를 수 있다 [추정]. 외부 플러그인의 「승인 뒤 바로 고치기」 흐름은 없어진다. 후보 4 · 5는 인자 변형과 이미 깔린 레포라는 빈 곳이 남는다.
- 결과: (구현 PR 뒤 채운다)

### 범위 밖

- `claude-md-management` 개인 설치 삭제: 레포 밖(dotfiles 몫). I2 병합 뒤.
- push 뒤 CI 결과 확인: 범위 밖. `pr-write`를 #52 `verify-flow` step 10이 고쳐 #52 뒤 후속으로 둔다(지휘).
- `tdd-guard`의 Python 짝 테스트: 훅은 TS · JVM 짝만 찾고(`hooks/tdd-guard.sh:81-93`) 러너는 `test_*.py`도 테스트로 본다(`skills/sdd-run/scripts/sdd_runner.py:68-70`). Python 레포는 `tdd.enabled`를 꺼야 한다. 별도 이슈.
- `test-writer`의 자리: #52가 러너에 검증 세션 지시문(`prompt --role test`)을 만들면 러너가 안 부르는 `test-writer`(`agents/test-writer.md:3`)와 역할이 겹친다. #52 뒤 후속(지휘).
- 커버리지 리포트 명령(게이트 아님): 스택 킷에 커버리지 설정이 없다. 「빈 곳을 찾는 신호」로 쓰려면 킷 쪽 몫(제안만).
- 깔린 사본(`testing.md`)의 갱신: I9(Q7 A) 릴리스 뒤 각 레포가 업그레이드 모드를 돌린다.

### 구현 이슈 분해(승인 뒤)

| 이슈 | 내용 | 주로 바꾸는 곳 | 순서 | 끝 기준 |
|---|---|---|---|---|
| I1 | doctor 새 검사 3축 · §2에 `references/` · §5에 줄 수 | `skills/harness-doctor/SKILL.md` | 줄 B 여섯째: I6 뒤(doctor 새 검사는 다 바뀐 상태를 보고 만든다). `verify-flow` step 8 · 9가 템플릿 칸 이름을 바꾸거나 doctor를 고치면 그 뒤(step8.md:32 · step9.md:6) | 낡은 경로 · 모호한 지시를 심은 임시 레포에서 해당 줄이 ⚠️. description 길이 상한 통과 |
| I2 | 환기 문구 전환 · 플러그인 의존 제거 · 이름표 | 위 「언급을 바꿀 곳」 | 줄 B 끝: I1 뒤(환기가 가리킬 검사가 먼저). I3이 먼저 들어가니 `reflect.md`는 그 변경 위에서 고친다. `reflect.md` · `sdd/SKILL.md`는 `verify-flow` step 6 · 9 · 10 병합 뒤(`sdd/SKILL.md`는 셋 다 고친다) | `bash hooks/test.sh` 통과. 이름표 밖 옛 이름 0건. Q4가 B면 임시 레포에서 첫 세션에 더해지는 시간 · 로드를 비포와 함께 재고, 기준(계획에서 정함)을 넘으면 범위를 줄인다. 같은 파일에서 Claude Code가 띄우는 rules와 훅이 고른 목록이 같다 |
| I3 | 규칙 수명 갈래(Q1 A ①~④) · 첫 적용: `git push --no-verify`를 훅 패턴(`hooks/deny-patterns.yaml`) + 템플릿 deny로 막음(`-n` 제외) + `CLAUDE.md.tmpl:12`를 장치가 못 막는 것만 남게 줄임 | `reflect.md` · `non-obvious-patterns.md` · `templates/.claude/settings.json` · `hooks/deny-patterns.yaml` · `CLAUDE.md.tmpl` | 줄 B 첫째: #103 뒤(같은 `hooks/deny-patterns.yaml`). I2보다 먼저 들어간다 | 템플릿과 REFLECT가 같은 판정을 가리킴(복사 없음). `git push --no-verify` · `git push origin x --no-verify`는 막히고 `git push -n`은 통과(훅과 Claude Code 권한 매처 둘 다 실측). 훅 패턴은 모든 레포에 걸리니 `code-reviewer` 1회(Q1 A ④). `CLAUDE.md.tmpl:12`에 `--no-verify` 지시가 남지 않고 훅 끄기 줄만 남음 |
| I4 | 확인받기(Q2) | `templates/.claude/settings.json` · `harness-init` §0 · doctor | I3 뒤(`templates/.claude/settings.json`). doctor 한 줄은 I1보다 먼저 들어가니 I1이 그 위에서 고친다 | 줄마다 걸리는 명령 / 안 걸리는 명령을 실행으로 확인. 러너가 쓰는 권한 모드와 auto에서 ask가 어떻게 되는지 실측 |
| I5 | CI 비밀값 검사 · `.env` ignore(Q3) | `templates/.github/workflows/ci.yml` · `templates/.gitignore.append` · 업그레이드 모드 안내 | 독립 | 가짜 키를 넣은 PR에서 실패, 뺀 PR에서 통과. 앱별 형태면 `ci-gate`의 `needs`에도 들어감. 깔린 레포에는 안내 한 줄만 |
| I6 | 배포 관례 한 줄(Q6) | `templates/.claude/README.md` | I9 뒤. I2보다 먼저 들어가니 I2가 같은 파일을 그 위에서 고친다 | references 설명에 관례 한 줄, 지울 후보 없음 |
| I7 | 테스트 양 문구(Q5 A) · 원천 정리 | `templates/.claude/rules/testing.md:9,15,24-25` · `templates/stacks/react-vite/rules/testing-fe.md:13` · `agents/test-writer.md:59,61` | I8(#52)과 같은 파일(`testing.md` · `test-writer.md`). 먼저 들어간 쪽 뒤 | 양 제한 줄 교체, 원칙 셋 ① 삭제, `test-writer`는 사본 대신 `testing.md`를 가리킴. `tdd.exclude` 주석(`templates/.claude/harness.json:49`)과 어긋남 0 |
| I8 | 엣지 5축을 주 경로에(Q5 A) | `skills/sdd-plan/SKILL.md`(step 템플릿 AC) · `skills/sdd-run/scripts/sdd_runner.py`(지시문 · 판정) · `preamble.md` · `test_sdd_runner.py` · `docs/sdd-runner.md` · `skills/sdd-run/SKILL.md`(판정 표) · `agents/test-writer.md`(질문 표를 옮김) · `testing.md` §2(축별 질문 표를 `test-writer`에서 옮김) | #52에 합침(사용자). `verify-flow` step 4 · 11 안에서 #52 구현 준비 트랙이 diff를 낸다. 같은 파일: step 2 · 3 · 4 · 5(`sdd_runner.py` · `preamble.md` · `test_sdd_runner.py` · `docs/sdd-runner.md`, step4.md:15 · step5.md:15), step 3 · 6(`skills/sdd-run/SKILL.md`), step 11(`sdd-plan/SKILL.md` step 템플릿, step11.md:15) | 엣지 칸이 빈 step은 판정 실패, 축마다 이름이나 「해당 없음」이 있으면 통과(단위 테스트). 판정 4(테스트 무수정) 유지 |
| I9 | 업그레이드 모드가 공통 rules도 갱신(Q7 A) | `skills/harness-init/SKILL.md` §0 대상 표(`:16-26`) | I4와 같은 절이라 I4 뒤. I7 · I3과는 독립(릴리스에 같이 실리면 깔린 레포까지 간다) | 기준 판 · 새 판 · 레포 사본 3방향 diff에 템플릿 공통 rules가 들어감. 레포가 고친 줄(예: 깔린 사본의 `paths`)은 「레포에만」으로 남음 |

순서 바꿈(2026-11-28, 사용자 · AI 추천 수용): 줄 B를 세션 하나로 `#103 → I3(#69) → I4(#70) → I9(#74) → I6(#72) → I1(#67) → I2(#68)` 차례로 돈다. 논리 순서는 I1 → I2 하나뿐이고 나머지는 「같은 파일이라 이어서」라, 깔린 레포에 실제로 나는 문제(I9 공통 rules 미갱신 · I3 push 우회)를 먼저 닫고 doctor(I1 · I2)는 다 바뀐 상태를 보고 고친다. 잃는 것: I3 · I4를 doctor 새 검사로 미리 확인하지 못한다(각 PR 테스트 · 리뷰로 확인).
