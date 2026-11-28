#!/usr/bin/env bash
# SessionStart — cadence 3축 환기(축 4 readiness 는 2026-10-11 weekly-readiness-check.sh 로 옮겼다). 읽기 전용·비차단(exit 0).
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
. "$(dirname "${BASH_SOURCE[0]}")/lib/hook-log.sh" 2>/dev/null || hook_log_on_exit() { :; }
hook_log_on_exit cadence-reminder   # 끝나는 모든 경로에서 기록 한 줄 — 경로마다 HOOK_RESULT 를 정하고 exit
cat >/dev/null 2>&1 || true   # hook 입력(JSON) 소비

MSGS=()
HINTS=()   # 상태줄에 띄울 권고 스킬 이름
# ⚠️ 메시지에 큰따옴표를 쓰지 않는다 — 아래에서 JSON 으로 직접 싸므로 이스케이프를 피한다.
say() { MSGS+=("$1"); }

# 모델에게 시킬 스킬은 SKILL.md 절대 경로로 준다 — harness-doctor 는 사람만 부르게 닫혀 Skill 도구로는 안 열린다.
# 플러그인 훅 실행이면 CLAUDE_PLUGIN_ROOT 가 있고, 테스트 · 직접 실행이면 이 스크립트 폴더의 상위다. 아래 cd 전에 정한다(상대 경로로 실행돼도 풀리게).
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DOCTOR_MD="$PLUGIN_ROOT/skills/harness-doctor/SKILL.md"

command -v git >/dev/null 2>&1 || { HOOK_RESULT=nogit; exit 0; }
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { HOOK_RESULT=norepo; exit 0; }
[ -n "$REPO_ROOT" ] || { HOOK_RESULT=norepo; exit 0; }
[ -f "$REPO_ROOT/.claude/harness.json" ] || { HOOK_RESULT=nocfg; exit 0; }
cd "$REPO_ROOT" 2>/dev/null || { HOOK_RESULT=norepo HOOK_DETAIL="cd 실패"; exit 0; }

HINT_DIR="${CLAUDE_SKILL_HINTS_DIR:-$HOME/.claude/skill-hints}"
HINT_KEY="$(printf '%s' "$REPO_ROOT" | tr '/' '-')"
TODAY="$(date +%F)"

FIX_THRESHOLD=3
CLAUDE_MAX_LINES=80    # 템플릿 46줄 · README 목표 ~40줄의 2배
RULES_MAX_LINES=400    # 정할 때 템플릿 rules 4개 180줄의 2배 + 여유. 지금 템플릿 rules 6개(조건부 포함) 231줄 — 여전히 아래

# ── 축 1: 함정 freshness ─────────────────────────────────────────────────────
# CLAUDE.md·rules 갱신 이후 fix: 가 쌓였다면 새 함정이 문서에 없을 가능성.
FIRST_RUN=()   # 쌓인 양 장치가 켜졌을 때 그날 첫 세션에 먼저 돌릴 doctor 검사
FIRST_TAIL=""
anchor=$(git log -1 --format=%H -- CLAUDE.md .claude/rules/ 2>/dev/null || true)
if [ -n "$anchor" ]; then
  fixes=$(git log --oneline "${anchor}..HEAD" --grep='^fix:' 2>/dev/null | wc -l | tr -d ' ')
  if [ "${fixes:-0}" -ge "$FIX_THRESHOLD" ]; then
    say "CLAUDE.md·rules 갱신 이후 fix: 커밋 ${fixes}건. 새 함정이 있으면 .claude/rules/non-obvious-patterns.md 에 한 줄 추가할 시점이다 (${DOCTOR_MD} 를 읽고 점검)."
    HINTS+=("harness-doctor — fix ${fixes}건")
    FIRST_RUN+=("§2 참조 무결성" "§3 빈 축적소")
    FIRST_TAIL=" fix: 커밋 중 함정 후보가 있으면 non-obvious-patterns.md 한 줄 초안까지 낸다(쓰기는 승인 뒤)."
  fi
fi

# ── 축 2: 지식 자본화 — 2026-11-23 뺐다(레포에 _brain/ 을 두지 않는다, ADR-013) ──

# ── 축 3: CLAUDE.md 비대 ─────────────────────────────────────────────────────
# sdd ④ REFLECT 「흘린 것」이 매 세션 한 줄씩 쌓는다. 쌓는 주체가 있으면
# 깎는 주체도 있어야 한다 — 깎는 쪽은 harness-doctor §5(크기) · §9(문서 품질)다(ADR-021 I2).
c=0; r=0
[ -f CLAUDE.md ] && c=$(wc -l < CLAUDE.md | tr -d ' ')
[ -d .claude/rules ] && r=$(find .claude/rules -name '*.md' -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
if [ "${c:-0}" -gt "$CLAUDE_MAX_LINES" ] || [ "${r:-0}" -gt "$RULES_MAX_LINES" ]; then
  say "CLAUDE.md ${c}줄(목표 ~40) · .claude/rules 합계 ${r}줄. ${DOCTOR_MD} 의 §5 · §9 로 점검할 시점이다."
  HINTS+=("harness-doctor — CLAUDE.md ${c}줄")
  FIRST_RUN+=("§5 크기")
fi

# ── 쌓인 양 장치가 켜진 날 첫 세션: 결과 먼저, 하루 한 번 ─────────────────────────
# 권유만으로는 17세션 환기에 doctor 호출 0이었다(2026-10-11) → 답보다 먼저 돌리게 한다.
# 조건은 문서를 고치기 전까지 안 풀리므로 매 세션 돌리면 반복 비용이 된다 → 레포마다 하루 첫 세션에만.
# 축 1 · 축 3 이 같은 날짜 기록 하나를 쓴다. 날짜 기록은 레포 밖(HINT_DIR). 레포는 건드리지 않는다.
# §9 문서 품질은 훅이 고른 파일만 본다(ADR-021 Q4 B): CLAUDE.md · paths 없는 rules · 문서 커밋 뒤 바뀐 파일에 걸리는 rules.
# 합계가 SCOPE_MAX_BYTES 를 넘으면 셋째 묶음 안에서 큰 파일부터 뺀다. 앞의 둘은 늘 넣고 넘었다고만 적는다(doctor §5 상시 로드량 ≈10KB 와 같은 값).
SCOPE_MAX_BYTES=10240
if [ "${#FIRST_RUN[@]}" -gt 0 ]; then
  stamp="$HINT_DIR/$HINT_KEY.doctor-date"
  if [ "$(cat "$stamp" 2>/dev/null)" != "$TODAY" ]; then
    scope=$(python3 "$PLUGIN_ROOT/hooks/lib/doc_scope.py" . "$SCOPE_MAX_BYTES" 2>/dev/null | awk 'NF{printf "%s%s", (n++ ? " · " : ""), $0}' | tr -d '\000-\037"\\')   # 줄을 이은 뒤 제어문자 · 따옴표 · 역슬래시를 지운다(JSON 을 깨지 않게)
    run=$(printf '%s · ' "${FIRST_RUN[@]}")
    if [ -n "$scope" ]; then
      say "오늘 이 레포 첫 세션이다 — 사용자 요청에 답하기 전에 ${DOCTOR_MD} 를 읽고 ${run}§9 문서 품질 세 축을 돌려 검사마다 한 줄로 먼저 보여라. §9 는 이 파일들만 본다: ${scope}.${FIRST_TAIL}"
    else
      say "오늘 이 레포 첫 세션이다 — 사용자 요청에 답하기 전에 ${DOCTOR_MD} 를 읽고 ${run% · } 검사를 돌려 검사마다 한 줄로 먼저 보여라.${FIRST_TAIL}"
    fi
    mkdir -p "$HINT_DIR" 2>/dev/null && printf '%s\n' "$TODAY" > "$stamp" 2>/dev/null || true
  fi
fi

# ── 축 4: AI-Readiness — 2026-10-11 이 훅에서 뺐다 ─────────────────────────────
# 환기만 94세션 떴고 채점은 0번이었다(weekly-readiness-check.sh 가 어디에도 등록돼 있지 않았다).
# 이제 weekly-readiness-check.sh 가 SessionStart 에서 조건부로 직접 채점하고, 떨어졌을 때만 알린다.

# ── 버전 차이: 레포 harness.version ≠ 설치본 plugin.json (ADR-018 B-10) ──────────
# 깔린 템플릿 사본은 릴리스 뒤 낡는데, harness-doctor §0 은 사람이 돌릴 때만 잡는다 → 세션 시작에 한 줄.
# 레포 값이 비었거나 없으면(템플릿 기본값 "") · 둘 중 하나를 못 읽으면 비교하지 않고 조용히 넘어간다.
DRIFT=""
read_ver() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); v=(d.get(sys.argv[2]) or {}).get("version") if sys.argv[2] else d.get("version"); print(v if isinstance(v,str) else "")' "$1" "${2:-}" 2>/dev/null | tr -d '"\\'; }
repo_ver="$(read_ver .claude/harness.json harness)"
inst_ver="$(read_ver "$PLUGIN_ROOT/.claude-plugin/plugin.json")"
if [ -n "$repo_ver" ] && [ -n "$inst_ver" ] && [ "$repo_ver" != "$inst_ver" ]; then
  DRIFT="${repo_ver}→${inst_ver}"
  say "하네스 ${repo_ver} → ${inst_ver}, /harness-init 업그레이드 모드"
fi

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
  # 결과 이름은 하나 — 기존 권고가 있으면 warn 그대로 두고 상세에 drift 를 붙이고, 버전 알림만이면 drift
  if [ "${#HINTS[@]}" -gt 0 ]; then
    HOOK_RESULT=warn HOOK_DETAIL="${HINTS[*]}${DRIFT:+ · drift ${DRIFT}}"
  else
    HOOK_RESULT=drift HOOK_DETAIL="$DRIFT"
  fi
else
  HOOK_RESULT=clean
fi

exit 0
