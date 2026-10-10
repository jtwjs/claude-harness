#!/usr/bin/env bash
# SessionStart — 개인 학습 폴더 _learn/ 준비 + 기록 지시 주입. 비차단(exit 0).
#
# 왜 있나 (2026-10-11):
#   레포 _brain/ 은 팀 위키(인수인계용)다. 사람은 raw 를 통합 wiki 에 던지지 레포에 던지지 않아서
#   _brain/raw 는 0~4건, brain-intake 는 30일 호출 0 이었다.
#   "이 레포를 하며 내가 이해해야 할 것"은 개인용이라 따로 둔다 — 커밋하지 않는 _learn/.
#   채우는 쪽은 작업 중인 모델이고(훅은 대화를 이해하지 못한다), 그 지시는 세션 시작에 넣어야 산다.
#   vault 로 옮기는 것은 통합 wiki 쪽 주간 /gauge week 가 ~/.claude/learn-repos.txt 를 읽어 한다.
#
# cadence-reminder.sh(읽기 전용 계약)와 따로 둔 이유: 이 훅은 레포에 쓴다.
#   쓰는 곳은 셋뿐이다 — _learn/inbox.md(없을 때만 생성) · .git/info/exclude(줄이 없을 때만) · 레포 목록 파일.
#   .gitignore 는 건드리지 않는다 — 회사 레포에 diff 를 남기지 않는다.
set -uo pipefail
cat >/dev/null 2>&1 || true   # hook 입력(JSON) 소비

command -v git >/dev/null 2>&1 || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0
cd "$REPO_ROOT" 2>/dev/null || exit 0

INBOX="_learn/inbox.md"

# ── 1. 폴더·수신함 ───────────────────────────────────────────────────────────
if [ ! -f "$INBOX" ]; then
  mkdir -p _learn 2>/dev/null || exit 0
  cat > "$INBOX" <<'MD'
# 학습 수신함 — 이 레포를 하며 내가 이해해야 할 것

> 개인용이다. git 에서 빠져 있다(.git/info/exclude). 레포 _brain/ 은 팀 위키(인수인계용)라 따로 둔다.
> 작업 중인 모델이 아래 형식으로 한 장씩 덧붙인다. 통합 wiki 의 주간 /gauge week 가 모아 vault 로 옮기고 vault: 칸을 채운다.
> 상태: 모름 → 설명 들음 → 내 말로 설명 가능

<!-- 카드 형식
## YYYY-MM-DD · 제목
- 종류: 도메인 | 기술 | 막힌 질문 · 출처: AI 설명 | 내가 물음 | 리허설
- 이 레포 어디: `경로`
- 요지: 2~3줄
- 상태: 설명 들음
- vault:
-->
MD
fi

# ── 2. git 제외 — 이 맥에서만 (worktree 도 같은 파일을 가리킨다) ──────────────
EXCLUDE="$(git rev-parse --git-path info/exclude 2>/dev/null)"
if [ -n "$EXCLUDE" ]; then
  case "$EXCLUDE" in /*) ;; *) EXCLUDE="$REPO_ROOT/$EXCLUDE" ;; esac
  mkdir -p "$(dirname "$EXCLUDE")" 2>/dev/null
  grep -qxF '_learn/' "$EXCLUDE" 2>/dev/null || printf '_learn/\n' >> "$EXCLUDE" 2>/dev/null || true
fi

# ── 3. 레포 목록 — 주간 통합이 찾는 곳 ───────────────────────────────────────
LIST="${CLAUDE_LEARN_REPOS:-$HOME/.claude/learn-repos.txt}"
mkdir -p "$(dirname "$LIST")" 2>/dev/null
grep -qxF "$REPO_ROOT" "$LIST" 2>/dev/null || printf '%s\n' "$REPO_ROOT" >> "$LIST" 2>/dev/null || true

# ── 4. 기록 지시 — additionalContext 로 넣는다 ────────────────────────────────
# 머리글 주석(<!-- 카드 형식 -->) 안의 예시 줄은 세지 않는다
pending=$(awk '/<!--/{c=1} !c && /^- vault:[[:space:]]*$/{n++} /-->/{c=0} END{print n+0}' "$INBOX" 2>/dev/null || true)
pending=${pending:-0}
# ⚠️ 큰따옴표를 쓰지 않는다 — JSON 으로 직접 싼다.
msg="개인 학습 수신함 _learn/inbox.md 가 있다(커밋 안 됨, 아직 vault 로 안 옮긴 카드 ${pending}장). 이 세션에서 ① 사용자가 몰랐던 도메인·기술 개념을 설명했거나 ② 사용자가 이게 뭐냐고 물었거나 ③ 설명 리허설에서 막힌 질문이 나오면, 그 자리에서 파일 머리의 카드 형식으로 한 장 덧붙인다(요지 2~3줄, 이 레포 코드 경로, 상태). 같은 제목이 있으면 새로 쓰지 말고 상태만 올린다. 작업을 마무리할 때 이번 세션 학습 카드 n건 을 한 줄 보고한다. 사람 이름·비밀값·사내 대화 원문은 적지 않는다."
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
exit 0
