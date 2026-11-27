# 알아 두지 않으면 어기게 되는 것 (이 레포 전용)

- **러너는 `feature/` 가 아닌 트랙 브랜치를 떠난다.** 커밋된 하네스 설정의 `git.branchPattern` 이 `feature/{task}` 라, `sdd_runner.py start` 는 지금 브랜치가 `feature/` 로 시작할 때만 그대로 쓰고 아니면 `feature/{task}` 로 옮긴다. 트랙 브랜치는 `feature/<이름>` 으로 연다. (harness-checkup step 6 리뷰, 2026-11-25)
- **러너 단위 테스트의 임시 레포는 `start` 뒤 브랜치가 바뀐다.** `test_sdd_runner.py`의 임시 레포는 `main`에서 시작하지만 `start`(또는 `red_turn`)가 `git.branchPattern` 없이 `feat-{task}`로 옮긴다. 「브랜치를 안 옮긴다」를 단언할 때는 이름을 박지 말고 호출 앞뒤 값을 대조한다. (runner-gate step 3 재판정, 2026-11-26)
