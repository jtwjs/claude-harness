#!/usr/bin/env bash
# 레이어 규칙이 CLAUDE.md 에 적힌 작은 앱(파일만, git 없음)
set -euo pipefail
mkdir -p src/api src/components src/lib
cat > CLAUDE.md <<'EOF'
# order-app

## 구조
- src/components/ — 화면. 서버 호출(fetch)을 직접 하지 않는다.
- src/api/ — 서버 호출. 컴포넌트는 이 폴더의 함수만 부른다.
- src/lib/ — 공용 도구(http).
- 의존 방향: components → api → lib
EOF
cat > src/lib/http.ts <<'EOF'
export async function http<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, init);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json() as Promise<T>;
}
EOF
cat > src/api/orders.ts <<'EOF'
import { http } from '../lib/http';

export function fetchOrders() {
  return http<{ id: string; status: string }[]>('/api/orders');
}
EOF
cat > src/components/OrderList.tsx <<'EOF'
import { useEffect, useState } from 'react';
import { fetchOrders } from '../api/orders';

export function OrderList() {
  const [orders, setOrders] = useState<{ id: string; status: string }[]>([]);
  useEffect(() => { fetchOrders().then(setOrders); }, []);
  return <ul>{orders.map((o) => <li key={o.id}>{o.status}</li>)}</ul>;
}
EOF
