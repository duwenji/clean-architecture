# 03: マイクロサービス（サービス分割・イベント駆動）

複数の独立したサービスが協調する大規模分散システム。重点：サービス分割、非同期通信、強い一貫性。

---

## 🎯 背景

ユーザー管理、注文処理、決済、在庫管理が のを独立したサービスとして運用される大規模ECプラットフォーム。

**サービス一覧：**
- User Service：ユーザー認証・プロフィール
- Order Service：注文管理
- Payment Service：決済処理
- Inventory Service：在庫管理
- Notification Service：通知

---

## 🏗️ サービス分割設計

### 各サービスのドメイン境界

```typescript
// user-service/domain/entities/User.ts
export class User {
  constructor(
    public id: string,
    public email: Email,
    public profile: Profile,
    public role: UserRole
  ) {}

  isAdmin(): boolean {
    return this.role === UserRole.ADMIN;
  }

  updateProfile(profile: Profile): void {
    this.profile = profile;
  }
}

// order-service/domain/entities/Order.ts
// ⚠️ 他サービスへの参照は ID のみ
export class Order {
  constructor(
    public id: string,
    public userId: string,  // User Service への外部キー
    public items: OrderItem[],
    public status: OrderStatus
  ) {}

  canBeCreated(): boolean {
    // Order Service のルール（User の詳細は不要）
    return this.items.length > 0;
  }
}

// payment-service/domain/entities/Payment.ts
export class Payment {
  constructor(
    public id: string,
    public orderId: string,  // Order Service への外部キー
    public amount: Money,
    public method: PaymentMethod,
    public status: PaymentStatus
  ) {}

  canBeProcessed(): boolean {
    return this.status === PaymentStatus.PENDING;
  }
}

// inventory-service/domain/entities/Stock.ts
export class Stock {
  constructor(
    public id: string,
    public productId: string,
    public quantity: number,
    public reservedQuantity: number = 0
  ) {}

  getAvailable(): number {
    return this.quantity - this.reservedQuantity;
  }

  canReserve(amount: number): boolean {
    return this.getAvailable() >= amount;
  }

  reserve(amount: number): void {
    if (!this.canReserve(amount)) {
      throw new InsufficientStockError();
    }
    this.reservedQuantity += amount;
  }

  release(amount: number): void {
    this.reservedQuantity -= amount;
  }
}
```

---

## 💼 イベント駆動アーキテクチャ

### イベント定義

```typescript
// shared/events/index.ts（すべてのサービスが参照）

export abstract class DomainEvent {
  public readonly eventId: string;
  public readonly occurredAt: Date;

  constructor() {
    this.eventId = uuid();
    this.occurredAt = new Date();
  }

  abstract getAggregateId(): string;
}

// ユーザー作成イベント
export class UserCreatedEvent extends DomainEvent {
  constructor(
    public readonly userId: string,
    public readonly email: string
  ) {
    super();
  }

  getAggregateId(): string {
    return this.userId;
  }
}

// 注文作成イベント（サービス間通信の中心）
export class OrderCreatedEvent extends DomainEvent {
  constructor(
    public readonly orderId: string,
    public readonly userId: string,
    public readonly items: Array<{
      productId: string;
      quantity: number;
      price: number;
    }>,
    public readonly totalAmount: number
  ) {
    super();
  }

  getAggregateId(): string {
    return this.orderId;
  }
}

// 決済承認イベント
export class PaymentApprovedEvent extends DomainEvent {
  constructor(
    public readonly paymentId: string,
    public readonly orderId: string,
    public readonly amount: number
  ) {
    super();
  }

  getAggregateId(): string {
    return this.paymentId;
  }
}

// 決済失敗イベント
export class PaymentFailedEvent extends DomainEvent {
  constructor(
    public readonly orderId: string,
    public readonly reason: string
  ) {
    super();
  }

  getAggregateId(): string {
    return this.orderId;
  }
}

// 在庫予約イベント
export class InventoryReservedEvent extends DomainEvent {
  constructor(
    public readonly orderId: string,
    public readonly items: Array<{
      productId: string;
      quantity: number;
    }>
  ) {
    super();
  }

  getAggregateId(): string {
    return this.orderId;
  }
}

// 在庫予約失敗イベント
export class InventoryReservationFailedEvent extends DomainEvent {
  constructor(
    public readonly orderId: string,
    public readonly failedProductId: string
  ) {
    super();
  }

  getAggregateId(): string {
    return this.orderId;
  }
}
```

### Order Service：イベント配信

```typescript
// order-service/application/CreateOrderUseCase.ts
export class CreateOrderUseCase {
  constructor(
    private orderRepository: OrderRepository,
    private eventPublisher: EventPublisher,
    private inventoryServiceClient: InventoryServiceClient
  ) {}

  async execute(request: CreateOrderRequest): Promise<CreateOrderResponse> {
    // 1. 注文を作成
    const order = new Order(
      uuid(),
      request.userId,
      request.items.map(item => new OrderItem(item.productId, item.quantity, item.price)),
      OrderStatus.PENDING
    );

    // ビジネスルール確認
    if (!order.canBeCreated()) {
      throw new InvalidOrderError('Order must have at least one item');
    }

    // 2. DB に保存
    await this.orderRepository.save(order);

    // 3. イベントをパブリッシュ（他サービスがアクション起こす）
    const event = new OrderCreatedEvent(
      order.id,
      request.userId,
      request.items,
      request.items.reduce((sum, item) => sum + item.price * item.quantity, 0)
    );

    await this.eventPublisher.publish(event);

    logger.info('Order created and event published', { orderId: order.id });

    return { orderId: order.id };
  }
}
```

### Inventory Service：イベントリスナー

```typescript
// inventory-service/application/EventHandlers.ts
export class OrderCreatedEventHandler {
  constructor(
    private stockRepository: StockRepository,
    private eventPublisher: EventPublisher,
    private transactionManager: TransactionManager
  ) {}

  @OnEvent('order.created')
  async handle(event: OrderCreatedEvent): Promise<void> {
    try {
      await this.transactionManager.run(async () => {
        // 1. 在庫確認
        for (const item of event.items) {
          const stock = await this.stockRepository.getByProductId(item.productId);

          if (!stock || !stock.canReserve(item.quantity)) {
            throw new InsufficientStockError(item.productId);
          }
        }

        // 2. 在庫予約
        for (const item of event.items) {
          const stock = await this.stockRepository.getByProductId(item.productId);
          stock.reserve(item.quantity);
          await this.stockRepository.update(stock);
        }

        // 3. 成功イベントを配信
        await this.eventPublisher.publish(
          new InventoryReservedEvent(
            event.orderId,
            event.items
          )
        );

        logger.info('Inventory reserved', { orderId: event.orderId });
      });
    } catch (error) {
      // 在庫不足 → 失敗イベント配信
      await this.eventPublisher.publish(
        new InventoryReservationFailedEvent(event.orderId, error.productId)
      );

      logger.warn('Inventory reservation failed', {
        orderId: event.orderId,
        reason: error.message
      });
    }
  }
}
```

### Payment Service：イベントリスナー

```typescript
// payment-service/application/EventHandlers.ts
export class InventoryReservedEventHandler {
  constructor(
    private paymentService: PaymentGateway,
    private paymentRepository: PaymentRepository,
    private eventPublisher: EventPublisher
  ) {}

  @OnEvent('inventory.reserved')
  async handle(event: InventoryReservedEvent): Promise<void> {
    try {
      // 注文情報を取得（Order Service に同期呼び出し）
      const order = await this.orderServiceClient.getOrder(event.orderId);

      // 決済処理
      const payment = await this.paymentService.authorize(
        order.userId,
        order.totalAmount
      );

      await this.paymentRepository.save(payment);

      // 成功イベント配信
      await this.eventPublisher.publish(
        new PaymentApprovedEvent(
          payment.id,
          event.orderId,
          order.totalAmount
        )
      );

      logger.info('Payment approved', { orderId: event.orderId });
    } catch (error) {
      // 決済失敗 → ロールバック開始
      await this.eventPublisher.publish(
        new PaymentFailedEvent(event.orderId, error.message)
      );

      logger.error('Payment failed', { orderId: event.orderId, error });
    }
  }
}
```

---

## 🔄 Saga パターン（オーケストレーション）

```typescript
// order-service/sagas/CreateOrderSaga.ts
@Injectable()
export class CreateOrderSaga {
  constructor(
    private commandBus: CommandBus,
    private eventBus: EventBus
  ) {}

  @Saga()
  orderCreated = (events$: Observable<IEvent>) => {
    return events$.pipe(
      ofType(OrderCreatedEvent),
      
      // Step 1: 在庫予約
      mergeMap((event: OrderCreatedEvent) =>
        of(new ReserveInventoryCommand(event.orderId, event.items)).pipe(
          mergeMap(cmd => this.commandBus.execute(cmd)),
          timeout(5000),  // 5秒でタイムアウト
          catchError(() => of(new CancelOrderCommand(event.orderId)))
        )
      ),

      // Step 2: 決済処理
      mergeMap((result: any) => {
        if (result instanceof CancelOrderCommand) {
          return of(result);  // ロールバック
        }

        return of(
          new ProcessPaymentCommand(event.orderId, event.totalAmount)
        ).pipe(
          mergeMap(cmd => this.commandBus.execute(cmd)),
          timeout(5000),
          catchError(() => of(new CancelOrderCommand(event.orderId)))
        );
      }),

      // Step 3: 配送手配
      mergeMap((result: any) => {
        if (result instanceof CancelOrderCommand) {
          return of(result);  // ロールバック
        }

        return of(
          new ArrangeShipmentCommand(event.orderId)
        ).pipe(
          mergeMap(cmd => this.commandBus.execute(cmd))
        );
      }),

      // エラー処理：サガ失敗時のキャンセルフローを発行
      catchError((error: any) =>
        of(new CancelOrderCommand(event.orderId))
      )
    );
  };

  @EventPattern('payment.failed')
  handlePaymentFailed(event: PaymentFailedEvent) {
    // Payment Service から通知（イベント）
    // Inventory のロックを解除
    this.commandBus.execute(
      new ReleaseInventoryCommand(event.orderId)
    );
  }
}
```

---

## 🗄️ イベントソーシング（オプション）

```typescript
// shared/event-store/EventStore.ts
export class EventStore {
  async append(event: DomainEvent): Promise<void> {
    // イベントログテーブルに append only で追加
    await this.db.query(`
      INSERT INTO events (aggregate_id, event_type, payload, created_at)
      VALUES (?, ?, ?, NOW())
    `, [
      event.getAggregateId(),
      event.constructor.name,
      JSON.stringify(event)
    ]);
  }

  async getEvents(aggregateId: string): Promise<DomainEvent[]> {
    // aggregateId のイベント履歴を取得
    const [rows] = await this.db.query(`
      SELECT payload FROM events
      WHERE aggregate_id = ?
      ORDER BY created_at ASC
    `, [aggregateId]);

    return rows.map(row => JSON.parse(row.payload));
  }

  // イベント再生で状態を復元
  async rebuild(aggregateId: string): Promise<Order> {
    const events = await this.getEvents(aggregateId);
    let order = null;

    for (const event of events) {
      if (event instanceof OrderCreatedEvent) {
        order = new Order(event.orderId, event.userId, [], OrderStatus.PENDING);
      } else if (event instanceof PaymentApprovedEvent) {
        order.status = OrderStatus.CONFIRMED;
      } else if (event instanceof OrderShippedEvent) {
        order.status = OrderStatus.SHIPPED;
      }
    }

    return order;
  }
}
```

---

## 📋 チェックリスト

```
サービス分割
✅ 各サービスが独立して展開可能
✅ データベースが独立
✅ サービス間は ID のみで参照

イベント駆動
✅ メッセージブローカー（RabbitMQ/Kafka）で通信
✅ イベントスキーマが版管理されている
✅ 非同期処理のタイムアウト設定

可用性・回復
✅ サガパターンでロールバック戦略がある
✅ デッドレターキューで失敗メッセージ保管
✅ リトライ戦略が定義されている
✅ Circuit Breaker パターン実装

監視
✅ サービス間の遅延を監視
✅ イベント配信遅延を監視
✅ デッドレターキュー監視アラート
```

---

## 関連リソース

- **メッセージング：** RabbitMQ, Apache Kafka, AWS SQS
- **マイクロサービスフレームワーク：** NestJS, Spring Cloud, Express + Decorators
- **分散トレーシング：** Jaeger, Zipkin

---

**完了！マイクロサービス構築マスター 🏭**
