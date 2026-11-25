# §4 의존과 "지금 진행 가능한 것" · 트랙 현황

`conductor`가 의존을 걸고, 진행 가능한 이슈와 트랙 현황을 볼 때 읽는다. `§N` · 「절 이름」은 `${CLAUDE_PLUGIN_ROOT}/skills/conductor/SKILL.md` 「상황 → 절」 표에서 파일을 찾는다.

## 4. 의존과 "지금 진행 가능한 것"

🔴 네이티브 의존은 `gh api graphql`로만 걸린다. `gh` CLI(2.92)에는 플래그가 없다(2026-10-08 확인). 그 호출은 `issues.py`가 감싼다 — 손으로 graphql을 쓰지 않는다.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/conductor/scripts/issues.py" block 12 10 --repo <owner>/<repo>     # #12 가 #10 에 막힌다
python3 "${CLAUDE_PLUGIN_ROOT}/skills/conductor/scripts/issues.py" unblock 12 10 --repo <owner>/<repo>   # 풀기
python3 "${CLAUDE_PLUGIN_ROOT}/skills/conductor/scripts/issues.py" sub 9 12 --repo <owner>/<repo>        # #12 를 결정 #9 의 하위로
```

**지금 진행 가능한 것** — 열린 `conductor` 이슈를 **한 번에** 받아 차단이 전부 닫힌 것만 거른다. 이슈마다 따로 부르지 않는다.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/conductor/scripts/issues.py" ready --repo <owner>/<repo>   # 한 줄에 `#번호 [track:…] 제목`
```

`decision` 이슈는 지휘가 들고 있는 원장이라 결과에서 뺀다 — 트랙이 집어 갈 것은 `follow-up`·`contract-change`뿐이다(2026-10-08 비공개 임시 레포 실측: 빼지 않으면 결정 이슈가 "진행 가능"으로 섞여 나왔다).

**실패하면**(권한·기능 미지원 — `issues.py`가 gh 오류를 stderr로 내고 종료 1): 본문 첫 줄 `Blocked-by: #N` + `blocked` 라벨로 대신한다. 조회는 `gh issue list -R <owner>/<repo> --label conductor --json number,title,body,labels` 한 번으로 받아 첫 줄을 파싱한다.

**트랙 현황** — 디스패치(§5) 전, 예외 판정(§6) 전, 사용자가 "현황"이라고 할 때 표 한 장으로 본다. 트랙 세션마다 묻거나 worktree를 하나씩 열지 않는다.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/conductor/scripts/tracks_status.py"            # --stale 분(기본 30) · --no-gh. 지휘 자리면 대상 레포마다 `## 레포` 절
```

worktree마다 트랙(브랜치 `feature/<트랙>-…`로 매칭) · 그 worktree의 phases 진행 · 마지막 신호(커밋·index.json) · 안 올린 변경 수 · 열린 후속 이슈 수가 한 행이다. 표 아래 「겹침」은 트랙 worktree 둘 이상이 같이 바꾸고 있는 파일이다(기준 브랜치와 갈라진 뒤 커밋 + 안 올린 변경) — 그대로 두면 먼저 병합된 쪽 뒤에 나머지가 충돌한다. 겹침이 나오면 §5 「겹치면」으로 판정한다. ⛔(막힌 step)이 맨 위, 그다음 💤(신호 없음). ⛔은 §6 예외 판정으로, 💤은 §8 초인종으로 그 트랙 세션에 상태를 묻는다. 끝난 worktree(남은 SDD step 없음)는 표 대신 아래 「지울 worktree」로 묶인다. 겹침은 진행 중 worktree끼리만 센다. 사람에게는 `--compact` 한 줄이 손댈 것만 담아 상태줄에 뜬다 — 레포 안이면 `트랙 ⛔admin 💤renderer 진행1 겹침2`, 지휘 자리면 `bv-admin ⛔fe 진행1 · dash (경로 없음)`. 손댈 것이 없으면 빈 출력이다(개인 dotfiles 상태줄이 부름). 아이디어는 lcalmsky/deadhd 레인 보드(MIT, 코드는 가져오지 않음).

사용자에게 올리는 현황의 형식은 `${CLAUDE_PLUGIN_ROOT}/skills/conductor/SKILL.md` 「사용자에게 올리는 현황」이 정본이다.
