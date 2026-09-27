#!/usr/bin/env bash
# Stop — 두 가지 cadence 환기. 읽기 전용·비차단(exit 0).
#
# 병합 이력: memory-reminder.sh + reflect-reminder.sh → 이 파일.
#   - memory 폴더 카운트 기능은 버렸다. 절대경로가 박혀 있었고(레포마다 오탐),
#     하네스는 에이전트 `memory:` 프론트매터를 쓰지 않아 셀 대상 자체가 없다.
#   - 남긴 두 축은 성격이 다르다:
#       fix: 누적       → "새 함정이 코드에만 있고 문서에 없다" (함정 freshness)
#       feat/refactor:  → "배운 것이 프로젝트에 갇혀 있다"      (지식 자본화)
#   - 축 3·4 추가(2026-09-27): 비대 → "쌓는 주체는 있는데 깎는 주체가 없다",
#     readiness → "채점기는 있는데 아무도 안 돌린다"(ax-framework §6 측정).
#     날짜가 아니라 '쌓인 양'으로 잰다 — 커밋 0인 2주는 감사할 것이 없고,
#     3일에 커밋 40개면 2주를 기다릴 이유가 없다. 세 축 모두 같은 원리다.
set -uo pipefail
cat >/dev/null 2>&1 || true

command -v git >/dev/null 2>&1 || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0
cd "$REPO_ROOT" 2>/dev/null || exit 0

FIX_THRESHOLD=3
WORK_THRESHOLD=5
CLAUDE_MAX_LINES=80    # 템플릿 45줄 · README 목표 ~40줄의 2배
RULES_MAX_LINES=400    # 템플릿 rules 4개 합계 180줄의 2배 + 여유
READINESS_GAP_COMMITS=20

# ── 축 1: 함정 freshness ─────────────────────────────────────────────────────
# CLAUDE.md·rules 갱신 이후 fix: 가 쌓였다면 새 함정이 문서에 없을 가능성.
anchor=$(git log -1 --format=%H -- CLAUDE.md .claude/rules/ 2>/dev/null || true)
if [ -n "$anchor" ]; then
  fixes=$(git log --oneline "${anchor}..HEAD" --grep='^fix:' 2>/dev/null | wc -l | tr -d ' ')
  if [ "${fixes:-0}" -ge "$FIX_THRESHOLD" ]; then
    printf 'ℹ️  CLAUDE.md·rules 갱신 이후 fix: 커밋 %s건. 새 함정이 있으면 .claude/rules/non-obvious-patterns.md 에 한 줄 추가하세요. (harness-doctor 로 점검 가능)\n' "$fixes" >&2
  fi
fi

# ── 축 2: 지식 자본화 ────────────────────────────────────────────────────────
# _brain/wiki/ 갱신 이후 실질 작업(feat/refactor)이 쌓였다면 통합 wiki 로 흘려보낼 때.
if [ -d "$REPO_ROOT/_brain/wiki" ]; then
  banchor=$(git log -1 --format=%H -- _brain/wiki/ 2>/dev/null || true)
  if [ -n "$banchor" ]; then
    n=$(git log --oneline -E --grep='^(feat|refactor):' "${banchor}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
    if [ "${n:-0}" -ge "$WORK_THRESHOLD" ]; then
      printf 'ℹ️  _brain/wiki 갱신 이후 feat:/refactor: 커밋 %s건. brain-intake 로 정리하고 brain-sync 로 통합 wiki 에 이관할 시점입니다.\n' "$n" >&2
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
  printf 'ℹ️  CLAUDE.md %s줄(목표 ~40) · .claude/rules 합계 %s줄. "audit my CLAUDE.md"(claude-md-improver)로 등급·압축 제안을 받을 시점입니다.\n' "$c" "$r" >&2
fi

# ── 축 4: AI-Readiness 채점 공백 ─────────────────────────────────────────────
# 채점기(weekly-readiness-check.sh → score.py)는 있는데 아무도 안 돌린다.
# 🔴 여기서 채점을 실행하지 않는다 — Stop 훅은 읽기 전용이고(hooks/test.sh 케이스 4),
#    python3 + HTML 생성을 매 턴에 얹지 않는다. 환기만 하고 실행은 사람·모델이 한다.
last_report=""
[ -d .claude/reports ] && last_report=$(ls -1 .claude/reports 2>/dev/null \
  | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort | tail -1)
if [ -n "$last_report" ]; then
  gap=$(git rev-list --count --since="$last_report" HEAD 2>/dev/null || echo 0)
  since_label="마지막 채점($last_report)"
else
  gap=$(git rev-list --count HEAD 2>/dev/null || echo 0)
  since_label="채점 이력 없음 — 레포 시작"
fi
if [ "${gap:-0}" -ge "$READINESS_GAP_COMMITS" ]; then
  printf 'ℹ️  %s 이후 커밋 %s건. ai-readiness-cartography 로 점수를 다시 재세요 — 떨어진 폭이 곧 "뭔가 들어왔는데 문서가 안 따라왔다"입니다.\n' "$since_label" "$gap" >&2
fi

exit 0
