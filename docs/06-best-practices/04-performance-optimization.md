# 04: パフォーマンス最適化

N+1 問題、キャッシング、クエリ最適化で高速なシステムを構築。

---

## 🎯 パフォーマンス最適化の原則

```
測定 → 分析 → 改善 → 検証
```

---

## 🔴 N+1 問題とは

### ❌ 悪い実装例

```typescript
// N+1 問題発生
async function getUsersWithOrders(): Promise<UserWithOrders[]> {
  const users = await userRepository.findAll();  // 1回のクエリ: SELECT * FROM users

  // ユーザーごとにループで追加クエリ実行
  for (const user of users) {
    user.orders = await orderRepository.findByUserId(user.id);  // N回のクエリ
  }

  return users;
}

// 実行されるSQL
// 1. SELECT * FROM users;              (1回)
// 2. SELECT * FROM orders WHERE user_id = 1;  (N回)
// 3. SELECT * FROM orders WHERE user_id = 2;
// ... 合計: 1 + N 回
```

### ✅ 改善例1: JOIN で取得

```typescript
// JOIN で一度に取得
async function getUsersWithOrders(): Promise<UserWithOrders[]> {
  const results = await db.query(`
    SELECT u.*, o.*
    FROM users u
    LEFT JOIN orders o ON u.id = o.user_id
  `);

  // メモリ上でマッピング
  const userMap = new Map<string, UserWithOrders>();
  for (const row of results) {
    if (!userMap.has(row.user_id)) {
      userMap.set(row.user_id, {
        ...row,
        orders: []
      });
    }
    if (row.order_id) {
      userMap.get(row.user_id)!.orders.push({
        id: row.order_id,
        ...
      });
    }
  }

  return Array.from(userMap.values());
}

// 実行されるSQL
// 1. SELECT ... FROM users LEFT JOIN orders ...  (1回だけ)
```

### ✅ 改善例2: Batch サイズ指定

```typescript
async function getUsersWithOrders(): Promise<UserWithOrders[]> {
  const users = await userRepository.findAll();

  // バッチで取得（IDs: [1, 2, 3, 4, 5]）
  const userIds = users.map(u => u.id);
  const orders = await orderRepository.findByUserIds(userIds);

  // メモリ上でマッピング
  const ordersByUserId = new Map<string, Order[]>();
  for (const order of orders) {
    if (!ordersByUserId.has(order.userId)) {
      ordersByUserId.set(order.userId, []);
    }
    ordersByUserId.get(order.userId)!.push(order);
  }

  return users.map(user => ({
    ...user,
    orders: ordersByUserId.get(user.id) || []
  }));
}

// 実行されるSQL
// 1. SELECT * FROM users;                              (1回)
// 2. SELECT * FROM orders WHERE user_id IN (1,2,3,4,5);  (1回)
```

---

## 💾 キャッシング戦略

### パターン1: デコレータパターン

```typescript
// infrastructure/repositories/CachedUserRepository.ts
export class CachedUserRepository implements IUserRepository {
  constructor(
    private baseRepository: IUserRepository,
    private cache: CacheProvider
  ) {}

  async findById(id: string): Promise<User | null> {
    // キャッシュキー
    const cacheKey = `user:${id}`;

    // キャッシュから取得
    const cached = await this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    // キャッシュミス時
    const user = await this.baseRepository.findById(id);
    if (user) {
      // キャッシュに保存（TTL: 1時間）
      await this.cache.set(cacheKey, JSON.stringify(user), 3600);
    }

    return user;
  }

  async save(user: User): Promise<void> {
    // DB保存
    await this.baseRepository.save(user);

    // キャッシュを更新
    const cacheKey = `user:${user.getId()}`;
    await this.cache.set(cacheKey, JSON.stringify(user), 3600);

    // ユーザーリスト用キャッシュを無効化
    await this.cache.delete('users:all');
  }
}
```

### パターン2: キャッシュ戦略別設定

```typescript
// config/CacheConfig.ts
const cacheStrategies = {
  // 頻繁に読み取られる、変更頻度が低い
  USER_PROFILE: {
    ttl: 3600,  // 1時間
    tags: ['user']
  },

  // リアルタイム性が重要
  ORDER_STATUS: {
    ttl: 60,    // 1分
    tags: ['order']
  },

  // 変わらない
  PRODUCT_CATALOG: {
    ttl: 86400, // 24時間
    tags: ['product']
  },

  // 一時的
  TEMP_VERIFICATION_CODE: {
    ttl: 300,   // 5分
    tags: ['verification']
  }
};

// 使用例
await this.cache.set(
  `user:${userId}`,
  userData,
  cacheStrategies.USER_PROFILE.ttl
);
```

### パターン3: キャッシュ無効化戦略

```typescript
// infrastructure/services/CacheInvalidationService.ts
export class CacheInvalidationService {
  constructor(
    private cache: CacheProvider,
    private eventPublisher: EventPublisher
  ) {
    // ユーザー更新イベントをリッスン
    this.eventPublisher.subscribe('user.updated', (event) => {
      this.invalidateUserCache(event.userId);
    });
  }

  private async invalidateUserCache(userId: string): Promise<void> {
    // 直接キャッシュ削除
    const keys = [
      `user:${userId}`,
      `user:${userId}:orders`,
      `user:${userId}:preferences`
    ];

    for (const key of keys) {
      await this.cache.delete(key);
    }

    // タグベース無効化
    await this.cache.invalidateByTag('user');
  }

  async invalidateUserListCache(): Promise<void> {
    await this.cache.delete('users:all');
    await this.cache.delete('users:active');
  }
}
```

---

## 📊 クエリ最適化

### 早期終了（LIMIT）

```typescript
// ❌ 全件取得してから配列を切る
const topUsers = (await userRepository.findAll()).slice(0, 10);

// ✅ DB側で制限
const topUsers = await userRepository.findTopN(10);

// 実装
async findTopN(limit: number): Promise<User[]> {
  return db.query('SELECT * FROM users LIMIT ?', [limit]);
}
```

### インデックス活用

```typescript
// DB スキーマレベル
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_created_at ON orders(created_at);

// 複合インデックス
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at);
```

### EXPLAIN で実行計画確認

```typescript
// EXPLAIN の実行
EXPLAIN SELECT * FROM users WHERE email = 'john@example.com';

// 結果例
// id | select_type | table | type | key | rows | Extra
// 1  | SIMPLE      | users | ref  | idx_users_email | 1 | NULL

// type = ref：インデックス使用 ✅
// type = ALL：全テーブルスキャン ❌
```

---

## 🚀 Connection Pool・接続管理

```typescript
// database/ConnectionPool.ts
import { Pool } from 'mysql2/promise';

const pool = new Pool({
  host: 'localhost',
  user: 'root',
  password: 'password',
  database: 'app_db',
  waitForConnections: true,
  connectionLimit: 10,        // プール内の最大接続数
  queueLimit: 0               // キュー内の最大待機数
});

// 接続数を監視
setInterval(() => {
  const metrics = pool._connectionPromiseQueue;
  logger.info('Connection pool status', {
    queueLength: metrics.length
  });
}, 60000);
```

---

## ⏱️ パフォーマンス計測

```typescript
// utils/PerformanceMonitor.ts
export function measureTime<T>(
  operation: () => Promise<T>
): Promise<{ result: T; duration: number }> {
  const startTime = Date.now();
  const result = await operation();
  const duration = Date.now() - startTime;
  return { result, duration };
}

// 使用例
const { result: users, duration } = await measureTime(async () => {
  return userRepository.findAll();
});

logger.info('Query performance', {
  operation: 'findAll',
  duration,
  resultCount: users.length
});
```

---

## 📋 チェックリスト

```
✅ N+1 問題がない（JOIN またはバッチ取得）
✅ 適切なインデックスが設定されている
✅ キャッシング戦略が定義されている
✅ キャッシュ無効化戦略がある
✅ Connection Pool が設定されている
✅ LIMIT で取得件数制限
✅ EXPLAIN で実行計画確認
✅ パフォーマンスメトリクスを記録
```

---

**次: [セキュリティ →](./05-security.md)**
