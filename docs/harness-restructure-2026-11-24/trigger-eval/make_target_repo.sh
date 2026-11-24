#!/usr/bin/env bash
# 발동 정확도를 잴 합성 대상 레포를 만든다(Before · After 같은 레포).
# 사용: bash make_target_repo.sh <만들 폴더> <claude-harness 레포 루트>
set -euo pipefail
R="$1"; H="$2"
rm -rf "$R"; mkdir -p "$R/src/features/orders" "$R/src/features/auth" "$R/.claude" "$R/docs"
cd "$R"
cat > package.json <<'EOF'
{ "name": "shop-web", "private": true, "type": "module",
  "scripts": { "dev": "vite", "build": "tsc -b && vite build", "lint": "eslint .", "typecheck": "tsc --noEmit", "test": "vitest run" },
  "dependencies": { "react": "^19.0.0", "react-dom": "^19.0.0", "@tanstack/react-query": "^5.59.0", "zustand": "^5.0.0" },
  "devDependencies": { "typescript": "^5.6.0", "vite": "^6.0.0", "vitest": "^2.1.0", "eslint": "^9.0.0" } }
EOF
cat > src/features/orders/OrderList.tsx <<'EOF'
import { useQuery } from "@tanstack/react-query";
import { fetchOrders } from "./api";

export function OrderList() {
  const { data } = useQuery({ queryKey: ["orders"], queryFn: fetchOrders });
  return <ul>{data?.map((o) => <li key={o.id}>{o.title} · {o.status}</li>)}</ul>;
}
EOF
cat > src/features/orders/api.ts <<'EOF'
export type Order = { id: string; title: string; status: "shipping" | "done" | "canceled" };
export async function fetchOrders(): Promise<Order[]> {
  const res = await fetch("/api/orders");
  return res.json();
}
EOF
cat > src/features/auth/session.ts <<'EOF'
export async function refreshToken(): Promise<string | null> {
  const res = await fetch("/api/auth/refresh", { method: "POST" });
  if (!res.ok) return null;
  return (await res.json()).accessToken;
}
EOF
python3 - "$H" <<'PY'
import sys
H = sys.argv[1]
t = open(f"{H}/templates/CLAUDE.md.tmpl").read()
rep = {"{{PROJECT_NAME}}": "shop-web", "{{ONE_LINE}}": "쇼핑몰 주문 · 회원 화면 (React 19 + Vite + TanStack Query)",
       "{{CRITICAL_RULES}}": "- **API 응답 타입은 `src/features/*/api.ts` 한 곳에서만 정의한다.**",
       "{{GENERATED_PATHS}}": "없음", "{{VERIFY_COMMANDS}}": "- `npm run lint` · `npm run typecheck` · `npm test`",
       "{{ENTRY_POINTS}}": "- `src/features/<도메인>/` — 화면 · api · 상태", "{{DEPENDENCY_DIRECTION}}": "- features 끼리 직접 import 하지 않는다"}
for k, v in rep.items():
    t = t.replace(k, v)
open("CLAUDE.md", "w").write(t)
PY
cp "$H/templates/.claude/README.md" .claude/README.md
cat > .claude/harness.json <<'EOF'
{ "harness": { "version": "0.40.0" }, "stacks": { "packs": [{ "pack": "react-vite", "root": "." }], "kitRef": "" },
  "git": { "baseBranch": "main", "branchPattern": "feature/{task}", "commitScope": false }, "packageManager": "npm",
  "verify": { "format": "", "lint": "npm run lint", "typecheck": "npm run typecheck", "test": "npm test", "build": "npm run build" },
  "release": { "tool": "none" } }
EOF
git init -q -b main; git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -qm "chore: init"
sed -i '' 's/if (!res.ok) return null;/if (!res.ok) { console.warn("refresh failed", res.status); return null; }/' src/features/auth/session.ts
