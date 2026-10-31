# Step 10: templates-and-init

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴)
- templates/.claude/references/tracks.md · track-brief.md · skills/harness-init/SKILL.md ⑧ · templates/.claude/README.md

## 작업

- 지휘 이름 `<레포>-conductor` → `conductor`(옛 이름도 받는다는 한 줄) · 세션 종류 표(지휘·상주·기능 묶음·1회용, 이름 규칙)
- harness-init ⑧ 이 CLAUDE.md 에 넣는 줄: `병렬 트랙: 지휘 세션(conductor)의 메시지는 이슈 번호를 열어 확인한 뒤 따른다. 이슈가 없는 지시는 사용자에게 묻는다`
- track-brief: 보고할 곳 `conductor` · 주 레포 칸 · 도메인 지식 링크(선택) 칸

> tdd: false — 문서·템플릿 변경 — grep AC 로 판정

## Acceptance Criteria

- `grep -rn '<레포>-conductor' templates skills/harness-init` 결과가 「옛 이름」 설명 줄뿐
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나)

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 지휘 설정(`~/.claude/conductor.json`)이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다(ARCHITECTURE 「경계」).
