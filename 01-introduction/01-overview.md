# 01. クリーンアーキテクチャ概要

> **コンセプト**: アプリケーションを独立した関心事の層に分けることで、テストしやすく、保守しやすいシステムを構築する。

## 🎯 このセクションで学べること

- クリーンアーキテクチャとは何か
- 従来の設計との違い
- 基本的な層構造
- なぜ今必要なのか

---

## クリーンアーキテクチャとは？

**クリーンアーキテクチャ** (Clean Architecture) は、ロバート・C・マーチン（Uncle Bob）が著書「Clean Architecture」で提唱した設計手法です。

### 🔑 核となる考え方

```
ビジネスロジック（ドメイン）
       ↑
   (依存する)
       ↓
アプリケーションロジック（ユースケース）
       ↑
   (依存する)
       ↓
外部フレームワーク・ツール（DB、Web、API）
```

**重要**: 外側が内側に依存する（内側は外側に依存しない）

---

## 📊 典型的なアーキテクチャ図

### クリーンアーキテクチャの4層構造

```
┌────────────────────────────────────┐
│    プレゼンテーション層              │
│  (UI, Web Controller, API, CLI)    │
│────────────────────────────────────│
│      アプリケーション層              │
│   (ユースケース, サービス)          │
│────────────────────────────────────│
│        ドメイン層                    │
│   (エンティティ, ビジネスロジック)  │
│────────────────────────────────────│
│    インフラストラクチャ層            │
│  (DB, 外部API, ファイルシステム)   │
└────────────────────────────────────┘

      ↑
  依存の方向
```

---

## 🔄 具体例：ユーザー登録機能

### ❌ 従来の設計（よくある悪い例）

```typescript
// controller.ts
class UserController {
  createUser(req, res) {
    // DBに直接接続
    const db = new Database();
    
    // ビジネスロジックとUIが混在
    if (!req.body.email) {
      res.status(400).send('メール必須');
      return;
    }
    
    const user = {
      id: Math.random(),
      email: req.body.email,
      password: req.body.password,
      createdAt: new Date()
    };
    
    // DBに直接保存
    db.insert('users', user);
    
    res.json(user);
  }
}
```

**問題点:**
- ❌ UI層（Controller）にビジネスロジック混在
- ❌ DBに強く依存している
- ❌ テストが困難（DBが必要）
- ❌ 変更に弱い（DBを変更したらテスト全体が影響）

---

### ✅ クリーンアーキテクチャ設計

```
プレゼンテーション層（外側）
      ↓
   controller.ts  ← HTTPリクエストを受け取る
      ↓
アプリケーション層
      ↓
   CreateUserUseCase.ts  ← ビジネスロジック実行
      ↓
ドメイン層
      ↓
   User エンティティ  ← ビジネスルール
   UserRepository インターフェース
      ↓
インフラストラクチャ層（内側）
      ↓
   MySQLUserRepository.ts  ← 実装詳細
```

#### **ドメイン層** - ビジネスルール

```typescript
// domain/entity/User.ts
export class User {
  id: string;
  email: string;
  password: string;
  createdAt: Date;

  constructor(id: string, email: string, password: string) {
    // ビジネスルール：メールのバリデーション
    if (!this.isValidEmail(email)) {
      throw new Error('Invalid email format');
    }
    
    this.id = id;
    this.email = email;
    this.password = password;
    this.createdAt = new Date();
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }
}

// domain/repository/UserRepository.ts
export interface UserRepository {
  save(user: User): Promise<void>;
  findByEmail(email: string): Promise<User | null>;
}
```

#### **アプリケーション層** - ユースケース

```typescript
// application/usecase/CreateUserUseCase.ts
export class CreateUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private generateId: () => string
  ) {}

  async execute(request: CreateUserRequest): Promise<CreateUserResponse> {
    // 既存ユーザーをチェック
    const existingUser = await this.userRepository.findByEmail(request.email);
    if (existingUser) {
      throw new Error('Email already registered');
    }

    // ユーザーを作成（ビジネスルールはドメイン層で実行）
    const user = new User(
      this.generateId(),
      request.email,
      request.password
    );

    // リポジトリを通じて保存
    await this.userRepository.save(user);

    return {
      id: user.id,
      email: user.email
    };
  }
}
```

#### **プレゼンテーション層** - Controller

```typescript
// presentation/controller/UserController.ts
export class UserController {
  constructor(private createUserUseCase: CreateUserUseCase) {}

  async createUser(req: Request, res: Response) {
    try {
      const result = await this.createUserUseCase.execute({
        email: req.body.email,
        password: req.body.password
      });
      
      res.status(201).json(result);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }
}
```

#### **インフラストラクチャ層** - 実装

```typescript
// infrastructure/persistence/MySQLUserRepository.ts
export class MySQLUserRepository implements UserRepository {
  constructor(private db: Database) {}

  async save(user: User): Promise<void> {
    await this.db.query(
      'INSERT INTO users (id, email, password, created_at) VALUES (?, ?, ?, ?)',
      [user.id, user.email, user.password, user.createdAt]
    );
  }

  async findByEmail(email: string): Promise<User | null> {
    const row = await this.db.query(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );
    
    if (!row) return null;
    
    return new User(row.id, row.email, row.password);
  }
}
```

---

## 📈 メリットの比較表

| 項目 | 従来設計 | クリーンアーキテクチャ |
|-----|--------|------------------|
| **テスト** | DB必須、遅い | モック使用、高速 |
| **変更对応** | 影響大きい | 局所的な影響 |
| **ビジネスロジック** | 複数の層に散在 | ドメイン層に集約 |
| **再利用性** | 低い | 高い |
| **保守性** | 困難 | 容易 |
| **学習曲線** | 浅い | 深い（最初） |

---

## 🧪 テストコード例

### クリーンアーキテクチャならテストが簡単

```typescript
// __tests__/application/CreateUserUseCase.test.ts
describe('CreateUserUseCase', () => {
  let useCase: CreateUserUseCase;
  let mockRepository: MockUserRepository;

  beforeEach(() => {
    // モックリポジトリを使用（DBは不要）
    mockRepository = new MockUserRepository();
    useCase = new CreateUserUseCase(
      mockRepository,
      () => 'generated-id'
    );
  });

  test('should create user successfully', async () => {
    const result = await useCase.execute({
      email: 'user@example.com',
      password: 'password123'
    });

    expect(result.email).toBe('user@example.com');
    expect(mockRepository.savedUsers).toHaveLength(1);
  });

  test('should reject duplicate email', async () => {
    mockRepository.addUser(new User('1', 'user@example.com', 'pass'));

    expect(async () => {
      await useCase.execute({
        email: 'user@example.com',
        password: 'password123'
      });
    }).rejects.toThrow('Email already registered');
  });

  test('should reject invalid email', async () => {
    expect(async () => {
      await useCase.execute({
        email: 'invalid-email',
        password: 'password123'
      });
    }).rejects.toThrow('Invalid email format');
  });
});
```

---

## 🎓 クリーンアーキテクチャの3つの特徴

1. **独立性** - ビジネスロジックがフレームワークに依存しない
2. **テスト性** - 外部依存なしにテスト可能
3. **保守性** - 変更が局所的で、相互的な影響が少ない

---

## 📋 まとめ

| ポイント | 説明 |
|---------|------|
| **本質** | 関心事の分離と依存方向の制御 |
| **4層構造** | Presentation → Application → Domain → Infrastructure |
| **依存性** | 外→内（内は外に依存しない） |
| **目的** | テスト性、保守性、再利用性の向上 |

---

## ➡️ 次のステップ

次のセクションでは、**なぜクリーンアーキテクチャが必要か** - 実際の問題と解決方法を詳しく見てみます。

[次: 導入のメリット →](./02-why-clean-architecture.md)
