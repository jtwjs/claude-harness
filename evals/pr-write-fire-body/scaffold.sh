#!/usr/bin/env bash
# PR 과제용: main 위에 feature 브랜치 커밋 1개(원격 없음)
set -euo pipefail
git init -q -b main
git config user.name eval
git config user.email eval@example.invalid
mkdir -p src/api
cat > src/api/orders.ts <<'EOF'
export async function fetchOrders() {
  const res = await fetch('/api/orders');
  return res.json();
}
EOF
git add -A && git commit -q -m "chore: 주문 api"
git checkout -q -b feature/order-cancel
cat >> src/api/orders.ts <<'EOF'

export async function cancelOrder(id: string) {
  const res = await fetch(`/api/orders/${id}/cancel`, { method: 'POST' });
  if (!res.ok) throw new Error(`cancel failed: ${res.status}`);
  return res.json();
}
EOF
cat > src/api/orders.test.ts <<'EOF'
import { cancelOrder } from './orders';

test('취소 실패면 에러를 던진다', async () => {
  global.fetch = async () => ({ ok: false, status: 409 }) as Response;
  await expect(cancelOrder('o1')).rejects.toThrow('409');
});
EOF
git add -A && git commit -q -m "feat: 주문 취소 api"
