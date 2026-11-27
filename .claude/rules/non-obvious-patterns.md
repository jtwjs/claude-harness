# 알아 두지 않으면 어기게 되는 것 (이 레포 전용)

- **러너는 `feature/` 가 아닌 트랙 브랜치를 떠난다.** 커밋된 하네스 설정의 `git.branchPattern` 이 `feature/{task}` 라, `sdd_runner.py start` 는 지금 브랜치가 `feature/` 로 시작할 때만 그대로 쓰고 아니면 `feature/{task}` 로 옮긴다. 트랙 브랜치는 `feature/<이름>` 으로 연다. (harness-checkup step 6 리뷰, 2026-11-25)
- **러너 단위 테스트의 임시 레포는 `start` 뒤 브랜치가 바뀐다.** `test_sdd_runner.py`의 임시 레포는 `main`에서 시작하지만 `start`(또는 `red_turn`)가 `git.branchPattern` 없이 `feat-{task}`로 옮긴다. 「브랜치를 안 옮긴다」를 단언할 때는 이름을 박지 말고 호출 앞뒤 값을 대조한다. (runner-gate step 3 재판정, 2026-11-26)
- **누가 만든 커밋인지는 커밋 제목 · 내용으로 가르지 않는다.** 나눔 모드 구현 지시문은 구현 세션에 직접 커밋하라고 해서, `wip:` 제목이나 「테스트만 담았다」로는 검증 커밋과 구현 커밋을 못 가른다. 경계는 러너가 그 순간 기록한 sha(`blocked_head` 등)로 잡고, 테스트도 구현 세션이 직접 커밋하는 경로를 만든다. (runner-gate-fix 새 맥락 리뷰 🔴, 2026-11-27)
- **훅 테스트에서 전체 마감을 호출 하나의 제한보다 짧게 주면 그 제한은 검증되지 않는다.** `conductor-context.sh`의 `run()`은 호출 제한과 남은 마감 중 짧은 쪽으로 끊어서, 마감을 줄인 느림 케이스는 호출 제한을 늘린 변이도 통과시킨다. 호출 제한을 볼 때는 전체 마감을 기본값으로 두고 걸린 시간을 단언한다. (release-alert REVIEW 1회차 code-reviewer 변이 실험, 2026-11-27)
