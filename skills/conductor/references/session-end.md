# §7 세션 끝

`conductor` 세션을 끝낼 때 이 순서로 보고 · 정리한다. `§N` · 「절 이름」은 `${CLAUDE_PLUGIN_ROOT}/skills/conductor/SKILL.md` 「상황 → 절」 표에서 파일을 찾는다.

## 7. 세션 끝

1. 열린 `decision` 중 하위 `follow-up`이 남은 것 — 번호 · 남은 후속 수 · 담당 트랙
2. 닫힌 `decision` 중 ADR 링크 코멘트가 없는 것 — **0이어야 한다**
3. `blocked` 목록과 무엇을 기다리는지
4. 「지울 worktree」(§4 현황 표 아래) — PR 병합을 확인하고 `git -C <레포> worktree remove`. 지우기 전에 안 올린 변경 수를 본다
5. 지휘가 연 트랙 세션(§5 「트랙 세션 열기」) — PR이 병합되면 `claude stop <id>` → `claude rm <id>` → 4번 worktree 정리. `worktree remove`가 잠금으로 거절되면 잠금을 쥔 pid가 끝났는지 `ps -p <pid>`로 보고 끝났을 때만 `git -C <레포> worktree unlock <경로>`
6. `쓴 원칙: <INDEX 이름|없음> · 바뀐 결정: <원칙을 읽고 달라진 판단 한 줄|없음>` 한 줄

```bash
gh issue list -R <owner>/<repo> --label decision --state closed --json number,comments \
  -q '.[] | select([.comments[].body | test("ADR-[0-9]{3}")] | any | not) | .number'
```
