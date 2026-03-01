# 01. プレゼンテーション層 (Presentation Layer)

> **責務**: ユーザーインターフェース。HTTP リクエストを受け取ってレスポンスを返す。ビジネスロジックは持たない。

## 🎯 層の位置付け

```
┌──────────────────────────┐
│  プレゼンテーション層      │ ← ここ
│ (Web Controller, API)    │
├──────────────────────────┤
│  アプリケーション層       │
│ (ユースケース)            │
├──────────────────────────┤
│  ドメイン層              │
│ (ビジネスロジック)       │
├──────────────────────────┤
│  インフラストラクチャ層   │
│ (DB, 外部API)           │
└──────────────────────────┘
```

---

## 📋 プレゼンテーション層の責務

```
✅ プレゼンテーション層が担当：
  - HTTPリクエストの受け取り
  - リクエストデータの検証
  - エラーハンドリング
  - HTTPレスポンスの返却
  - ステータスコード管理
  - ログイン認証チェック

❌ プレゼンテーション層がしてはいけない：
  - ビジネスロジック
  - データベース直接アクセス
  - ドメイン知識の埋め込み
```

---

## 🏗️ 典型的なプレゼンテーション層の構成

```
presentation/
├── controller/
│   ├── UserController.ts
│   ├── ProductController.ts
│   └── OrderController.ts
├── dto/
│   ├── request/
│   │   └── CreateUserRequest.ts
│   └── response/
│       └── UserResponse.ts
├── middleware/
│   ├── AuthenticationMiddleware.ts
│   ├── ValidationMiddleware.ts
│   └── ErrorHandlingMiddleware.ts
└── mapper/
    └── UserMapper.ts
```

---

## 💻 実装例：ユーザー作成エンドポイント

### Step 1: リクエスト/レスポンスDTO

```typescript
// presentation/dto/request/CreateUserRequest.ts
export interface CreateUserRequest {
  email: string;
  password: string;
  name: string;
}

// presentation/dto/response/UserResponse.ts
export interface UserResponse {
  id: string;
  email: string;
  name: string;
  createdAt: string;
}

// 検証スキーマ
export class CreateUserRequestValidator {
  validate(data: any): CreateUserRequest {
    if (!data.email || !data.password || !data.name) {
      throw new ValidationError('Missing required fields');
    }

    if (typeof data.email !== 'string' || !data.email.includes('@')) {
      throw new ValidationError('Invalid email format');
    }

    if (typeof data.password !== 'string' || data.password.length < 8) {
      throw new ValidationError('Password must be at least 8 characters');
    }

    return {
      email: data.email.trim().toLowerCase(),
      password: data.password,
      name: data.name.trim()
    };
  }
}
```

### Step 2: Controller

```typescript
// presentation/controller/UserController.ts
export class UserController {
  constructor(
    private registerUserUseCase: RegisterUserUseCase,
    private getUserUseCase: GetUserUseCase,
    private validator: CreateUserRequestValidator,
    private mapper: UserMapper
  ) {}

  // ✅ HTTPハンドラー
  async createUser(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      // 1️⃣ リクエストの検証
      const validatedRequest = this.validator.validate(req.body);

      // 2️⃣ ユースケース実行（ビジネスロジックはここから）
      const user = await this.registerUserUseCase.execute(validatedRequest);

      // 3️⃣ ドメインモデルをDTOにマッピング
      const response = this.mapper.toUserResponse(user);

      // 4️⃣ レスポンス返却
      res.status(201).json(response);
    } catch (error) {
      // エラーハンドリング（詳細は後章）
      next(error);
    }
  }

  // ✅ ユーザー取得エンドポイント
  async getUser(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.params.id;

      if (!userId) {
        res.status(400).json({ error: 'User ID is required' });
        return;
      }

      const user = await this.getUserUseCase.execute(userId);
      const response = this.mapper.toUserResponse(user);

      res.status(200).json(response);
    } catch (error) {
      next(error);
    }
  }

  // ✅ ユーザー削除エンドポイント
  async deleteUser(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.params.id;

      if (!userId) {
        res.status(400).json({ error: 'User ID is required' });
        return;
      }

      await this.deleteUserUseCase.execute(userId);

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }
}
```

### Step 3: マッピング（ドメイン層 ↔ プレゼンテーション層）

```typescript
// presentation/mapper/UserMapper.ts
export class UserMapper {
  // ドメインモデル → レスポンスDTO
  toUserResponse(user: User): UserResponse {
    return {
      id: user.getId(),
      email: user.getEmail(),
      name: user.getName(),
      createdAt: user.getCreatedAt().toISOString()
    };
  }

  // リクエストDTO → ドメインモデル（アプリケーション層で実施）
  // ※ ここでは変換ロジックは簡潔に
}
```

### Step 4: ルーティング設定

```typescript
// presentation/routes/userRoutes.ts
import { Router } from 'express';

export function createUserRoutes(userController: UserController): Router {
  const router = Router();

  // POST /users
  router.post('/', (req, res, next) => {
    userController.createUser(req, res, next);
  });

  // GET /users/:id
  router.get('/:id', (req, res, next) => {
    userController.getUser(req, res, next);
  });

  // DELETE /users/:id
  router.delete('/:id', (req, res, next) => {
    userController.deleteUser(req, res, next);
  });

  return router;
}
```

---

## 🔐 プレゼンテーション層でのセキュリティ

### 認証ミドルウェア

```typescript
// presentation/middleware/AuthenticationMiddleware.ts
export class AuthenticationMiddleware {
  execute(req: Request, res: Response, next: NextFunction): void {
    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      res.status(401).json({ error: 'No token provided' });
      return;
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET!);
      req.user = decoded;  // リクエストに認証情報を付与
      next();
    } catch (error) {
      res.status(403).json({ error: 'Invalid token' });
    }
  }
}
```

### リクエスト検証ミドルウェア

```typescript
// presentation/middleware/ValidationMiddleware.ts
export function createValidationMiddleware(schema: Joi.Schema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const { error, value } = schema.validate(req.body);

    if (error) {
      res.status(400).json({
        error: 'Validation failed',
        details: error.details.map(d => d.message)
      });
      return;
    }

    req.body = value;  // 検証済みデータに置き換え
    next();
  };
}
```

---

## 📊 複数の UI メディア対応

クリーンアーキテクチャでは、複数の UI をサポートできます：

```
同じユースケース層を使用
      ↓
┌─────────────────────────────────────┐
│  Web API (REST/GraphQL)            │
│  UI（React SPA）                    │
│  モバイルAPI                        │
│  CLI                                │
└─────────────────────────────────────┘
      ↑ 全て同じビジネスロジック
      └─ RegisterUserUseCase など
```

### 複数の Controller 実装例

```typescript
// presentation/controller/WebUserController.ts（REST API）
export class WebUserController {
  async createUser(req: Request, res: Response): Promise<void> {
    const result = await this.registerUserUseCase.execute(req.body);
    res.status(201).json(result);
  }
}

// presentation/controller/GraphQLUserResolver.ts（GraphQL）
export class GraphQLUserResolver {
  @Mutation()
  async createUser(@Args('input') input: CreateUserInput): Promise<UserResponse> {
    const result = await this.registerUserUseCase.execute(input);
    return result;
  }
}

// presentation/controller/CLIUserCommand.ts（CLI）
export class CLIUserCommand {
  async createUser(email: string, password: string, name: string): Promise<void> {
    const result = await this.registerUserUseCase.execute({
      email,
      password,
      name
    });
    console.log(`User created: ${result.id}`);
  }
}

// 全て同じ RegisterUserUseCase を使用している！
```

---

## 🧪 テスト例

```typescript
describe('UserController', () => {
  let controller: UserController;
  let mockRegisterUseCase: MockRegisterUserUseCase;
  let mockValidator: MockValidator;
  let mockMapper: MockMapper;

  beforeEach(() => {
    mockRegisterUseCase = new MockRegisterUserUseCase();
    mockValidator = new MockValidator();
    mockMapper = new MockMapper();

    controller = new UserController(
      mockRegisterUseCase,
      mockValidator,
      mockMapper
    );
  });

  test('should create user successfully', async () => {
    const req = {
      body: {
        email: 'user@example.com',
        password: 'password123',
        name: 'John Doe'
      }
    } as Request;

    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    } as unknown as Response;

    await controller.createUser(req, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalled();
  });

  test('should handle validation error', async () => {
    mockValidator.throwError(new ValidationError('Invalid email'));

    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    } as unknown as Response;

    const next = jest.fn();

    await controller.createUser({} as Request, res, next);

    expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
  });
});
```

---

## 📋 プレゼンテーション層のチェックリスト

```
✅ ビジネスロジックがない
✅ DB直接アクセスがない
✅ リクエスト検証がある
✅ レスポンスマッピングがある
✅ エラーハンドリングがある
✅ 認証・認可チェックがある
✅ ログが適切にある
```

---

## ➡️ 次のステップ

次は、**アプリケーション層**を学びます。これはビジネスロジックの実行層です。

[次: アプリケーション層 →](./02-application-layer.md)
