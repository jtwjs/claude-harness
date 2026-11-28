# ARCHITECTURE — runner-headless-block

기존 구조 그대로 — 바뀌는 층: 없음. 러너 구조는 [`docs/sdd-runner.md`](../sdd-runner.md)가 정본이다. (← 검증 세션)

## 코드 지도

| 파일 | 이번에 하는 일 | 출처 |
|---|---|---|
| `skills/sdd-run/scripts/sdd_runner.py` `invoke` | `claude -p` 인자에 `--disallowedTools` + 차단 규칙(코드 상수 한 곳)을 넣는다. 지시문은 마지막 인자 그대로 | PRD AC-1 |
| `skills/sdd-run/scripts/test_sdd_runner.py` | 가짜 claude가 받은 인자(`N.argv`)로 차단 규칙 · 지시문 위치를 단언 | PRD AC-1 |
| `skills/sdd-run/scripts/preamble.md` 7번 금지 줄 | 「`~/.claude` 아래(대화 기록 · 원장 · 설정)를 읽지 않는다」 + 예외 | PRD AC-3 |
| `skills/sdd-plan/SKILL.md` §3 · step 템플릿 「금지사항」 | 같은 금지 줄 · 「가린 샘플을 넘긴다」 규칙 | PRD AC-3 · AC-4 |
| `docs/sdd-runner.md` | 헤드리스 차단 · 한계 한 줄 | PRD AC-5 |

## 확인한 사실 (2026-11-28, main 4f32c14)

| 사실 | 근거 | 출처 |
|---|---|---|
| 헤드리스 호출은 `[claude, -p, --dangerously-skip-permissions, --output-format, json, (--model), --effort, <값>, <지시문>]` 이다 | `sdd_runner.py` `invoke` | 검증 세션 |
| `claude --disallowedTools <tools...>`는 값을 여러 개 받는 옵션이다. 뒤에 다른 옵션 없이 지시문이 오면 지시문까지 규칙으로 먹는다. 지시문 앞에 `--`를 두면 정상으로 돈다 | `claude --help`(2.1.332) · 지휘 실측(2026-11-28) | 검증 세션 |
| 구현 세부(AI 결정): 지시문 바로 앞에 `--`를 둔다 — 옵션 순서에 기대지 않아 뒤에 옵션이 늘어도 안전하다. 단위 테스트가 `--` 다음 인자가 지시문 하나뿐이고 차단 규칙 목록에 지시문이 섞이지 않음을 단언한다 | 지휘 참고 사실 | 검증 세션 |
| 러너 지시문(`preamble.md` · 러너 문구)은 `~/.claude` 경로를 가리키지 않는다. 레포 안 `.claude/harness.json`은 가리킨다(`sdd_runner.py:591`) | grep | 검증 세션 |
| 헤드리스 step이 스킬을 쓰면 스킬 본문이 플러그인 폴더(`~/.claude/plugins/…`)의 참조 문서를 읽으라고 시킬 수 있다 | `skills/sdd-run/SKILL.md` · `skills/sdd-plan/SKILL.md`의 `CLAUDE_PLUGIN_ROOT` 경로 | 검증 세션 |

## 금지 문구와 장치의 범위 (지휘 확인 요청 반영)

- 장치(`--disallowedTools`)는 `.claude/projects`만 막는다. 플러그인 스킬 문서 · 레포 안 `.claude/`는 막지 않는다 (← #75 바꾸는 곳)
- 금지 문구는 `~/.claude` 아래 전체를 말하므로, 예외 둘을 같은 줄에 적는다: 레포 안 `.claude/`(harness.json · rules) · 스킬이 시키는 플러그인 스킬 문서(`~/.claude/plugins/`). 안 적으면 지시 두 개가 부딪쳐 이슈 원인 2를 다시 만든다 (← 지휘 확인 요청)

## 테스트 전략

- 러너 단위 테스트: 가짜 claude가 이미 인자를 `prompts/N.argv`에 남긴다(`test_intent_effort_headless_passes_effort` 꼴). 그 목록으로 차단 규칙과 지시문 위치를 본다 (← 검증 세션)
- 헤드리스 시험: 유료 `claude -p` 실행이라 측정 step(`kind: measure`)으로 두고, 돌리기 전에 횟수 · 내용을 지휘에 묻는다 (← 트랙 지시문)

## 배포와 롤백

- 플러그인 릴리스로 나간다. 되돌릴 때는 PR revert 하나다 (← 검증 세션)
