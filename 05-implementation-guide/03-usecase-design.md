# 03: ユースケース設計

アプリケーション層の中核であるユースケース（ビジネスロジック実行層）の設計・実装を学びます。

## 🎯 ユースケースとは

**定義:** [Clean Architecture では] ビジネスロジックを実行する「アプリケーションのユースケース」を実装する層

**役割:**
1. ドメイン層（Entity）の組み合わせ
2. インフラ層（Repository）の呼び出し
3. 副作用（メール送信等）の実行
4. トランザクション管理
5. エラーハンドリング

**特徴:**
- 1 ユースケース = 1 機能
- ビジネスプロセスの流れを表現
- フレームワークに依存しない

---

## 📊 ユースケース例：ユーザー登録

```
ユースケース: RegisterUser
  ↓
入力: メール、パスワード、名前
  ↓
処理:
  1. 既存ユーザー確認
  2. ユーザーオブジェクト生成
  3. DB 保存
  4. 確認メール送信
  ↓
出力: なし（成功 or エラーをスロー）
```

---

## ❌ 悪い実装例

```typescript
// ❌ NG: ユースケースが散らばっている

// Controller に直接ビジネスロジック
express.post("/register", async (req, res) => {
  // 1. バリデーション
  if (!req.body.email || !req.body.password) {
    return res.status(400).json({ error: "Invalid input" });
  }

  // 2. ユーザー確認（リポジトリ）
  const existingUser = await userDb.query(
    "SELECT * FROM users WHERE email = ?",
    [req.body.email]
  );
  if (existingUser) {
    return res.status(400).json({ error: "User already exists" });
  }

  // 3. パスワードハッシュ化
  const hashedPassword = await bcrypt.hash(req.body.password, 10);

  // 4. DB 保存
  const userId = uuid();
  await userDb.query(
    "INSERT INTO users (id, email, password, name) VALUES (?, ?, ?, ?)",
    [userId, req.body.email, hashedPassword, req.body.name]
  );

  // 5. メール送信
  await sendEmail(req.body.email, "Welcome!");

  // 6. レスポンス
  res.status(201).json({ message: "User registered" });
});

// 問題: テストが困難、他のプレゼンテーション層から再利用不可
```

---

## ✅ 良い実装例

### 1️⃣ ユースケース定義（リクエスト/レスポンス）

```typescript
// application/usecases/RegisterUserUseCase/RegisterUserRequest.ts
export class RegisterUserRequest {
  constructor(
    readonly email: string,
    readonly password: string,
    readonly name: string
  ) {}
}

// application/usecases/RegisterUserUseCase/RegisterUserResponse.ts
export class RegisterUserResponse {
  constructor(readonly userId: string) {}
}
```

### 2️⃣ インターフェース定義（依存性の抽象化）

```typescript
// domain/interfaces/IUserRepository.ts
export interface IUserRepository {
  save(user: User): Promise<void>;
  findByEmail(email: Email): Promise<User | null>;
  findById(id: string): Promise<User | null>;
}

// application/interfaces/IEmailSendingService.ts
export interface IEmailSendingService {
  send(to: string, subject: string, body: string): Promise<void>;
}

// application/interfaces/IPasswordHasher.ts
export interface IPasswordHasher {
  hash(plainPassword: string): Promise<string>;
  compare(plainPassword: string, hash: string): Promise<boolean>;
}
```

### 3️⃣ ユースケース実装

```typescript
// application/usecases/RegisterUserUseCase/RegisterUserUseCase.ts
export class RegisterUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private emailSendingService: IEmailSendingService,
    private passwordHasher: IPasswordHasher
  ) {}

  async execute(request: RegisterUserRequest): Promise<RegisterUserResponse> {
    // 1. ビジネスルール検証：ユーザー重複チェック
    const existingUser = await this.userRepository.findByEmail(
      new Email(request.email)
    );

    if (existingUser) {
      throw new UserAlreadyExistsError(
        `Email ${request.email} is already registered`
      );
    }

    // 2. ドメインオブジェクト生成
    // Email と Password は値オブジェクトで validation 済み
    const email = new Email(request.email);
    const user = await User.create(email, request.password, request.name);

    // 3. リポジトリで永続化
    try {
      await this.userRepository.save(user);
    } catch (error) {
      throw new UserSaveError(`Failed to save user: ${error.message}`);
    }

    // 4. 副作用：メール送信
    try {
      await this.emailSendingService.send(
        request.email,
        "ユーザー登録完了",
        `ようこそ、${request.name}さん！`
      );
    } catch (error) {
      // メール送信失敗はログするが、ユーザー登録は成功扱い
      console.warn(`Failed to send welcome email: ${error.message}`);
    }

    // 5. レスポンス返却
    return new RegisterUserResponse(user.getId());
  }
}
```

---

## 📝 その他のユースケース例

### ユースケース2: ユーザーログイン

```typescript
// application/usecases/LoginUserUseCase/LoginUserRequest.ts
export class LoginUserRequest {
  constructor(readonly email: string, readonly password: string) {}
}

// application/usecases/LoginUserUseCase/LoginUserResponse.ts
export class LoginUserResponse {
  constructor(readonly userId: string, readonly token: string) {}
}

// application/usecases/LoginUserUseCase/LoginUserUseCase.ts
export class LoginUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private tokenGenerator: ITokenGenerator
  ) {}

  async execute(request: LoginUserRequest): Promise<LoginUserResponse> {
    // 1. メールでユーザー検索
    const user = await this.userRepository.findByEmail(
      new Email(request.email)
    );

    if (!user) {
      throw new UserNotFoundError(`User not found: ${request.email}`);
    }

    // 2. パスワード検証
    const passwordMatches = await user.isPasswordMatches(request.password);

    if (!passwordMatches) {
      throw new InvalidPasswordError("Password is incorrect");
    }

    // 3. アカウント状態確認
    if (!user.isUserActive()) {
      throw new UserDeactivatedError("Account is deactivated");
    }

    // 4. トークン生成
    const token = await this.tokenGenerator.generate(user.getId());

    // 5. レスポンス
    return new LoginUserResponse(user.getId(), token);
  }
}
```

### ユースケース3: プロフィール更新

```typescript
// application/usecases/UpdateProfileUseCase/UpdateProfileRequest.ts
export class UpdateProfileRequest {
  constructor(
    readonly userId: string,
    readonly newName: string,
    readonly newEmail: string
  ) {}
}

// application/usecases/UpdateProfileUseCase/UpdateProfileUseCase.ts
export class UpdateProfileUseCase {
  constructor(
    private userRepository: IUserRepository,
    private emailSendingService: IEmailSendingService
  ) {}

  async execute(request: UpdateProfileRequest): Promise<void> {
    // 1. ユーザー取得
    const user = await this.userRepository.findById(request.userId);
    if (!user) {
      throw new UserNotFoundError(`User not found: ${request.userId}`);
    }

    // 2. 新しいメールの重複チェック
    const newEmail = new Email(request.newEmail);
    const existingUserWithEmail = await this.userRepository.findByEmail(newEmail);

    if (existingUserWithEmail && existingUserWithEmail.getId() !== request.userId) {
      throw new EmailAlreadyInUseError(
        `Email ${request.newEmail} is already in use`
      );
    }

    // 3. プロフィール更新（ドメインロジック）
    const oldEmail = user.getEmail().getValue();
    user.updateProfile(request.newName, newEmail);

    // 4. DB 更新
    await this.userRepository.save(user);

    // 5. メール変更時のみ確認メール送信
    if (oldEmail !== request.newEmail) {
      await this.emailSendingService.send(
        request.newEmail,
        "メールアドレス変更確認",
        "このメールアドレスでプロフィールが更新されました"
      );
    }
  }
}
```

---

## 🔄 Request → Response フロー

```
Controller
  ↓ (HTTP Request から Request オブジェクト生成)
  ↓
UseCase.execute(Request)
  ↓
  1. ビジネスルール検証
  2. ドメインオブジェクト操作
  3. リポジトリで永続化
  4. 副作用（メール等）実行
  ↓
Response オブジェクト返却
  ↓ (Response から HTTP Response に変換)
Controller
```

---

## 🌐 Controller から ユースケース呼び出し

```typescript
// presentation/controllers/UserController.ts
export class UserController {
  constructor(
    private registerUserUseCase: RegisterUserUseCase,
    private loginUserUseCase: LoginUserUseCase,
    private updateProfileUseCase: UpdateProfileUseCase
  ) {}

  // POST /users/register
  async register(req: Request, res: Response): Promise<void> {
    try {
      // 1. HTTP リクエストを Request オブジェクトに変換
      const request = new RegisterUserRequest(
        req.body.email,
        req.body.password,
        req.body.name
      );

      // 2. ユースケース実行
      const response = await this.registerUserUseCase.execute(request);

      // 3. Response를 HTTP レスポンスに変換
      res.status(201).json({
        message: "User registered successfully",
        userId: response.userId
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  // POST /auth/login
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

  // PUT /users/:id/profile
  async updateProfile(req: Request, res: Response): Promise<void> {
    try {
      const request = new UpdateProfileRequest(
        req.params.id,
        req.body.name,
        req.body.email
      );

      await this.updateProfileUseCase.execute(request);

      res.status(200).json({ message: "Profile updated successfully" });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  // エラーハンドリング
  private handleError(error: any, res: Response): void {
    if (error instanceof UserAlreadyExistsError) {
      res.status(400).json({ error: error.message });
    } else if (error instanceof UserNotFoundError) {
      res.status(404).json({ error: error.message });
    } else if (error instanceof InvalidPasswordError) {
      res.status(401).json({ error: error.message });
    } else {
      res.status(500).json({ error: "Internal server error" });
    }
  }
}
```

---

## 🧩 ユースケースの層間依存関係

```
Presentation
    ↓
UseCase ← Interface (IUserRepository / IEmailService)
    ↓
Domain (Entity, ValueObject)

Infrastructure (実装)
    ↓
（IUserRepository の実装 = MySQL用リポジトリ）
```

**重要:** ユースケースは Infrastructure に直接依存 しない → インターフェース経由

---

## ✅ ユースケース実装チェックリスト

```
□ Request / Response クラス定義
□ 依存性をコンストラクタで受け取る（DI）
□ ビジネスルール検証を最初に
□ ドメインオブジェクトを生成・操作
□ リポジトリで永続化
□ 副作用（メール等）を実行
□ エラーケースで適切な Exception をスロー
□ 単一責任の原則に従う（1 UseCase = 1 機能）
□ 同期・非同期ロジックが明確
```

---

## 🎯 ベストプラクティス

### 1️⃣ トランザクション管理

```typescript
export class UpdateProfileUseCase {
  constructor(
    private userRepository: IUserRepository,
    private unitOfWork: IUnitOfWork  // トランザクション管理
  ) {}

  async execute(request: UpdateProfileRequest): Promise<void> {
    // トランザクション開始
    const transaction = await this.unitOfWork.begin();

    try {
      // ユーザー取得
      const user = await this.userRepository.findById(request.userId);

      // プロフィール更新
      user.updateProfile(request.newName, new Email(request.newEmail));

      // 保存
      await this.userRepository.save(user);

      // コミット
      await transaction.commit();
    } catch (error) {
      // ロールバック
      await transaction.rollback();
      throw error;
    }
  }
}
```

### 2️⃣ 副作用の分離

```typescript
export class RegisterUserUseCase {
  async execute(request: RegisterUserRequest): Promise<RegisterUserResponse> {
    // ... ユーザー作成・保存 ...

    // メール送信は「副作用」としてログ出力
    // 実際の送信は非同期で別途実行
    await this.eventBus.publish(new UserRegisteredEvent(userId, email));

    return new RegisterUserResponse(userId);
  }
}

// 別処理で非同期実行
eventBus.subscribe(UserRegisteredEvent, (event) => {
  emailService.send(event.email, "Welcome!").catch(err => {
    logger.warn(`Failed to send email: ${err}`);
  });
});
```

---

**次: [完全実装例 →](./04-implementation-example.md)**
