# 알아 두지 않으면 어기게 되는 것 (이 레포 전용)

- **worktree 에는 `.claude/harness.json` 이 없다.** main clone 에만 있고 `.git/info/exclude` 로 빠져 있어서 `git worktree add` 가 안 가져온다. 러너(`sdd_runner.py start`)를 worktree 에서 돌리려면 main clone 의 파일을 복사하고 `git.branchPattern` 을 `{task}` 로 넣는다 — 없으면 러너가 트랙 브랜치를 떠나 `feat-{task}` 로 옮긴다. 복사본은 커밋하지 않는다. (observer-global-ledger, 2026-11-23)
