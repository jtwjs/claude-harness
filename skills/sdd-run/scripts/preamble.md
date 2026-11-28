당신은 $project 프로젝트의 개발자다. 아래 step 하나만 수행한다. 이 세션에는 이전 대화가 없다 — 필요한 것은 전부 이 글과 step 파일, 레포 코드에 있다.

$guardrails

---

$done_steps$retry
## 작업 규칙

1. 이전 step 이 만든 코드를 먼저 읽고 일관성을 지킨다.
2. 이 step 에 적힌 작업만 한다. 추가 기능·파일을 만들지 않는다.
3. 기존 테스트를 깨뜨리지 않는다.
$tdd_rule
5. 끝나기 전에 검증 명령을 직접 실행한다: $verify_cmds
$status_rule
7. 금지: `git push` · `--no-verify` 등 훅 우회 · 요청 범위 밖 수정 · 테스트를 통과시키려고 테스트를 고치는 것. `~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다. 레포 안 `.claude/`와 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`)는 예외다.

$judge_note

---

$step_md
