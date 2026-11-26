#!/usr/bin/env bash
# 부품 하나를 뺀 플러그인 임시 사본을 만들고 그 폴더 경로를 출력한다(ADR-018 A3 — 과제마다 그 과제가 기대는 부품 하나를 뺀 변형).
# 사용: bash scripts/eval-variant.sh <부품 경로(레포 루트 기준, 예: agents/code-reviewer.md)>
# 레포 파일은 건드리지 않는다. 사본 = git 이 아는 파일(추적 + 무시 안 된 새 파일)에서 evals/results/ 를 뺀 것.
# 쓰는 법은 evals/README.md 「부품 변형」 — 출력 경로를 `claude plugin eval <경로>` 의 대상으로 준다.
set -euo pipefail

part="${1:?사용: bash scripts/eval-variant.sh <부품 경로(레포 루트 기준)>}"
part="${part%/}"; part="${part#./}"
case "$part" in
  ""|.|/*|..|../*|*/../*|*/..) echo "레포 안 상대 경로만 받는다: $part" >&2; exit 2 ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
[ -e "$root/$part" ] || { echo "없는 경로: $part" >&2; exit 2; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/harness-variant.XXXXXX")"
trap 'rm -rf "$tmp"' ERR   # 실패하면 사본을 남기지 않는다. 성공한 사본은 eval 뒤 사람이 지운다(evals/README.md)
dest="$tmp/claude-harness"
mkdir -p "$dest"

(
  cd "$root"
  git ls-files -co --exclude-standard -z |
    while IFS= read -r -d '' f; do
      case "$f" in evals/results/*) continue ;; esac
      [ -e "$f" ] && printf '%s\0' "$f"
    done |
    tar --null -T - -cf - | tar -xf - -C "$dest"
)

rm -rf "${dest:?}/$part"
printf '%s\n' "$dest"
