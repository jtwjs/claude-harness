# Step 6: known-repos-check

> REVIEW 1회차 수정 step. 지적: `append` 가 후보의 레포 이름이 서로 다른지만 보고, 재료(gather)에 실제로 있던 레포인지는 보지 않는다 — 모델이 이름을 지어내면 「레포 2곳 이상」(ADR-015)이 가짜로 참이 된다.

## 읽어야 할 파일

- docs/observer-global-ledger-2026-11-23/PRD.md (AC6 · AC12) · ARCHITECTURE.md 「observer.py append」 · 「weekly.sh」 · ADR.md
- skills/task-observer/scripts/observer.py (`_validate` · `append` · `main`) · skills/task-observer/scripts/weekly.sh
- hooks/tests/task-observer-append.sh · hooks/tests/task-observer-weekly.sh (케이스 형식 — 이 두 파일은 고치지 않는다)

## 작업

- `observer.py append [--dry-run] [--known NAME,NAME,...] FILE`: `--known` 이 있으면 후보의 `repos` 이름이 **하나라도** 그 목록 밖이면 그 후보를 건너뛰고 stderr 한 줄(`레포 이름이 재료에 없음: <이름>`). `--known` 이 없으면 지금 동작 그대로(하위 호환).
- `weekly.sh`: gather 재료의 `repos[].name` 을 쉼표로 이어 `append` 에 `--known` 으로 넘긴다(dry-run · 실제 둘 다).
- 문서: PRD AC6 에 「재료에 있던 레포 이름만」 한 구절, AC12 를 「후보 0이면 "후보 없음"과 요약 줄 · exit 0」으로, ARCHITECTURE append 검증 · weekly 흐름에 `--known` 한 줄씩. ADR 본문은 고치지 않는다.

## Acceptance Criteria

- 새 케이스 파일 `hooks/tests/task-observer-known.sh`: `--known a,b` 에서 repos [a,c] 후보 거부 · [a,b] 후보 씀 / `--known` 없으면 [a,c] 도 씀(하위 호환) / weekly.sh 가 가짜 claude 결과에 재료에 없는 레포 이름을 섞으면 그 후보만 빠지고 나머지는 씀.
- `bash hooks/test.sh` 전부 통과(`.claude/harness.json` verify.test). 테스트 커밋 먼저 · 그 시점에 새 케이스 실패.

## 검증 절차

1. `bash hooks/test.sh` 실제 실행.
2. 쓰기는 여전히 `append` 한 곳.
3. index.json 해당 step 기록.

## 금지사항

- hook 우회(`--no-verify`) · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 단계에서) 금지. 기존 `hooks/tests/task-observer-*.sh` 도 고치지 않는다.
- 🔴 `hooks/test.sh` 는 고치지 않는다(러너의 테스트 파일 판정이 못 알아봐 RED 확인이 깨진다). 새 케이스는 `hooks/tests/` 새 파일.
- 🔴 실제 `~/.claude` · 개인 원장을 읽거나 쓰지 않는다. 원장 실제 경로 · 볼트 폴더 이름을 코드 · 문서 · 픽스처에 쓰지 않는다.
- 쌓기만 하는 기록(로그 · 회고 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- macOS bash 3.2 호환: 변수 뒤 한글은 `${}`.
