# 01. 依存性注入 (Dependency Injection)

> **パターン**: オブジェクトの依存関係を外部から注入する。テスト性と柔軟性を大幅に向上させる。

## 🎯 コンセプト

```
❌ 自分で依存関係を作成
class UserService {
  private repository = new MySQLUserRepository();
}

✅ 外部から注入されて受け取る
class UserService {
  constructor(private repository: UserRepository) {}
}
```

---

## 📊 3つの DI パターン

### パターン1：コンストラクタインジェクション（推奨）

```typescript
// 依存関係がコンストラクタのパラメータ
export class UserService {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService,
    private passwordService: PasswordService
  ) {}

  async registerUser(request: RegisterRequest): Promise<void> {
    // 注入された依存関係を使用
    const user = new User(...);
    await this.userRepository.save(user);
    await this.emailService.send(...);
  }
}

// 使用方法
const repository = new MySQLUserRepository(db);
const emailService = new EmailService(mailClient);
const passwordService = new PasswordService();

const userService = new UserService(
  repository,
  emailService,
  passwordService
);

userService.registerUser(request);
```

**メリット:**
- 依存関係が明確
- 不変（immutable）
- テストが簡単

### パターン2：セッターインジェクション

```typescript
export class UserService {
  private userRepository: UserRepository;
  private emailService: EmailService;

  setUserRepository(repo: UserRepository): void {
    this.userRepository = repo;
  }

  setEmailService(service: EmailService): void {
    this.emailService = service;
  }
}

// 使用
const service = new UserService();
service.setUserRepository(new MySQLUserRepository(db));
service.setEmailService(new EmailService());
```

**欠点:**
- 依存関係を忘れることがある
- 可変でテストしにくい

### パターン3：インターフェースインジェクション

```typescript
export interface Injector {
  inject(service: any, dependencies: any): void;
}

export class ContainerInjector implements Injector {
  inject(service: any, dependencies: any): void {
    for (const key in dependencies) {
      service[key] = dependencies[key];
    }
  }
}
```

---

## 🏭 DI コンテナの使用

### 手動での組み立て

```typescript
// factory.ts
export class ApplicationFactory {
  static createUserService(): UserService {
    const db = new Database();
    const userRepository = new MySQLUserRepository(db);
    const emailService = new EmailService();
    const passwordService = new PasswordService();

    return new UserService(
      userRepository,
      emailService,
      passwordService
    );
  }

  static createOrderService(): OrderService {
    const db = new Database();
    const orderRepository = new MySQLOrderRepository(db);
    const inventoryService = new InventoryService();

    return new OrderService(
      orderRepository,
      inventoryService
    );
  }
}

// 使用
const userService = ApplicationFactory.createUserService();
const orderService = ApplicationFactory.createOrderService();
```

### InversifyJS を使った DI コンテナ

```typescript
// 依存関係を定義
import { Container, injectable, inject } from 'inversify';

@injectable()
export class UserService {
  constructor(
    @inject('UserRepository') private userRepository: UserRepository,
    @inject('EmailService') private emailService: EmailService
  ) {}
}

@injectable()
export class MySQLUserRepository implements UserRepository {
  constructor(@inject('Database') private db: Database) {}
}

// コンテナ設定
const container = new Container();

container.bind<Database>('Database').toConstantValue(new Database());
container.bind<UserRepository>('UserRepository')
  .to(MySQLUserRepository)
  .inSingletonScope();  // シングルトン
container.bind<EmailService>('EmailService')
  .to(EmailService);
container.bind<UserService>(UserService)
  .to(UserService);

// 取得
const userService = container.get<UserService>(UserService);
```

---

## 🧪 テストでの活用

```typescript
describe('DI with Testing', () => {
  test('should work with mock dependencies', async () => {
    // 本当のDB を使わずにモックを注入
    const mockRepository: UserRepository = {
      save: jest.fn(),
      findById: jest.fn().mockResolvedValue(null)
    };

    const mockEmailService: EmailService = {
      send: jest.fn()
    };

    const mockPasswordService: PasswordService = {
      hash: jest.fn().mockReturnValue('hashed')
    };

    // テスト用のサービスを作成
    const userService = new UserService(
      mockRepository,
      mockEmailService,
      mockPasswordService
    );

    // テスト実行（DBなしで高速）
    await userService.registerUser({
      email: 'test@example.com',
      password: 'pass123'
    });

    expect(mockRepository.save).toHaveBeenCalled();
    expect(mockEmailService.send).toHaveBeenCalled();
  });
});
```

---

## 📋 DI チェックリスト

```
✅ 依存関係がコンストラクタで明確
✅ インターフェースで抽象化されている
✅ 循環依存がない
✅ テストで簡単にモックできる
✅ DI コンテナの設定が集約されている
```

---

[次: リポジトリパターン →](./02-repository-pattern.md)
