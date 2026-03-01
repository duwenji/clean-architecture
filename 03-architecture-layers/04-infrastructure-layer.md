# 04. インフラストラクチャ層 (Infrastructure Layer)

> **責務**: 外部システムとの連携。データベース、メール、外部API、ファイルシステムなど、ビジネスロジックの外部にある実装詳細をカプセル化する。

## 🎯 層の位置付け

```
┌──────────────────────────┐
│  プレゼンテーション層     │
├──────────────────────────┤
│  アプリケーション層       │
├──────────────────────────┤
│  ドメイン層              │
├──────────────────────────┤
│  インフラストラクチャ層   │  ← ここ
│ (DB, 外部API)           │
└──────────────────────────┘
```

---

## 📋 インフラストラクチャ層の責務

```
✅ インフラストラクチャ層が担当：
  - リポジトリ実装（DB操作）
  - 外部API連携
  - ファイルシステム操作
  - キャッシュ管理
  - ロギング実装
  - メール送信実装

❌ インフラストラクチャ層がしてはいけない：
  - ビジネスロジック
  - ユースケース管理
  - 直接的なプレゼンテーション
```

---

## 🏗️ 典型的なインフラストラクチャ層の構成

```
infrastructure/
├── persistence/
│   ├── repository/
│   │   ├── MySQLUserRepository.ts
│   │   ├── MongoDBOrderRepository.ts
│   │   └── ...
│   ├── database/
│   │   ├── MySQLConnection.ts
│   │   ├── MongoDBConnection.ts
│   │   └── ...
│   └── migration/
│       ├── 001_create_users_table.ts
│       └── ...
├── external/
│   ├── EmailService.ts
│   ├── PaymentProvider.ts
│   ├── SMSService.ts
│   └── ...
├── cache/
│   ├── RedisCache.ts
│   └── MemoryCache.ts
└── storage/
    ├── FileStorage.ts
    └── S3Storage.ts
```

---

## 💻 実装例1：リポジトリ実装

### MySQL リポジトリ

```typescript
// infrastructure/persistence/repository/MySQLUserRepository.ts

export class MySQLUserRepository implements UserRepository {
  constructor(private db: MySQLDatabase) {}

  async save(user: User): Promise<void> {
    const query = `
      INSERT INTO users (id, email, password, name, status, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        status = VALUES(status),
        updated_at = NOW()
    `;

    await this.db.query(query, [
      user.getId(),
      user.getEmail().getValue(),
      user.getPassword().getHashed(),
      user.getName(),
      user.getStatus(),
      new Date()
    ]);
  }

  async getUser(userId: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE id = ?';
    const row = await this.db.query(query, [userId]);

    if (!row) return null;

    return this.mapRowToUserEntity(row);
  }

  async findByEmail(email: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE email = ?';
    const row = await this.db.query(query, [email]);

    if (!row) return null;

    return this.mapRowToUserEntity(row);
  }

  async delete(userId: string): Promise<void> {
    const query = 'DELETE FROM users WHERE id = ?';
    await this.db.query(query, [userId]);
  }

  async search(criteria: {
    status?: UserStatus;
    limit?: number;
    offset?: number;
  }): Promise<User[]> {
    let query = 'SELECT * FROM users WHERE 1=1';
    const params: any[] = [];

    if (criteria.status) {
      query += ' AND status = ?';
      params.push(criteria.status);
    }

    query += ' LIMIT ? OFFSET ?';
    params.push(criteria.limit || 10);
    params.push(criteria.offset || 0);

    const rows = await this.db.query(query, params);
    return rows.map(row => this.mapRowToUserEntity(row));
  }

  // ドメインモデルへのマッピング
  private mapRowToUserEntity(row: any): User {
    return new User(
      row.id,
      new Email(row.email),
      new HashedPassword(row.password),
      row.name
    );
  }
}
```

### MongoDB リポジトリ

```typescript
// infrastructure/persistence/repository/MongoDBUserRepository.ts

export class MongoDBUserRepository implements UserRepository {
  private collection: MongoCollection;

  constructor(db: MongoDatabase) {
    this.collection = db.collection('users');
  }

  async save(user: User): Promise<void> {
    const doc = {
      _id: user.getId(),
      email: user.getEmail().getValue(),
      password: user.getPassword().getHashed(),
      name: user.getName(),
      status: user.getStatus(),
      createdAt: new Date(),
      updatedAt: new Date()
    };

    await this.collection.updateOne(
      { _id: user.getId() },
      { $set: doc },
      { upsert: true }
    );
  }

  async getUser(userId: string): Promise<User | null> {
    const doc = await this.collection.findOne({ _id: userId });

    if (!doc) return null;

    return this.mapDocToUserEntity(doc);
  }

  async findByEmail(email: string): Promise<User | null> {
    const doc = await this.collection.findOne({
      email: email.toLowerCase()
    });

    if (!doc) return null;

    return this.mapDocToUserEntity(doc);
  }

  async delete(userId: string): Promise<void> {
    await this.collection.deleteOne({ _id: userId });
  }

  async search(criteria: any): Promise<User[]> {
    const filter: any = {};

    if (criteria.status) {
      filter.status = criteria.status;
    }

    const docs = await this.collection
      .find(filter)
      .skip(criteria.offset || 0)
      .limit(criteria.limit || 10)
      .toArray();

    return docs.map(doc => this.mapDocToUserEntity(doc));
  }

  private mapDocToUserEntity(doc: any): User {
    return new User(
      doc._id,
      new Email(doc.email),
      new HashedPassword(doc.password),
      doc.name
    );
  }
}
```

---

## 💻 実装例2：外部サービス実装

### メール送信サービス

```typescript
// infrastructure/external/EmailService.ts

export class EmailService implements NotificationService {
  constructor(private emailProvider: EmailProvider) {}

  async sendWelcomeEmail(email: string): Promise<void> {
    const result = await this.emailProvider.send({
      to: email,
      subject: 'Welcome to Our Service',
      templateId: 'welcome-email',
      variables: {
        name: email.split('@')[0]
      }
    });

    if (!result.success) {
      throw new EmailSendError(result.errorMessage);
    }

    // ロギング
    console.log(`Welcome email sent to ${email}`);
  }

  async sendOrderConfirmation(
    email: string,
    orderId: string,
    total: number
  ): Promise<void> {
    await this.emailProvider.send({
      to: email,
      subject: 'Order Confirmation',
      templateId: 'order-confirmation',
      variables: {
        orderId,
        total
      }
    });
  }

  async sendPasswordReset(email: string, resetToken: string): Promise<void> {
    await this.emailProvider.send({
      to: email,
      subject: 'Password Reset Request',
      templateId: 'password-reset',
      variables: {
        resetUrl: `https://example.com/reset/${resetToken}`
      }
    });
  }
}
```

### 支払いサービス

```typescript
// infrastructure/external/StripePaymentService.ts

export class StripePaymentService implements PaymentService {
  constructor(private stripeClient: Stripe) {}

  async charge(
    paymentMethodId: string,
    amount: Money
  ): Promise<PaymentResult> {
    try {
      const result = await this.stripeClient.paymentIntents.create({
        amount: amount.getAmount() * 100,  // セント単位
        currency: amount.getCurrency().toLowerCase(),
        payment_method: paymentMethodId,
        confirm: true
      });

      if (result.status === 'succeeded') {
        return {
          success: true,
          transactionId: result.id,
          amount: amount.getAmount(),
          timestamp: new Date()
        };
      } else {
        return {
          success: false,
          reason: result.last_payment_error?.message || 'Unknown error',
          timestamp: new Date()
        };
      }
    } catch (error) {
      throw new PaymentProviderError(
        'Stripe API error',
        error
      );
    }
  }

  async refund(transactionId: string, amount: Money): Promise<RefundResult> {
    try {
      const result = await this.stripeClient.refunds.create({
        payment_intent: transactionId,
        amount: amount.getAmount() * 100
      });

      return {
        success: result.status === 'succeeded',
        refundId: result.id,
        amount: amount.getAmount(),
        timestamp: new Date()
      };
    } catch (error) {
      throw new PaymentProviderError(
        'Stripe refund error',
        error
      );
    }
  }
}
```

---

## 💻 実装例3：キャッシュ層

```typescript
// infrastructure/cache/CachedUserRepository.ts

export class CachedUserRepository implements UserRepository {
  constructor(
    private baseRepository: UserRepository,
    private cache: CacheProvider
  ) {}

  async getUser(userId: string): Promise<User | null> {
    // キャッシュから取得を試す
    const cacheKey = `user:${userId}`;
    const cached = await this.cache.get(cacheKey);

    if (cached) {
      return this.deserializeUser(cached);
    }

    // キャッシュミス：DB から取得
    const user = await this.baseRepository.getUser(userId);

    if (user) {
      // キャッシュに保存（1時間有効）
      await this.cache.set(
        cacheKey,
        this.serializeUser(user),
        3600
      );
    }

    return user;
  }

  async save(user: User): Promise<void> {
    // DB に保存
    await this.baseRepository.save(user);

    // キャッシュを無効化
    const cacheKey = `user:${user.getId()}`;
    await this.cache.invalidate(cacheKey);
  }

  // 他のメソッド...

  private serializeUser(user: User): string {
    return JSON.stringify({
      id: user.getId(),
      email: user.getEmail().getValue(),
      name: user.getName()
    });
  }

  private deserializeUser(data: string): User {
    const obj = JSON.parse(data);
    return new User(
      obj.id,
      new Email(obj.email),
      // ... パスワードはキャッシュしないため不完全
    );
  }
}
```

---

## 📊 DB抽象化のメリット

```
インターフェース：UserRepository
        ↑
    実装1: MySQLUserRepository
    実装2: MongoDBUserRepository
    実装3: PostgreSQLUserRepository
    実装4: CachedUserRepository

メリット：
- DB を切り替え可能
- テスト時にモック可能
- キャッシュレイアーを透過的に追加可能
```

---

## 🧪 テスト

```typescript
describe('MySQLUserRepository', () => {
  let repository: MySQLUserRepository;
  let db: MySQLDatabase;

  beforeAll(async () => {
    db = await startTestDatabase();
    await db.runMigrations();
    repository = new MySQLUserRepository(db);
  });

  afterEach(async () => {
    await db.truncateTable('users');
  });

  test('should save and retrieve user', async () => {
    const user = new User(
      'user-123',
      new Email('test@example.com'),
      new HashedPassword('hashed'),
      'John Doe'
    );

    await repository.save(user);
    const retrieved = await repository.getUser('user-123');

    expect(retrieved).not.toBeNull();
    expect(retrieved?.getEmail().getValue()).toBe('test@example.com');
  });

  test('should find user by email', async () => {
    const user = new User(
      'user-123',
      new Email('test@example.com'),
      new HashedPassword('hashed'),
      'John Doe'
    );

    await repository.save(user);
    const found = await repository.findByEmail('test@example.com');

    expect(found?.getId()).toBe('user-123');
  });
});
```

---

## 📋 インフラストラクチャ層のチェックリスト

```
✅ インターフェースで抽象化されている
✅ ドメインロジックがない
✅ DB方言に特化したコード
✅ エラーハンドリングが適切
✅ ロギングがある
✅ トランザクション管理がある
```

---

## ➡️ 次のステップ

最後に、**層間の依存関係**を定義するルールを学びます。これがクリーンアーキテクチャの最も重要なルールです。

[次: 層の依存関係 →](./05-layer-dependencies.md)
