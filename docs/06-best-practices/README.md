# 06: ベストプラクティス - 実装品質の向上

実装が完成した後に、品質を高めるための実践的な知見をまとめます。

---

## 📚 セクション構成

| # | トピック | 内容 |
|---|---------|------|
| [01](./01-naming-conventions.md) | **命名規則** | チーム全体で一貫した命名のルール |
| [02](./02-error-handling.md) | **エラーハンドリング** | 層別のエラー処理戦略 |
| [03](./03-logging-monitoring.md) | **ロギング・監視** | 本番環境での可視化 |
| [04](./04-performance-optimization.md) | **パフォーマンス** | N+1問題、キャッシング等 |
| [05](./05-security.md) | **セキュリティ** | 入力検証、認証・認可、SQL インジェクション対策 |

---

## 🎯 各トピックの概要

クラス・メソッド・変数の命名ルール。意図が明確で、チーム全体で統一できる規則。

**詳細 → [01-命名規則へ](./01-naming-conventions.md)**

### 02: エラーハンドリング

#### ドメイン層：ビジネスエラー例外

```typescript
export class DomainError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class InvalidEmailError extends DomainError {}
export class UserAlreadyExistsError extends DomainError {}
export class InsufficientBalanceError extends DomainError {}
```

#### アプリケーション層：エラー変換

```typescript
try {
  await useCase.execute(request);
} catch (error) {
  if (error instanceof InvalidEmailError) {
    // ビジネスエラー（回復可能）
    res.status(400).json({ error: error.message });
  } else if (error instanceof DatabaseError) {
    // システムエラー
    res.status(500).json({ error: 'Internal Server Error' });
    logger.error('Database failed', error);
  }
}
```

#### プレゼンテーション層：HTTP ステータス

```typescript
const errorStatusMap = {
  'InvalidEmailError': 400,
  'UserAlreadyExistsError': 409,
  'UserNotFoundError': 404,
  'UnauthorizedError': 401,
  'ForbiddenError': 403,
  'DatabaseError': 500,
  'ExternalServiceError': 503
};
```

### 3️⃣ ロギング戦略

```typescript
// プレゼンテーション層
logger.info('User registration request', { email, ip: req.ip });

// アプリケーション層
logger.debug('Creating new user', { email, userId });

// インフラ層
logger.error('Database query failed', { query, error });

// Elasticsearch + Kibana で集約・検索
```

### 4️⃣ パフォーマンス最適化

#### N+1 問題の回避

```typescript
❌ 悪い例
const users = await userRepository.findAll();
for (const user of users) {
  // ループ内で毎回クエリ実行
  const orders = await orderRepository.findByUserId(user.id);
  user.orders = orders;  // N+1 問題
}

✅ 良い例
const users = await userRepository.findAllWithOrders();
// JOIN で一度に取得
```

#### キャッシング戦略

```typescript
// インターフェース
export interface CacheRepository extends UserRepository {
  // キャッシュレイヤー
}

// 実装（デコレータパターン）
export class CachedUserRepository implements UserRepository {
  constructor(
    private baseRepository: UserRepository,
    private cache: CacheProvider
  ) {}

  async getById(id: string): Promise<User | null> {
    const cached = await this.cache.get(`user:${id}`);
    if (cached) return cached;

    const user = await this.baseRepository.getById(id);
    if (user) {
      await this.cache.set(`user:${id}`, user, 3600);
    }
    return user;
  }
}
```

### 5️⃣ セキュリティ注意事項

#### 入力検証（複数層）

```typescript
// プレゼンテーション層：型チェック
const validateEmail = (email: string): boolean => {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
};

// ドメイン層：ビジネスルール
class Email {
  constructor(value: string) {
    if (!this.isValidEmail(value)) {
      throw new InvalidEmailError(value);
    }
  }
}

// インフラ層：DB スキーマ
// email VARCHAR(255) NOT NULL UNIQUE
// password VARCHAR(255) NOT NULL CHECK (CHAR_LENGTH(password) >= 8)
```

#### Authentication/Authorization

```typescript
// MiddleWare
export const authenticate = (req: Request, res: Response, next: NextFunction) => {
  const token = extractToken(req);
  try {
    const user = jwt.verify(token, secret);
    req.user = user;
    next();
  } catch {
    res.status(401).json({ error: 'Unauthorized' });
  }
};

// Authorization チェック
export const authorize = (roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!roles.includes(req.user.role)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    next();
  };
};
```

#### SQL インジェクション対策

```typescript
❌ 悪い例：文字列連結
const query = `SELECT * FROM users WHERE email = '${email}'`;

✅ 良い例：パラメータライズド
const query = 'SELECT * FROM users WHERE email = ?';
await db.query(query, [email]);
```

---

## 📋 チェックリスト

```
✅ 命名規則が統一されている
✅ エラーハンドリングが層別に適切
✅ ロギングで重要情報が記録されている
✅ N+1 問題がない
✅ SQL インジェクション対策がされている
✅ 認証・認可が実装されている
✅ パスワードが安全に保存されている（ハッシュ化）
✅ 本番環境での監視体制がある
```

---

## 🔗 関連セクション

- [実装ガイド](../05-implementation-guide/) - 基本実装
- [よくある間違い](../07-common-pitfalls/) - アンチパターン
- [ケーススタディ](../08-case-studies/) - 実例

---

**次: [よくある間違い →](../07-common-pitfalls/)**
