# 05. 依存性逆転の原則 (DIP) - Dependency Inversion Principle

> **原則**: 高レベルモジュール（ビジネスロジック）は低レベルモジュール（実装詳細）に依存してはいけない。両方とも抽象化に依存すべき。

## 🎯 コンセプト

```
❌ 従来の依存関係（上から下へ）
UserService
  ↓ 依存
MySQLDatabase
  ↓ 依存
MySQLDriver

問題：データベースを変更したら全て変更する必要

✅ 逆転した依存関係（抽象化に依存）
UserService
  ↓ 依存
Database インターフェース
  ↑ 実装
MySQLDatabase  or  PostgreSQLDatabase

メリット：どのDBを使うか選べる
```

---

## ❌ DIPに違反する例

### シナリオ：ユーザーリポジトリ

```typescript
// ❌ 悪い例：高レベルモジュールが低レベルモジュール（MySQL）に依存

import mysql = require('mysql');

// UserService（高レベル：ビジネスロジック）
export class UserService {
  private mysqlConnection: mysql.Connection;

  constructor() {
    // ❌ 直接MySQL実装に依存
    this.mysqlConnection = mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'password',
      database: 'myapp'
    });
  }

  async getUser(userId: string) {
    // ❌ SQLクエリを直接実装
    return new Promise((resolve, reject) => {
      this.mysqlConnection.query(
        'SELECT * FROM users WHERE id = ?',
        [userId],
        (error, results) => {
          if (error) reject(error);
          resolve(results[0]);
        }
      );
    });
  }

  async saveUser(user: User) {
    // ❌ SQL操作が漏れている
    return new Promise((resolve, reject) => {
      this.mysqlConnection.query(
        'INSERT INTO users (id, name, email) VALUES (?, ?, ?)',
        [user.id, user.name, user.email],
        (error, results) => {
          if (error) reject(error);
          resolve(results);
        }
      );
    });
  }
}

// UI層が直接UserServiceに依存
class UserController {
  private userService: UserService;

  constructor() {
    // ❌ 各階層が下位階層に依存
    this.userService = new UserService();
  }

  async getUser(userId: string) {
    return this.userService.getUser(userId);
  }
}
```

**問題:**
- 🔴 UserService が MySQL に強く依存している
- 🔴 PostgreSQL に変更するには？
  → UserService の全体を書き直す必要
- 🔴 テスト時に MySQL を起動が必須
- 🔴 別の DB（MongoDB など）に対応できない

---

## ✅ DIP を適用した設計

### Step 1: 抽象化（インターフェース）を定義

```typescript
// ##### ドメイン層：抽象化 #####

// 抽象リポジトリ（高レベルモジュールが依存する）
export interface UserRepository {
  getUser(userId: string): Promise<User | null>;
  saveUser(user: User): Promise<void>;
  deleteUser(userId: string): Promise<void>;
  findByEmail(email: string): Promise<User | null>;
}
```

### Step 2: 高レベルモジュール（ビジネスロジック）

```typescript
// ##### アプリケーション層：高レベルモジュール #####

export class UserService {
  // ✅ インターフェースに依存（実装詳細は知らない）
  constructor(private userRepository: UserRepository) {}

  async getUserProfile(userId: string): Promise<UserProfile> {
    const user = await this.userRepository.getUser(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }
    return {
      id: user.id,
      name: user.name,
      email: user.email
    };
  }

  async updateUser(userId: string, updates: Partial<User>): Promise<void> {
    const user = await this.userRepository.getUser(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }

    const updatedUser = { ...user, ...updates };
    await this.userRepository.saveUser(updatedUser);
  }
}

// ✅ UseCase層も同じ
export class RegisterUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private passwordService: PasswordService,
    private emailService: EmailService
  ) {}

  async execute(request: RegisterRequest): Promise<RegisterResponse> {
    // ビジネスロジック（実装詳細に依存しない）
    const existingUser = await this.userRepository.findByEmail(request.email);
    if (existingUser) {
      throw new UserAlreadyExistsError(request.email);
    }

    const user = new User(
      this.generateId(),
      request.email,
      this.passwordService.hashPassword(request.password)
    );

    await this.userRepository.saveUser(user);
    await this.emailService.sendWelcomeEmail(user.email);

    return { id: user.id, email: user.email };
  }
}
```

### Step 3: 低レベルモジュール（実装詳細）

```typescript
// ##### インフラストラクチャ層：低レベルモジュール #####

// MySQL実装
export class MySQLUserRepository implements UserRepository {
  constructor(private db: MySQLConnection) {}

  async getUser(userId: string): Promise<User | null> {
    const row = await this.db.query(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );
    return row ? this.mapRowToUser(row) : null;
  }

  async saveUser(user: User): Promise<void> {
    await this.db.query(
      'INSERT INTO users (id, email, password) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE email=?, password=?',
      [user.id, user.email, user.password, user.email, user.password]
    );
  }

  // ... 他のメソッド
}

// PostgreSQL実装
export class PostgreSQLUserRepository implements UserRepository {
  constructor(private db: PostgreSQLConnection) {}

  async getUser(userId: string): Promise<User | null> {
    const row = await this.db.query(
      'SELECT * FROM users WHERE id = $1',
      [userId]
    );
    return row ? this.mapRowToUser(row) : null;
  }

  async saveUser(user: User): Promise<void> {
    await this.db.query(
      'INSERT INTO users (id, email, password) VALUES ($1, $2, $3) ON CONFLICT (id) DO UPDATE SET email=$2, password=$3',
      [user.id, user.email, user.password]
    );
  }

  // ... 他のメソッド
}

// MongoDB実装
export class MongoDBUserRepository implements UserRepository {
  constructor(private db: MongoDBConnection) {}

  async getUser(userId: string): Promise<User | null> {
    const doc = await this.db.collection('users').findOne({ _id: userId });
    return doc ? this.mapDocToUser(doc) : null;
  }

  async saveUser(user: User): Promise<void> {
    await this.db.collection('users').updateOne(
      { _id: user.id },
      { $set: user },
      { upsert: true }
    );
  }

  // ... 他のメソッド
}
```

### Step 4: 依存性注入で組み立て

```typescript
// ##### 依存性解決（ファクトリやコンテナ） #####

export class ApplicationFactory {
  static createUserService(dbType: 'mysql' | 'postgresql' | 'mongodb'): UserService {
    const repository = this.createUserRepository(dbType);
    return new UserService(repository);
  }

  static createRegisterUseCase(
    dbType: 'mysql' | 'postgresql' | 'mongodb'
  ): RegisterUserUseCase {
    const repository = this.createUserRepository(dbType);
    const passwordService = new PasswordService();
    const emailService = new EmailService();

    return new RegisterUserUseCase(
      repository,
      passwordService,
      emailService
    );
  }

  private static createUserRepository(dbType: string): UserRepository {
    switch (dbType) {
      case 'mysql':
        return new MySQLUserRepository(new MySQLConnection());
      case 'postgresql':
        return new PostgreSQLUserRepository(new PostgreSQLConnection());
      case 'mongodb':
        return new MongoDBUserRepository(new MongoDBConnection());
      default:
        throw new Error(`Unknown database type: ${dbType}`);
    }
  }
}

// または、依存性注入コンテナを使用
import { Container } from 'inversify';

const container = new Container();

// バインディング
container.bind<UserRepository>('UserRepository')
  .to(MySQLUserRepository);  // またはPostgreSQLUserRepository

container.bind<UserService>(UserService)
  .toSelf();

// 取得
const userService = container.get<UserService>(UserService);
```

---

## 📊 依存方向の比較

### ❌ DIP違反（上から下へ）

```
  UI層
    ↓ 依存
Application層
    ↓ 依存
MySQL実装

→ 下位層を変更すると上位層全て影響
```

### ✅ DIP適用（両方が抽象化に依存）

```
  UI層          Application層          インフラ層
     ↓            ↓                        ↓
     └─────────→ 抽象化 ←─────────────┘
              (UserRepository)

→ インフラ層の実装を変更しても上位層は影響なし
```

---

## 🧪 テストでの利点

### DIP違反の場合

```typescript
// ❌ MySQLが必須
describe('UserService without DIP', () => {
  test('should get user', async () => {
    // MySQL起動が必須
    const db = new MySQLConnection();
    const service = new UserService();  // ❌ 内部でMySQL接続

    // テストが遅い、不安定
    const user = await service.getUser('user-123');
    expect(user.name).toBe('John');
  });
});
```

### DIP適用の場合

```typescript
// ✅ モックで十分
describe('UserService with DIP', () => {
  test('should get user', async () => {
    // モックリポジトリ（高速、安定）
    const mockRepository: UserRepository = {
      getUser: jest.fn().mockResolvedValue({
        id: 'user-123',
        name: 'John',
        email: 'john@example.com'
      })
    };

    const service = new UserService(mockRepository);
    const user = await service.getUserProfile('user-123');

    expect(user.name).toBe('John');
    expect(mockRepository.getUser).toHaveBeenCalledWith('user-123');
  });

  test('should throw when user not found', async () => {
    const mockRepository: UserRepository = {
      getUser: jest.fn().mockResolvedValue(null)
    };

    const service = new UserService(mockRepository);

    expect(async () => {
      await service.getUserProfile('nonexistent');
    }).rejects.toThrow(UserNotFoundError);
  });
});
```

---

## 📊 SOLID原則と DIP の関係

```
DIP（依存性逆転の原則）
  ↑
  実装に必要な他の4つの原則
  
SRP（単一責任）→ 変更理由が明確
  ↓
OCP（開放閉鎖）→ 拡張ポイントが定まる
  ↓
LSP（リスコフ置換）→ インターフェース契約
  ↓
ISP（インターフェース分離）→ 必要な機能のみ
  ↓
DIP（依存性逆転）→ 抽象化に依存する設計
```

---

## 🎯 DIP チェックリスト

```
✅ 高レベルモジュールが低レベルモジュールに直接依存していないか
✅ 両方が抽象化（インターフェース）に依存しているか
✅ 依存性注入（コンストラクタ引数など）が使われているか
✅ モックで簡単にテスト可能か
✅ 実装を変更しても上位層への影響がないか
```

---

## 📋 SOLID原則 全体まとめ

| 原則 | 意味 | メリット |
|-----|------|---------|
| **S** | 1つの責任 | テスト容易、再利用性 |
| **O** | 拡張に開放、修正に閉鎖 | 既存コード保護 |
| **L** | リスコフ置換可能 | 予測可能な動作 |
| **I** | インターフェース分離 | 不要な依存回避 |
| **D** | 依存性逆転 | テスト性、柔軟性 |

---

## 📈 実装レベルの段階

```
段階1: SRP + OCP
  → 各クラスが明確な責任を持つ

段階2: + LSP + ISP
  → インターフェースが適切に定義される

段階3: + DIP
  → 完全なテスト可能設計が実現
```

---

## ➡️ 次のステップ

さて、SOLID原則を理解したので、次は **アーキテクチャ層**を学びます。SOLID原則は設計の基本ですが、アーキテクチャ層はそれらの原則を実際のシステムに適用する大きな枠組みです。

[次: アーキテクチャ層 →](../03-architecture-layers/)
