# Step 9: conductor-skill-doc

## 읽어야 할 파일

- docs/single-conductor-2026-10-31/PRD.md · ARCHITECTURE.md · ADR.md
- hooks/test.sh (케이스 형식·임시 디렉터리·env 격리 패턴)
- skills/conductor/SKILL.md 전부

## 작업

- §0: 세션 이름 `conductor` 또는 옛 `<레포>-conductor` 면 진행. 지휘 자리(설정)면 대상 레포 목록을 `conductor.py repos` 로 읽는다. 판정 전 대상 레포 CLAUDE.md·tracks.md 를 Read
- 모든 gh·git 예시에 `-R <owner>/<repo>` · `git -C <레포>`
- 「세션 종류」 표(PRD 결정 session-kinds) · 결정 원장(PRD cross-repo-decision-ledger)
- §7 세션 끝에 「지울 worktree」 · 재개(압축 뒤는 conductor-context 훅이 넣은 현황부터)
- 트랙 지시문에 「도메인 지식 링크(선택)」 칸 언급 — 링크만, 내용 복사 금지
- 「검사 상한」 한 줄(ADR-007)

> tdd: false — 문서(SKILL.md) 변경 — 실행 코드가 없어 실패하는 테스트를 먼저 쓸 수 없다. grep AC 로 판정

## Acceptance Criteria

- `grep -nE '^\s*gh (issue|label|pr|api)' skills/conductor/SKILL.md | grep -v -- '-R'` 0줄 (graphql 은 owner 명시)
- `grep -c 'conductor.py' skills/conductor/SKILL.md` ≥ 1 · `grep -c '세션 종류' …` ≥ 1
- `bash hooks/test.sh` 전부 통과(이 레포엔 harness.json 이 없어 verify 는 이 명령 하나)

## 검증 절차

1. `bash hooks/test.sh` 를 실제 실행한다(테스트 커밋 시점 실패 → 구현 뒤 전부 통과).
2. ARCHITECTURE 「경계·의존 방향」 대조.
3. `phases/single-conductor/index.json` 해당 step 에 status·summary 기록.

## 금지사항

- hook 우회(`--no-verify`) · 자동 생성물 직접 수정 · 요청 범위 밖 수정 · **테스트 파일 수정**(구현 커밋에서) 금지.
- 쌓기만 하는 기록(`docs/` 의 지난 설계 · ADR 본문 · `phases/*/`)은 고치지 않는다.
- 지휘 설정(`~/.claude/conductor.json`)이 없으면 새 코드 경로는 전부 건너뛰어 지금 동작과 같아야 한다(ARCHITECTURE 「경계」).
