---
name: conductor
description: 병렬 트랙(worktree 세션 2개 이상)의 지휘를 맡길 때("너는 지휘 세션"·"지휘 맡아", ~/.claude/conductor.json이면 대상 레포 여럿) 쓴다 — 결정·계약 변경 이슈를 후속 이슈로 쪼개 의존을 걸고, 다 닫히면 ADR로 옮긴다(번호 발급은 여기만). 트랙이 하나면 안 쓴다.
allowed-tools: [Read, Write, Bash, Glob, Grep]
---

지휘 세션은 **디스패치 · 판정 · 기록만** 한다. 코드와 다른 트랙 소유 문서는 고치지 않는다. 고치는 것은 그 트랙 세션이거나 공유 구역 PR이다.

**원칙**: 판단 전에 `${CLAUDE_PLUGIN_ROOT}/docs/principles/INDEX.md`를 보고, 쓰는 원칙은 원문을 읽는다.

## 지휘 원칙

- 트랙이 하나면 쓰지 않는다(`sdd`만). 트랙 세션 자신도 쓰지 않는다 — `sdd-run`이 열린 이슈를 읽기만 한다
- 조율 채널은 **GitHub 이슈**다. 보드 없이 라벨 + 네이티브 의존(§4)만 쓴다. 레포 파일 원장은 worktree가 기준 브랜치를 다시 받기 전까지 옛 상태를 읽어 지연을 그대로 물려받는다
- **설계 결정은 지휘에서 사용자와 정하고, 문서 초안 · 코드 조사는 코드 옆(트랙 세션)에서 한다.** 관문 둘 — 디스패치는 설계서 최종본 뒤, 구현 시작(계획 쪼개기 포함)은 구조 · 기술 결정 「정할 것」 0일 때(§1 관문 둘). 자리마다 하는 일은 `seat.md` 「세 자리 역할」 표가 정본이다
- 🔴 **ADR 번호는 한 곳에서만** 발급한다 — 지휘가 §1 4번 명령으로. 막힌 질문 번호도 같다. 트랙 세션이 매기게 두지 않는다
- 지시문에 값을 복사하지 않는다. 이슈 번호와 `ADR-NNN` 참조만 넣는다 — 복사본은 정본이 바뀐 걸 따라오지 못한다(「왜」 표 3번째 줄)
- **메시지는 초인종이다.** `SendMessage`는 이슈가 열리거나 닫혔다고 알리는 데까지만 쓴다. 결정은 메시지로 끝내지 않고 이슈에 남긴다 — 메시지는 받은 세션의 대화 안에만 남아 새로 연 세션이나 다른 트랙은 모른다(§8)
- 트랙 예외(소유 경로 밖)는 지휘가 판정한다. 사용자에게는 비가역 · 보안 · 외부 부작용만 넘긴다(§6)
- 🔴 **모든 gh 명령에 `-R <owner>/<repo>`**(`issues.py`는 `--repo <owner>/<repo>`), **모든 git 명령에 `git -C <레포>`.** 지휘 자리에서 `-R` 없는 gh 쓰기는 `block-dangerous-bash`가 막는다

## 상황 → 절

`§N` · 「절 이름」은 트랙 지시문 템플릿 · `tracks.md` · 스크립트 출력에서도 이 이름으로 가리킨다. 그 행의 파일을 Read하고 그 절대로 한다.

| 상황 | 절 | 읽을 파일 |
|---|---|---|
| 첫 실행 · 세션 이름 확인 · gh 쓰기 권한 · 라벨 만들기 | §0 준비 · 라벨 표 | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/seat.md` |
| `~/.claude/conductor.json`으로 레포 여럿을 맡는다 · 세션 이름을 짓는다 · 한 곳 / 지휘 / 작업 역할 | 「지휘 자리」 · 「세션 종류」 · 「세 자리 역할」 | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/seat.md` |
| 결정이 생겼다 · 사용자에게 물을지 거른다 · ADR 번호를 낸다 | §1 결정 흐름(관문 둘 · 판정 거르기 · 결정 이슈 틀) | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/decisions.md` |
| API 스키마 · 공유 타입 · 의미(기준 · 주기 · 단위)가 바뀐다 | §2 계약 변경 흐름 | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/decisions.md` |
| enum · 주기 · 테이블 구조를 계약으로 굳히려 한다 | §3 mock 관문 | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/decisions.md` |
| 의존 · 하위 이슈를 건다(`issues.py`) · 지금 진행 가능한 것 · 트랙 현황 · 겹침 · 지울 worktree | §4 의존과 "지금 진행 가능한 것"(「실패하면」 · 트랙 현황) | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/progress.md` |
| 트랙에 지시문을 보낸다 · 겹치면 · 새 규칙 → 기존 코드 정리 · 트랙 세션을 연다 | §5 트랙 지시문 · 「트랙 세션 열기」 | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/dispatch.md` |
| 트랙이 소유 경로 밖을 고쳐야 한다고 보고했다 | §6 트랙 예외 승인(「새 규칙 위반 정리만」) | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/dispatch.md` |
| 지휘 세션을 끝낸다 · worktree · 트랙 세션 정리 | §7 세션 끝 | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/session-end.md` |
| 트랙과 메시지를 주고받는다 · 트랙 보고(세 줄 요약 · 판정 재료 7줄 · 학습 카드)를 받는다 | §8 초인종 | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/doorbell.md` |
| 사용자에게 현황 · 트랙 보고를 올린다 | 「사용자에게 올리는 현황」 | 이 파일 아래 |
| 규칙이 왜 생겼나(실측 · 빌려 온 것) | 「왜」 | `${CLAUDE_PLUGIN_ROOT}/skills/conductor/references/why.md` |

## 사용자에게 올리는 현황

recall 출력 계약(`${CLAUDE_PLUGIN_ROOT}/skills/sdd/SKILL.md` 「재개」)으로 낸다. 상태 태그는 step 대신 트랙마다 §4 트랙 현황 표의 신호(⛔ · 💤 · 진행)를 붙인다. 트랙이 보고한 세 줄 요약 · 학습 카드의 형식은 같은 파일 ⑤ 마무리가 정본이다(track-brief 「끝나면 지휘에 보고」). 트랙 보고를 사용자에게 넘길 때 세 줄 요약 · 학습 카드는 **그대로** 싣는다. 지휘가 요약하거나 다시 풀어 쓰지 않는다 — 다시 쓰면 PR 본문 · 트랙 보고와 다른 말이 된다. 학습 카드는 사용자의 개인 기록 자리(설정이나 사용자가 알려 준 곳)가 있으면 거기에도 붙이고, 없으면 보고에만 싣는다. 카드의 「내 한 줄」은 사용자만 쓴다. 지휘도 트랙도 채우지 않는다.

머지를 물을 때는 PR마다 한 줄로 낸다: `Risk n · 심각도 · 사람이 볼 것 n개 · 규칙 diff 있음/없음`(값은 PR 본문의 Risk Score · 리뷰 심각도 · 「사람이 볼 것」 절에서). 규칙 파일(`CLAUDE.md` · `.claude/rules/**`)이 바뀐 PR이면 그 diff를 줄 아래에 그대로 붙인다 — 머지는 「조건 맞으면 머지」 한 줄로 승인되므로, PR에만 실린 규칙 diff는 사람이 실제로 보지 않는다.

## ⚠️ 주의 · 금지

1. 이슈는 팀 레포에서 동료에게 보인다. 본문에 사람 이름 · 내부 평가 · 비밀값 · 고객 식별 정보를 쓰지 않는다. 담당은 직함 또는 트랙 라벨로.
2. 이슈가 정본이 되면 안 된다. 확정된 결정은 ADR(git)로 옮기고 이슈를 닫는다. 열린 이슈만 실시간 상태다.
3. gh 호출 비용 · 권한: 조회는 한 번으로 묶는다. 이슈를 만드는 계정의 쓰기 권한을 첫 실행 때 확인한다.
4. 검사 상한: 머신에서 검사(`verify`)가 `CLAUDE_VERIFY_MAX`(기본 2)개 이상 돌면 Stop 훅은 건너뛰고, 러너는 기다리고, 직접 친 검사 명령은 막힌다. 트랙을 여럿 열수록 부딪힌다 — 트랙 수를 늘리기 전에 이 숫자를 본다.
5. 네이티브 의존은 `issues.py`(§4)로만 건다 — gh CLI에는 의존 플래그가 없어 `gh api graphql`로만 걸린다. 실패하면(종료 1) 본문 첫 줄 `Blocked-by: #N` + `blocked` 라벨로 대신한다.
