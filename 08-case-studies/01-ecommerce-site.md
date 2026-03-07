# 01: ECサイト（注文・決済・在庫管理）

複数の決済方法、在庫管理、注文フロー、トランザクション管理を扱う中規模プロジェクト。

---

## 🎯 背景

ユーザーが商品を選び、複数の決済方法で購入できるEコマースプラットフォーム。

**実装すべき機能：**
- 商品カタログ管理
- ショッピングカート
- 注文作成・確認
- 複数の決済方法対応
- 在庫管理
- 注文キャンセル・返品

---

## 🏗️ ドメイン層

### エンティティ設計

```typescript
// domain/entities/Order.ts
export class Order {
  constructor(
    public id: string,
    public userId: string,
    public items: OrderItem[],
    public payment: Payment,
    public status: OrderStatus,
    public shippingAddress: Address
  ) {}

  addItem(product: Product, quantity: number): void {
    if (quantity <= 0) {
      throw new InvalidQuantityError('Quantity must be positive');
    }

    // ビジネスルール：在庫確認
    if (quantity > product.availableStock) {
      throw new OutOfStockError(
        `Product ${product.id} has only ${product.availableStock} in stock`
      );
    }

    const item = new OrderItem(product, quantity);
    this.items.push(item);
  }

  removeItem(itemIndex: number): void {
    if (itemIndex < 0 || itemIndex >= this.items.length) {
      throw new InvalidItemIndexError();
    }
    this.items.splice(itemIndex, 1);
  }

  getTotalPrice(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.getSubtotal()),
      Money.zero()
    );
  }

  // 状態遷移のビジネスルール
  canBeCanceled(): boolean {
    return this.status === OrderStatus.PENDING 
      || this.status === OrderStatus.CONFIRMED;
  }

  cancel(): void {
    if (!this.canBeCanceled()) {
      throw new OrderCannotBeCanceledError(this.id);
    }
    this.status = OrderStatus.CANCELED;
  }

  canBeShipped(): boolean {
    return this.status === OrderStatus.CONFIRMED 
      && this.payment.status === PaymentStatus.APPROVED;
  }

  ship(): void {
    if (!this.canBeShipped()) {
      throw new OrderCannotBeShippedError(this.id);
    }
    this.status = OrderStatus.SHIPPED;
  }
}

// domain/entities/OrderItem.ts
export class OrderItem {
  constructor(
    public product: Product,
    public quantity: number
  ) {
    if (quantity <= 0) {
      throw new InvalidQuantityError();
    }
  }

  getSubtotal(): Money {
    return this.product.price.multiply(this.quantity);
  }
}

// domain/entities/Payment.ts
export class Payment {
  constructor(
    public id: string,
    public method: PaymentMethod,
    public amount: Money,
    public status: PaymentStatus,
    public transactionId?: string
  ) {}

  approve(): void {
    if (this.status !== PaymentStatus.PENDING) {
      throw new PaymentAlreadyProcessedError(this.id);
    }
    this.status = PaymentStatus.APPROVED;
  }

  decline(): void {
    if (this.status !== PaymentStatus.PENDING) {
      throw new PaymentAlreadyProcessedError(this.id);
    }
    this.status = PaymentStatus.DECLINED;
  }

  refund(): void {
    if (this.status !== PaymentStatus.APPROVED) {
      throw new PaymentCannotBeRefundedError(this.id);
    }
    this.status = PaymentStatus.REFUNDED;
  }
}

// domain/value-objects
export enum PaymentMethod {
  CREDIT_CARD = 'CREDIT_CARD',
  DEBIT_CARD = 'DEBIT_CARD',
  PAYPAL = 'PAYPAL',
  BANK_TRANSFER = 'BANK_TRANSFER'
}

export enum OrderStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  SHIPPED = 'SHIPPED',
  DELIVERED = 'DELIVERED',
  CANCELED = 'CANCELED',
  REFUNDED = 'REFUNDED'
}

export enum PaymentStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  DECLINED = 'DECLINED',
  REFUNDED = 'REFUNDED'
}

// domain/value-objects/Address.ts
export class Address {
  constructor(
    public street: string,
    public city: string,
    public postalCode: string,
    public country: string
  ) {
    if (!street || !city || !postalCode) {
      throw new InvalidAddressError('Address is incomplete');
    }
  }
}
```

---

## 💼 アプリケーション層

### 複雑なユースケース

```typescript
// application/usecases/CreateOrderUseCase.ts
export class CreateOrderUseCase {
  constructor(
    private orderRepository: OrderRepository,
    private productRepository: ProductRepository,
    private paymentService: PaymentService,
    private inventoryService: InventoryService,
    private notificationService: NotificationService,
    private transactionManager: TransactionManager
  ) {}

  async execute(request: CreateOrderRequest): Promise<CreateOrderResponse> {
    // トランザクション内で実行
    return await this.transactionManager.run(async () => {
      // 1. ユーザーと商品を検証
      const user = await this.validateUser(request.userId);
      const products = await this.validateProducts(request.items);

      // 2. 注文を作成
      const order = new Order(
        uuid(),
        user.id,
        [],
        null,
        OrderStatus.PENDING,
        request.shippingAddress
      );

      // 3. アイテムを追加（ドメインロジック）
      for (const item of request.items) {
        const product = products.find(p => p.id === item.productId);
        order.addItem(product, item.quantity);
      }

      // 4. 在庫を予約
      const reservationId = await this.inventoryService.reserve(
        order.id,
        request.items
      );

      // 5. 決済を処理
      let payment: Payment;
      try {
        payment = await this.paymentService.processPayment(
          request.paymentMethod,
          order.getTotalPrice()
        );
      } catch (error) {
        // 決済失敗時は在庫予約をキャンセル
        await this.inventoryService.cancelReservation(reservationId);
        throw new PaymentFailedError(error.message);
      }

      order.payment = payment;
      payment.approve();  // 決済承認

      // 6. 注文を確定
      order.status = OrderStatus.CONFIRMED;
      await this.orderRepository.save(order);

      // 7. 確認メール送信（非同期、失敗しても続行）
      try {
        await this.notificationService.sendOrderConfirmation(order);
      } catch (error) {
        logger.error('Failed to send confirmation email', { orderId: order.id });
      }

      return { orderId: order.id, totalPrice: order.getTotalPrice() };
    });
  }

  private async validateUser(userId: string): Promise<User> {
    const user = await this.userRepository.getById(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }
    return user;
  }

  private async validateProducts(items: { productId: string; quantity: number }[]): Promise<Product[]> {
    const productIds = items.map(i => i.productId);
    const products = await this.productRepository.getByIds(productIds);

    if (products.length !== productIds.length) {
      throw new ProductNotFoundError();
    }

    return products;
  }
}

// application/usecases/CancelOrderUseCase.ts
export class CancelOrderUseCase {
  constructor(
    private orderRepository: OrderRepository,
    private paymentService: PaymentService,
    private inventoryService: InventoryService,
    private notificationService: NotificationService,
    private transactionManager: TransactionManager
  ) {}

  async execute(orderId: string): Promise<void> {
    return await this.transactionManager.run(async () => {
      const order = await this.orderRepository.getById(orderId);
      if (!order) {
        throw new OrderNotFoundError(orderId);
      }

      // ビジネスルール：キャンセル可否を確認
      if (!order.canBeCanceled()) {
        throw new OrderCannotBeCanceledError(orderId);
      }

      // 在庫を解放
      await this.inventoryService.releaseReservation(orderId);

      // 支払いを払戻
      if (order.payment.status === PaymentStatus.APPROVED) {
        await this.paymentService.refundPayment(order.payment.id);
        order.payment.refund();
      }

      // 注文をキャンセル状態に
      order.cancel();
      await this.orderRepository.save(order);

      // キャンセル通知を送信
      await this.notificationService.sendCancelConfirmation(order);
    });
  }
}
```

---

## 🗄️ インフラ層

### リレーショナルDB実装

```typescript
// infrastructure/repositories/MySQLOrderRepository.ts
export class MySQLOrderRepository implements OrderRepository {
  constructor(private connection: Pool) {}

  async save(order: Order): Promise<void> {
    await this.connection.query('BEGIN');
    try {
      // orders テーブル
      await this.connection.query(
        `INSERT INTO orders (id, user_id, status, shipping_address, created_at) 
         VALUES (?, ?, ?, ?, NOW())`,
        [
          order.id,
          order.userId,
          order.status,
          JSON.stringify(order.shippingAddress)
        ]
      );

      // order_items テーブル
      for (const item of order.items) {
        await this.connection.query(
          `INSERT INTO order_items (order_id, product_id, quantity, unit_price) 
           VALUES (?, ?, ?, ?)`,
          [
            order.id,
            item.product.id,
            item.quantity,
            item.product.price.value
          ]
        );
      }

      // payments テーブル
      await this.connection.query(
        `INSERT INTO payments (id, order_id, method, amount, status, transaction_id) 
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          order.payment.id,
          order.id,
          order.payment.method,
          order.getTotalPrice().value,
          order.payment.status,
          order.payment.transactionId || null
        ]
      );

      await this.connection.query('COMMIT');
    } catch (error) {
      await this.connection.query('ROLLBACK');
      throw new DatabaseError('Failed to save order');
    }
  }

  async getById(id: string): Promise<Order | null> {
    // N+1問題を避けるため JOIN で一度に取得
    const [results] = await this.connection.query(`
      SELECT 
        o.id, o.user_id, o.status, o.shipping_address,
        oi.product_id, oi.quantity, oi.unit_price,
        p.id as payment_id, p.method, p.amount, p.status as payment_status,
        p.transaction_id,
        pr.id as product_id_2, pr.name, pr.price as product_price
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN products pr ON oi.product_id = pr.id
      LEFT JOIN payments p ON o.id = p.order_id
      WHERE o.id = ?
    `, [id]);

    if (!results.length) {
      return null;
    }

    // 結果を集約ルート（Order）に再構築
    return this.reconstructOrder(results);
  }

  private reconstructOrder(rows: any[]): Order {
    const firstRow = rows[0];
    const order = new Order(
      firstRow.id,
      firstRow.user_id,
      [],
      null,
      firstRow.status,
      JSON.parse(firstRow.shipping_address)
    );

    // アイテムを集約
    const itemMap = new Map();
    rows.forEach(row => {
      if (row.product_id && !itemMap.has(row.product_id)) {
        const product = new Product(
          row.product_id_2,
          row.name,
          new Money(row.product_price)
        );
        itemMap.set(row.product_id, new OrderItem(product, row.quantity));
      }
    });

    order.items = Array.from(itemMap.values());

    // 支払い情報を集約
    if (firstRow.payment_id) {
      order.payment = new Payment(
        firstRow.payment_id,
        firstRow.method,
        new Money(firstRow.amount),
        firstRow.payment_status,
        firstRow.transaction_id
      );
    }

    return order;
  }
}
```

### 決済サービスアダプター

```typescript
// infrastructure/adapters/StripePaymentAdapter.ts
export class StripePaymentAdapter implements PaymentService {
  constructor(private stripeClient: Stripe) {}

  async processPayment(
    method: PaymentMethod,
    amount: Money
  ): Promise<Payment> {
    try {
      const charge = await this.stripeClient.charges.create({
        amount: amount.value * 100,  // セント単位
        currency: 'usd',
        source: method
      });

      if (charge.status !== 'succeeded') {
        throw new PaymentFailedError('Payment was not successful');
      }

      return new Payment(
        charge.id,
        method,
        amount,
        PaymentStatus.APPROVED,
        charge.id
      );
    } catch (error) {
      throw new PaymentFailedError(error.message);
    }
  }

  async refundPayment(paymentId: string): Promise<void> {
    try {
      await this.stripeClient.refunds.create({
        charge: paymentId
      });
    } catch (error) {
      throw new PaymentRefundFailedError(error.message);
    }
  }
}
```

---

## 🎯 重要な設計ポイント

### 1. 集約設計

**Order** を集約の根として、OrderItem と Payment は Order を通じて管理。
- 直接 Payment を削除できない（Order から削除）
- 直接 OrderItem を作成できない（Order.addItem() 経由）

### 2. トランザクション管理

複数テーブルの変更は必ずトランザクション内で。ロールバック戦略も重要。

### 3. N+1 問題を避ける

リポジトリは JOIN でデータを一度に取得し、メモリ上で再構築。

### 4. ドメインルールの一貫性

支払い承認条件、キャンセル可否などは全て Entity が責任を持つ。

---

## 📋 チェックリスト

```
ドメイン設計
✅ 集約が明確（Order が根）
✅ ビジネスルールが Entity に
✅ 値オブジェクトで型安全性確保
✅ 状態遷移ルールを定義

トランザクション
✅ 複数テーブル更新は同一トランザクション
✅ ロールバック戦略がある
✅ 部分的な失敗時の回復処理

データアクセス
✅ N+1 問題なし
✅ 適切なインデックス
✅ JOIN で効率的に取得
```

---

**次: [SNS プラットフォーム →](./02-sns-platform.md)**
