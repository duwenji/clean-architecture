# 05: テスト戦略

クリーンアーキテクチャで各層を効率的かつ品質高く テストする方法を学びます。

---

## 🎯 テスト戦略の方針

```
Domain（ビジネスロジック）
  └─ ユニットテスト [最重要]
  
Application（ユースケース）
  └─ ユニット + 統合テスト
  
Presentation & Infrastructure
  └─ 統合テスト + モック
```

---

## 🧪 01: Domain 層テスト（ユニットテスト）

### Domain テストの特徴

- **外部依存なし** - DB、API 呼び出しなし
- **最も高速** - 数ミリ秒で実行
- **本数が多い** - ビジネスロジックをすべてカバー

### Email 値オブジェクトテスト

```typescript
// tests/unit/domain/value-objects/Email.test.ts
import { Email } from "../../../../src/domain/value-objects/Email";
import { InvalidEmailError } from "../../../../src/domain/errors/DomainError";

describe("Email Value Object", () => {
  describe("constructor", () => {
    it("should create valid email", () => {
      const email = new Email("user@example.com");
      expect(email.getValue()).toBe("user@example.com");
    });

    it("should lowercase email", () => {
      const email = new Email("User@Example.Com");
      expect(email.getValue()).toBe("user@example.com");
    });

    it("should throw error for invalid format", () => {
      expect(() => new Email("invalid-email")).toThrow(InvalidEmailError);
      expect(() => new Email("@example.com")).toThrow(InvalidEmailError);
      expect(() => new Email("user@")).toThrow(InvalidEmailError);
    });
  });

  describe("equals", () => {
    it("should return true for same value", () => {
      const email1 = new Email("user@example.com");
      const email2 = new Email("user@example.com");
      expect(email1.equals(email2)).toBe(true);
    });

    it("should return false for different value", () => {
      const email1 = new Email("user1@example.com");
      const email2 = new Email("user2@example.com");
      expect(email1.equals(email2)).toBe(false);
    });

    it("should be case-insensitive", () => {
      const email1 = new Email("User@Example.Com");
      const email2 = new Email("user@example.com");
      expect(email1.equals(email2)).toBe(true);
    });
  });

  describe("getDomain", () => {
    it("should extract domain", () => {
      const email = new Email("user@example.com");
      expect(email.getDomain()).toBe("example.com");
    });
  });
});
```

### Password 値オブジェクトテスト

```typescript
// tests/unit/domain/value-objects/Password.test.ts
import { Password } from "../../../../src/domain/value-objects/Password";
import { InvalidPasswordError } from "../../../../src/domain/errors/DomainError";

describe("Password Value Object", () => {
  describe("fromPlainText", () => {
    it("should create password from valid plain text", async () => {
      const password = await Password.fromPlainText("ValidPassword123");
      expect(password).toBeDefined();
      expect(password.getHashedValue().length).toBeGreaterThan(50);
    });

    it("should hash password using bcrypt", async () => {
      const password1 = await Password.fromPlainText("TestPassword123");
      const password2 = await Password.fromPlainText("TestPassword123");

      // ハッシュは毎回異なる（salt が異なる）
      expect(password1.getHashedValue()).not.toBe(
        password2.getHashedValue()
      );
    });

    it("should throw error for weak password", async () => {
      // 8文字未満
      await expect(
        Password.fromPlainText("weak")
      ).rejects.toThrow(InvalidPasswordError);

      // 大文字なし
      await expect(
        Password.fromPlainText("weakpassword123")
      ).rejects.toThrow(InvalidPasswordError);

      // 小文字なし
      await expect(
        Password.fromPlainText("WEAKPASSWORD123")
      ).rejects.toThrow(InvalidPasswordError);

      // 数字なし
      await expect(
        Password.fromPlainText("WeakPassword")
      ).rejects.toThrow(InvalidPasswordError);
    });
  });

  describe("matches", () => {
    it("should return true for correct password", async () => {
      const password = await Password.fromPlainText("CorrectPassword123");
      expect(await password.matches("CorrectPassword123")).toBe(true);
    });

    it("should return false for incorrect password", async () => {
      const password = await Password.fromPlainText("CorrectPassword123");
      expect(await password.matches("IncorrectPassword123")).toBe(false);
    });
  });

  describe("fromHash", () => {
    it("should create password from hash", async () => {
      const originalPassword = await Password.fromPlainText(
        "TestPassword123"
      );
      const hash = originalPassword.getHashedValue();

      const reconstructed = Password.fromHash(hash);
      expect(await reconstructed.matches("TestPassword123")).toBe(true);
    });

    it("should throw error for invalid hash", () => {
      expect(() => Password.fromHash("invalid")).toThrow(InvalidPasswordError);
    });
  });
});
```

### User エンティティテスト

```typescript
// tests/unit/domain/entities/User.test.ts
import { User } from "../../../../src/domain/entities/User";
import { Email } from "../../../../src/domain/value-objects/Email";
import { Password } from "../../../../src/domain/value-objects/Password";

describe("User Entity", () => {
  describe("create", () => {
    it("should create user with valid data", async () => {
      const email = new Email("john@example.com");
      const user = await User.create(email, "ValidPassword123", "John Doe");

      expect(user.getId()).toBeDefined();
      expect(user.getEmail().getValue()).toBe("john@example.com");
      expect(user.getName()).toBe("John Doe");
      expect(user.isUserActive()).toBe(true);
    });

    it("should throw error for invalid name length", async () => {
      const email = new Email("john@example.com");

      // 1文字
      await expect(
        User.create(email, "ValidPassword123", "J")
      ).rejects.toThrow();

      // 101文字
      const longName = "A".repeat(101);
      await expect(
        User.create(email, "ValidPassword123", longName)
      ).rejects.toThrow();
    });

    it("should generate unique IDs", async () => {
      const email1 = new Email("user1@example.com");
      const email2 = new Email("user2@example.com");

      const user1 = await User.create(email1, "ValidPassword123", "User One");
      const user2 = await User.create(email2, "ValidPassword123", "User Two");

      expect(user1.getId()).not.toBe(user2.getId());
    });
  });

  describe("isPasswordMatches", () => {
    it("should return true for correct password", async () => {
      const email = new Email("john@example.com");
      const user = await User.create(
        email,
        "CorrectPassword123",
        "John Doe"
      );

      expect(await user.isPasswordMatches("CorrectPassword123")).toBe(true);
    });

    it("should return false for incorrect password", async () => {
      const email = new Email("john@example.com");
      const user = await User.create(
        email,
        "CorrectPassword123",
        "John Doe"
      );

      expect(await user.isPasswordMatches("IncorrectPassword123")).toBe(false);
    });
  });

  describe("reconstruct", () => {
    it("should reconstruct user from database data", async () => {
      const originalUser = await User.create(
        new Email("john@example.com"),
        "ValidPassword123",
        "John Doe"
      );

      const reconstructed = User.reconstruct(
        originalUser.getId(),
        new Email("john@example.com"),
        originalUser.getHashedPassword(),
        "John Doe",
        originalUser.getCreatedAt(),
        originalUser.getUpdatedAt(),
        true
      );

      expect(reconstructed.getId()).toBe(originalUser.getId());
      expect(await reconstructed.isPasswordMatches("ValidPassword123")).toBe(true);
    });
  });
});
```

---

## 📋 02: Application 層テスト

### Application テストの特徴

- **モックが必要** - Repository、ExternalService をモック
- **ユースケース全体をテスト** - エンドツーエンドロジック
- **テストダブル** - Mock / Stub

### RegisterUserUseCase テスト

```typescript
// tests/unit/application/usecases/RegisterUserUseCase.test.ts
import { RegisterUserUseCase } from "../../../../src/application/usecases/RegisterUserUseCase";
import { RegisterUserRequest } from "../../../../src/application/dtos/RegisterUserRequest";
import { IUserRepository } from "../../../../src/domain/interfaces/IUserRepository";
import { IEmailSendingService } from "../../../../src/application/interfaces/IEmailSendingService";
import { User } from "../../../../src/domain/entities/User";
import { Email } from "../../../../src/domain/value-objects/Email";
import { UserAlreadyExistsError } from "../../../../src/domain/errors/DomainError";

// モック実装
class MockUserRepository implements IUserRepository {
  private users: Map<string, User> = new Map();
  findByEmailWasCalled = false;

  async save(user: User): Promise<void> {
    this.users.set(user.getId(), user);
  }

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) || null;
  }

  async findByEmail(email: Email): Promise<User | null> {
    this.findByEmailWasCalled = true;
    for (const user of this.users.values()) {
      if (user.getEmail().equals(email)) {
        return user;
      }
    }
    return null;
  }
}

class MockEmailSendingService implements IEmailSendingService {
  sentEmails: Array<{ to: string; subject: string; body: string }> = [];

  async send(to: string, subject: string, body: string): Promise<void> {
    this.sentEmails.push({ to, subject, body });
  }
}

describe("RegisterUserUseCase", () => {
  let useCase: RegisterUserUseCase;
  let userRepository: MockUserRepository;
  let emailSendingService: MockEmailSendingService;

  beforeEach(() => {
    userRepository = new MockUserRepository();
    emailSendingService = new MockEmailSendingService();
    useCase = new RegisterUserUseCase(userRepository, emailSendingService);
  });

  it("should register new user successfully", async () => {
    const request = new RegisterUserRequest(
      "john@example.com",
      "ValidPassword123",
      "John Doe"
    );

    const response = await useCase.execute(request);

    expect(response.userId).toBeDefined();
    expect(await userRepository.findById(response.userId)).toBeDefined();
  });

  it("should throw error if email already exists", async () => {
    // 1回目：ユーザー登録
    const request1 = new RegisterUserRequest(
      "john@example.com",
      "ValidPassword123",
      "John Doe"
    );
    await useCase.execute(request1);

    // 2回目：同じメールで登録
    const request2 = new RegisterUserRequest(
      "john@example.com",
      "AnotherPassword123",
      "Another User"
    );

    await expect(useCase.execute(request2)).rejects.toThrow(
      UserAlreadyExistsError
    );
  });

  it("should send welcome email after registration", async () => {
    const request = new RegisterUserRequest(
      "john@example.com",
      "ValidPassword123",
      "John Doe"
    );

    await useCase.execute(request);

    expect(emailSendingService.sentEmails.length).toBe(1);
    expect(emailSendingService.sentEmails[0].to).toBe("john@example.com");
    expect(emailSendingService.sentEmails[0].subject).toContain("Welcome");
  });

  it("should validate email format", async () => {
    const request = new RegisterUserRequest(
      "invalid-email",
      "ValidPassword123",
      "John Doe"
    );

    await expect(useCase.execute(request)).rejects.toThrow();
  });

  it("should validate password strength", async () => {
    const request = new RegisterUserRequest(
      "john@example.com",
      "weak",  // 弱いパスワード
      "John Doe"
    );

    await expect(useCase.execute(request)).rejects.toThrow();
  });
});
```

### LoginUserUseCase テスト

```typescript
// tests/unit/application/usecases/LoginUserUseCase.test.ts
import { LoginUserUseCase } from "../../../../src/application/usecases/LoginUserUseCase";
import { LoginUserRequest } from "../../../../src/application/dtos/LoginUserRequest";
import { IUserRepository } from "../../../../src/domain/interfaces/IUserRepository";
import { ITokenGenerator } from "../../../../src/application/interfaces/ITokenGenerator";
import { User } from "../../../../src/domain/entities/User";
import { Email } from "../../../../src/domain/value-objects/Email";
import { InvalidCredentialsError } from "../../../../src/application/errors/ApplicationError";

class MockTokenGenerator implements ITokenGenerator {
  async generate(userId: string): Promise<string> {
    return `token_${userId}`;
  }

  async verify(token: string): Promise<string> {
    return token.replace("token_", "");
  }
}

describe("LoginUserUseCase", () => {
  let useCase: LoginUserUseCase;
  let userRepository: MockUserRepository;
  let tokenGenerator: MockTokenGenerator;

  beforeEach(async () => {
    userRepository = new MockUserRepository();
    tokenGenerator = new MockTokenGenerator();
    useCase = new LoginUserUseCase(userRepository, tokenGenerator);

    // テスト用ユーザー作成
    const user = await User.create(
      new Email("john@example.com"),
      "ValidPassword123",
      "John Doe"
    );
    await userRepository.save(user);
  });

  it("should login successfully with correct credentials", async () => {
    const request = new LoginUserRequest(
      "john@example.com",
      "ValidPassword123"
    );

    const response = await useCase.execute(request);

    expect(response.userId).toBeDefined();
    expect(response.token).toBeDefined();
    expect(response.token).toContain("token_");
  });

  it("should throw error for non-existent email", async () => {
    const request = new LoginUserRequest(
      "nonexistent@example.com",
      "ValidPassword123"
    );

    await expect(useCase.execute(request)).rejects.toThrow(
      InvalidCredentialsError
    );
  });

  it("should throw error for incorrect password", async () => {
    const request = new LoginUserRequest(
      "john@example.com",
      "WrongPassword123"
    );

    await expect(useCase.execute(request)).rejects.toThrow(
      InvalidCredentialsError
    );
  });
});
```

---

## 🌐 03: Integration テスト

### 統合テストの特徴

- **複数層をまとめてテスト** - UseCase + Repository
- **実際のDB（テストDB）を使用** - 実装を含めて検証
- **遅い可能性** - DB アクセスがある
- **本数は少なめ** - 既にユニットテストで細部は確認済み

```typescript
// tests/integration/RegisterUserUseCase.integration.test.ts
import { RegisterUserUseCase } from "../../src/application/usecases/RegisterUserUseCase";
import { UserRepository } from "../../src/infrastructure/repositories/UserRepository";
import { MySQLConnection, Database } from "../../src/infrastructure/database/MySQLConnection";
import { EmailAdapter } from "../../src/infrastructure/services/EmailAdapter";
import { RegisterUserRequest } from "../../src/application/dtos/RegisterUserRequest";

describe("RegisterUserUseCase Integration Test", () => {
  let useCase: RegisterUserUseCase;
  let database: Database;

  beforeAll(async () => {
    // テスト用 DB に接続
    const connection = new MySQLConnection();
    await connection.connect({
      host: "localhost",
      user: "test_user",
      password: "test_password",
      database: "test_user_management"
    });
    database = connection;

    // テーブル作成
    await database.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(36) PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        name VARCHAR(100) NOT NULL,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL,
        is_active TINYINT NOT NULL
      )
    `);
  });

  beforeEach(async () => {
    // 各テスト前にテーブルをクリア
    await database.execute("TRUNCATE TABLE users");

    const userRepository = new UserRepository(database);
    const emailService = new EmailAdapter();

    useCase = new RegisterUserUseCase(userRepository, emailService);
  });

  afterAll(async () => {
    await database.execute("DROP TABLE users");
    await database.close();
  });

  it("should persist user to database and retrieve it", async () => {
    const request = new RegisterUserRequest(
      "integration@example.com",
      "ValidPassword123",
      "Integration User"
    );

    const response = await useCase.execute(request);

    // DB から直接確認
    const user = await database.queryOne(
      "SELECT * FROM users WHERE id = ?",
      [response.userId]
    );

    expect(user).toBeDefined();
    expect(user.email).toBe("integration@example.com");
    expect(user.name).toBe("Integration User");
    expect(user.password_hash).toBeDefined();
  });

  it("should prevent duplicate email registration", async () => {
    const request1 = new RegisterUserRequest(
      "duplicate@example.com",
      "ValidPassword123",
      "User One"
    );
    await useCase.execute(request1);

    const request2 = new RegisterUserRequest(
      "duplicate@example.com",
      "AnotherPassword123",
      "User Two"
    );

    await expect(useCase.execute(request2)).rejects.toThrow();

    // DB には1ユーザーだけ
    const users = await database.query("SELECT * FROM users WHERE email = ?", [
      "duplicate@example.com"
    ]);
    expect(users.length).toBe(1);
  });
});
```

---

## 🧪 04: Controller（Presentation）テスト

```typescript
// tests/unit/presentation/controllers/UserController.test.ts
import { UserController } from "../../../../src/presentation/controllers/UserController";
import { RegisterUserUseCase } from "../../../../src/application/usecases/RegisterUserUseCase";
import { LoginUserUseCase } from "../../../../src/application/usecases/LoginUserUseCase";
import { Request, Response } from "express";
import { InvalidEmailError } from "../../../../src/domain/errors/DomainError";

describe("UserController", () => {
  let controller: UserController;
  let registerUseCase: RegisterUserUseCase;
  let loginUseCase: LoginUserUseCase;
  let req: Partial<Request>;
  let res: Partial<Response>;

  beforeEach(() => {
    // モック UseCase
    registerUseCase = {
      execute: jest.fn()
    } as any;

    loginUseCase = {
      execute: jest.fn()
    } as any;

    controller = new UserController(registerUseCase, loginUseCase);

    // モック Request / Response
    req = { body: {}, params: {} };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
  });

  describe("register", () => {
    it("should return 201 on successful registration", async () => {
      req.body = {
        email: "john@example.com",
        password: "ValidPassword123",
        name: "John Doe"
      };

      jest.spyOn(registerUseCase, "execute").mockResolvedValue({
        userId: "user-123"
      } as any);

      await controller.register(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          message: "User registered successfully",
          userId: "user-123"
        })
      );
    });

    it("should return 400 on invalid email", async () => {
      req.body = {
        email: "invalid-email",
        password: "ValidPassword123",
        name: "John Doe"
      };

      jest
        .spyOn(registerUseCase, "execute")
        .mockRejectedValue(new InvalidEmailError("Invalid email"));

      await controller.register(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.any(String) })
      );
    });
  });

  describe("login", () => {
    it("should return 200 on successful login", async () => {
      req.body = {
        email: "john@example.com",
        password: "ValidPassword123"
      };

      jest.spyOn(loginUseCase, "execute").mockResolvedValue({
        userId: "user-123",
        token: "jwt-token"
      } as any);

      await controller.login(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          message: "Login successful",
          userId: "user-123",
          token: "jwt-token"
        })
      );
    });
  });
});
```

---

## ✅ テストチェックリスト

### Domain テスト

```
□ Email 値オブジェクト - 有効/無効フォーマット
□ Password 値オブジェクト - 強度チェック、マッチング
□ User エンティティ - 生成、ビジネスロジック
□ エラークラス - 適切にスロー
```

### Application テスト

```
□ RegisterUserUseCase - 成功、エラーケース
□ LoginUserUseCase - 認証ロジック
□ UseCase 間の連携
□ モック Repository/Service
```

### Integration テスト

```
□ DB への永続化
□ 重複登録の防止
□ 複数層の連携
□ 実際のリポジトリ実装
```

### Controller テスト

```
□ HTTP レスポンス形式
□ ステータスコード
□ エラーハンドリング
```

---

## 🚀 Jest 設定（jest.config.js）

```typescript
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/tests"],
  testMatch: ["**/__tests__/**/*.ts", "**/?(*.)+(spec|test).ts"],
  moduleFileExtensions: ["ts", "js", "json"],
  collectCoverageFrom: [
    "src/**/*.ts",
    "!src/**/*.d.ts",
    "!src/app.ts"
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70
    }
  }
};
```

---

## 🎯 テスト実行

```bash
# すべてテスト実行
npm test

# 特定ファイルテスト
npm test -- Email.test.ts

# ウォッチ模式
npm test -- --watch

# カバレッジレポート
npm test -- --coverage
```

---

**完了！クリーンアーキテクチャ完全実装ガイド終了**

---

## 📚 振り返りチェックリスト

このセクション（05-実装ガイド）を通じて：

```
□ フォルダ構造が設計できる
□ エンティティ・値オブジェクトを実装できる
□ ユースケースを実装できる
□ 4層すべてを実装できる
□ 依存性注入（DI）ができる
□ 各層を効率的にテストできる
□ 動くシステムを構築できる
```

---

## 🔗 関連セクション

**前:** [デザインパターン](../04-design-patterns/)
- パターンの理論を学んだ

**ここ:** **実装ガイド**
- パターンを実装に適用 ✅

**次:** [ベストプラクティス](../06-best-practices/)
- 実装品質をさらに上げる知見

**後:** [コモンピットフォール](../07-common-pitfalls/)
- よくある失敗パターン

---

## 💡 さらに学ぶ

**次のステップ:**

1. **セットアップガイド を読む**
   - 実装例コードが網羅的
   - コピーして使える

2. **テストを追加する**
   - ユニットテスト完備
   - テスト駆動開発（TDD）をやってみる

3. **CI/CD パイプラインを構築**
   - GitHub Actions で自動テスト
   - デプロイメント自動化

4. **マイクロサービス化**
   - 各層を独立したサービスに
   - API ゲートウェイ

5. **キャッシング・パフォーマンス最適化**
   - Redis キャッシング
   - クエリ最適化

---

**ご質問は [ベストプラクティス](../06-best-practices/) セクションで！**
