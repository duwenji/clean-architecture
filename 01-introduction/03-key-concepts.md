# 03. クリーンアーキテクチャの3つの主要概念

> **コンセプト**: クリーンアーキテクチャは3つの重要な特性で成り立っている：独立性、テスト性、保守性。

## 🎯 3つの主要概念

```
┌──────────────────────────────────────────────┐
│   クリーンアーキテクチャの3本柱              │
├──────────────────────────────────────────────┤
│ 1️⃣  独立性 (Independence)                   │
│    ビジネスロジックがフレームワークに依存しない│
├──────────────────────────────────────────────┤
│ 2️⃣  テスト性 (Testability)                  │
│    外部ツールなしにテストできる              │
├──────────────────────────────────────────────┤
│ 3️⃣  保守性 (Maintainability)                │
│    変更が局所的で、相互影響が少ない          │
└──────────────────────────────────────────────┘
```

---

## 1️⃣ 独立性 (Independence)

### コンセプト
ビジネスロジック（ドメイン層）は、フレームワーク、DB、Webサーバーなどの外部ツールに**依存しない**という特性。

### ❌ 独立性がない例

```typescript
// ドメインクラスがExpressに依存している
import { Request, Response } from 'express';

export class User {
  constructor(private req: Request) {
    // Requestオブジェクトがないと作成できない
    this.email = req.body.email;
  }

  sendEmail(res: Response) {
    // Responseオブジェクトがないとメールできない
    res.send('Email sent');
  }
}
```

**問題:**
- 🔴 Expressなしに使用できない
- 🔴 他のフレームワークに移行できない
- 🔴 CLI から使用できない

---

### ✅ 独立性がある例

```typescript
// ドメインクラスはフレームワークに依存しない
export class User {
  constructor(
    private id: string,
    private email: string,
    private password: string
  ) {
    // 外部ツールがなくても動作
  }

  // 通常のメソッド
  getEmail(): string {
    return this.email;
  }

  // メール送信は別のサービスに任せる
  requestEmailNotification(): void {
    // これはドメインロジックではなく、
    // アプリケーション層が処理する
  }
}

// 使用例1: Web API
const user = new User('1', 'user@example.com', 'pass');
res.json(user.getEmail());

// 使用例2: CLI
const user = new User('1', 'user@example.com', 'pass');
console.log(user.getEmail());

// どちらでも同じユーザークラスが使える！
```

### 📊 独立性の利点

| シナリオ | 影響 |
|---------|-----|
| **ExpressからFastifyに移行** | UI層のみ変更 |
| **MySQLからPostgreSQLに移行** | インフラ層のみ変更 |
| **Webからモバイルに追加展開** | ドメイン・アプリケーション層は流用 |
| **テスト環境での実行** | モックで十分 |

---

## 2️⃣ テスト性 (Testability)

### コンセプト
単体テスト（ユニットテスト）が簡単に書けて、高速に実行できる特性。

### ❌ テスト性が低い例

```typescript
// 外部依存が多い
export class PaymentService {
  async processPayment(userId: string, amount: number) {
    // 必須：ユーザーDB
    const user = await db.getUser(userId);
    
    // 必須：支払いゲートウェイAPI
    const result = await stripe.charge(user.paymentMethod, amount);
    
    // 必須：メールサーバー
    await emailService.sendReceipt(user.email);
    
    // 必須：決済ログDB
    await db.saveTransaction(userId, amount, result.id);
    
    return result;
  }
}

// テスト
describe('PaymentService', () => {
  test('should process payment', async () => {
    // 🔴 DBを起動
    const db = await startDatabase();
    
    // 🔴 支払いゲートウェイをモック
    const stripe = mockStripe();
    
    // 🔴 メールサーバーをモック
    const emailService = mockEmailService();
    
    // テスト（30秒かかる）
    const service = new PaymentService(db, stripe, emailService);
    const result = await service.processPayment('user-1', 100);
    
    // テスト後の後片付け
    await db.close();
    
    expect(result.success).toBe(true);
  });
});
```

**問題:**
- 🔴 実行時間が長い（DB起動に数秒）
- 🔴 テストが脆弱（ネットワークエラーで失敗）
- 🔴 複数のテストの外部依存が競合する

---

### ✅ テスト性が高い例

#### **Step 1: リポジトリで抽象化**

```typescript
// インターフェース（ドメイン層）
export interface UserRepository {
  getUser(userId: string): Promise<User>;
  saveTransaction(userId: string, amount: number, txId: string): Promise<void>;
}

export interface PaymentGateway {
  charge(paymentMethod: string, amount: number): Promise<PaymentResult>;
}

export interface NotificationService {
  sendReceipt(email: string, amount: number): Promise<void>;
}
```

#### **Step 2: 依存性注入**

```typescript
// アプリケーション層
export class ProcessPaymentUseCase {
  constructor(
    private userRepository: UserRepository,
    private paymentGateway: PaymentGateway,
    private notificationService: NotificationService
  ) {}

  async execute(userId: string, amount: number): Promise<PaymentResult> {
    const user = await this.userRepository.getUser(userId);
    const result = await this.paymentGateway.charge(user.paymentMethod, amount);
    
    if (result.success) {
      await this.notificationService.sendReceipt(user.email, amount);
      await this.userRepository.saveTransaction(userId, amount, result.id);
    }
    
    return result;
  }
}
```

#### **Step 3: モックを使ったテスト**

```typescript
describe('ProcessPaymentUseCase', () => {
  test('should process payment', async () => {
    // ✅ モックリポジトリ（メモリ内）
    const mockUserRepository: UserRepository = {
      getUser: jest.fn().mockResolvedValue({
        email: 'user@example.com',
        paymentMethod: 'pm_123'
      }),
      saveTransaction: jest.fn()
    };

    // ✅ モック支払いゲートウェイ
    const mockPaymentGateway: PaymentGateway = {
      charge: jest.fn().mockResolvedValue({
        success: true,
        id: 'tx_123'
      })
    };

    // ✅ モック通知サービス
    const mockNotificationService: NotificationService = {
      sendReceipt: jest.fn()
    };

    // テスト（0.1秒で実行完了）
    const useCase = new ProcessPaymentUseCase(
      mockUserRepository,
      mockPaymentGateway,
      mockNotificationService
    );

    const result = await useCase.execute('user-1', 100);

    // 検証
    expect(result.success).toBe(true);
    expect(mockNotificationService.sendReceipt).toHaveBeenCalled();
    expect(mockUserRepository.saveTransaction).toHaveBeenCalled();
  });
});
```

### 📊 テスト性の改善効果

```
従来設計                クリーン設計
  
テスト1回: 30秒  →  テスト1回: 0.1秒
100テスト : 50分  →  100テスト : 10秒

結果：
- 🔴 テストが遅い       ✅ テストが高速
- 🔴 テストを避ける     ✅ テストを積極的に追加
- 🔴 品質が低下         ✅ 品質が向上
```

---

## 3️⃣ 保守性 (Maintainability)

### コンセプト
コードを修正や拡張する際に、変更が局所的で、他の部分への影響が最小限である特性。

### ❌ 保守性が低い例

```typescript
// 複数の層が混在（修正時の影響が大きい）

export class UserService {
  async registerUser(email: string, password: string) {
    // UI層: バリデーション
    if (!email.includes('@')) {
      throw new Error('Invalid email');
    }

    // ドメイン層: ビジネスロジック
    if (password.length < 8) {
      throw new Error('Password too short');
    }

    // アプリケーション層: ユースケース処理
    const existingUser = await this.db.query(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );

    if (existingUser) {
      throw new Error('User exists');
    }

    // インフラ層: DB操作
    const userId = await this.db.query(
      'INSERT INTO users (email, password) VALUES (?, ?)',
      [email, hashPassword(password)]
    );

    // またアプリケーション層: メール送信
    await this.emailService.send(email, 'Welcome!');

    // またUI層: レスポンス
    return { id: userId, email };
  }
}
```

**問題:**
- 🔴 メールアドレスのバリデーション形式を変更
  → バリデーション、ドメイン、アプリケーション層全てを修正
- 🔴 DBをPostgreSQLに変更
  → サービスの全体を見直す必要あり
- 🔴 パスワード要件を変更
  → 複数ファイルを修正

---

### ✅ 保守性が高い例

#### **修正例1: メールバリデーション形式を変更**

```typescript
// ドメイン層の1ファイルのみ修正
export class User {
  constructor(email: string) {
    if (!this.isValidEmailFormat(email)) {
      throw new InvalidEmailError(email);
    }
  }

  // ここだけを修正
  private isValidEmailFormat(email: string): boolean {
    // 変更: より厳密なバリデーション
    return /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(email);
  }
}
```

**影響:**
- ✅ ドメイン層の1ファイルだけ変更
- ✅ 他の層は一切変更不要
- ✅ テストも該当ユニットテストのみ

---

#### **修正例2: DBをPostgreSQLに変更**

```typescript
// インフラストラクチャ層の1ファイルのみ修正
export class PostgresUserRepository implements UserRepository {
  async save(user: User): Promise<void> {
    await this.pool.query(
      'INSERT INTO users (id, email, password) VALUES ($1, $2, $3)',
      [user.id, user.email, user.hashedPassword]
    );
  }
}
```

**影響:**
- ✅ リポジトリ実装の1ファイルだけ変更
- ✅ ドメイン層は一切変更なし
- ✅ アプリケーション層は一切変更なし
- ✅ UI層は一切変更なし

---

#### **修正例3: パスワード要件を変更**

```typescript
// ドメイン層の1ファイルのみ修正
export class User {
  constructor(password: string) {
    if (!this.isStrongPassword(password)) {
      throw new WeakPasswordError();
    }
  }

  // ここだけを修正
  private isStrongPassword(password: string): boolean {
    // 変更: 大文字、数字、特殊文字が必須
    const regex = /^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{12,}$/;
    return regex.test(password);
  }
}
```

**影響:**
- ✅ ドメイン層の1ファイルだけ変更
- ✅ 他の層は一切変更なし

---

### 📊 保守性の改善効果

```
       修正対象ファイル数

従来設計  │     ███████ (7-15ファイル)
          │
クリーン   │ █ (1-2ファイル)
設計      │
          └─────────────────
            0   5   10  15
```

---

## 🎓 まとめ：3つの概念の相互関係

```
┌─────────────────────────────────────────────┐
│                  独立性                      │
│  ビジネスロジックがフレームワークに依存しない │
│                    ↓                        │
│               テスト性                      │
│   外部ツールなしにテストできる              │
│                    ↓                        │
│               保守性                        │
│    変更が局所的で、相互影響が少ない          │
│                    ➶                       │
└─────────────────────────────────────────────┘

独立性が高い
  → テストしやすい
    → 安全に修正・拡張できる
      → 保守性が高い
```

---

## 📋 各概念のチェックリスト

### 独立性のチェック

- [ ] ドメイン層がフレームワーク（Express, Django等）をインポートしていない
- [ ] ドメイン層がDB操作を直接行なっていない
- [ ] ドメイン層が外部APIを直接呼び出していない
- [ ] ドメイン層がファイルシステムに直接アクセスしていない

### テスト性のチェック

- [ ] ドメイン層は外部依存なしにテスト可能
- [ ] リポジトリがインターフェースで定義されている
- [ ] 外部サービスがインターフェースで抽象化されている
- [ ] テストに外部ツール（DBサーバー等）が不要

### 保住性のチェック

- [ ] 同じビジネスロジックが複数ファイルに散在していない
- [ ] 層の責任が明確に分かれている
- [ ] 1つの変更で影響を受けるファイルが3ファイル以下
- [ ] 名前から責任が推測できる

---

## ➡️ 次のステップ

さて、クリーンアーキテクチャの基本概念がわかったところで、具体的な**SOLID原則**を学びます。これらの原則がクリーンアーキテクチャを実現するための設計ルールです。

[次: SOLID原則 →](../02-core-principles/)
