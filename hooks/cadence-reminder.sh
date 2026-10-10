#!/usr/bin/env bash
# SessionStart — cadence 4축 환기. 읽기 전용·비차단(exit 0).
#
# 🔴 왜 Stop 이 아니라 SessionStart 인가 (2026-09-28 실측으로 옮겼다):
#   Stop 은 세션이 **끝나는** 시점이라 "이제 회고 쓰세요"를 받을 사람이 이미 나간다.
#   LEARNED 실측이 증거다 — 이 훅은 3레포에 설치돼 매 세션 발화했는데
#   임계 초과가 13·21·8건 쌓인 채 엔트리 생산은 **0** 이었다.
#   세션 **시작**에 뜨면 그 세션에서 처리할 수 있다.
#   출력도 stderr → stdout JSON additionalContext 로 바꿨다(stderr 는 컨텍스트에 안 들어간다).
#
# 병합 이력: memory-reminder.sh + reflect-reminder.sh → 이 파일.
#   - memory 폴더 카운트 기능은 버렸다. 절대경로가 박혀 있었고(레포마다 오탐),
#     하네스는 에이전트 `memory:` 프론트매터를 쓰지 않아 셀 대상 자체가 없다.
#   - 남긴 두 축은 성격이 다르다:
#       fix: 누적       → "새 함정이 코드에만 있고 문서에 없다" (함정 freshness)
#       feat/refactor:  → "배운 것이 프로젝트에 갇혀 있다"      (지식 자본화)
#   - 축 3·4 추가(2026-09-27): 비대 → "쌓는 주체는 있는데 깎는 주체가 없다",
#     readiness → "채점기는 있는데 아무도 안 돌린다"(측정 공백).
#     날짜가 아니라 '쌓인 양'으로 잰다 — 커밋 0인 2주는 감사할 것이 없고,
#     3일에 커밋 40개면 2주를 기다릴 이유가 없다. 세 축 모두 같은 원리다.
set -uo pipefail
cat >/dev/null 2>&1 || true   # hook 입력(JSON) 소비

MSGS=()
HINTS=()   # 상태줄에 띄울 권고 스킬 이름
# ⚠️ 메시지에 큰따옴표를 쓰지 않는다 — 아래에서 JSON 으로 직접 싸므로 이스케이프를 피한다.
say() { MSGS+=("$1"); }

command -v git >/dev/null 2>&1 || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0
cd "$REPO_ROOT" 2>/dev/null || exit 0

HINT_DIR="${CLAUDE_SKILL_HINTS_DIR:-$HOME/.claude/skill-hints}"
HINT_KEY="$(printf '%s' "$REPO_ROOT" | tr '/' '-')"
TODAY="$(date +%F)"

FIX_THRESHOLD=3
WORK_THRESHOLD=5
CLAUDE_MAX_LINES=80    # 템플릿 45줄 · README 목표 ~40줄의 2배
RULES_MAX_LINES=400    # 템플릿 rules 4개 합계 180줄의 2배 + 여유

# ── 축 1: 함정 freshness ─────────────────────────────────────────────────────
# CLAUDE.md·rules 갱신 이후 fix: 가 쌓였다면 새 함정이 문서에 없을 가능성.
anchor=$(git log -1 --format=%H -- CLAUDE.md .claude/rules/ 2>/dev/null || true)
if [ -n "$anchor" ]; then
  fixes=$(git log --oneline "${anchor}..HEAD" --grep='^fix:' 2>/dev/null | wc -l | tr -d ' ')
  if [ "${fixes:-0}" -ge "$FIX_THRESHOLD" ]; then
    say "CLAUDE.md·rules 갱신 이후 fix: 커밋 ${fixes}건. 새 함정이 있으면 .claude/rules/non-obvious-patterns.md 에 한 줄 추가할 시점이다 (harness-doctor 로 점검)."
    HINTS+=("harness-doctor — fix ${fixes}건")
    # 결과 먼저, 하루 한 번 (2026-10-11) — 권유만으로는 17세션 환기에 doctor 호출 0이었다.
    # 조건은 CLAUDE.md·rules 를 고치기 전까지 안 풀리므로 매 세션 돌리면 반복 비용이 된다 → 레포마다 하루 첫 세션에만.
    # 날짜 기록은 레포 밖(HINT_DIR). 레포는 건드리지 않는다.
    stamp="$HINT_DIR/$HINT_KEY.doctor-date"
    if [ "$(cat "$stamp" 2>/dev/null)" != "$TODAY" ]; then
      say "오늘 이 레포 첫 세션이다 — 사용자 요청에 답하기 전에 harness-doctor 의 §2 참조 무결성 · §3 빈 축적소 두 검사만 돌려 결과를 3줄로 먼저 보여라. fix: 커밋 중 함정 후보가 있으면 non-obvious-patterns.md 한 줄 초안까지 낸다(쓰기는 승인 뒤)."
      mkdir -p "$HINT_DIR" 2>/dev/null && printf '%s\n' "$TODAY" > "$stamp" 2>/dev/null || true
    fi
  fi
fi

# ── 축 2: 지식 자본화 ────────────────────────────────────────────────────────
# _brain/wiki/ 갱신 이후 실질 작업(feat/refactor)이 쌓였다면 통합 wiki 로 흘려보낼 때.
if [ -d "$REPO_ROOT/_brain/wiki" ]; then
  banchor=$(git log -1 --format=%H -- _brain/wiki/ 2>/dev/null || true)
  if [ -n "$banchor" ]; then
    n=$(git log --oneline -E --grep='^(feat|refactor):' "${banchor}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${n:-0}" -ge "$WORK_THRESHOLD" ]; then
      say "_brain/wiki 갱신 이후 feat:/refactor: 커밋 ${n}건. 그 커밋들을 근거로 decisions/ 또는 infra/ **초안을 만들어 제시할 것** — 환기만 하면 안 쓰인다(실측: 임계 초과 13·21·8건에 엔트리 0). _brain 은 팀 위키(인수인계용)라 코드가 raw 다 — 갱신은 brain-walk, 이관은 brain-sync."
      HINTS+=("brain-walk — feat/refactor ${n}건")
    fi
  fi
fi

# ── 축 3: CLAUDE.md 비대 ─────────────────────────────────────────────────────
# `revise-claude-md`(SDD REFLECT)가 매 세션 한 줄씩 쌓는다. 쌓는 주체가 있으면
# 깎는 주체도 있어야 한다 — 깎는 쪽은 공식 `claude-md-improver`다.
c=0; r=0
[ -f CLAUDE.md ] && c=$(wc -l < CLAUDE.md | tr -d ' ')
[ -d .claude/rules ] && r=$(find .claude/rules -name '*.md' -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
if [ "${c:-0}" -gt "$CLAUDE_MAX_LINES" ] || [ "${r:-0}" -gt "$RULES_MAX_LINES" ]; then
  say "CLAUDE.md ${c}줄(목표 ~40) · .claude/rules 합계 ${r}줄. claude-md-improver 로 등급·압축 제안을 받을 시점이다."
  HINTS+=("claude-md-improver — CLAUDE.md ${c}줄")
fi

# ── 축 4: AI-Readiness — 2026-10-11 이 훅에서 뺐다 ─────────────────────────────
# 환기만 94세션 떴고 채점은 0번이었다(weekly-readiness-check.sh 가 어디에도 등록돼 있지 않았다).
# 이제 weekly-readiness-check.sh 가 SessionStart 에서 조건부로 직접 채점하고, 떨어졌을 때만 알린다.

# ── 상태줄 권고 칸 ───────────────────────────────────────────────────────────
# 대화 속 환기는 묻힌다(실측 2026-10-10: 환기 17~94세션에 해당 스킬 호출 0).
# 권고 스킬 이름을 레포 밖 파일에 남기면 상태줄 스크립트(dotfiles statusline-skill-hints.sh)가 색으로 상시 띄운다.
# 레포는 건드리지 않는다(읽기 전용 계약). 권고가 없으면 파일을 지워 칸을 비운다.
# readiness 하락 권고는 weekly-readiness-check.sh 가 따로 $HINT_KEY.readiness 에 쓴다(서로 지우지 않게 파일을 나눈다).
HINT_FILE="$HINT_DIR/$HINT_KEY"
if [ "${#HINTS[@]}" -gt 0 ]; then
  mkdir -p "$HINT_DIR" 2>/dev/null && printf '%s\n' "${HINTS[@]}" > "$HINT_FILE" 2>/dev/null || true
else
  rm -f "$HINT_FILE" 2>/dev/null || true
fi

# ── 출력: SessionStart 는 stdout JSON 의 additionalContext 를 컨텍스트로 넣는다 ─────
if [ "${#MSGS[@]}" -gt 0 ]; then
  msg=""
  for m in "${MSGS[@]}"; do
    msg="${msg}${msg:+  }⚠️ ${m}"
  done
  printf '{"systemMessage":"%s","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$msg" "$msg"
fi

exit 0
