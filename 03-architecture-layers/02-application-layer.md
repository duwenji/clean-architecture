# 02. アプリケーション層 (Application Layer)

> **責務**: ユースケース（ビジネスフロー）の実行。複数のドメインオブジェクトを組み合わせてビジネスプロセスを実現する。

## 🎯 層の位置付け

```
┌──────────────────────────┐
│  プレゼンテーション層     │
├──────────────────────────┤
│  アプリケーション層       │  ← ここ
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

## 📋 アプリケーション層の責務

```
✅ アプリケーション層が担当：
  - ユースケースの実行
  - トランザクション管理
  - 異なるドメインモデルの組み合わせ
  - 外部サービスの呼び出し調整
  - DTO の変換
  - ビジネスプロセスの順序制御

❌ アプリケーション層がしてはいけない：
  - 複雑なビジネスルール制定（ドメイン層で）
  - データベース方言固有のロジック（インフラ層で）
```

---

## 🏗️ 典型的なアプリケーション層の構成

```
application/
├── usecase/
│   ├── user/
│   │   ├── RegisterUserUseCase.ts
│   │   ├── GetUserUseCase.ts
│   │   ├── UpdateUserUseCase.ts
│   │   └── DeleteUserUseCase.ts
│   ├── order/
│   │   ├── CreateOrderUseCase.ts
│   │   ├── CancelOrderUseCase.ts
│   │   └── GetOrderHistoryUseCase.ts
│   └── ...
├── service/
│   ├── UserApplicationService.ts
│   ├── NotificationService.ts
│   └── ...
├── dto/
│   ├── UserDto.ts
│   ├── OrderDto.ts
│   └── ...
└── port/
    ├── UserRepository.ts
    └── ...
```

---

## 💻 実装例：ユースケース

### シンプルなユースケース：ユーザー登録

```typescript
// application/usecase/user/RegisterUserUseCase.ts

export interface RegisterUserRequest {
  email: string;
  password: string;
  name: string;
}

export interface RegisterUserResponse {
  id: string;
  email: string;
  name: string;
  createdAt: Date;
}

export class RegisterUserUseCase {
  constructor(
    private userRepository: UserRepository,           // ドメイン層の業務
    private passwordService: PasswordService,         // ドメイン層の業務
    private notificationService: NotificationService  // 外部サービス呼び出し
  ) {}

  async execute(request: RegisterUserRequest): Promise<RegisterUserResponse> {
    // Step 1: 事前チェック
    const existingUser = await this.userRepository.findByEmail(request.email);
    if (existingUser) {
      throw new UserAlreadyExistsError(request.email);
    }

    // Step 2: ドメインモデル作成（ビジネスルール適用）
    const user = new User(
      this.generateId(),
      request.email,
      this.passwordService.hashPassword(request.password),
      request.name
    );

    // Step 3: 永続化
    await this.userRepository.save(user);

    // Step 4: 外部サービス呼び出し（エラーは記録するが無視）
    try {
      await this.notificationService.sendWelcomeEmail(user.getEmail());
    } catch (error) {
      console.error('Failed to send welcome email:', error);
      // ウェルカムメール送信失敗でも、ユーザー作成は成功
    }

    // Step 5: レスポンス返却
    return {
      id: user.getId(),
      email: user.getEmail(),
      name: user.getName(),
      createdAt: user.getCreatedAt()
    };
  }

  private generateId(): string {
    return uuid();
  }
}
```

### 複雑なユースケース：注文作成

```typescript
// application/usecase/order/CreateOrderUseCase.ts

export interface CreateOrderRequest {
  userId: string;
  items: Array<{ productId: string; quantity: number }>;
  shippingAddress: string;
}

export interface CreateOrderResponse {
  orderId: string;
  totalPrice: number;
  estimatedDeliveryDate: Date;
}

export class CreateOrderUseCase {
  constructor(
    private orderRepository: OrderRepository,
    private productRepository: ProductRepository,
    private userRepository: UserRepository,
    private inventoryService: InventoryService,
    private paymentService: PaymentService,
    private shippingService: ShippingService,
    private emailService: EmailService
  ) {}

  async execute(request: CreateOrderRequest): Promise<CreateOrderResponse> {
    // Step 1: ユーザー存在確認
    const user = await this.userRepository.getUser(request.userId);
    if (!user) {
      throw new UserNotFoundError(request.userId);
    }

    // Step 2: 商品情報と在庫確認
    const orderItems = [];
    let totalPrice = 0;

    for (const item of request.items) {
      const product = await this.productRepository.getProduct(item.productId);
      if (!product) {
        throw new ProductNotFoundError(item.productId);
      }

      const available = await this.inventoryService.checkAvailability(
        item.productId,
        item.quantity
      );
      if (!available) {
        throw new InsufficientInventoryError(item.productId);
      }

      orderItems.push({
        productId: product.getId(),
        quantity: item.quantity,
        price: product.getPrice()
      });

      totalPrice += product.getPrice() * item.quantity;
    }

    // Step 3: 配送予定日の計算
    const estimatedDeliveryDate = this.calculateEstimatedDelivery(request.shippingAddress);

    // Step 4: 支払い処理
    const paymentResult = await this.paymentService.charge(
      user.getPaymentMethod(),
      totalPrice
    );

    if (!paymentResult.success) {
      throw new PaymentFailedError(paymentResult.reason);
    }

    // Step 5: 在庫減少
    for (const item of request.items) {
      await this.inventoryService.decreaseStock(item.productId, item.quantity);
    }

    // Step 6: 注文作成（ドメインモデル）
    const order = new Order(
      this.generateOrderId(),
      user.getId(),
      orderItems,
      totalPrice,
      request.shippingAddress,
      estimatedDeliveryDate,
      paymentResult.transactionId
    );

    // Step 7: 注文を保存
    await this.orderRepository.save(order);

    // Step 8: 配送指示
    try {
      await this.shippingService.createShipment(
        order.getId(),
        request.shippingAddress,
        estimatedDeliveryDate
      );
    } catch (error) {
      // 配送失敗時の処理（重要な業務）
      // キャンセルして返金
      await this.paymentService.refund(paymentResult.transactionId, totalPrice);
      await this.orderRepository.delete(order.getId());
      throw new ShippingFailedError();
    }

    // Step 9: 確認メール
    try {
      await this.emailService.sendOrderConfirmation(
        user.getEmail(),
        order.getId(),
        totalPrice
      );
    } catch (error) {
      // メール送信失敗は無視（重要ではない）
      console.warn('Failed to send confirmation email');
    }

    return {
      orderId: order.getId(),
      totalPrice,
      estimatedDeliveryDate
    };
  }

  private calculateEstimatedDelivery(shippingAddress: string): Date {
    // 実装
  }

  private generateOrderId(): string {
    return uuid();
  }
}
```

---

## 📊 アプリケーション層の特性

### トランザクション管理

```typescript
export class UpdateUserProfileUseCase {
  async execute(userId: string, updates: UpdateProfileRequest): Promise<void> {
    // トランザクション開始
    const transaction = await this.db.beginTransaction();

    try {
      // Step 1: ユーザー取得
      const user = await this.userRepository.getUser(userId, transaction);

      // Step 2: プロフィール更新
      user.updateProfile(updates.name, updates.bio, updates.avatarUrl);

      // Step 3: 変更履歴記録
      await this.auditService.recordChange(
        userId,
        'PROFILE_UPDATE',
        updates,
        transaction
      );

      // Step 4: 通知送信
      await this.notificationService.notifyProfileUpdate(
        user.getEmail(),
        transaction
      );

      // トランザクション確定
      await transaction.commit();
    } catch (error) {
      // ロールバック
      await transaction.rollback();
      throw error;
    }
  }
}
```

### エラーハンドリング

```typescript
export class TransferMoneyUseCase {
  async execute(request: TransferRequest): Promise<TransferResponse> {
    // ビジネスエラー：回復可能
    if (request.amount <= 0) {
      throw new InvalidAmountError('Amount must be positive');
    }

    const fromAccount = await this.accountRepository.getAccount(request.fromAccountId);
    if (!fromAccount) {
      throw new AccountNotFoundError(request.fromAccountId);
    }

    if (fromAccount.getBalance() < request.amount) {
      throw new InsufficientBalanceError(fromAccount.getBalance(), request.amount);
    }

    // システムエラー：回復不可
    try {
      await this.externalBankService.validateAccountNumber(request.toAccountId);
    } catch (error) {
      throw new ExternalServiceError('Bank service unavailable', error);
    }

    // 正常処理
    const transaction = await this.transactionService.execute(
      fromAccount,
      request.toAccountId,
      request.amount
    );

    return {
      transactionId: transaction.getId(),
      timestamp: transaction.getTimestamp()
    };
  }
}
```

---

## 🧪 テスト例

```typescript
describe('RegisterUserUseCase', () => {
  let useCase: RegisterUserUseCase;
  let mockUserRepository: MockUserRepository;
  let mockPasswordService: MockPasswordService;
  let mockNotificationService: MockNotificationService;

  beforeEach(() => {
    mockUserRepository = new MockUserRepository();
    mockPasswordService = new MockPasswordService();
    mockNotificationService = new MockNotificationService();

    useCase = new RegisterUserUseCase(
      mockUserRepository,
      mockPasswordService,
      mockNotificationService
    );
  });

  test('should register new user', async () => {
    const result = await useCase.execute({
      email: 'user@example.com',
      password: 'password123',
      name: 'John Doe'
    });

    expect(result.email).toBe('user@example.com');
    expect(result.id).toBeDefined();
    expect(mockUserRepository.savedUsers).toHaveLength(1);
  });

  test('should reject duplicate email', async () => {
    mockUserRepository.addUser({
      id: '1',
      email: 'user@example.com',
      password: 'hashed',
      name: 'Existing'
    });

    expect(async () => {
      await useCase.execute({
        email: 'user@example.com',
        password: 'password123',
        name: 'New User'
      });
    }).rejects.toThrow(UserAlreadyExistsError);
  });

  test('should send welcome email', async () => {
    await useCase.execute({
      email: 'user@example.com',
      password: 'password123',
      name: 'John Doe'
    });

    expect(mockNotificationService.emailsSent).toContain('user@example.com');
  });
});
```

---

## 📋 アプリケーション層のチェックリスト

```
✅ ユースケースが明確に定義されている
✅ トランザクション管理がある
✅ エラーハンドリングが適切
✅ ビジネスロジックがドメイン層に移譲
✅ DTOへの変換がある
✅ 外部サービス呼び出しが適切に処理
✅ テストが容易なインターフェース設計
```

---

## ➡️ 次のステップ

次は、**ドメイン層**を学びます。これはビジネスルールの実装層です。

[次: ドメイン層 →](./03-domain-layer.md)
