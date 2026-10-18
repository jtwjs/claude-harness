---
name: conductor
description: 병렬 트랙(worktree 세션 2개 이상)으로 한 레포를 진행할 때 지휘 세션이 쓴다. 결정·계약 변경을 GitHub 이슈로 받아 전파 후속 이슈로 쪼개고 의존을 건 뒤, 다 닫히면 ADR로 옮긴다. ADR 번호는 여기서만 발급한다. 트랙 지시문을 채워 넘기고 예외를 판정한다. 사용자가 "너는 지휘 세션"·"지휘 맡아"라고 하면 쓴다. 트랙이 하나면 쓰지 않는다.
allowed-tools: [Read, Write, Bash, Glob, Grep]
---

지휘 세션은 **디스패치 · 판정 · 기록만** 한다. 코드와 다른 트랙 소유 문서는 고치지 않는다. 고치는 것은 그 트랙 세션이거나 공유 구역 PR이다.

## 왜

한 레포를 트랙 3개 병렬 세션(worktree)으로 만들며 실측한 것(2026-10-01~08):

| 실측 | 이 스킬의 답 |
|---|---|
| ADR 번호 충돌 3회(10-01·10-04·10-08). 10-04에 "번호는 전역, grep으로 확인" 규칙을 둔 뒤에도 10-08에 또 충돌. 막힌 질문 번호도 충돌 | 번호는 지휘가 **한 곳에서만** 발급한다(§1) |
| 한 트랙의 결정이 다른 트랙 문서(PRD·BRIEF)에 몇 시간 늦게 반영. 정본 PRD와 복사본 BRIEF가 지금도 어긋남 | 결정마다 **전파 체크리스트**를 후속 이슈로 쪼갠다(§1) |
| ADR이 바꾼 값이 step 파일에 안 돌아가 지시문에서 "step 값은 옛 값"이라고 덮어씀(재지시 2회). step md 111개 중 49개가 ADR 내용을 복사 | step은 `ADR-NNN` 참조만 적는다(`harness` §3) |
| 설계 결정 하나가 6일간 5번 바뀌며 서버 코드·계약·화면·다른 트랙 PRD를 같이 흔듦. mock이 운영 근거 없이 PRD 표기를 따라 enum이 계약까지 굳었다가 통째로 되돌림 | 계약 변경 흐름(§2) · mock 관문(§3) |
| 트랙 예외 승인 12건이 전부 사용자에게 몰림. phase 간 의존은 각 머리말에 흩어짐. 트랙 지시문은 매번 손으로 다시 씀 | 예외는 지휘가 판정(§6) · 의존은 이슈 그래프(§4) · 지시문은 템플릿(§5) |

조율 채널은 **GitHub 이슈**다. 레포 파일 원장은 worktree가 기준 브랜치를 다시 받기 전까지 옛 상태를 읽어 지연을 그대로 물려받는다. 보드는 쓰지 않고 라벨 + 네이티브 의존만 쓴다.

세션 간 메시지(`SendMessage`)는 **초인종**으로만 쓴다(§8). 이슈가 열리거나 닫혔다고 알리는 데까지만 쓰고, 결정은 메시지로 끝내지 않는다. 메시지는 받은 세션의 대화 안에만 남는다. 그래서 새로 연 세션이나 다른 트랙은 그 내용을 모른다.

빌려 온 것: obra/superpowers `subagent-driven-development`(지휘는 디스패치·판정·기록만, 판정을 원장에 남김) · mattpocock `wayfinder`(결정은 티켓 하나에 한 번만, 차단 관계로 진행 가능한 것 조회) · warpdotdev `saga`(선의보다 빈틈없는 계약).

## 언제

| 상황 | 쓰나 |
|---|---|
| worktree 세션 2개 이상이 한 레포를 동시에 진행 | 지휘 세션 **하나**가 쓴다 |
| 트랙이 하나 | 쓰지 않는다. `sdd`만 |
| 트랙 세션 자신 | 쓰지 않는다. `harness-run`이 열린 이슈를 읽기만 한다 |

## 0. 준비 (첫 실행)

```bash
gh auth status                                   # gh 계정이 여럿이면 활성 계정을 확인한다(owner별 쓰기 계정은 block-dangerous-bash 가 ~/.claude/gh-accounts.txt 로 막는다)
gh repo view --json nameWithOwner,viewerPermission -q '.nameWithOwner+" "+.viewerPermission'
gh label list --limit 200 --json name -q '.[].name'
```

- **세션 이름부터 맞춘다.** `ListAgents` 결과 첫 줄 `This session is <이름>`이 `<레포>-conductor`와 다르면, 사용자에게 `/rename <레포>-conductor` 한 줄을 그대로 보여 주고 다음 단계로 가지 않는다. 세션은 자기 이름을 스스로 바꾸지 못한다(`/rename`은 사용자 입력 명령). `<레포>`는 `gh repo view --json name -q .name`의 값이다. 같은 이름이 목록에 이미 있으면 그 세션이 살아 있는 지휘 세션인지 먼저 묻는다
- `viewerPermission`이 `WRITE`·`MAINTAIN`·`ADMIN`이 아니면 멈추고 보고한다. 계정을 바꿀지는 사용자가 정한다
- 트랙 이름은 레포 `.claude/references/tracks.md`의 트랙 표에서 읽는다. 없으면 묻는다(지어내지 않는다)
- 아래 라벨 중 없는 것을 목록으로 보여 주고 **물은 뒤** 만든다

| 라벨 | 뜻 |
|---|---|
| `conductor` | 지휘가 관리하는 이슈. 트랙 세션이 조회하는 표식 |
| `decision` | 결정 하나. ADR로 옮기면 닫는다 |
| `contract-change` | 계약(API 스키마·공유 타입) 변경 |
| `follow-up` | 결정·계약 변경이 낳은 전파 작업 하나 |
| `blocked` | 근거·선행이 없어 멈춘 것 |
| `track:<이름>` | 담당 트랙. tracks.md 트랙마다 하나 |

```bash
gh label create conductor --color 5319e7 --description "지휘 세션이 관리"
gh label create "track:<이름>" --color 0e8a16
```

## 1. 결정 흐름

트랙 세션이 결정을 알린다. `SendMessage`로 지휘에게 직접 알리고, 메시지가 닿지 않으면 사용자가 옮겨 준다(§8). 지휘는 받는 즉시 `decision` 이슈를 만들고 이슈 번호로 회신한다. 트랙은 번호를 받기 전까지 그 결정을 확정된 것으로 쓰지 않는다.

```markdown
결정: <한 줄>

## 근거
<쿼리 결과·문서 링크·실측. 없으면 §3 관문>

## 대안
<버린 안과 버린 이유>

## 전파 체크리스트
- [ ] PRD — <경로 또는 "해당 없음">
- [ ] BRIEF(트랙 복사본) — <경로 또는 "해당 없음">
- [ ] ERD — <경로 또는 "해당 없음">
- [ ] 영향 step 파일 — <phases/... 또는 "해당 없음">
- [ ] 픽스처 — <경로 또는 "해당 없음">
- [ ] `_brain` 노드 — <경로 또는 "해당 없음">

영향 트랙: track:<a> track:<b>
```

1. 라벨: `conductor` `decision` + 영향 트랙 라벨
2. 체크리스트 한 줄 = 담당 트랙의 `follow-up` 이슈 하나(`conductor` `follow-up` `track:<담당>`). 본문 첫 줄은 `Decision: #<결정 번호>`
3. 후속 이슈를 결정 이슈의 하위로 건다(`addSubIssue`, §4). 후속끼리 순서가 있으면 `addBlockedBy`
4. 후속이 **전부 닫히면** ADR로 옮긴다. 🔴 **ADR 번호는 여기서만 발급한다**:
   ```bash
   git fetch -q origin && git grep -h -o 'ADR-[0-9]\{3\}' origin/<기준 브랜치> -- 'docs/*/ADR.md' | sort -u | tail -1
   ```
   최대 번호 + 1. 로컬 작업 트리가 아니라 **원격 기준 브랜치**를 본다(로컬은 늦다). 열린 PR에 든 ADR 번호도 `gh pr list --search "ADR-" --state open`으로 한 번 본다
5. ADR을 담는 PR은 해당 트랙이 올린다. 지휘는 번호와 본문 초안만 넘긴다
6. 결정 이슈에 ADR 링크를 코멘트로 남기고 닫는다

막힌 질문 번호(`_brain` 등)도 같은 이유로 지휘가 발급한다.

## 2. 계약 변경 흐름

`contract-change` 이슈(`conductor` `contract-change` + 영향 트랙). 본문: 바뀌는 엔드포인트·스키마 · 이유 · 호환 여부.

| 변경 | 바로 발행할 후속 |
|---|---|
| required 필드 추가 · enum 값 변경 · 타입 변경 | 소비 트랙 `follow-up`: 픽스처·생성 타입 재생성·화면 분기 |
| **계약에 안 드러나는 의미 변경**(기준·주기·단위·집계 범위) | 소비 트랙 `follow-up`: 화면 문구·툴팁·도움말 |
| 엔드포인트 삭제·개명 | 소비 트랙 `follow-up` + 제공 트랙에 "소비 쪽 닫힌 뒤 삭제" `addBlockedBy` |

스키마가 같아도 의미가 바뀌면 생성 타입 diff가 0이라 CI가 못 잡는다. 그래서 두 번째 줄이 있다.

## 3. mock 관문

enum 값 · 주기 · 테이블 구조를 **계약으로 굳히기 전에** 운영 실측 근거(쿼리 결과·원천 문서 링크)를 이슈 본문 「근거」에 적게 한다.

- 근거가 없으면 `blocked` 라벨 + 본문 첫 줄 `Blocked: 운영 근거 없음 — <무엇을 세야 하나>`
- PRD 표기 · 회의 기록 · mock 값은 근거가 아니다. 운영에 그 값이 있는지 센 결과가 근거다

## 4. 의존과 "지금 진행 가능한 것"

🔴 네이티브 의존은 `gh api graphql`로만 걸린다. `gh` CLI(2.92)에는 플래그가 없다(2026-10-08 확인).

```bash
id() { gh issue view "$1" --json id -q .id; }

# #12 가 #10 에 막힌다
gh api graphql -f query='mutation($i:ID!,$b:ID!){addBlockedBy(input:{issueId:$i,blockingIssueId:$b}){issue{number}}}' \
  -f i="$(id 12)" -f b="$(id 10)"

# 풀기
gh api graphql -f query='mutation($i:ID!,$b:ID!){removeBlockedBy(input:{issueId:$i,blockingIssueId:$b}){issue{number}}}' \
  -f i="$(id 12)" -f b="$(id 10)"

# #12 를 결정 #9 의 하위로
gh api graphql -f query='mutation($p:ID!,$c:ID!){addSubIssue(input:{issueId:$p,subIssueId:$c}){issue{number}}}' \
  -f p="$(id 9)" -f c="$(id 12)"
```

**지금 진행 가능한 것** — 열린 `conductor` 이슈를 **한 번에** 받아 차단이 전부 닫힌 것만 거른다. 이슈마다 따로 부르지 않는다.

```bash
gh api graphql -F owner=<owner> -F name=<repo> -f query='
query($owner:String!,$name:String!){repository(owner:$owner,name:$name){
  issues(first:100,states:OPEN,labels:["conductor"]){nodes{
    number title labels(first:10){nodes{name}}
    blockedBy(first:20){nodes{number state}}
}}}}' --jq '.data.repository.issues.nodes[]
  | select([.labels.nodes[].name] | index("decision") | not)
  | select([.blockedBy.nodes[] | select(.state=="OPEN")] | length == 0)
  | "#\(.number) [\([.labels.nodes[].name | select(startswith("track:"))] | join(","))] \(.title)"'
```

`decision` 이슈는 지휘가 들고 있는 원장이라 결과에서 뺀다 — 트랙이 집어 갈 것은 `follow-up`·`contract-change`뿐이다(2026-10-08 비공개 임시 레포 실측: 빼지 않으면 결정 이슈가 "진행 가능"으로 섞여 나왔다).

**실패하면**(권한·기능 미지원): 본문 첫 줄 `Blocked-by: #N` + `blocked` 라벨로 대신한다. 조회는 `gh issue list --label conductor --json number,title,body,labels` 한 번으로 받아 첫 줄을 파싱한다.

**트랙 현황** — 디스패치(§5) 전, 예외 판정(§6) 전, 사용자가 "현황"이라고 할 때 표 한 장으로 본다. 트랙 세션마다 묻거나 worktree를 하나씩 열지 않는다.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/conductor/scripts/tracks_status.py"            # --stale 분(기본 30) · --no-gh
```

worktree마다 트랙(브랜치 `feature/<트랙>-…`로 매칭) · 그 worktree의 phases 진행 · 마지막 신호(커밋·index.json) · 안 올린 변경 수 · 열린 후속 이슈 수가 한 행이다. ⛔(막힌 step)이 맨 위, 그다음 💤(신호 없음). ⛔은 §6 예외 판정으로, 💤은 §8 초인종으로 그 트랙 세션에 상태를 묻는다. 사람에게는 `--compact` 한 줄(`트랙 ⛔admin 💤renderer 진행1 끝1`)이 지휘 자리(기준 worktree) 상태줄에 자동으로 뜬다(개인 dotfiles 상태줄이 부름). 아이디어는 lcalmsky/deadhd 레인 보드(MIT, 코드는 가져오지 않음).

## 5. 트랙 지시문

`.claude/references/track-brief.md`를 채워 트랙 세션에 넘긴다. 손으로 다시 쓰지 않는다. 트랙 세션이 이미 떠 있으면 채운 지시문을 `SendMessage`로 보낸다(§8). 지시문에는 값이 없고 이슈 번호와 `ADR-NNN` 참조만 들어 있으므로 메시지로 보내도 원장이 갈라지지 않는다. 열린 이슈 목록은 §4 조회 결과를 그대로 붙인다.

지시문에 값을 복사하지 않는다. ADR·PRD에 있는 값은 `ADR-NNN` 참조만 적는다 — 복사본은 정본이 바뀐 걸 따라오지 못한다(§왜 3번째 줄).

## 6. 트랙 예외 승인

트랙 세션이 소유 경로 밖을 고쳐야 한다고 보고하면 **지휘가 판정한다.** 트랙은 사용자보다 지휘에게 먼저 `SendMessage`로 묻는다. 사용자에게는 아래 표의 「사용자에게 넘김」만 간다(2026-10-01~08 실측: 예외 12건이 전부 사용자에게 몰렸다).

| 판정 | 언제 |
|---|---|
| 승인 — 그 트랙 PR에 포함 | 한두 줄 · 다른 트랙이 지금 안 만지는 파일(예: 픽스처 한 줄) |
| 공유 구역 PR로 분리 | 여러 트랙이 받아 갈 변경 |
| 소유 트랙에 `follow-up` 발행 | 소유 트랙이 지금 그 파일을 만지는 중 |
| **사용자에게 넘김** | 비가역(운영 DB·배포) · 보안(비밀값·권한) · 외부 부작용(메시지 발송·과금) |

판정은 해당 이슈에 코멘트로 남긴다: `판정: <승인|분리|후속 #N|사용자> — <이유 한 줄>`. 이슈가 없으면 `follow-up` 이슈를 만들고 거기에 남긴다.

## 7. 세션 끝

1. 열린 `decision` 중 하위 `follow-up`이 남은 것 — 번호 · 남은 후속 수 · 담당 트랙
2. 닫힌 `decision` 중 ADR 링크 코멘트가 없는 것 — **0이어야 한다**
3. `blocked` 목록과 무엇을 기다리는지

```bash
gh issue list --label decision --state closed --json number,comments \
  -q '.[] | select([.comments[].body | test("ADR-[0-9]{3}")] | any | not) | .number'
```

## 8. 초인종 — 세션 간 메시지

같은 머신, 같은 계정의 세션끼리는 `SendMessage`로 서로 알릴 수 있다. 이 메시지는 사용자가 세션 사이에서 말을 옮겨 주던 일을 대신한다. 원장은 계속 이슈다.

**세션 이름** — 각 세션 시작 때 `/rename`으로 정한다. 지휘는 `<레포>-conductor`, 트랙은 `<레포>-<트랙>`이다. 보내기 전에 `ListAgents`로 이름이 하나뿐인지 본다. 같은 이름이 둘이면 `이름 [ref]`로 보낸다(2026-10-14 실측: 세션 89개 중 같은 이름 2개).

| 언제 | 누가 → 누구 | 본문 |
|---|---|---|
| `follow-up`·`contract-change` 이슈를 열었다 | 지휘 → 담당 트랙 | `#N <라벨> 열림 — <제목>` 한 줄 |
| 결정을 이슈로 옮겼다 | 지휘 → 보고한 트랙 | `#N decision 열림` |
| 결정이 생겼다 · 예외가 필요하다 | 트랙 → 지휘 | 결정·요청 한 줄. 지휘가 이슈로 옮기고 번호로 회신한다 |
| 트랙 지시문을 넘긴다 | 지휘 → 트랙 | 채운 `track-brief.md`(§5) |
| step·PR을 끝냈다 | 트랙 → 지휘 | track-brief 「끝나면 지휘에 보고」 5줄 |

- **다 끝났는지(fan-in) 확인**: 지시문을 보낸 뒤 트랙마다 `notify_when_idle: true`를 한 번 건다. 그러면 트랙이 멈출 때 알림이 한 번 온다. `ListAgents`를 반복 조회하거나 "끝났어?"를 보내지 않는다
- **트랙끼리는 직접 보내지 않는다.** 트랙 A가 트랙 B에만 알리면 트랙 C와 다음 세션은 그 내용을 모른다. 반드시 지휘를 거쳐 이슈로 남긴다
- **메시지에 결정 값을 담지 않는다.** 지휘가 보내는 메시지는 이슈 번호와 한 줄만 담는다. 값은 이슈와 ADR에 있다
- **무응답은 동의가 아니다.** 다른 머신, Remote Control, 클라우드 세션은 수신 여부를 알려 주지 않는다. 회신이 없으면 사용자에게 옮겨 달라고 한다
- **권한을 넘기지 않는다.** 내 세션에서 막힌 일, 그리고 §6의 「사용자에게 넘김」에 해당하는 일(운영 DB·배포·비밀값·외부 발송)은 다른 세션에 시키지 않는다. 받은 쪽도 하지 않는다

2026-10-14 실측: 쉬고 있던(idle) 세션이 메시지를 받고 바로 처리해 회신했다. 권한 모드가 다른 세션(auto와 기본 모드) 사이에서도 승인 창 없이 전달됐다. `notify_when_idle` 알림도 보낸 쪽 세션에 도착했다.

## ⚠️ 주의 · 금지

1. 이슈는 팀 레포에서 동료에게 보인다. 본문에 사람 이름 · 내부 평가 · 비밀값 · 고객 식별 정보를 쓰지 않는다. 담당은 직함 또는 트랙 라벨로.
2. 이슈가 정본이 되면 안 된다. 확정된 결정은 반드시 ADR(git)로 옮기고 이슈를 닫는다. 열린 이슈만 실시간 상태다.
3. gh 호출 비용 · 권한: 조회는 한 번으로 묶는다. 이슈를 만드는 계정의 쓰기 권한을 첫 실행 때 확인한다.
4. 네이티브 의존은 `gh api graphql`로만 걸린다(gh CLI 플래그 없음, 2026-10-08 확인). 실패하면 본문 첫 줄 `Blocked-by: #N` + `blocked` 라벨로 대신한다.

- 코드 · 다른 트랙 소유 문서를 직접 고치지 않는다
- ADR 번호를 트랙 세션이 매기게 두지 않는다
- 메시지로만 정하고 끝내지 않는다. 결정은 이슈에 남기고, 확정되면 ADR로 옮긴다(§8)
