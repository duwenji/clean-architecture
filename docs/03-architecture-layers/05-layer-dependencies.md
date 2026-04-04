# 05. 層の依存関係ルール (Layer Dependency Rules)

> **最も重要なルール**: 内側の層は外側の層に依存しない。外側の層が内側の層に依存する一方向のみ。

## 🎯 依存方向の基本ルール

```
┌────────────────────────────┐
│  プレゼンテーション層       │       
│  (UI, Controller)          │
└────────────┬───────────────┘
             │
             ↓ 依存する
┌────────────────────────────┐
│  アプリケーション層         │       
│  (ユースケース)            │
└────────────┬───────────────┘
             │
             ↓ 依存する
┌────────────────────────────┐
│  ドメイン層                │
│  (ビジネスロジック)        │
└────────────┬───────────────┘
             │
             ↓ 依存する
┌────────────────────────────┐
│  インフラストラクチャ層     │       
│  (DB, API)                │
└────────────────────────────┘

重要：逆方向の依存は禁止
```

---

## ❌ 違反パターン

### 違反1：ドメイン層が外部フレームワークに依存

```typescript
// ❌ ダメな例：ドメイン層が Express に依存

import express = require('express');

export class User {
  constructor(private req: express.Request) {
    // Express がないとドメイン層が使えない
  }

  processLogin(): express.Response {
    // Express に依存している
  }
}
```

**問題:**
- Express がなければ動かない
- テストが困難（Express をセットアップ必須）
- フレームワーク変更が大変

---

### 違反2：ドメイン層が DB に直接依存

```typescript
// ❌ ダメな例：ドメイン層が MySQL に依存

import mysql = require('mysql');

export class Order {
  async getTotalPrice(): Promise<number> {
    const connection = mysql.createConnection({...});
    const result = await connection.query('SELECT SUM(price) FROM items');
    // DB がないとドメイン層が使えない
  }
}
```

**問題:**
- テスト時に DB 起動が必須
- DB を変更できない
- ビジネスロジックと DB 方言が混在

---

### 違反3：アプリケーション層がプレゼンテーション層に依存

```typescript
// ❌ ダメな例：アプリケーション層が HTTP に依存

import { Response } from 'express';

export class RegisterUserUseCase {
  async execute(req: Request, res: Response): Promise<void> {
    // HTTP ステータスコード
    res.status(201).json({...});
    // プレゼンテーション層への依存
  }
}
```

**問題:**
- CLI から呼べない
- GraphQL 対応できない
- ユースケース がプレゼンテーション形式に依存

---

## ✅ 正しいパターン

### 正しいパターン1：依存性逆転で抽象化

```typescript
// ✅ 良い例：インターフェースで抽象化

// ドメイン層：抽象化
export interface UserRepository {
  save(user: User): Promise<void>;
  findById(id: string): Promise<User | null>;
}

// ドメイン層：ビジネスロジック
export class User {
  constructor(id: string, email: string, password: string) {
    // 外部ツールに依存しない
  }
}

// アプリケーション層：インターフェース経由
export class RegisterUserUseCase {
  constructor(private userRepository: UserRepository) {}

  async execute(request: RegisterRequest): Promise<RegisterResponse> {
    const user = new User(uuid(), request.email, request.password);
    await this.userRepository.save(user);  // インターフェース使用
    return { id: user.getId(), email: user.getEmail() };
  }
}

// インフラストラクチャ層：具体的実装
export class MySQLUserRepository implements UserRepository {
  async save(user: User): Promise<void> {
    await this.db.query('INSERT INTO users ...', [...]);
  }
}

// プレゼンテーション層：複数メディア対応可能
export class UserRESTController {
  constructor(private registerUseCase: RegisterUserUseCase) {}

  async register(req: Request, res: Response): Promise<void> {
    const result = await this.registerUseCase.execute(req.body);
    res.status(201).json(result);
  }
}

export class UserCLICommand {
  constructor(private registerUseCase: RegisterUserUseCase) {}

  async execute(email: string, password: string): Promise<void> {
    const result = await this.registerUseCase.execute({ email, password });
    console.log(`User created: ${result.id}`);
  }
}
```

---

## 📊 依存関係の図解

### ❌ 違反設計

```
         UI層
          ↑
          │ 依存
          │
     ビジネス層
          ↑
          │ 依存
          │
       DB層

問題：下位層の変更が上位層全体に影響
```

### ✅ 正しい設計（依存性逆転）

```
    UI層 ←── インターフェース ──→ DB層
       ↖          ↙
         ビジネス層
         
すべてがインターフェースに依存
```

---

## 💻 実装例：複雑なユースケース

### ステップ1：ドメイン層（フレームワーク独立）

```typescript
// domain/entity/PaymentTransaction.ts
export class PaymentTransaction {
  private amount: Money;
  private status: TransactionStatus;

  constructor(amount: Money) {
    if (amount.getAmount() <= 0) {
      throw new InvalidAmountError();
    }
    this.amount = amount;
    this.status = TransactionStatus.PENDING;
  }

  complete(): void {
    this.status = TransactionStatus.COMPLETED;
  }

  fail(reason: string): void {
    this.status = TransactionStatus.FAILED;
  }

  // フレームワークに依存しない純粋なビジネスロジック
}

// domain/repository/PaymentTransactionRepository.ts
export interface PaymentTransactionRepository {
  save(transaction: PaymentTransaction): Promise<void>;
  findById(id: string): Promise<PaymentTransaction | null>;
}

// domain/service/PaymentProcessingService.ts
export interface PaymentProvider {
  charge(amount: number, paymentMethodId: string): Promise<ChargeResult>;
}

export class PaymentProcessingService {
  constructor(private paymentProvider: PaymentProvider) {}

  async processPayment(
    amount: Money,
    paymentMethodId: string
  ): Promise<PaymentTransaction> {
    const transaction = new PaymentTransaction(amount);

    try {
      const result = await this.paymentProvider.charge(
        amount.getAmount(),
        paymentMethodId
      );

      if (result.success) {
        transaction.complete();
      } else {
        transaction.fail(result.reason);
      }

      return transaction;
    } catch (error) {
      transaction.fail('Payment service error');
      throw error;
    }
  }
}
```

### ステップ2：アプリケーション層

```typescript
// application/usecase/ProcessPaymentUseCase.ts
export class ProcessPaymentUseCase {
  constructor(
    private paymentService: PaymentProcessingService,
    private transactionRepository: PaymentTransactionRepository,
    private notificationService: NotificationService
  ) {}

  async execute(request: ProcessPaymentRequest): Promise<ProcessPaymentResponse> {
    const amount = new Money(request.amount);

    // ドメインサービス呼び出し
    const transaction = await this.paymentService.processPayment(
      amount,
      request.paymentMethodId
    );

    // リポジトリで永続化
    await this.transactionRepository.save(transaction);

    // 通知サービス呼び出し
    if (transaction.isCompleted()) {
      await this.notificationService.sendPaymentConfirmation(
        request.email,
        transaction.getId()
      );
    }

    return {
      transactionId: transaction.getId(),
      status: transaction.getStatus(),
      amount: amount.getAmount()
    };
  }
}
```

### ステップ3：インフラストラクチャ層

```typescript
// infrastructure/persistence/MySQLPaymentRepository.ts
export class MySQLPaymentRepository implements PaymentTransactionRepository {
  async save(transaction: PaymentTransaction): Promise<void> {
    await this.db.query(
      'INSERT INTO payment_transactions (id, amount, status) VALUES (?, ?, ?)',
      [transaction.getId(), transaction.getAmount(), transaction.getStatus()]
    );
  }
}

// infrastructure/external/StripePaymentProvider.ts
export class StripePaymentProvider implements PaymentProvider {
  async charge(amount: number, paymentMethodId: string): Promise<ChargeResult> {
    try {
      const result = await stripe.paymentIntents.create({
        amount: amount * 100,
        payment_method: paymentMethodId,
        confirm: true
      });

      return {
        success: result.status === 'succeeded',
        chargeId: result.id,
        reason: result.last_payment_error?.message
      };
    } catch (error) {
      return {
        success: false,
        reason: 'API Error'
      };
    }
  }
}

// infrastructure/external/EmailNotificationService.ts
export class EmailNotificationService implements NotificationService {
  async sendPaymentConfirmation(email: string, transactionId: string): Promise<void> {
    await this.emailClient.send({
      to: email,
      subject: 'Payment Confirmed',
      template: 'payment-confirmation',
      variables: { transactionId }
    });
  }
}
```

### ステップ4：プレゼンテーション層

```typescript
// presentation/controller/PaymentController.ts
export class PaymentController {
  constructor(private processPaymentUseCase: ProcessPaymentUseCase) {}

  async handlePayment(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await this.processPaymentUseCase.execute({
        amount: req.body.amount,
        paymentMethodId: req.body.paymentMethodId,
        email: req.body.email
      });

      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  }
}

// presentation/cli/PaymentCommand.ts
export class PaymentCommand {
  constructor(private processPaymentUseCase: ProcessPaymentUseCase) {}

  async execute(amount: number, methodId: string, email: string): Promise<void> {
    const result = await this.processPaymentUseCase.execute({
      amount,
      paymentMethodId: methodId,
      email
    });

    console.log(`Payment processed: ${result.transactionId}`);
  }
}
```

---

## 🧪 依存関係を意識したテスト

```typescript
describe('ProcessPaymentUseCase - Dependency Layers', () => {
  // モック：すべてインターフェースで提供
  const paymentService = new MockPaymentService();
  const repository = new MockRepository();
  const notification = new MockNotificationService();

  test('should respect dependency rules', async () => {
    const useCase = new ProcessPaymentUseCase(
      paymentService,
      repository,
      notification
    );

    // DB を知らずにテスト可能
    const result = await useCase.execute({
      amount: 100,
      paymentMethodId: 'pm_123',
      email: 'user@example.com'
    });

    expect(result.transactionId).toBeDefined();
    expect(repository.savedCount).toBe(1);
  });

  test('should work with different payment provider', async () => {
    // 実装を切り替え可能
    const differentProvider = new DifferentPaymentProvider();
    const useCase = new ProcessPaymentUseCase(
      new PaymentProcessingService(differentProvider),
      repository,
      notification
    );

    // 同じテストが動く
    const result = await useCase.execute({...});
    expect(result).toBeDefined();
  });
});
```

---

## 📋 層の依存関係チェックリスト

```
✅ ドメイン層がフレームワークをインポートしていない
✅ ドメイン層が外部ライブラリをインポートしていない
✅ アプリケーション層が HTTP/CLI に依存していない
✅ リポジトリがインターフェースで定義されている
✅ 外部サービスがインターフェースで抽象化されている
✅ テストでモックが使用できる
✅ 実装を切り替え可能である
```

---

## 📊 全4層の依存関係まとめ

| 層 | 依存できる層 | 依存コンセプト |
|---|-----------|----------|
| **プレゼンテーション** | API層、ドメイン層、インフラ層 | UI形式 |
| **アプリケーション** | ドメイン層、インフラ層 | ユースケース |
| **ドメイン** | なし | ビジネスルール |
| **インフラストラクチャ** | なし（上層がインターフェース経由で依存） | 実装詳細 |

```
  何も依存しない（最も重要）
       ↑
  ドメイン層
       ↑ インターフェース経由
  他の全層
```

---

## ➡️ 次のステップ

4層の理論を理解したので、次は **デザインパターン**を学びます。これらはクリーンアーキテクチャを実装するための具体的なパターンです。

[次: デザインパターン →](../04-design-patterns/)
