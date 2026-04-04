# 04: 完全な実装例

01 ~ 03 で学んだ知識を、実際に動く完全なコード例として示します。

ユーザー管理システム（ユーザー登録・ログイン）の全層実装です。

---

## 🗂️ ファイル構成（完全版）

```
src/
├── domain/
│   ├── entities/
│   │   └── User.ts          # User エンティティ
│   ├── value-objects/
│   │   ├── Email.ts         # Email 値オブジェクト
│   │   └── Password.ts      # Password 値オブジェクト
│   ├── interfaces/
│   │   └── IUserRepository.ts
│   └── errors/
│       ├── DomainError.ts
│       ├── InvalidEmailError.ts
│       └── UserAlreadyExistsError.ts
│
├── application/
│   ├── usecases/
│   │   ├── RegisterUserUseCase.ts
│   │   └── LoginUserUseCase.ts
│   ├── dtos/
│   │   ├── RegisterUserRequest.ts
│   │   └── LoginUserRequest.ts
│   ├── interfaces/
│   │   ├── IEmailSendingService.ts
│   │   └── IPasswordHasher.ts
│   └── errors/
│       └── ApplicationError.ts
│
├── presentation/
│   ├── controllers/
│   │   └── UserController.ts
│   ├── routes/
│   │   └── userRoutes.ts
│   └── middlewares/
│       └── ErrorHandlerMiddleware.ts
│
├── infrastructure/
│   ├── repositories/
│   │   └── UserRepository.ts   # MySQL 実装
│   ├── services/
│   │   ├── BcryptHasher.ts
│   │   └── EmailAdapter.ts
│   └── database/
│       └── MySQLConnection.ts
│
├── config/
│   ├── Container.ts            # DI コンテナ
│   └── dependencies.ts         # 依存性設定
│
└── app.ts                       # Express アプリケーション
```

---

## 💾 01: Domain 層の実装

### domain/errors/DomainError.ts

```typescript
export abstract class DomainError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class InvalidEmailError extends DomainError {}
export class InvalidPasswordError extends DomainError {}
export class UserAlreadyExistsError extends DomainError {}
export class UserNotFoundError extends DomainError {}
```

### domain/value-objects/Email.ts

```typescript
import { InvalidEmailError } from "../errors/DomainError";

export class Email {
  private readonly value: string;

  constructor(value: string) {
    if (!Email.isValid(value)) {
      throw new InvalidEmailError(`Invalid email format: ${value}`);
    }
    this.value = value.toLowerCase();
  }

  static isValid(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  getValue(): string {
    return this.value;
  }

  equals(other: Email): boolean {
    return this.value === other.value;
  }

  getDomain(): string {
    return this.value.split("@")[1];
  }

  toString(): string {
    return this.value;
  }
}
```

### domain/value-objects/Password.ts

```typescript
import * as bcrypt from "bcrypt";
import { InvalidPasswordError } from "../errors/DomainError";

export class Password {
  private readonly hashedValue: string;

  private constructor(hashedValue: string) {
    if (hashedValue.length < 60) {
      throw new InvalidPasswordError("Password must be hashed");
    }
    this.hashedValue = hashedValue;
  }

  static async fromPlainText(plainPassword: string): Promise<Password> {
    this.validateStrength(plainPassword);
    const hashedValue = await bcrypt.hash(plainPassword, 10);
    return new Password(hashedValue);
  }

  static fromHash(hash: string): Password {
    return new Password(hash);
  }

  async matches(plainPassword: string): Promise<boolean> {
    return bcrypt.compare(plainPassword, this.hashedValue);
  }

  getHashedValue(): string {
    return this.hashedValue;
  }

  private static validateStrength(password: string): void {
    const errors: string[] = [];

    if (password.length < 8) {
      errors.push("At least 8 characters");
    }
    if (!/[A-Z]/.test(password)) {
      errors.push("Uppercase letter required");
    }
    if (!/[a-z]/.test(password)) {
      errors.push("Lowercase letter required");
    }
    if (!/[0-9]/.test(password)) {
      errors.push("Number required");
    }

    if (errors.length > 0) {
      throw new InvalidPasswordError(`Password must contain: ${errors.join(", ")}`);
    }
  }
}
```

### domain/entities/User.ts

```typescript
import { v4 as uuid } from "uuid";
import { Email } from "../value-objects/Email";
import { Password } from "../value-objects/Password";
import { UserAlreadyExistsError, UserNotFoundError } from "../errors/DomainError";

export class User {
  private readonly id: string;
  private email: Email;
  private password: Password;
  private name: string;
  private readonly createdAt: Date;
  private updatedAt: Date;
  private isActive: boolean;

  private constructor(
    id: string,
    email: Email,
    password: Password,
    name: string,
    createdAt: Date,
    updatedAt: Date,
    isActive: boolean
  ) {
    this.id = id;
    this.email = email;
    this.password = password;
    this.name = name;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
    this.isActive = isActive;
  }

  static async create(
    email: Email,
    plainPassword: string,
    name: string
  ): Promise<User> {
    if (name.length < 2 || name.length > 100) {
      throw new Error("Name must be 2-100 characters");
    }

    const password = await Password.fromPlainText(plainPassword);
    return new User(uuid(), email, password, name, new Date(), new Date(), true);
  }

  static reconstruct(
    id: string,
    email: Email,
    hashedPassword: string,
    name: string,
    createdAt: Date,
    updatedAt: Date,
    isActive: boolean
  ): User {
    const password = Password.fromHash(hashedPassword);
    return new User(id, email, password, name, createdAt, updatedAt, isActive);
  }

  async isPasswordMatches(plainPassword: string): Promise<boolean> {
    return this.password.matches(plainPassword);
  }

  getId(): string {
    return this.id;
  }

  getEmail(): Email {
    return this.email;
  }

  getName(): string {
    return this.name;
  }

  getCreatedAt(): Date {
    return this.createdAt;
  }

  getUpdatedAt(): Date {
    return this.updatedAt;
  }

  isUserActive(): boolean {
    return this.isActive;
  }

  getHashedPassword(): string {
    return this.password.getHashedValue();
  }
}
```

### domain/interfaces/IUserRepository.ts

```typescript
import { User } from "../entities/User";
import { Email } from "../value-objects/Email";

export interface IUserRepository {
  save(user: User): Promise<void>;
  findById(id: string): Promise<User | null>;
  findByEmail(email: Email): Promise<User | null>;
}
```

---

## 🔄 02: Application 層の実装

### application/errors/ApplicationError.ts

```typescript
export abstract class ApplicationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class UserAlreadyExistsApplicationError extends ApplicationError {}
export class UserNotFoundApplicationError extends ApplicationError {}
export class InvalidCredentialsError extends ApplicationError {}
```

### application/dtos/RegisterUserRequest.ts

```typescript
export class RegisterUserRequest {
  constructor(
    readonly email: string,
    readonly password: string,
    readonly name: string
  ) {}
}

export class RegisterUserResponse {
  constructor(readonly userId: string) {}
}
```

### application/dtos/LoginUserRequest.ts

```typescript
export class LoginUserRequest {
  constructor(readonly email: string, readonly password: string) {}
}

export class LoginUserResponse {
  constructor(readonly userId: string, readonly token: string) {}
}
```

### application/interfaces/

```typescript
// application/interfaces/IEmailSendingService.ts
export interface IEmailSendingService {
  send(to: string, subject: string, body: string): Promise<void>;
}

// application/interfaces/IPasswordHasher.ts
export interface IPasswordHasher {
  hash(plainPassword: string): Promise<string>;
  compare(plainPassword: string, hash: string): Promise<boolean>;
}

// application/interfaces/ITokenGenerator.ts
export interface ITokenGenerator {
  generate(userId: string): Promise<string>;
  verify(token: string): Promise<string>;
}
```

### application/usecases/RegisterUserUseCase.ts

```typescript
import { IUserRepository } from "../../domain/interfaces/IUserRepository";
import { IEmailSendingService } from "../interfaces/IEmailSendingService";
import { Email } from "../../domain/value-objects/Email";
import { User } from "../../domain/entities/User";
import {
  UserAlreadyExistsError,
  InvalidEmailError,
} from "../../domain/errors/DomainError";
import {
  RegisterUserRequest,
  RegisterUserResponse
} from "../dtos/RegisterUserRequest";

export class RegisterUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private emailSendingService: IEmailSendingService
  ) {}

  async execute(request: RegisterUserRequest): Promise<RegisterUserResponse> {
    try {
      // 1. Email 値オブジェクト生成（バリデーション）
      const email = new Email(request.email);

      // 2. 既存ユーザー確認
      const existingUser = await this.userRepository.findByEmail(email);
      if (existingUser) {
        throw new UserAlreadyExistsError(
          `Email ${request.email} is already registered`
        );
      }

      // 3. User エンティティ生成
      const user = await User.create(email, request.password, request.name);

      // 4. リポジトリで保存
      await this.userRepository.save(user);

      // 5. メール送信（非同期で、失敗してもユースケースは成功）
      this.emailSendingService
        .send(
          request.email,
          "Welcome to User Management System",
          `Hello ${request.name}!\n\nThank you for signing up.`
        )
        .catch((err) => {
          console.warn(`Failed to send welcome email: ${err.message}`);
        });

      // 6. レスポンス
      return new RegisterUserResponse(user.getId());
    } catch (error) {
      throw error;
    }
  }
}
```

### application/usecases/LoginUserUseCase.ts

```typescript
import { IUserRepository } from "../../domain/interfaces/IUserRepository";
import { ITokenGenerator } from "../interfaces/ITokenGenerator";
import { Email } from "../../domain/value-objects/Email";
import { InvalidCredentialsError } from "../errors/ApplicationError";
import {
  LoginUserRequest,
  LoginUserResponse
} from "../dtos/LoginUserRequest";

export class LoginUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private tokenGenerator: ITokenGenerator
  ) {}

  async execute(request: LoginUserRequest): Promise<LoginUserResponse> {
    // 1. メールでユーザー検索
    const email = new Email(request.email);
    const user = await this.userRepository.findByEmail(email);

    if (!user) {
      throw new InvalidCredentialsError("Invalid email or password");
    }

    // 2. パスワード検証
    const passwordMatches = await user.isPasswordMatches(request.password);
    if (!passwordMatches) {
      throw new InvalidCredentialsError("Invalid email or password");
    }

    // 3. アカウント状態確認
    if (!user.isUserActive()) {
      throw new InvalidCredentialsError("Account is deactivated");
    }

    // 4. トークン生成
    const token = await this.tokenGenerator.generate(user.getId());

    // 5. レスポンス
    return new LoginUserResponse(user.getId(), token);
  }
}
```

---

## 🌐 03: Presentation 層の実装

### presentation/controllers/UserController.ts

```typescript
import { Request, Response } from "express";
import { RegisterUserUseCase } from "../../application/usecases/RegisterUserUseCase";
import { LoginUserUseCase } from "../../application/usecases/LoginUserUseCase";
import { RegisterUserRequest } from "../../application/dtos/RegisterUserRequest";
import { LoginUserRequest } from "../../application/dtos/LoginUserRequest";

export class UserController {
  constructor(
    private registerUserUseCase: RegisterUserUseCase,
    private loginUserUseCase: LoginUserUseCase
  ) {}

  async register(req: Request, res: Response): Promise<void> {
    try {
      const request = new RegisterUserRequest(
        req.body.email,
        req.body.password,
        req.body.name
      );

      const response = await this.registerUserUseCase.execute(request);

      res.status(201).json({
        message: "User registered successfully",
        userId: response.userId
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  async login(req: Request, res: Response): Promise<void> {
    try {
      const request = new LoginUserRequest(
        req.body.email,
        req.body.password
      );

      const response = await this.loginUserUseCase.execute(request);

      res.status(200).json({
        message: "Login successful",
        userId: response.userId,
        token: response.token
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  private handleError(error: any, res: Response): void {
    if (error.name === "InvalidEmailError") {
      return res.status(400).json({ error: error.message });
    }
    if (error.name === "UserAlreadyExistsError") {
      return res.status(409).json({ error: error.message });
    }
    if (error.name === "InvalidCredentialsError") {
      return res.status(401).json({ error: error.message });
    }

    console.error("Unexpected error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}
```

### presentation/routes/userRoutes.ts

```typescript
import { Express, Router } from "express";
import { UserController } from "../controllers/UserController";

export function setupUserRoutes(app: Express, userController: UserController): void {
  const router = Router();

  router.post("/register", (req, res) => userController.register(req, res));
  router.post("/login", (req, res) => userController.login(req, res));

  app.use("/users", router);
}
```

---

## 💾 04: Infrastructure 層の実装

### infrastructure/database/MySQLConnection.ts

```typescript
import * as mysql from "mysql2/promise";

export interface Database {
  query(sql: string, params?: any[]): Promise<any[]>;
  queryOne(sql: string, params?: any[]): Promise<any | null>;
  execute(sql: string, params?: any[]): Promise<void>;
  close(): Promise<void>;
}

export class MySQLConnection implements Database {
  private connection: mysql.Connection | null = null;

  async connect(config: mysql.ConnectionOptions): Promise<void> {
    this.connection = await mysql.createConnection(config);
    console.log("Database connected");
  }

  async query(sql: string, params: any[] = []): Promise<any[]> {
    if (!this.connection) throw new Error("Database not connected");
    const [rows] = await this.connection.execute(sql, params);
    return rows as any[];
  }

  async queryOne(sql: string, params: any[] = []): Promise<any | null> {
    const results = await this.query(sql, params);
    return results[0] || null;
  }

  async execute(sql: string, params: any[] = []): Promise<void> {
    if (!this.connection) throw new Error("Database not connected");
    await this.connection.execute(sql, params);
  }

  async close(): Promise<void> {
    if (this.connection) {
      await this.connection.end();
      this.connection = null;
    }
  }
}
```

### infrastructure/repositories/UserRepository.ts

```typescript
import { IUserRepository } from "../../domain/interfaces/IUserRepository";
import { User } from "../../domain/entities/User";
import { Email } from "../../domain/value-objects/Email";
import { Database } from "../database/MySQLConnection";

export class UserRepository implements IUserRepository {
  constructor(private database: Database) {}

  async save(user: User): Promise<void> {
    await this.database.execute(
      `INSERT INTO users (id, email, password_hash, name, created_at, updated_at, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
       email = VALUES(email), password_hash = VALUES(password_hash), name = VALUES(name), updated_at = VALUES(updated_at)`,
      [
        user.getId(),
        user.getEmail().getValue(),
        user.getHashedPassword(),
        user.getName(),
        user.getCreatedAt(),
        user.getUpdatedAt(),
        user.isUserActive() ? 1 : 0
      ]
    );
  }

  async findById(id: string): Promise<User | null> {
    const row = await this.database.queryOne(
      "SELECT * FROM users WHERE id = ?",
      [id]
    );
    if (!row) return null;
    return this.mapRowToUser(row);
  }

  async findByEmail(email: Email): Promise<User | null> {
    const row = await this.database.queryOne(
      "SELECT * FROM users WHERE email = ?",
      [email.getValue()]
    );
    if (!row) return null;
    return this.mapRowToUser(row);
  }

  private mapRowToUser(row: any): User {
    return User.reconstruct(
      row.id,
      new Email(row.email),
      row.password_hash,
      row.name,
      new Date(row.created_at),
      new Date(row.updated_at),
      row.is_active === 1
    );
  }
}
```

### infrastructure/services/BcryptHasher.ts

```typescript
import * as bcrypt from "bcrypt";
import { IPasswordHasher } from "../../application/interfaces/IPasswordHasher";

export class BcryptHasher implements IPasswordHasher {
  async hash(plainPassword: string): Promise<string> {
    return bcrypt.hash(plainPassword, 10);
  }

  async compare(plainPassword: string, hash: string): Promise<boolean> {
    return bcrypt.compare(plainPassword, hash);
  }
}
```

### infrastructure/services/EmailAdapter.ts

```typescript
import { IEmailSendingService } from "../../application/interfaces/IEmailSendingService";

export class EmailAdapter implements IEmailSendingService {
  async send(to: string, subject: string, body: string): Promise<void> {
    // 実装例: console に出力（本番は SendGrid / AWS SES 等）
    console.log(`Email sent:`);
    console.log(`  To: ${to}`);
    console.log(`  Subject: ${subject}`);
    console.log(`  Body: ${body}`);

    // await sendGridClient.send({ to, subject, html: body });
  }
}
```

### infrastructure/services/JwtTokenGenerator.ts

```typescript
import * as jwt from "jsonwebtoken";
import { ITokenGenerator } from "../../application/interfaces/ITokenGenerator";

export class JwtTokenGenerator implements ITokenGenerator {
  constructor(private secret: string) {}

  async generate(userId: string): Promise<string> {
    return jwt.sign({ userId }, this.secret, { expiresIn: "24h" });
  }

  async verify(token: string): Promise<string> {
    const decoded = jwt.verify(token, this.secret) as { userId: string };
    return decoded.userId;
  }
}
```

---

## ⚙️ 05: Config 層（DI 設定）

### config/Container.ts

```typescript
import { RegisterUserUseCase } from "../application/usecases/RegisterUserUseCase";
import { LoginUserUseCase } from "../application/usecases/LoginUserUseCase";
import { UserRepository } from "../infrastructure/repositories/UserRepository";
import { UserController } from "../presentation/controllers/UserController";
import { Database } from "../infrastructure/database/MySQLConnection";
import { IUserRepository } from "../domain/interfaces/IUserRepository";
import { IEmailSendingService } from "../application/interfaces/IEmailSendingService";
import { ITokenGenerator } from "../application/interfaces/ITokenGenerator";
import { EmailAdapter } from "../infrastructure/services/EmailAdapter";
import { JwtTokenGenerator } from "../infrastructure/services/JwtTokenGenerator";

export class Container {
  private instances: Map<string, any> = new Map();

  register<T>(key: string, instance: T): void {
    this.instances.set(key, instance);
  }

  get<T>(key: string): T {
    const instance = this.instances.get(key);
    if (!instance) {
      throw new Error(`Dependency not found: ${key}`);
    }
    return instance;
  }

  registerRepository(database: Database): void {
    const userRepository: IUserRepository = new UserRepository(database);
    this.register("UserRepository", userRepository);
  }

  registerServices(): void {
    const emailService: IEmailSendingService = new EmailAdapter();
    this.register("EmailSendingService", emailService);

    const tokenGenerator: ITokenGenerator = new JwtTokenGenerator(
      process.env.JWT_SECRET || "secret"
    );
    this.register("TokenGenerator", tokenGenerator);
  }

  registerUseCases(): void {
    const userRepository = this.get<IUserRepository>("UserRepository");
    const emailService = this.get<IEmailSendingService>("EmailSendingService");
    const tokenGenerator = this.get<ITokenGenerator>("TokenGenerator");

    this.register(
      "RegisterUserUseCase",
      new RegisterUserUseCase(userRepository, emailService)
    );

    this.register(
      "LoginUserUseCase",
      new LoginUserUseCase(userRepository, tokenGenerator)
    );
  }

  registerControllers(): void {
    const registerUseCase =
      this.get<RegisterUserUseCase>("RegisterUserUseCase");
    const loginUseCase = this.get<LoginUserUseCase>("LoginUserUseCase");

    this.register(
      "UserController",
      new UserController(registerUseCase, loginUseCase)
    );
  }
}
```

---

## 🚀 06: アプリケーション起動

### app.ts

```typescript
import * as express from "express";
import { MySQLConnection } from "./infrastructure/database/MySQLConnection";
import { Container } from "./config/Container";
import { setupUserRoutes } from "./presentation/routes/userRoutes";
import { UserController } from "./presentation/controllers/UserController";

async function bootstrap(): Promise<void> {
  // 1. DB 接続
  const database = new MySQLConnection();
  await database.connect({
    host: process.env.DB_HOST || "localhost",
    user: process.env.DB_USER || "root",
    password: process.env.DB_PASSWORD || "password",
    database: process.env.DB_NAME || "user_management"
  });

  // 2. DI コンテナ設定
  const container = new Container();
  container.register("Database", database);
  container.registerRepository(database);
  container.registerServices();
  container.registerUseCases();
  container.registerControllers();

  // 3. Express アプリケーション
  const app = express();

  // ミドルウェア
  app.use(express.json());

  // ルート設定
  const userController = container.get<UserController>("UserController");
  setupUserRoutes(app, userController);

  // サーバー起動
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

bootstrap().catch((error) => {
  console.error("Failed to start server:", error);
  process.exit(1);
});
```

### package.json

```json
{
  "name": "clean-architecture-example",
  "version": "1.0.0",
  "description": "User management system with clean architecture",
  "main": "dist/app.js",
  "scripts": {
    "start": "node dist/app.js",
    "dev": "ts-node-dev --respawn src/app.ts",
    "build": "tsc",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.0",
    "bcrypt": "^5.1.0",
    "jsonwebtoken": "^9.0.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0",
    "@types/express": "^4.17.17",
    "@types/bcrypt": "^5.0.0",
    "@types/jsonwebtoken": "^9.0.2",
    "ts-node-dev": "^2.0.0",
    "jest": "^29.5.0",
    "@types/jest": "^29.5.0",
    "ts-jest": "^29.1.0"
  }
}
```

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "tests"]
}
```

---

## 🧪 使用例

### ユーザー登録

```bash
curl -X POST http://localhost:3000/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "MyPassword123",
    "name": "John Doe"
  }'

# レスポンス
{
  "message": "User registered successfully",
  "userId": "550e8400-e29b-41d4-a716-446655440000"
}
```

### ログイン

```bash
curl -X POST http://localhost:3000/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "MyPassword123"
  }'

# レスポンス
{
  "message": "Login successful",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

**次: [テスト戦略 →](./05-testing-strategy.md)**
