# 지휘 자리 · 세션 종류 · 세 자리 역할 · §0 준비

`conductor`가 처음 돌 때와 자리 · 세션 이름을 정할 때 읽는다. `§N` · 「절 이름」은 `${CLAUDE_PLUGIN_ROOT}/skills/conductor/SKILL.md` 「상황 → 절」 표에서 파일을 찾는다.

## 지휘 자리 — 레포 여럿을 하나에서

지휘 설정 `~/.claude/conductor.json`(`{"seat": "<지휘 자리>", "repos": [<대상 레포>…]}`)이 있으면 지휘는 대상 레포 밖, 지휘 자리 폴더에서 돈다. 설정이 없으면 지금처럼 레포 안 기준 worktree에서 레포 하나를 맡는다.

- 대상 레포 목록은 `python3 "${CLAUDE_PLUGIN_ROOT}/hooks/lib/conductor.py" repos`로 읽는다. 목록을 지어내지 않는다
- 판정(§1·§5·§6) 전에 그 레포의 `CLAUDE.md`·`.claude/references/tracks.md`를 Read한다. 지휘 자리에서는 대상 레포 설정·규칙이 자동으로 로드되지 않는다. 지휘 자리 문서와 레포가 다르면 레포가 맞다
- 시작·재개·압축 뒤에는 `conductor-context` 훅이 레포마다 트랙 한 줄과 열린 지휘 이슈를 넣는다. 그 현황부터 읽고 이어 간다. 대화 기억으로 상태를 잇지 않는다
- 레포 여럿에 걸친 결정은 **기능이 시작된 주 레포**에 `decision` 이슈·ADR을 둔다. 다른 레포에는 `follow-up` 이슈를 내고 본문 첫 줄에 `Decision: <owner>/<repo>#N`을 적는다. ADR 번호는 레포마다 따로다. 같은 결정을 레포마다 복제하지 않는다(한쪽이 낡는다)

### 세션 종류

| 종류 | 이름 | 언제 닫나 | 트랙 표 |
|---|---|---|---|
| 지휘 | `conductor` (옛 사본은 `<레포>-conductor`) | 닫지 않는다 | — |
| 상주 | `<레포>-<층>` (`fe`·`be`) · FE 앱이 둘 이상이면 `<레포>-<앱>` | 닫지 않는다. 자동 압축에 맡긴다. 한 레포에 여러 개 | 행 |
| 기능 묶음 | `<레포>-<층>-<기능>` (병렬 worktree) | PR이 병합되면 worktree와 같이. 지휘가 열고 닫는다 | 행. 소유 경로는 상주 트랙에서 떼어 온다 |
| 기획·시안 단계 | 기능 묶음과 같다(코드 0, PRD·시안만) | 승인되면 코드 트랙으로 이어지거나 닫힌다 | 행 |
| 1회용 | `<레포>-tmp-<할일>` (버그·리뷰) | 끝나면. 결정이 나오면 지휘에 보고 | 표 밖 |

레포 밖 코드를 고치는 트랙은 두지 않는다. 그 레포를 따로 열어 그 레포의 상주 트랙이 지휘 지시를 받는다.

### 세 자리 역할 (ADR-014 — ADR-012 「판정함 직행」 대체)

| 자리 | 하는 일 | 결정 | 안 하는 일 | 상태 자리 |
|---|---|---|---|---|
| desk (사용자 화면) | 지휘가 올린 판정함 질문을 읽고 고른다 | 사용자가 고른다 | 코드 · 이슈를 직접 만지지 않는다 | 판정함(레포 이름 키) |
| 지휘 | 사용자와 설계를 끝낸다(결정 이슈 「정할 것」 0 · 설계 문서 확정). 그 뒤에 디스패치하고, 이슈 · 전파 · ADR 번호, 세션 열고 닫기, 예외 판정 | 사용자와 함께 정한다. 사용자에게 물을 것은 판정함에 올린다(§1 판정 거르기) | 설계가 덜 끝난 채 디스패치 · 코드 고치기 | GitHub 이슈 · ADR |
| 작업 (트랙 세션) | 설계가 끝난 지시문대로 코드 · 문서를 고친다. 코드 사실이 필요하면 조사해 사실만 지휘에 보고한다 | 하지 않는다. 지시문 밖 설계 결정이 필요하면 멈추고 지휘에 보고한다 | 판정함에 직접 올리기 · 소유 경로 밖 고치기(사용자가 그 세션에서 시켜도 먼저 지휘에 보고) | 브랜치 · PR |

판정함 질문 형식(추천 표시 · `ask`/`picks`/`applied`)은 desk의 `decision-inbox` 스킬이 정본이다. 여기 다시 적지 않는다.

## 0. 준비 (첫 실행)

```bash
gh auth status                                   # gh 계정이 여럿이면 활성 계정을 확인한다(owner별 쓰기 계정은 block-dangerous-bash 가 ~/.claude/gh-accounts.txt 로 막는다)
gh repo view <owner>/<repo> --json nameWithOwner,viewerPermission -q '.nameWithOwner+" "+.viewerPermission'
gh label list -R <owner>/<repo> --limit 200 --json name -q '.[].name'
```

- **세션 이름부터 맞춘다.** `ListAgents` 결과 첫 줄 `This session is <이름>`이 `conductor`(지휘 자리) 또는 옛 이름 `<레포>-conductor`(설정 없이 레포 안)가 아니면, 사용자에게 `/rename conductor` 한 줄을 그대로 보여 주고 다음 단계로 가지 않는다. 세션은 자기 이름을 스스로 바꾸지 못한다(`/rename`은 사용자 입력 명령). 같은 이름이 목록에 이미 있으면 그 세션이 살아 있는 지휘 세션인지 먼저 묻는다
- 지휘 자리면 대상 레포마다 아래 확인·라벨을 한 번씩 돈다(`<owner>/<repo>`는 그 레포 `git -C <레포> remote get-url origin`에서)
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
gh label create -R <owner>/<repo> conductor --color 5319e7 --description "지휘 세션이 관리"
gh label create -R <owner>/<repo> "track:<이름>" --color 0e8a16
```
