# 01: プロジェクト構造

クリーンアーキテクチャを実装する際の、フォルダ・ファイル配置を学びます。

## 📁 推奨フォルダ構成

```
user-management-system/
├── src/
│   ├── domain/                    # ドメイン層（ビジネスロジック）
│   │   ├── entities/
│   │   │   ├── User.ts
│   │   │   ├── Password.ts        # 値オブジェクト
│   │   │   └── Email.ts           # 値オブジェクト
│   │   ├── interfaces/
│   │   │   └── IUserRepository.ts # リポジトリI/F
│   │   ├── errors/
│   │   │   ├── DomainError.ts
│   │   │   ├── InvalidEmailError.ts
│   │   │   └── UserNotFoundError.ts
│   │   └── services/
│   │       └── PasswordHashService.ts
│   │
│   ├── application/               # アプリケーション層（ユースケース）
│   │   ├── usecases/
│   │   │   ├── RegisterUserUseCase.ts
│   │   │   ├── GetUserUseCase.ts
│   │   │   ├── UpdateProfileUseCase.ts
│   │   │   └── LoginUserUseCase.ts
│   │   ├── dtos/
│   │   │   ├── RegisterUserDTO.ts
│   │   │   ├── UserResponseDTO.ts
│   │   │   └── LoginRequestDTO.ts
│   │   └── services/
│   │       └── EmailSendingService.ts
│   │
│   ├── presentation/              # プレゼンテーション層（UI）
│   │   ├── controllers/
│   │   │   ├── UserController.ts
│   │   │   └── AuthController.ts
│   │   ├── middlewares/
│   │   │   ├── AuthMiddleware.ts
│   │   │   ├── ErrorHandler.ts
│   │   │   └── ValidationMiddleware.ts
│   │   └── routes/
│   │       ├── userRoutes.ts
│   │       └── authRoutes.ts
│   │
│   ├── infrastructure/            # インフラ層（外部リソース）
│   │   ├── repositories/
│   │   │   └── UserRepository.ts  # MySQL実装
│   │   ├── database/
│   │   │   ├── connection.ts
│   │   │   └── migrations/
│   │   │       └── 001_create_users_table.sql
│   │   ├── external-services/
│   │   │   └── EmailAdapter.ts    # メール送信
│   │   └── cryptography/
│   │       └── BcryptHasher.ts    # パスワードハッシュ化
│   │
│   ├── config/                    # DI設定
│   │   ├── Container.ts
│   │   └── dependencies.ts
│   │
│   └── app.ts                     # Express アプリケーション
│
├── tests/                         # テスト
│   ├── unit/
│   │   ├── domain/
│   │   │   └── entities/
│   │   │       └── User.test.ts
│   │   ├── application/
│   │   │   └── usecases/
│   │   │       └── RegisterUserUseCase.test.ts
│   │   └── presentation/
│   │       └── controllers/
│   │           └── UserController.test.ts
│   │
│   ├── integration/
│   │   ├── repositories/
│   │   │   └── UserRepository.test.ts
│   │   └── usecases/
│   │       └── RegisterUserUseCase.integration.test.ts
│   │
│   └── e2e/
│       └── auth.test.ts
│
├── package.json
├── tsconfig.json
├── jest.config.js
└── README.md
```

---

## 🎯 各層の役割と責務

### 1️⃣ Domain（ドメイン層）

**責務:** ビジネスロジック、ルール、制約

**独立性:** フレームワーク・DBに依存しない

**構成と何を置くか:**

```typescript
// domain/entities/User.ts
// パぐあいエンティティ
export class User {
  private id: string;
  private email: Email;       // 値オブジェクト
  private password: Password; // 値オブジェクト
  private name: string;
  private createdAt: Date;

  // ビジネスロジック
  isPasswordCorrect(plainPassword: string): boolean {
    return this.password.matches(plainPassword);
  }

  updateProfile(name: string, email: Email): void {
    this.name = name;
    this.email = email;
  }
}

// domain/entities/Email.ts
// 値オブジェクト（メールアドレス固有の業務ルール）
export class Email {
  private readonly value: string;

  constructor(value: string) {
    if (!this.isValid(value)) {
      throw new InvalidEmailError(`Invalid email: ${value}`);
    }
    this.value = value;
  }

  private isValid(email: string): boolean {
    // メール形式チェック（ビジネスルール）
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  getValue(): string {
    return this.value;
  }
}

// domain/interfaces/IUserRepository.ts
// リポジトリインターフェース（抽象化）
export interface IUserRepository {
  save(user: User): Promise<void>;
  findById(id: string): Promise<User | null>;
  findByEmail(email: Email): Promise<User | null>;
  delete(id: string): Promise<void>;
}
```

**特徴:**
- エンティティ（ビジネスオブジェクト）
- 値オブジェクト（ルールを持つ値）
- エラークラス
- リポジトリインターフェース（抽象化）
- ビジネスサービス

---

### 2️⃣ Application（アプリケーション層）

**責務:** ユースケース実行、トランザクション管理

**特性:** ドメイン層に依存 ← インフラ層には依存しない（インターフェース経由）

**構成と何を置くか:**

```typescript
// application/usecases/RegisterUserUseCase.ts
export class RegisterUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private emailSendingService: IEmailSendingService,
    private passwordHasher: IPasswordHasher
  ) {}

  async execute(request: RegisterUserRequest): Promise<void> {
    // 1. ビジネスルールチェック
    const existingUser = await this.userRepository.findByEmail(
      new Email(request.email)
    );
    if (existingUser) {
      throw new UserAlreadyExistsError();
    }

    // 2. ドメインオブジェクト生成
    const password = new Password(request.password);
    const hashedPassword = await this.passwordHasher.hash(password.getValue());
    const user = new User(
      UUID.v4(),
      new Email(request.email),
      hashedPassword,
      request.name
    );

    // 3. リポジトリで保存
    await this.userRepository.save(user);

    // 4. 副作用（メール送信）
    await this.emailSendingService.send(
      request.email,
      "ユーザー登録完了",
      `ようこそ、${request.name}さん`
    );
  }
}

// application/dtos/RegisterUserDTO.ts
// データ転送オブジェクト（層間のデータ受け渡し）
export class RegisterUserDTO {
  constructor(
    public email: string,
    public password: string,
    public name: string
  ) {}
}
```

**特徴:**
- ユースケース（1機能 = 1クラス）
- DTO（Data Transfer Object）
- アプリケーションサービス
- トランザクション管理

---

### 3️⃣ Presentation（プレゼンテーション層）

**責務:** HTTP リクエスト処理、HTTPレスポンス形成

**特性:** 最もフレームワークに依存する層

**構成と何を置くか:**

```typescript
// presentation/controllers/UserController.ts
export class UserController {
  constructor(
    private registerUserUseCase: RegisterUserUseCase,
    private getUserUseCase: GetUserUseCase,
    private updateProfileUseCase: UpdateProfileUseCase
  ) {}

  async register(req: Request, res: Response): Promise<void> {
    try {
      // 1. リクエストボディをDTO変換
      const dto = new RegisterUserDTO(
        req.body.email,
        req.body.password,
        req.body.name
      );

      // 2. ユースケース実行
      await this.registerUserUseCase.execute(dto);

      // 3. HTTPレスポンス
      res.status(201).json({ message: "User registered successfully" });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async getUser(req: Request, res: Response): Promise<void> {
    try {
      const user = await this.getUserUseCase.execute(req.params.id);
      res.json(new UserResponseDTO(user));
    } catch (error) {
      res.status(404).json({ error: "User not found" });
    }
  }
}

// presentation/routes/userRoutes.ts
export function setupUserRoutes(
  app: Express,
  userController: UserController
): void {
  app.post("/users/register", (req, res) =>
    userController.register(req, res)
  );
  app.get("/users/:id", (req, res) => userController.getUser(req, res));
}
```

**特徴:**
- Controllers（HTTPハンドラー）
- Routes（ルーティング）
- Middlewares（バリデーション、認証等）
- HTTPエラーハンドリング

---

### 4️⃣ Infrastructure（インフラ層）

**責務:** 外部リソース設定・実装

**特性:** 最も変更する可能性が高い層

**構成と何を置くか:**

```typescript
// infrastructure/repositories/UserRepository.ts
export class UserRepository implements IUserRepository {
  constructor(private database: Database) {}

  async save(user: User): Promise<void> {
    await this.database.execute(
      `INSERT INTO users (id, email, password, name, created_at)
       VALUES (?, ?, ?, ?, ?)`,
      [
        user.getId(),
        user.getEmail().getValue(),
        user.getPassword(),
        user.getName(),
        user.getCreatedAt()
      ]
    );
  }

  async findById(id: string): Promise<User | null> {
    const row = await this.database.query(
      "SELECT * FROM users WHERE id = ?",
      [id]
    );
    if (!row) return null;
    return this.mapRowToUser(row);
  }

  private mapRowToUser(row: any): User {
    return new User(
      row.id,
      new Email(row.email),
      row.password,
      row.name,
      new Date(row.created_at)
    );
  }
}

// infrastructure/database/connection.ts
// MySQL接続設定
export const createConnection = async (): Promise<Database> => {
  return mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
  });
};

// infrastructure/external-services/EmailAdapter.ts
export class EmailAdapter implements IEmailSendingService {
  async send(to: string, subject: string, body: string): Promise<void> {
    // SendGrid APIやSMTPを使用
    await sendEmail({ to, subject, body });
  }
}
```

**特徴:**
- リポジトリ実装（DB操作）
- DB接続設定
- 外部API統合
- キャッシュ層

---

### 5️⃣ Config（DI設定）

**責務:** 依存性の紐付け

**特性:** アプリケーション起動時に依存関係を組み立てる

```typescript
// config/Container.ts
export class Container {
  private instances: Map<string, any> = new Map();

  // リポジトリ
  registerUserRepository(db: Database): void {
    this.instances.set("UserRepository", new UserRepository(db));
  }

  // ユースケース
  registerRegisterUserUseCase(): void {
    const userRepository = this.instances.get("UserRepository");
    const emailService = this.instances.get("EmailSendingService");
    const passwordHasher = this.instances.get("PasswordHasher");

    this.instances.set(
      "RegisterUserUseCase",
      new RegisterUserUseCase(userRepository, emailService, passwordHasher)
    );
  }

  // コントローラー
  registerUserController(): void {
    const registerUseCase = this.instances.get("RegisterUserUseCase");
    const getUseCase = this.instances.get("GetUserUseCase");
    const updateUseCase = this.instances.get("UpdateProfileUseCase");

    this.instances.set(
      "UserController",
      new UserController(registerUseCase, getUseCase, updateUseCase)
    );
  }

  get<T>(key: string): T {
    return this.instances.get(key);
  }
}

// config/dependencies.ts
export const setupDependencies = async (): Promise<Container> => {
  const container = new Container();

  // データベース
  const db = await createConnection();

  // インフラ層
  container.registerUserRepository(db);
  container.register("Database", db);
  container.register("EmailSendingService", new EmailAdapter());
  container.register("PasswordHasher", new BcryptHasher());

  // アプリケーション層
  container.registerRegisterUserUseCase();
  container.registerGetUserUseCase();
  container.registerUpdateProfileUseCase();

  // プレゼンテーション層
  container.registerUserController();

  return container;
};

// app.ts
async function bootstrap() {
  const container = await setupDependencies();
  const app = express();

  const userController = container.get<UserController>("UserController");
  setupUserRoutes(app, userController);

  app.listen(3000, () => console.log("Server running on port 3000"));
}

bootstrap();
```

---

## 🔄 層間の依存関係

```
          Presentation
               ↓
          Application
               ↓
            Domain
               ↓
         Infrastructure
```

**重要ルール:**

- 上位層 → 下位層への依存は OK
- 下位層 → 上位層への依存は NG
- Infrastructure は他層に依存しない（インターフェース経由で逆転）

---

## 🏗️ プロジェクト初期化コマンド

```bash
# プロジェクト作成
mkdir user-management-system
cd user-management-system

# Node.js 初期化
npm init -y

# TypeScript インストール
npm install -D typescript @types/node ts-node

# Express インストール
npm install express
npm install -D @types/express

# MySQL インストール
npm install mysql2/promise

# テスト環境（Jest）
npm install -D jest @types/jest ts-jest

# 型チェック・構文チェック
npm install -D eslint @typescript-eslint/eslint-plugin

# フォルダ構成作成
mkdir -p src/{domain/{entities,interfaces,errors,services},application/{usecases,dtos,services},presentation/{controllers,middlewares,routes},infrastructure/{repositories,database,external-services,cryptography},config}
mkdir -p tests/{unit,integration,e2e}
```

---

## 📋 チェックリスト

このファイル理解後:

```
□ 5層の責務が明確
□ 各層に何を置くか理解した
□ 層間の依存関係ルールが分かった
□ フォルダ構成をプロジェクトに適用できた
```

---

**次: [エンティティ設計 →](./02-entity-design.md)**
