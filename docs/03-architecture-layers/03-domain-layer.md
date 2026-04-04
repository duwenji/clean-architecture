# 03. ドメイン層 (Domain Layer)

> **責務**: ビジネスルール。金銭計算、バリデーション、状態管理など、ビジネスに必要なロジックを実装する。最も重要な層。

## 🎯 層の位置付け

```
┌──────────────────────────┐
│  プレゼンテーション層     │
├──────────────────────────┤
│  アプリケーション層       │
├──────────────────────────┤
│  ドメイン層              │  ← ここ
│ (ビジネスロジック)       │
├──────────────────────────┤
│  インフラストラクチャ層   │
│ (DB, 外部API)           │
└──────────────────────────┘
```

---

## 📋 ドメイン層の責務

```
✅ ドメイン層が担当：
  - ビジネスルール実装
  - エンティティの定義
  - 値オブジェクト
  - ドメインロジック
  - バリデーション
  - 状態管理

❌ ドメイン層がしてはいけない：
  - フレームワークに依存
  - DBアクセス
  - HTTPスタッフの知識
  - UI の知識
```

---

## 🏗️ 典型的なドメイン層の構成

```
domain/
├── entity/
│   ├── User.ts
│   ├── Order.ts
│   ├── Product.ts
│   └── ...
├── value-object/
│   ├── Email.ts
│   ├── Money.ts
│   ├── Address.ts
│   └── ...
├── repository/
│   ├── UserRepository.ts  (インターフェース)
│   ├── OrderRepository.ts
│   └── ...
├── service/
│   ├── UserDomainService.ts
│   ├── OrderDomainService.ts
│   └── ...
└── exception/
    ├── InvalidEmailError.ts
    ├── InsufficientBalanceError.ts
    └── ...
```

---

## 💻 実装例1：値オブジェクト

### Email 値オブジェクト

```typescript
// domain/value-object/Email.ts

export class Email {
  private value: string;

  constructor(value: string) {
    if (!this.isValid(value)) {
      throw new InvalidEmailError(value);
    }
    // 不変性：大文字小文字を正規化して保存
    this.value = value.toLowerCase().trim();
  }

  getValue(): string {
    return this.value;
  }

  // 値オブジェクトは値で比較
  equals(other: Email): boolean {
    return this.value === other.getValue();
  }

  private isValid(email: string): boolean {
    const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return regex.test(email);
  }
}
```

### Money 値オブジェクト

```typescript
// domain/value-object/Money.ts

export class Money {
  private amount: number;
  private currency: string;

  constructor(amount: number, currency: string = 'JPY') {
    if (amount < 0) {
      throw new NegativeMoneyError(amount);
    }
    this.amount = Math.round(amount * 100) / 100;  // 小数点以下2位まで
    this.currency = currency;
  }

  add(other: Money): Money {
    if (this.currency !== other.currency) {
      throw new CurrencyMismatchError(this.currency, other.currency);
    }
    return new Money(this.amount + other.amount, this.currency);
  }

  subtract(other: Money): Money {
    if (this.currency !== other.currency) {
      throw new CurrencyMismatchError(this.currency, other.currency);
    }
    if (this.amount < other.amount) {
      throw new InsufficientFundsError(this.amount, other.amount);
    }
    return new Money(this.amount - other.amount, this.currency);
  }

  multiply(factor: number): Money {
    return new Money(this.amount * factor, this.currency);
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency;
  }

  getAmount(): number {
    return this.amount;
  }

  getCurrency(): string {
    return this.currency;
  }
}
```

### Address 値オブジェクト

```typescript
// domain/value-object/Address.ts

export class Address {
  private prefecture: string;
  private city: string;
  private street: string;
  private postalCode: string;

  constructor(prefecture: string, city: string, street: string, postalCode: string) {
    if (!prefecture || !city || !street || !postalCode) {
      throw new InvalidAddressError('All fields required');
    }
    this.prefecture = prefecture;
    this.city = city;
    this.street = street;
    this.postalCode = postalCode;
  }

  getFullAddress(): string {
    return `${this.postalCode} ${this.prefecture}${this.city}${this.street}`;
  }

  equals(other: Address): boolean {
    return (
      this.prefecture === other.prefecture &&
      this.city === other.city &&
      this.street === other.street &&
      this.postalCode === other.postalCode
    );
  }

  // 配送可能かチェック（ビジネスルール）
  isShippableRegion(): boolean {
    const unshippableRegions = ['北方領土', '占守島'];
    return !unshippableRegions.includes(this.prefecture);
  }
}
```

---

## 💻 実装例2：エンティティ

### User エンティティ

```typescript
// domain/entity/User.ts

export class User {
  private id: string;
  private email: Email;  // 値オブジェクト
  private password: HashedPassword;  // 値オブジェクト
  private name: string;
  private status: UserStatus;  // enum または値オブジェクト
  private createdAt: Date;
  private updatedAt: Date;

  constructor(
    id: string,
    email: Email,
    password: HashedPassword,
    name: string
  ) {
    // バリデーション
    if (!id || !email || !password || !name) {
      throw new InvalidUserError('All fields required');
    }

    if (name.length > 100) {
      throw new InvalidUserError('Name too long');
    }

    // 初期化
    this.id = id;
    this.email = email;
    this.password = password;
    this.name = name;
    this.status = UserStatus.ACTIVE;
    this.createdAt = new Date();
    this.updatedAt = new Date();
  }

  // ID による比較（エンティティは ID で比較）
  equals(other: User): boolean {
    return this.id === other.id;
  }

  // ビジネスロジック：ユーザーアクティブ化
  activate(): void {
    if (this.status === UserStatus.ACTIVE) {
      throw new UserAlreadyActiveError(this.id);
    }
    this.status = UserStatus.ACTIVE;
    this.updatedAt = new Date();
  }

  // ビジネスロジック：ユーザー削除
  deactivate(): void {
    if (this.status === UserStatus.INACTIVE) {
      throw new UserAlreadyInactiveError(this.id);
    }
    this.status = UserStatus.INACTIVE;
    this.updatedAt = new Date();
  }

  // ビジネスロジック：プロフィール更新（制約がある）
  updateProfile(newName: string): void {
    if (this.status !== UserStatus.ACTIVE) {
      throw new CannotUpdateInactiveUserError(this.id);
    }

    if (newName.length > 100) {
      throw new InvalidNameError('Name too long');
    }

    this.name = newName;
    this.updatedAt = new Date();
  }

  // Getter（読み取り専用）
  getId(): string {
    return this.id;
  }

  getEmail(): Email {
    return this.email;
  }

  getPassword(): HashedPassword {
    return this.password;
  }

  getName(): string {
    return this.name;
  }

  getStatus(): UserStatus {
    return this.status;
  }

  getCreatedAt(): Date {
    return this.createdAt;
  }
}

// User の状態を表すEnum
export enum UserStatus {
  ACTIVE = 'ACTIVE',
  INACTIVE = 'INACTIVE',
  SUSPENDED = 'SUSPENDED'
}
```

### Order エンティティ（複雑な例）

```typescript
// domain/entity/Order.ts

export class Order {
  private id: string;
  private userId: string;
  private items: OrderItem[];  // 値オブジェクトの配列
  private totalPrice: Money;  // 値オブジェクト
  private shippingAddress: Address;  // 値オブジェクト
  private status: OrderStatus;
  private createdAt: Date;
  private estimatedDelivery: Date;

  constructor(
    id: string,
    userId: string,
    items: OrderItem[],
    totalPrice: Money,
    shippingAddress: Address,
    estimatedDelivery: Date
  ) {
    // バリデーション
    if (items.length === 0) {
      throw new InvalidOrderError('Order must have at least one item');
    }

    if (!shippingAddress.isShippableRegion()) {
      throw new UnshippableRegionError(shippingAddress);
    }

    // 合計金額の検証
    const calculatedTotal = this.calculateTotal(items);
    if (!calculatedTotal.equals(totalPrice)) {
      throw new InvalidOrderPriceError();
    }

    this.id = id;
    this.userId = userId;
    this.items = items;
    this.totalPrice = totalPrice;
    this.shippingAddress = shippingAddress;
    this.status = OrderStatus.PENDING;
    this.createdAt = new Date();
    this.estimatedDelivery = estimatedDelivery;
  }

  // ビジネスロジック：注文確定
  confirm(): void {
    if (this.status !== OrderStatus.PENDING) {
      throw new InvalidOrderStatusError('Can only confirm pending orders');
    }
    this.status = OrderStatus.CONFIRMED;
  }

  // ビジネスロジック：注文キャンセル（制約あり）
  cancel(): void {
    const cancellableStatuses = [
      OrderStatus.PENDING,
      OrderStatus.CONFIRMED
    ];

    if (!cancellableStatuses.includes(this.status)) {
      throw new NonCancellableOrderError(this.id, this.status);
    }

    this.status = OrderStatus.CANCELLED;
  }

  // ビジネスロジック：割引の適用
  applyDiscount(discountPercentage: number): void {
    if (discountPercentage < 0 || discountPercentage > 100) {
      throw new InvalidDiscountError(discountPercentage);
    }

    const discountAmount = this.totalPrice.multiply(discountPercentage / 100);
    this.totalPrice = this.totalPrice.subtract(discountAmount);
  }

  // Getter
  getId(): string {
    return this.id;
  }

  getUserId(): string {
    return this.userId;
  }

  getItems(): OrderItem[] {
    return this.items;
  }

  getTotalPrice(): Money {
    return this.totalPrice;
  }

  getStatus(): OrderStatus {
    return this.status;
  }

  private calculateTotal(items: OrderItem[]): Money {
    return items.reduce(
      (sum, item) => sum.add(item.price.multiply(item.quantity)),
      new Money(0)
    );
  }
}

export interface OrderItem {
  productId: string;
  quantity: number;
  price: Money;
}

export enum OrderStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  SHIPPED = 'SHIPPED',
  DELIVERED = 'DELIVERED',
  CANCELLED = 'CANCELLED'
}
```

---

## 💻 実装例3：ドメインサービス

```typescript
// domain/service/TransferDomainService.ts

export class TransferDomainService {
  // 2つのアカウント間でお金を移動
  transfer(
    fromAccount: Account,
    toAccount: Account,
    amount: Money
  ): Transfer {
    // ビジネスルール：出金元が十分なお金を持っているか
    if (fromAccount.getBalance().getAmount() < amount.getAmount()) {
      throw new InsufficientBalanceError(
        fromAccount.getBalance(),
        amount
      );
    }

    // ビジネスルール：同じ通貨か
    if (fromAccount.getBalance().getCurrency() !== amount.getCurrency()) {
      throw new CurrencyMismatchError(
        fromAccount.getBalance().getCurrency(),
        amount.getCurrency()
      );
    }

    // ビジネスルール：両方が活動中か
    if (!fromAccount.isActive() || !toAccount.isActive()) {
      throw new InactiveAccountError();
    }

    // トランザクション作成
    const transfer = new Transfer(
      uuid(),
      fromAccount.getId(),
      toAccount.getId(),
      amount,
      new Date()
    );

    // アカウント残高を更新
    fromAccount.debit(amount);
    toAccount.credit(amount);

    return transfer;
  }
}
```

---

## 🧪 テスト例

```typescript
describe('Order Domain Entity', () => {
  describe('creation', () => {
    test('should create order with valid data', () => {
      const items = [
        new OrderItem('product-1', 2, new Money(1000)),
        new OrderItem('product-2', 1, new Money(500))
      ];
      const totalPrice = new Money(2500);
      const address = new Address('東京都', '渋谷区', '1-2-3', '150-0001');

      const order = new Order(
        'order-1',
        'user-1',
        items,
        totalPrice,
        address,
        new Date('2025-01-10')
      );

      expect(order.getId()).toBe('order-1');
      expect(order.getStatus()).toBe(OrderStatus.PENDING);
    });

    test('should reject empty items', () => {
      expect(() => {
        new Order(
          'order-1',
          'user-1',
          [],  // 空
          new Money(0),
          new Address('東京都', '渋谷区', '1-2-3', '150-0001'),
          new Date('2025-01-10')
        );
      }).toThrow(InvalidOrderError);
    });

    test('should reject incorrect total price', () => {
      const items = [
        new OrderItem('product-1', 2, new Money(1000))
      ];
      const wrongTotal = new Money(5000);  // 正解は2000

      expect(() => {
        new Order(
          'order-1',
          'user-1',
          items,
          wrongTotal,
          new Address('東京都', '渋谷区', '1-2-3', '150-0001'),
          new Date('2025-01-10')
        );
      }).toThrow(InvalidOrderPriceError);
    });
  });

  describe('business logic', () => {
    test('should apply discount', () => {
      const order = createValidOrder(new Money(10000));

      order.applyDiscount(10);  // 10% 割引

      expect(order.getTotalPrice().getAmount()).toBe(9000);
    });

    test('should reject invalid discount', () => {
      const order = createValidOrder(new Money(10000));

      expect(() => {
        order.applyDiscount(150);  // 150% は不可
      }).toThrow(InvalidDiscountError);
    });

    test('should allow cancellation only in certain states', () => {
      const order = createValidOrder(new Money(10000));
      order.confirm();

      expect(() => {
        order.cancel();  // 確認済み注文はキャンセル可能
      }).not.toThrow();

      order.ship();  // 発送済みに変更

      expect(() => {
        order.cancel();  // 発送済み注文はキャンセル不可
      }).toThrow(NonCancellableOrderError);
    });
  });
});
```

---

## 📋 ドメイン層のチェックリスト

```
✅ ビジネスルールが集約されている
✅ 値オブジェクトが使われている
✅ エンティティが正しく定義されている
✅ インターフェースで外部依存を隔離
✅ 例外が明確（ビジネス例外）
✅ テストがビジネスロジック中心
✅ フレームワーク依存がない
```

---

## ➡️ 次のステップ

次は、**インフラストラクチャ層**を学びます。ここでビジネスロジックは外部ツール（DB、メール、API）と連携します。

[次: インフラストラクチャ層 →](./04-infrastructure-layer.md)
