# 02: 密結合（Tight Coupling）

層間の依存関係を逆転させて疎結合を実現する。

---

## 🎯 問題

下位層が上位層を参照する、または層間の依存が双方向になると：
- テスト困難（実装に依存）
- 変更範囲が不確定（連鎖的に影響）
- 再利用不可（依存が特定実装に限定）

---

## 📍 具体例：密結合アンチパターン

```typescript
// 🚫 ドメイン層がインフラ層に依存

// domain/User.ts（ドメイン層）
import { Database } from '../infrastructure/database';  // ❌ 上位層への参照

export class User {
  id: string;
  email: string;

  async save() {
    // DB を直接操作
    await Database.instance.query(
      'INSERT INTO users (id, email) VALUES (?, ?)',
      [this.id, this.email]
    );
  }
}

// application/SaveUserUseCase.ts（アプリケーション層）
import { User } from '../domain/User';
import { NotificationService } from '../infrastructure/NotificationService';

export class SaveUserUseCase {
  async execute(email: string) {
    const user = new User(email);
    // インフラ層の具体的な実装に直接依存
    await user.save();

    // Service もベタ参照
    await NotificationService.send(email);
  }
}

// 🔴 テストが困難
// Domain をテストするのに、Database が必須
import { User } from '../domain/User';

describe('User', () => {
  it('should save user', async () => {
    const user = new User('john@example.com');
    await user.save();  // ← DB が必須
    // モック化不可
  });
});
```

**問題の内容：**
- ドメイン = data + behavior
- infrastructure = 実装詳細

この2つが混在すると、テストや再利用が困難になる

---

## ✅ 解決策：依存関係の逆転

### 原則：依存は下位層（抽象度↑）へ

```
Presentation → Application → Domain ↔ Infrastructure
                                ↑
                             依存の向き
```

**各層で参照可能なもの：**
- Presentation: Application + Infrastructure
- Application: Domain + Infrastructure
- Domain: Domain のみ（他層は参照禁止）
- Infrastructure: 外部ライブラリ

### 実装例：インターフェース経由

```typescript
// domain/ports/UserRepository.ts（インターフェース）
export interface UserRepository {
  save(user: User): Promise<void>;
  getById(id: string): Promise<User | null>;
}

// domain/User.ts（ドメイン層）
export class User {
  constructor(
    public id: string,
    public email: Email  // 値オブジェクト
  ) {}

  // ドメインロジックのみ
  isActive(): boolean {
    return this.email != null;
  }

  sendWelcomeEmail(): void {
    // ❌このロジックはドメインに含めない
    // インフラの詳細になるため
  }
}

// application/SaveUserUseCase.ts（アプリケーション層）
export class SaveUserUseCase {
  constructor(
    private userRepository: UserRepository,  // ✅ インターフェース依存
    private notificationService: NotificationService
  ) {}

  async execute(email: string): Promise<void> {
    // ドメインロジック
    const emailObj = new Email(email);
    const user = new User(uuid(), emailObj);

    // リポジトリを通じて永続化
    await this.userRepository.save(user);

    // 副作用を処理
    await this.notificationService.notifyUserCreated(user);
  }
}

// infrastructure/repositories/MySQLUserRepository.ts
export class MySQLUserRepository implements UserRepository {
  constructor(private connection: Pool) {}

  async save(user: User): Promise<void> {
    await this.connection.query(
      'INSERT INTO users (id, email) VALUES (?, ?)',
      [user.id, user.email.getValue()]
    );
  }

  async getById(id: string): Promise<User | null> {
    const [rows] = await this.connection.query(
      'SELECT * FROM users WHERE id = ?',
      [id]
    );
    if (!rows[0]) return null;

    return new User(rows[0].id, new Email(rows[0].email));
  }
}

// infrastructure/adapters/SendgridNotificationService.ts
import { httpClient } from '../http';

export class SendgridNotificationService implements NotificationService {
  async notifyUserCreated(user: User): Promise<void> {
    await httpClient.post('https://api.sendgrid.com/v3/mail/send', {
      to: user.email.getValue(),
      subject: 'Welcome!',
      html: '<h1>Welcome to our app</h1>'
    });
  }
}
```

### テスト：インターフェース を使ったモック

```typescript
// tests/usecases/SaveUserUseCase.test.ts
describe('SaveUserUseCase', () => {
  let useCase: SaveUserUseCase;
  let mockRepository: UserRepository;
  let mockNotificationService: NotificationService;

  beforeEach(() => {
    // モック実装
    mockRepository = {
      save: jest.fn(),
      getById: jest.fn()
    };

    mockNotificationService = {
      notifyUserCreated: jest.fn()
    };

    useCase = new SaveUserUseCase(
      mockRepository,
      mockNotificationService
    );
  });

  it('should save user and send notification', async () => {
    // ✅ DB なしでテスト可能
    await useCase.execute('john@example.com');

    expect(mockRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        email: expect.any(Email)
      })
    );

    expect(mockNotificationService.notifyUserCreated).toHaveBeenCalled();
  });

  it('should throw error for invalid email', async () => {
    // ドメイン層のバリデーション
    await expect(useCase.execute('invalid-email')).rejects.toThrow(
      InvalidEmailError
    );
  });
});
```

---

## 🔄 よくある密結合パターンと修正

### パターン1：グローバルゴブリン

```typescript
// ❌ グローバルインスタンスへの依存
// config/Database.ts
export class Database {
  static instance = new Pool();  // シングルトン
}

// domain/User.ts
import { Database } from '../config/Database';
export class User {
  async save() {
    await Database.instance.query(...);  // グローバル参照
  }
}

// ✅ コンストラクタで注入
// domain/User.ts
export class User {
  // リポジトリインターフェースとして依存
}

// application/SaveUserUseCase.ts
export class SaveUserUseCase {
  constructor(private userRepository: UserRepository) {}
  // リポジトリは DI コンテナから来る
}
```

### パターン2：具体的なクラスに依存

```typescript
// ❌ 具体実装に依存
import { MySQLUserRepository } from '../infrastructure/MySQLUserRepository';

export class SaveUserUseCase {
  private repository = new MySQLUserRepository();
}

// ✅ インターフェースに依存
import { UserRepository } from '../domain/ports/UserRepository';

export class SaveUserUseCase {
  constructor(private userRepository: UserRepository) {}
  // MongoDB に切り替えも簡単
}
```

### パターン3：層を超えた直接参照

```typescript
// ❌ Presentation が直接 Infrastructure を参照
import { MySQLUserRepository } from '../infrastructure/MySQLUserRepository';

export class UserController {
  private repository = new MySQLUserRepository();

  async getUser(req: Request, res: Response) {
    const user = await this.repository.getById(req.params.id);
    res.json(user);
  }
}

// ✅ Application を経由
import { GetUserUseCase } from '../application/GetUserUseCase';

export class UserController {
  constructor(private getUserUseCase: GetUserUseCase) {}

  async getUser(req: Request, res: Response) {
    const user = await this.getUserUseCase.execute(req.params.id);
    res.json(user);
  }
}
```

---

## 🔍 密結合の検出

### madge で循環・密結合を検出

```bash
npm install --save-dev madge

# 循環依存をチェック
npx madge --circular src/

# 詳細な依存グラフを表示
npx madge src/

# グラフ画像を生成
npx madge --image graph.png src/
```

**出力例：**
```
⚠️  Circular dependencies found:
  A → B → A

❌ domain/User → infrastructure/Database → domain/User
```

---

## 📋 チェックリスト

```
✅ ドメイン層は他層を参照していない
✅ 依存関係がわかりやすい DAG（有向非巡回グラフ）
✅ インターフェース経由で層を分離
✅ DI コンテナで依存を一元管理
✅ テストでモックが使える
✅ madge で循環依存がない
✅ 層の責務が明確
```

---

**次: [貧血モデルの回避 →](./03-anemic-model.md)**
