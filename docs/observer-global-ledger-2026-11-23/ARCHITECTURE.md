# ARCHITECTURE — harness-gaps 전역 후보 적재

## 개요

결정적인 일(재료 추리기 · 미위임 집계 · 검증 · ID · 원장 쓰기)은 파이썬 스크립트가, 뜻을 봐야 하는 일(4종 판정 · 레포 2곳 이상 묶기)만 `claude -p`가 한다. 모델은 파일을 쓰지 않고 후보 JSON만 낸다.

## 계층 배치

```
skills/harness-gaps/
├── SKILL.md                     # 범위 칸 · 경계 · 헤드리스 길 · 개인 설정 (정본)
├── references/weekly-prompt.md  # claude -p 지시문 (재료 JSON을 뒤에 붙여 stdin으로)
└── scripts/
    ├── gaps.py              # gather · append (표준 라이브러리만)
    └── weekly.sh                # gather → claude -p → append, --dry-run, 소요 시간
hooks/tests/harness-gaps.sh     # test.sh 가 source
```

## 데이터 흐름

```
weekly.sh [--dry-run] [--days 7]
  ├─ gaps.py config            → 원장 경로 없으면 "원장 설정 없음" · exit 0 (dry-run은 계속)
  ├─ gaps.py gather --days 7   → 재료 JSON (stdout)
  │     repos[]: { name, sessions(날짜[]), user[], bash[], observations[], undelegated[] }
  ├─ (repos 2곳 미만이면 "후보 없음" · exit 0 — 묶을 수 없다)
  ├─ claude -p --tools "" --no-session-persistence --output-format json  < 지시문 + 재료
  │     → .result = 후보 JSON 배열
  └─ gaps.py append [--dry-run] --known <재료 repos[].name 쉼표> <후보.json>
        → 검증 → ID → 원장 행 삽입 → 월별 파일 항목 append
```

### `gaps.py config`
- 설정: env `CLAUDE_HARNESS_GAPS_CONFIG`(테스트용) 또는 `~/.claude/harness-gaps.json`. `{"ledger": "<원장 index.md 경로>"}`. `~` 펼침. 없거나 깨졌거나 칸 없으면 빈 줄 + exit 0.

### `gaps.py gather --days N [--projects DIR]`
- 대화 기록: env `CLAUDE_HARNESS_GAPS_PROJECTS` 또는 `~/.claude/projects/*/*.jsonl`. 파일 mtime이 창 밖이면 열지 않는다. 줄의 `timestamp`가 창 안인 것만.
- 레포 식별: 줄의 `cwd`를 `git -C <cwd> rev-parse --path-format=absolute --git-common-dir`로 묶는다. 이름 = 공통 디렉터리가 `.git`이면 그 부모 폴더 이름, 아니면(bare) 그 폴더 이름. 경로가 없거나 git이 아니면 뺀다. cwd별 결과는 캐시.
- 사람 말: `type == "user"` 줄의 text 내용만(tool_result 제외). `<`로 시작하는 줄(명령 · 시스템 래퍼)과 다른 세션 메시지는 뺀다. 한 줄 400자 · 레포당 최근 150개.
- Bash 명령: assistant `tool_use` 중 `name == "Bash"`의 `input.command` 첫 줄. 200자 · 레포당 최근 150개.
- observations: 레포마다 그 레포에 속한 cwd들의 toplevel(worktree 포함, `git rev-parse --show-toplevel`)을 각각 훑어 합친다. 각 toplevel의 `.claude/observations.md` 「열린 것」 표에서 헤더에 `범위` 칸이 있고 값이 `전역 후보`이며 `마지막`이 창 안인 행.
- 미위임: 같은 toplevel들의 `phases/*/index.json`에서 `status == "blocked"` 또는 `retries >= 3`인 step → `{phase, step, name, reason}`(reason = `blocked_reason` 또는 `last_error`/`error_message`, 200자).
- 출력은 레포 이름 순 정렬(결정적).

### `gaps.py append [--dry-run] [--known NAME,...] FILE`
- FILE: 후보 배열 `[{pattern, kind, repos[], count, first, last, direction, evidence[]}]`.
- 검증(AC6): kind ∈ `재지시 | 재교정 | 불발 | 미위임 | 반복 절차`, repos 서로 다른 이름 2개 이상, pattern 한 줄 · 1~200자, direction ∈ `direct | investigate | plan`, first/last `YYYY-MM-DD`(없으면 실행 날짜), count 양의 정수(없으면 레포 수). 어긋나면 그 후보만 건너뜀 + stderr.
- `--known`(weekly.sh 가 재료 `repos[].name` 을 넘김): repos 중 하나라도 목록 밖이면 그 후보만 건너뜀 + stderr `레포 이름이 재료에 없음: <이름>`. 없으면 이 검사를 하지 않는다(하위 호환).
- ID(AC7): 원장 전체에서 `^\| F-(\d+) \|` 최댓값 + 1, 세 자리 0 채움.
- 원장 행(AC8): 표 = 헤더가 `| ID | 패턴 |`로 시작하는 첫 표. 그 표의 마지막 `|` 줄 뒤에 삽입. 표가 없으면 쓰지 않고 exit 2(원장 형식 불일치 — 원장 주인은 볼트 friction 스킬). 칸 안 `|`는 `\|`, 줄바꿈은 공백.
  - 칸: `F-NNN | 패턴 | 유형 | 레포(a, b) | ⚠️ | count | first | last | direction | 후보 | 연결`
  - 연결: 원장 폴더에서 위로 `.obsidian`이 있는 폴더를 찾으면 `[[<그 폴더 기준 상대경로>/YYYY-MM\|YYYY-MM]]`, 없으면 `[[YYYY-MM]]`.
- 월별 파일(AC9): 원장 폴더 `YYYY-MM.md`(실행 날짜). 없으면 frontmatter(`type: brain-note` · `tags: [me, kind/friction]`)와 `# 불편 원문 YYYY-MM`로 만든다. 항목 형식(볼트 friction 스킬 「월별 파일 항목 형식」에 맞춤):

  ```markdown
  ## YYYY-MM-DD · <패턴> → F-NNN

  > 근거(harness-gaps 헤드리스): <evidence 한 줄씩 · 로 이음>

  - 상황: 주 1회 헤드리스가 레포 <a>, <b>의 지난 7일 대화 기록 · phases를 훑음
  - 불편: <패턴>
  - 비용: ⚠️
  - 유형: <kind>
  - 대상: 레포(<a>, <b>)
  - 프로젝트: ⚠️
  - 방향: <direction>
  ```
- 쓰기 순서: 월별 파일 → 원장(원장이 정본이라 마지막). 원장은 임시 파일에 쓰고 rename.
- `--dry-run`: 둘 다 쓰지 않고 행 · 항목을 stdout에. 설정 없어도 돈다(원장 대신 빈 표 가정, ID F-001부터).
- 종료: 0 성공(후보 0 포함) · 1 쓰기 실패 · 2 입력 · 원장 형식 거부.

### `weekly.sh`
- `claude` 실행 파일: env `HARNESS_GAPS_CLAUDE`(테스트용 가짜) 또는 `claude`.
- `ANTHROPIC_API_KEY`가 있으면 경고 한 줄(구독이 아니라 API 과금 — sdd_runner와 같은 안내).
- 시작 · 끝 시각과 소요 초를 stdout 마지막 줄에: `harness-gaps weekly: 후보 n · 쓴 행 m · 소요 Ns`.
- 재료 · 결과 원문은 `${TMPDIR}` 임시 폴더, 끝나면 지운다(대화 원문을 남기지 않는다).

## 경계 · 의존 방향

- 모델 → 파일 쓰기 없음. 모든 쓰기는 `gaps.py append` 한 곳.
- 원장 형식(11칸 · `F-NNN` · 상태 이름)은 볼트 friction 스킬이 주인이다. 하네스는 따라가고, 바뀌면 같이 고친다(ADR 「대가」).
- 공개 레포: 원장 경로 · 볼트 폴더 이름은 설정 파일에서만 온다. 코드 · 문서 · 테스트 픽스처에 실제 경로를 쓰지 않는다.

## 테스트 전략

- `hooks/tests/harness-gaps.sh` 하나. 임시 폴더에 가짜 `projects/*.jsonl` · 가짜 git 레포 2개(+ worktree 1) · 가짜 원장 · 가짜 `claude`(정해진 JSON을 내는 셸 스크립트)를 만든다.
- 실제 `~/.claude`를 읽지 않게 `CLAUDE_HARNESS_GAPS_CONFIG` · `CLAUDE_HARNESS_GAPS_PROJECTS`를 늘 임시 경로로.
- 모델 판정 품질은 테스트하지 않는다(사람이 `/friction review`에서 거른다). 첫 수동 실행 결과를 PR에 보고.
