# 08: ケーススタディ - 実世界の実装例

クリーンアーキテクチャを実際のビジネスドメインに適用した事例を通じて学習します。

---

## 📚 セクション構成

| プロジェクト | スケール | 複雑度 | 重点 |
|-----------|--------|------|------|
| **ECサイト** | 中規模 | ★★★★☆ | 複数の決済方法、在庫管理、注文フロー |
| **SNS** | 大規模 | ★★★★★ | フィード生成、キャッシング、スケーリング |
| **マイクロサービス** | 大規模 | ★★★★★ | サービス分割、非同期通信、サガパターン |

---

## 📦 ケース1: ECサイト（商品販売）

### 🎯 背景

ユーザーが商品を選び、複数の決済方法で購入できる E コマースプラットフォーム。

### 🏗️ ドメイン層の核

```typescript
// domain/entities/Order.ts
export class Order {
  constructor(
    public id: string,
    public userId: string,
    public items: OrderItem[],
    public payment: Payment,
    public status: OrderStatus
  ) {}

  addItem(product: Product, quantity: number): void {
    if (quantity <= 0) {
      throw new InvalidQuantityError('Quantity must be positive');
    }
    
    // ビジネスルール：在庫確認
    if (quantity > product.availableStock) {
      throw new OutOfStockError(product.id);
    }

    const item = new OrderItem(product, quantity);
    this.items.push(item);
  }

  getTotalPrice(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.getSubtotal()),
      Money.zero()
    );
  }

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
}

// domain/entities/Payment.ts
export class Payment {
  constructor(
    public id: string,
    public method: PaymentMethod,
    public amount: Money,
    public status: PaymentStatus
  ) {}

  approve(): void {
    if (this.status !== PaymentStatus.PENDING) {
      throw new PaymentAlreadyProcessedError(this.id);
    }
    this.status = PaymentStatus.APPROVED;
  }
}

// domain/value-objects/OrderStatus.ts
export enum OrderStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  SHIPPED = 'SHIPPED',
  DELIVERED = 'DELIVERED',
  CANCELED = 'CANCELED'
}
```

### 💼 アプリケーション層：複雑なユースケース

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
    return await this.transactionManager.run(async () => {
      // 1. ユーザー・商品を検証
      const user = await this.validateUser(request.userId);
      const products = await this.validateProducts(request.items);

      // 2. 注文を作成
      const order = new Order(uuid(), user.id, [], null, OrderStatus.PENDING);
      
      for (const item of request.items) {
        const product = products.find(p => p.id === item.productId);
        order.addItem(product, item.quantity);  // ドメインロジック
      }

      // 3. 在庫を予約
      await this.inventoryService.reserve(order.id, request.items);

      // 4. 決済を処理
      const payment = await this.paymentService.processPayment(
        request.paymentMethod,
        order.getTotalPrice()
      );
      order.payment = payment;

      // 5. 注文を確定
      order.status = OrderStatus.CONFIRMED;
      await this.orderRepository.save(order);

      // 6. 確認メール送信（非同期）
      await this.notificationService.sendOrderConfirmation(order);

      return { orderId: order.id };
    });
  }

  private async validateUser(userId: string): Promise<User> {
    const user = await this.userRepository.getById(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }
    return user;
  }

  private async validateProducts(items: OrderItem[]): Promise<Product[]> {
    // 複数の商品IDを一度に取得（N+1問題を避ける）
    const productIds = items.map(i => i.productId);
    return await this.productRepository.getByIds(productIds);
  }
}
```

### 🗄️ インフラ層：複雑なリポジトリ

```typescript
// infrastructure/repositories/MySQLOrderRepository.ts
export class MySQLOrderRepository implements OrderRepository {
  constructor(private connection: Pool) {}

  async save(order: Order): Promise<void> {
    await this.connection.query('BEGIN');
    try {
      // order テーブル
      await this.connection.query(
        'INSERT INTO orders (id, user_id, status, created_at) VALUES (?, ?, ?, ?)',
        [order.id, order.userId, order.status, new Date()]
      );

      // order_items テーブル
      for (const item of order.items) {
        await this.connection.query(
          'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES (?, ?, ?, ?)',
          [order.id, item.product.id, item.quantity, item.getSubtotal().value]
        );
      }

      // payments テーブル
      await this.connection.query(
        'INSERT INTO payments (id, order_id, method, amount, status) VALUES (?, ?, ?, ?, ?)',
        [order.payment.id, order.id, order.payment.method, order.getTotalPrice().value, order.payment.status]
      );

      await this.connection.query('COMMIT');
    } catch (error) {
      await this.connection.query('ROLLBACK');
      throw error;
    }
  }

  async getById(id: string): Promise<(Order | null)> {
    // JOIN で全データを一度取得（N+1 を避ける）
    const result = await this.connection.query(`
      SELECT 
        o.id, o.user_id, o.status,
        oi.product_id, oi.quantity, oi.price,
        p.id as payment_id, p.method, p.amount, p.status as payment_status
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN payments p ON o.id = p.order_id
      WHERE o.id = ?
    `, [id]);

    if (!result.length) {
      return null;
    }

    // 結果を集約ルートに再構築
    return this.reconstuctOrder(result);
  }
}
```

---

## 📱 ケース2: ソーシャルネットワーク

### 🎯 背景

高スループット、リアルタイムフィード、大量のユーザーを扱う SNS。重点：スケーラビリティ。

### 🏗️ ドメイン層：フィード関連

```typescript
// domain/entities/Post.ts
export class Post {
  constructor(
    public id: string,
    public authorId: string,
    public content: PostContent,
    public likeCount: number = 0,
    public commentCount: number = 0,
    public createdAt: Date = new Date()
  ) {}

  like(): void {
    this.likeCount++;
  }

  unlike(): void {
    if (this.likeCount > 0) {
      this.likeCount--;
    }
  }

  addComment(): void {
    this.commentCount++;
  }
}

// domain/value-objects/PostContent.ts
export class PostContent {
  constructor(public text: string) {
    if (text.length === 0 || text.length > 280) {
      throw new InvalidPostContentError('Content must be 1-280 characters');
    }
  }
}

// domain/services/FeedService.ts
export class FeedService {
  // フィード生成ロジック（複雑なビジネスルール）
  generateFeed(posts: Post[], userPreferences: UserPreferences): Post[] {
    return posts
      .filter(post => this.matchesUserInterests(post, userPreferences))
      .sort((a, b) => b.likeCount - a.likeCount)
      .slice(0, 50);
  }

  private matchesUserInterests(post: Post, prefs: UserPreferences): boolean {
    // ビジネスロジック
    return prefs.followedUserIds.includes(post.authorId);
  }
}
```

### 💼 アプリケーション層：キャッシング戦略

```typescript
// application/usecases/GetUserFeedUseCase.ts
export class GetUserFeedUseCase {
  constructor(
    private feedRepository: FeedRepository,
    private postRepository: PostRepository,
    private feedService: FeedService,
    private cacheService: CacheService
  ) {}

  async execute(userId: string, page: number): Promise<PostDTO[]> {
    // キャッシュキー
    const cacheKey = `feed:${userId}:${page}`;

    // キャッシュから取得
    const cached = await this.cacheService.get(cacheKey);
    if (cached) {
      return cached;
    }

    // キャッシュミス時
    const userPrefs = await this.getUserPreferences(userId);
    const posts = await this.feedRepository.getPosts(
      userPrefs.followedUserIds,
      { page, limit: 20 }
    );

    const feed = this.feedService.generateFeed(posts, userPrefs);
    const dtos = feed.map(post => PostDTO.fromEntity(post));

    // キャッシュに保存（60秒）
    await this.cacheService.set(cacheKey, dtos, 60);

    return dtos;
  }
}
```

### 🗄️ インフラ層：スケーリング対策

```typescript
// infrastructure/repositories/RedisPostRepository.ts
export class RedisPostRepository implements PostRepository {
  constructor(
    private redis: Redis,
    private mysql: Pool
  ) {}

  async save(post: Post): Promise<void> {
    // 書き込みは両方に
    await Promise.all([
      this.mysql.query('INSERT INTO posts ... VALUES ?', [post]),
      this.redis.set(`post:${post.id}`, JSON.stringify(post), 'EX', 3600)
    ]);

    // キャッシュキーリストに追加
    await this.redis.lpush('posts:latest', post.id);
    await this.redis.ltrim('posts:latest', 0, 1000);  // 最新1000件を保持
  }

  async getById(id: string): Promise<Post | null> {
    // キャッシュから優先的に
    let postData = await this.redis.get(`post:${id}`);
    
    if (!postData) {
      const result = await this.mysql.query('SELECT * FROM posts WHERE id = ?', [id]);
      if (!result.length) return null;
      
      postData = JSON.stringify(result[0]);
      await this.redis.setex(`post:${id}`, 3600, postData);
    }

    return JSON.parse(postData);
  }
}
```

---

## 🔀 ケース3: マイクロサービス

### 🎯 背景

複数の独立したサービス（User、Order、Payment、Inventory）が協調する大規模システム。重点：サービス分割と非同期通信。

### 🏗️ サービス境界

```typescript
// user-service/domain/User.ts
export class User {
  constructor(
    public id: string,
    public email: Email,
    public profile: Profile
  ) {}
}

// order-service/domain/Order.ts
export class Order {
  constructor(
    public id: string,
    public userId: string,  // 他サービスへの参照（ID のみ）
    public items: OrderItem[]
  ) {}
}

// payment-service/domain/Payment.ts
export class Payment {
  constructor(
    public id: string,
    public orderId: string,  // 他サービスへの参照（ID のみ）
    public amount: Money
  ) {}
}
```

### 💼 サービス間通信：非同期イベント

```typescript
// order-service/application/CreateOrderUseCase.ts
export class CreateOrderUseCase {
  constructor(
    private orderRepository: OrderRepository,
    private eventPublisher: EventPublisher,  // イベント配信
    private inventoryServiceClient: InventoryServiceClient  // 同期呼び出し
  ) {}

  async execute(request: CreateOrderRequest): Promise<void> {
    // 1. 在庫確認（同期）
    const available = await this.inventoryServiceClient
      .checkStock(request.items);
    
    if (!available) {
      throw new OutOfStockError();
    }

    // 2. 注文作成
    const order = new Order(
      uuid(),
      request.userId,
      request.items.map(item => new OrderItem(item.productId, item.quantity))
    );

    await this.orderRepository.save(order);

    // 3. イベント配信（支払いサービスが購読）
    await this.eventPublisher.publish(
      new OrderCreatedEvent(order.id, order.userId, order.getTotalPrice())
    );

    // 4. イベント配信（在庫サービスが購読）
    await this.eventPublisher.publish(
      new InventoryReservedEvent(order.id, request.items)
    );
  }
}

// payment-service/application/ProcessPaymentUseCase.ts
export class ProcessPaymentUseCase {
  @OnEvent('order.created')
  async handleOrderCreated(event: OrderCreatedEvent): Promise<void> {
    // 支払い処理を非同期で実行
    const payment = await this.processPayment(
      event.orderId,
      event.amount
    );

    // 完了イベントを配信
    await this.eventPublisher.publish(
      new PaymentProcessedEvent(payment.id, event.orderId, event.amount)
    );
  }
}
```

### 🔄 サガパターン：長時間トランザクション

```typescript
// order-service/application/sagas/CreateOrderSaga.ts
export class CreateOrderSaga {
  @Saga()
  async orchestrate(event$: Observable<IEvent>) {
    return event$.pipe(
      ofType(OrderCreatedEvent),
      mergeMap((event: OrderCreatedEvent) =>
        of(event).pipe(
          // Step 1: 在庫を予約
          mergeMap(() =>
            this.commandBus.send(
              new ReserveInventoryCommand(event.orderId, event.items)
            )
          ),
          // Step 2: 支払いを処理
          mergeMap(() =>
            this.commandBus.send(
              new ProcessPaymentCommand(event.orderId, event.amount)
            )
          ),
          // Step 3: 配送を手配
          mergeMap(() =>
            this.commandBus.send(
              new ArrangeShipmentCommand(event.orderId)
            )
          ),
          // エラー時のロールバック
          catchError(error => {
            this.commandBus.send(
              new CancelOrderCommand(event.orderId)
            );
            return throwError(error);
          })
        )
      )
    );
  }
}
```

---

## 📋 各ケースの学習ポイント

| ケース | 学べる設計パターン | リアルな課題 | 適用技術 |
|------|---------------------------|-------------|---------|
| EC | 集約設計、複雑なユースケース | 在庫管理、決済処理 | MySQL, Redis |
| SNS | キャッシング戦略、フィード生成 | スケーラビリティ | Redis, ElasticSearch |
| マイクロサービス | サービス分割、非同期通信 | サービス間通信、サガパターン | RabbitMQ, Event Sourcing |

---

## 🔗 関連セクション

- [ベストプラクティス](../06-best-practices/) - 実装品質
- [よくある間違い](../07-common-pitfalls/) - アンチパターン回避
- [ツール・リソース](../09-tools-and-resources/) - 実装支援ツール

---

**次: [ツール・リソース →](../09-tools-and-resources/)**
