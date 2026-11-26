#!/usr/bin/env bash
# 커밋 과제용: 서로 관련 없는 변경 2개(README 오타 · 새 날짜 함수)가 커밋 안 된 채로 있다
set -euo pipefail
git init -q -b main
git config user.name eval
git config user.email eval@example.invalid
mkdir -p src
printf '# order-app\n\nAPI 응답을 recieve 하면 목록을 그린다.\n' > README.md
printf 'export const VERSION = "1.0.0";\n' > src/version.ts
git add -A && git commit -q -m "chore: 첫 커밋"
printf '# order-app\n\nAPI 응답을 receive 하면 목록을 그린다.\n' > README.md
cat > src/date.ts <<'EOF'
export function formatOrderDate(iso: string): string {
  const d = new Date(iso);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
EOF
