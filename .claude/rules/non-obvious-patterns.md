# 알아 두지 않으면 어기게 되는 것 (이 레포 전용)

- **새 테스트는 `hooks/tests/*.sh` 에만 둔다. `hooks/test.sh` 는 고치지 않는다.** 러너(`sdd_runner.py judge`)의 테스트 파일 판정이 `hooks/test.sh` 를 못 알아봐서, 고치면 RED 확인(테스트만 담긴 커밋이 먼저·그 시점에 실패·뒤에 테스트 파일 무변경)이 깨진다. `hooks/test.sh` 는 `hooks/tests/*.sh` 를 source 하므로 새 파일은 자동으로 돈다. (hypothesis-ledger step 2·8 에서 2h 넘게 막힘)
- **worktree 에는 `.claude/harness.json` 이 없다.** main clone 에만 있고 `.git/info/exclude` 로 빠져 있어서 `git worktree add` 가 안 가져온다. 러너(`sdd_runner.py start`)를 worktree 에서 돌리려면 main clone 의 파일을 복사하고 `git.branchPattern` 을 `{task}` 로 넣는다 — 없으면 러너가 트랙 브랜치를 떠나 `feat-{task}` 로 옮긴다. 복사본은 커밋하지 않는다. (observer-global-ledger, 2026-11-23)
