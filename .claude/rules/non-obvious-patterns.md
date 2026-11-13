# 알아 두지 않으면 어기게 되는 것 (이 레포 전용)

- **새 테스트는 `hooks/tests/*.sh` 에만 둔다. `hooks/test.sh` 는 고치지 않는다.** 러너(`sdd_runner.py judge`)의 테스트 파일 판정이 `hooks/test.sh` 를 못 알아봐서, 고치면 RED 확인(테스트만 담긴 커밋이 먼저·그 시점에 실패·뒤에 테스트 파일 무변경)이 깨진다. `hooks/test.sh` 는 `hooks/tests/*.sh` 를 source 하므로 새 파일은 자동으로 돈다. (hypothesis-ledger step 2·8 에서 2h 넘게 막힘)
