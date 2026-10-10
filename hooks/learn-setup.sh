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

# 🔴 수신함은 **본 레포(메인 워크트리)** 에 둔다 — 워크트리마다 두면 `git worktree remove` 가 무시 파일인 _learn/ 을
#    경고 없이 함께 지운다(2026-10-11 리뷰 재현). 레포 목록도 본 레포 경로로 남겨 주간 통합이 사라진 경로를 읽지 않게 한다.
COMMON="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
case "$COMMON" in */.git) MAIN_ROOT="${COMMON%/.git}" ;; *) MAIN_ROOT="$REPO_ROOT" ;; esac
[ -d "$MAIN_ROOT" ] || MAIN_ROOT="$REPO_ROOT"
INBOX="$MAIN_ROOT/_learn/inbox.md"

# ── 1. 폴더·수신함 ───────────────────────────────────────────────────────────
if [ ! -f "$INBOX" ]; then
  mkdir -p "$MAIN_ROOT/_learn" 2>/dev/null || exit 0
  cat > "$INBOX" <<'MD'
# 학습 수신함 — 이 레포를 하며 내가 이해해야 할 것

> 개인용이다. git 에서 빠져 있다(.git/info/exclude). 여기엔 회사를 옮겨도 쓸모 있는 기술·직무 학습만 — 이 프로젝트의 도메인·규칙·제품 결정은 팀 위키 _brain/ 으로, 기술 결정은 ADR 로 간다.
> 작업 중인 모델이 아래 형식으로 한 장씩 덧붙인다. 통합 wiki 의 주간 /gauge week 가 모아 vault 로 옮기고 vault: 칸을 채운다.
> 상태: 모름 → 설명 들음 → 내 말로 설명 가능

<!-- 카드 형식
## YYYY-MM-DD · 제목
- 종류: 기술 | 직무 | 막힌 질문 · 출처: AI 설명 | 내가 물음 | 리허설
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
grep -qxF "$MAIN_ROOT" "$LIST" 2>/dev/null || printf '%s\n' "$MAIN_ROOT" >> "$LIST" 2>/dev/null || true

# ── 4. 기록 지시 — additionalContext 로 넣는다 ────────────────────────────────
# JSON 안에 넣을 경로 — 큰따옴표·역슬래시를 이스케이프한다(경로에 들어 있으면 출력이 깨져 지시가 조용히 빠진다)
INBOX_J="$(printf '%s' "$INBOX" | sed 's/\\/\\\\/g; s/"/\\"/g')"
# 머리글 주석(<!-- 카드 형식 -->) 안의 예시 줄은 세지 않는다
pending=$(awk '/<!--/{c=1} !c && /^- vault:[[:space:]]*$/{n++} /-->/{c=0} END{print n+0}' "$INBOX" 2>/dev/null || true)
pending=${pending:-0}
# ⚠️ 큰따옴표를 쓰지 않는다 — JSON 으로 직접 싼다.
msg="이 세션에서 배운 것은 그 자리에서 나눠 적는다. 기준은 회사를 옮겨도 쓸모 있나. ① 예(기술·개발자 직무 학습) → 개인 학습 수신함 ${INBOX_J}(본 레포 기준 절대 경로 — 워크트리에서도 이 파일에, 커밋 안 됨, 아직 vault 로 안 옮긴 카드 ${pending}장)에 파일 머리의 카드 형식으로 한 장(요지 2~3줄, 이 레포 코드 경로, 상태). 같은 제목이 있으면 상태만 올린다. ② 아니오 → 결정의 종류로 한 곳에만: 제품·도메인 결정(정책·고객 사정·지표·범위)과 이 제품의 규칙·용어는 레포 _brain/wiki/ 의 decisions/<주제>.md·domain/·glossary/ 에 같은 PR 로(_brain 이 없으면 그 기능 PRD 의 결정 절에), 기술 결정(구조·데이터·라이브러리)은 docs/<feature-date>/ADR.md 에만. 둘 다 걸치면 쪼갠다(기술 개념은 _learn, 이 프로젝트의 쓰임과 이유는 _brain). 대상은 사용자가 몰랐던 것을 설명했을 때, 사용자가 이게 뭐냐고 물었을 때, 설명 리허설에서 막힌 질문. 작업을 마무리할 때 이번 세션 학습 카드 n건 을 한 줄 보고한다. 사람 이름·비밀값·사내 대화 원문은 적지 않는다."
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg"
exit 0
