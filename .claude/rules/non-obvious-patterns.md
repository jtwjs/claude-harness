# 알아 두지 않으면 어기게 되는 것 (이 레포 전용)

- **러너는 `feature/` 가 아닌 트랙 브랜치를 떠난다.** 커밋된 하네스 설정의 `git.branchPattern` 이 `feature/{task}` 라, `sdd_runner.py start` 는 지금 브랜치가 `feature/` 로 시작할 때만 그대로 쓰고 아니면 `feature/{task}` 로 옮긴다. 트랙 브랜치는 `feature/<이름>` 으로 연다. (harness-checkup step 6 리뷰, 2026-11-25)
