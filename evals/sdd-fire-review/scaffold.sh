#!/usr/bin/env bash
# 리뷰 과제용 작은 레포: main 위에 설계 문서, feature 브랜치에 경계 위반 1건(컴포넌트가 fetch 를 직접 부름)
set -euo pipefail
git init -q -b main
git config user.name eval
git config user.email eval@example.invalid
mkdir -p src/api src/components docs/order-filter-2026-11-25 phases/order-filter
cat > CLAUDE.md <<'EOF'
# order-app

## 구조
- src/components/ — 화면. 서버 호출(fetch)을 직접 하지 않는다.
- src/api/ — 서버 호출. 컴포넌트는 이 폴더의 함수만 부른다.
- 의존 방향: components → api
EOF
cat > docs/order-filter-2026-11-25/ARCHITECTURE.md <<'EOF'
# ARCHITECTURE — 주문 목록 배송 상태 필터

- 필터 값은 src/components/OrderFilter.tsx 가 들고, 목록 조회는 src/api/orders.ts 의 fetchOrders(status) 로만 한다.
- 컴포넌트는 fetch 를 직접 부르지 않는다(루트 CLAUDE.md 의존 방향).
EOF
cat > docs/order-filter-2026-11-25/ADR.md <<'EOF'
# ADR
## ADR-001 필터 값은 쿼리 문자열 status 로 서버에 넘긴다
- 상태: 수락
EOF
cat > phases/order-filter/index.json <<'EOF'
{"project": "order-app", "phase": "order-filter", "docs": "docs/order-filter-2026-11-25", "steps": [{"step": 0, "name": "filter-ui", "status": "completed"}]}
EOF
cat > src/api/orders.ts <<'EOF'
export type OrderStatus = 'shipping' | 'done' | 'canceled';

export async function fetchOrders(status?: OrderStatus) {
  const q = status ? `?status=${status}` : '';
  const res = await fetch(`/api/orders${q}`);
  return res.json();
}
EOF
git add -A && git commit -q -m "chore: 설계 문서와 주문 api"
git checkout -q -b feature/order-filter
cat > src/components/OrderFilter.tsx <<'EOF'
import { useEffect, useState } from 'react';

export function OrderFilter() {
  const [status, setStatus] = useState('shipping');
  const [orders, setOrders] = useState([]);

  useEffect(() => {
    fetch(`/api/orders?status=${status}`)
      .then((r) => r.json())
      .then(setOrders);
  }, [status]);

  return (
    <select value={status} onChange={(e) => setStatus(e.target.value)}>
      <option value="shipping">배송중</option>
      <option value="done">완료</option>
      <option value="canceled">취소</option>
    </select>
  );
}
EOF
git add -A && git commit -q -m "feat: 배송 상태 필터"
