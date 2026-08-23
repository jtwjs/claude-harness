#!/usr/bin/env bash
# Stop — 두 가지 cadence 환기. 읽기 전용·비차단(exit 0).
#
# 병합 이력: memory-reminder.sh + reflect-reminder.sh → 이 파일.
#   - memory 폴더 카운트 기능은 버렸다. 절대경로가 박혀 있었고(레포마다 오탐),
#     하네스는 에이전트 `memory:` 프론트매터를 쓰지 않아 셀 대상 자체가 없다.
#   - 남긴 두 축은 성격이 다르다:
#       fix: 누적       → "새 함정이 코드에만 있고 문서에 없다" (함정 freshness)
#       feat/refactor:  → "배운 것이 프로젝트에 갇혀 있다"      (지식 자본화)
set -uo pipefail
cat >/dev/null 2>&1 || true

command -v git >/dev/null 2>&1 || exit 0
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO_ROOT" ] || exit 0
[ -f "$REPO_ROOT/.claude/harness.json" ] || exit 0
cd "$REPO_ROOT" 2>/dev/null || exit 0

FIX_THRESHOLD=3
WORK_THRESHOLD=5

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

exit 0
