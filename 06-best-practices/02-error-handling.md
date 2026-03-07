# 02: エラーハンドリング

層別のエラー処理戦略で、予測可能で回復可能なシステムを構築。

---

## 🎯 エラーハンドリングの原則

```
予測可能：何が起きるか分かる
│
回復可能：対応方法が存在する
│
可視化：ログ・監視に記録
```

---

## 🔴 エラーの分類

```
ドメイン層エラー（ビジネスエラー）
  ├─ 回復可能なエラー
  ├─ ユースケース側で処理
  └─ 例: InvalidEmailError, InsufficientBalanceError

アプリケーション層エラー（ロジックエラー）
  ├─ ユースケース実行の問題
  ├─ トランザクション失敗
  └─ 例: UserAlreadyExistsError, DataConsistencyError

システムエラー（インフラエラー）
  ├─ 回復困難なエラー
  ├─ 外部依存の失敗
  └─ 例: DatabaseConnectionError, ExternalAPIError
```

---

## 📊 階層別のエラーハンドリング

### ドメイン層：ビジネスエラー例外

```typescript
// domain/errors/DomainError.ts
export abstract class DomainError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
    Object.setPrototypeOf(this, DomainError.prototype);
  }
}

export class InvalidEmailError extends DomainError {}
export class InvalidPasswordError extends DomainError {}
export class UserAlreadyExistsError extends DomainError {}
export class InsufficientBalanceError extends DomainError {}
export class InvalidOrderStatusError extends DomainError {}

// domain/entities/User.ts
export class User {
  constructor(email: Email) {
    // バリデーション時点でエラーをスロー
    if (!email) {
      throw new InvalidEmailError('Email is required');
    }
  }

  transfer(amount: Money): void {
    if (this.balance.isLessThan(amount)) {
      throw new InsufficientBalanceError(
        `Need ${amount.value}, have ${this.balance.value}`
      );
    }
    this.balance = this.balance.subtract(amount);
  }
}
```

### アプリケーション層：エラー変換＆集約

```typescript
// application/errors/ApplicationError.ts
export abstract class ApplicationError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class UserAlreadyExistsApplicationError extends ApplicationError {
  constructor(email: string) {
    super(
      `User with email ${email} already exists`,
      'USER_ALREADY_EXISTS',
      409  // Conflict
    );
  }
}

// application/usecases/RegisterUserUseCase.ts
export class RegisterUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService
  ) {}

  async execute(request: RegisterUserRequest): Promise<void> {
    try {
      // ドメインエラーはここで発生
      const email = new Email(request.email);
      const user = await User.create(email, request.password, request.name);

      // ビジネスロジック
      const existing = await this.userRepository.findByEmail(email);
      if (existing) {
        throw new UserAlreadyExistsApplicationError(request.email);
      }

      await this.userRepository.save(user);

      // 副作用
      await this.emailService.send(request.email, 'Welcome!');
    } catch (error) {
      // ドメインエラーをアプリケーションエラーに変換
      if (error instanceof InvalidEmailError) {
        throw new InvalidEmailApplicationError(error.message);
      }
      if (error instanceof InvalidPasswordError) {
        throw new InvalidPasswordApplicationError(error.message);
      }
      // その他のエラーはそのままスロー
      throw error;
    }
  }
}
```

### プレゼンテーション層：HTTP応答

```typescript
// presentation/controllers/UserController.ts
export class UserController {
  constructor(private registerUseCase: RegisterUserUseCase) {}

  async register(req: Request, res: Response): Promise<void> {
    try {
      const request = new RegisterUserRequest(
        req.body.email,
        req.body.password,
        req.body.name
      );

      await this.registerUseCase.execute(request);
      res.status(201).json({ message: 'User registered' });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  private handleError(error: any, res: Response): void {
    // ビジネスエラー → 4xx
    if (error instanceof InvalidEmailError) {
      return res.status(400).json({
        error: error.message,
        code: 'INVALID_EMAIL'
      });
    }

    if (error instanceof UserAlreadyExistsError) {
      return res.status(409).json({
        error: error.message,
        code: 'USER_ALREADY_EXISTS'
      });
    }

    // システムエラー → 5xx
    if (error instanceof DatabaseError) {
      logger.error('Database error', error);
      return res.status(500).json({
        error: 'Internal Server Error'
      });
    }

    if (error instanceof ExternalServiceError) {
      logger.error('External service error', error);
      return res.status(503).json({
        error: 'Service Unavailable'
      });
    }

    // 予期しないエラー
    logger.error('Unexpected error', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
}

// presentation/middlewares/ErrorHandlerMiddleware.ts
export const errorHandler = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  // アプリケーション層エラーをHTTPに変換
  const errorStatusMap: Record<string, number> = {
    'InvalidEmailError': 400,
    'InvalidPasswordError': 400,
    'UserAlreadyExistsError': 409,
    'UserNotFoundError': 404,
    'UnauthorizedError': 401,
    'ForbiddenError': 403,
    'DatabaseError': 500,
    'ExternalServiceError': 503,
    'ValidationError': 422
  };

  const statusCode = errorStatusMap[error.name] || 500;

  logger.error(`[${error.name}] ${error.message}`, {
    name: error.name,
    message: error.message,
    path: req.path,
    method: req.method
  });

  res.status(statusCode).json({
    error: error.message,
    code: error.name,
    timestamp: new Date().toISOString()
  });
};
```

---

## 🔄 エラーハンドリングパターン

### パターン1: Try-Catch で回復

```typescript
async function processUser(userId: string): Promise<void> {
  try {
    const user = await userRepository.findById(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }

    await processUserData(user);
  } catch (error) {
    if (error instanceof UserNotFoundError) {
      // 処理可能 → ログして続行
      logger.warn(`User not found: ${userId}`);
      return;  // 処理を中断
    }

    if (error instanceof ValidationError) {
      // 修正可能 → デフォルト値を使用
      logger.warn(`Invalid data for ${userId}, using default`);
      await processUserData(createDefaultUser());
      return;
    }

    // 処理不可 → スロー
    throw error;
  }
}
```

### パターン2: Result オブジェクトで結果を返す

```typescript
// Rust/Golang スタイル
export type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

export class UserService {
  async registerUser(email: string, password: string): Promise<Result<string, RegisterError>> {
    try {
      const emailObj = new Email(email);
      const user = await User.create(emailObj, password, 'User');
      await this.userRepository.save(user);
      return { ok: true, value: user.getId() };
    } catch (error) {
      if (error instanceof InvalidEmailError) {
        return {
          ok: false,
          error: { type: 'INVALID_EMAIL', message: error.message }
        };
      }
      if (error instanceof InvalidPasswordError) {
        return {
          ok: false,
          error: { type: 'INVALID_PASSWORD', message: error.message }
        };
      }
      return {
        ok: false,
        error: { type: 'UNKNOWN', message: 'Unexpected error' }
      };
    }
  }
}

// 使用側
const result = await userService.registerUser(email, password);
if (result.ok) {
  console.log(`User registered: ${result.value}`);
} else {
  console.error(`Registration failed: ${result.error.message}`);
}
```

### パターン3: カスタムエラークラス

```typescript
// より詳細な情報を含める
export class ApiError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly code: string,
    public readonly details?: Record<string, any>
  ) {
    super(message);
    this.name = this.constructor.name;
  }

  toJSON() {
    return {
      error: this.message,
      code: this.code,
      statusCode: this.statusCode,
      details: this.details
    };
  }
}

throw new ApiError(
  'Invalid email format',
  400,
  'INVALID_EMAIL',
  { email: 'invalid-email@' }
);
```

---

## 📋 チェックリスト

```
✅ ドメイン層：DomainError 基底クラスから継承
✅ アプリケーション層：DomainError をキャッチ＆変換
✅ プレゼンテーション層：エラー名 → HTTPステータスコード
✅ 予測可能なHTTPステータスコード
✅ エラーログに十分な情報
✅ 本番環境での詳細情報は隠す
✅ エラーメッセージはユーザーフレンドリー
✅ エラーレスポンスに `code` フィールド
```

---

**次: [ロギング・監視 →](./03-logging-monitoring.md)**
