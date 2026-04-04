# 02. 開放閉鎖の原則 (OCP) - Open/Closed Principle

> **原則**: ソフトウェアは拡張に対して開かれていて、修正に対して閉じられているべき。新機能追加では既存コードを修正せず、新しいコードを追加する。

## 🎯 コンセプト

```
新機能を追加したい
  ↓
既存のコードを修正する？
  ❌ いいえ
     ↓
既存のコードに新しいコードを追加する？
  ✅ はい
     ↓
     結果：既存のテストが壊れない
```

---

## ❌ OCPに違反する例

### シナリオ：決済方法を追加したい

```typescript
// ❌ 悪い例：新しい決済方法を追加するたびに修正が必要

export class PaymentProcessor {
  processPayment(amount: number, paymentMethod: string): void {
    if (paymentMethod === 'credit_card') {
      // クレジットカード処理
      console.log(`Processing ${amount} with credit card`);
      // ... 実装
      
    } else if (paymentMethod === 'bank_transfer') {
      // 銀行振込処理
      console.log(`Processing ${amount} with bank transfer`);
      // ... 実装
      
    } else if (paymentMethod === 'paypal') {
      // PayPal処理
      console.log(`Processing ${amount} with PayPal`);
      // ... 実装
    }
    // ← 新しい決済方法を追加するたびにここを修正する必要がある
  }
}
```

**問題:**
- 🔴 新しい決済方法を追加するたびにこのクラスを修正
- 🔴 既存のテストの影響を受ける可能性
- 🔴 スケーラビリティが悪い
- 🔴 既存コードのリグレッションテストが必要

---

## ✅ OCP を適用した設計

### Step 1: インターフェースを定義

```typescript
// ドメイン層：決済方法のインターフェース
export interface PaymentMethod {
  process(amount: number): Promise<PaymentResult>;
  validate(): boolean;
}

// 決済結果
export interface PaymentResult {
  success: boolean;
  transactionId: string;
  amount: number;
  timestamp: Date;
}
```

### Step 2: インターフェース実装

```typescript
// ##### インフラストラクチャ層：各決済方法の実装 #####

// クレジットカード
export class CreditCardPayment implements PaymentMethod {
  constructor(
    private cardNumber: string,
    private expiryDate: string,
    private cvv: string
  ) {}

  validate(): boolean {
    // クレジットカード番号の検証
    return this.isValidCardNumber(this.cardNumber);
  }

  async process(amount: number): Promise<PaymentResult> {
    if (!this.validate()) {
      throw new InvalidPaymentMethodError('Invalid card');
    }

    // 決済ゲートウェイに接続
    const result = await this.chargeCard(amount);

    return {
      success: result.approved,
      transactionId: result.txId,
      amount,
      timestamp: new Date()
    };
  }

  private isValidCardNumber(cardNumber: string): boolean {
    // Luhnアルゴリズムなど
    return cardNumber.length === 16;
  }

  private async chargeCard(amount: number) {
    // 実装
  }
}

// 銀行振込
export class BankTransferPayment implements PaymentMethod {
  constructor(
    private bankCode: string,
    private accountNumber: string,
    private accountHolder: string
  ) {}

  validate(): boolean {
    return this.bankCode.length > 0 && this.accountNumber.length > 0;
  }

  async process(amount: number): Promise<PaymentResult> {
    if (!this.validate()) {
      throw new InvalidPaymentMethodError('Invalid bank details');
    }

    // 銀行振込処理
    const result = await this.initiateTransfer(amount);

    return {
      success: result.confirmed,
      transactionId: result.referenceNumber,
      amount,
      timestamp: new Date()
    };
  }

  private async initiateTransfer(amount: number) {
    // 実装
  }
}

// PayPal
export class PayPalPayment implements PaymentMethod {
  constructor(private email: string) {}

  validate(): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.email);
  }

  async process(amount: number): Promise<PaymentResult> {
    if (!this.validate()) {
      throw new InvalidPaymentMethodError('Invalid email');
    }

    const result = await this.chargePayPal(amount);

    return {
      success: result.status === 'COMPLETED',
      transactionId: result.orderId,
      amount,
      timestamp: new Date()
    };
  }

  private async chargePayPal(amount: number) {
    // 実装
  }
}

// 将来：新しい決済方法を追加するときは、
// このインターフェースを実装するだけ！
export class CryptoCurrencyPayment implements PaymentMethod {
  constructor(private walletAddress: string) {}

  validate(): boolean {
    return this.walletAddress.length === 42;
  }

  async process(amount: number): Promise<PaymentResult> {
    // 新規に追加
  }
}
```

### Step 3: アプリケーション層で抽象化を使用

```typescript
// ##### アプリケーション層 #####

// PaymentProcessor は抽象化に依存（修正が不要）
export class PaymentProcessor {
  async processPayment(
    amount: number,
    paymentMethod: PaymentMethod  // インターフェース
  ): Promise<PaymentResult> {
    // 具体的な実装を知らない
    // インターフェースのメソッドを呼び出すだけ
    if (!paymentMethod.validate()) {
      throw new InvalidPaymentMethodError('Payment method validation failed');
    }

    const result = await paymentMethod.process(amount);

    // 決済結果をログに記録
    await this.logTransaction(result);

    return result;
  }

  private async logTransaction(result: PaymentResult): Promise<void> {
    // 実装
  }
}

// ユースケース
export class MakePaymentUseCase {
  constructor(
    private paymentProcessor: PaymentProcessor,
    private paymentMethodFactory: PaymentMethodFactory
  ) {}

  async execute(request: PaymentRequest): Promise<PaymentResult> {
    // 決済方法を作成（ファクトリパターン）
    const paymentMethod = this.paymentMethodFactory.create(
      request.paymentMethodType,
      request.paymentDetails
    );

    // 処理実行
    const result = await this.paymentProcessor.processPayment(
      request.amount,
      paymentMethod
    );

    return result;
  }
}

// ファクトリパターン：決済方法を生成
export class PaymentMethodFactory {
  create(type: string, details: any): PaymentMethod {
    switch (type) {
      case 'credit_card':
        return new CreditCardPayment(
          details.cardNumber,
          details.expiryDate,
          details.cvv
        );
      case 'bank_transfer':
        return new BankTransferPayment(
          details.bankCode,
          details.accountNumber,
          details.accountHolder
        );
      case 'paypal':
        return new PayPalPayment(details.email);
      case 'crypto':
        return new CryptoCurrencyPayment(details.walletAddress);
      default:
        throw new UnsupportedPaymentMethodError(type);
    }
  }
}
```

---

## 📊 修正の比較

### ❌ OCP違反：新しい決済方法を追加

```
既存コード（PaymentProcessor）を修正
  ↓
修正前：
  else if (paymentMethod === 'paypal') { ... }
  
修正後：
  else if (paymentMethod === 'paypal') { ... }
  else if (paymentMethod === 'crypto') { ... }
  
リスク：
- 既存ロジックが壊れる可能性
- 全テストを再実行する必要
```

### ✅ OCP適用：新しい決済方法を追加

```
新しいクラスを追加するだけ
  ↓
CryptoCurrencyPayment implements PaymentMethod { ... }
  
既存コード（PaymentProcessor）は一切修正なし
  
リスク：
- なし（既存テストはそのまま動く）
```

---

## 🎓 実装パターン

### パターン1: インターフェース/抽象クラス

```typescript
// ❌ 実装に依存
class PaymentProcessor {
  process(payment: CreditCardPayment) { }
}

// ✅ インターフェースに依存
class PaymentProcessor {
  process(payment: PaymentMethod) { }
}
```

### パターン2: Strategy パターン

```typescript
// Strategy は拡張可能な戦略を表現
export interface Strategy {
  execute(): void;
}

export class ConcreteStrategyA implements Strategy {
  execute() { console.log('Strategy A'); }
}

export class ConcreteStrategyB implements Strategy {
  execute() { console.log('Strategy B'); }
}
```

### パターン3: Template Method パターン

```typescript
// 拡張に開かれた抽象クラス
export abstract class ReportGenerator {
  // 不変部分
  generate(data: any): string {
    const header = this.generateHeader();
    const body = this.generateBody(data);
    const footer = this.generateFooter();
    return header + body + footer;
  }

  // 変動部分（サブクラスで実装）
  protected abstract generateBody(data: any): string;
  
  protected generateHeader(): string { return '===\n'; }
  protected generateFooter(): string { return '\n==='; }
}

// 拡張：既存コードを修正しない
export class PDFReportGenerator extends ReportGenerator {
  protected generateBody(data: any): string {
    return `PDF: ${data}`;
  }
}

export class HTMLReportGenerator extends ReportGenerator {
  protected generateBody(data: any): string {
    return `<body>${data}</body>`;
  }
}
```

---

## 📊 テスト

```typescript
describe('PaymentProcessor with OCP', () => {
  // 新しい決済方法が追加されても、
  // 既存のテストは一切変更不要
  
  test('should process credit card payment', async () => {
    const payment = new CreditCardPayment('1234', '12/25', '123');
    const processor = new PaymentProcessor();
    const result = await processor.processPayment(100, payment);
    expect(result.success).toBe(true);
  });

  // ← 新機能追加：新しいテストを追加するだけ
  test('should process crypto currency payment', async () => {
    const payment = new CryptoCurrencyPayment('0x...');
    const processor = new PaymentProcessor();
    const result = await processor.processPayment(100, payment);
    expect(result.success).toBe(true);
  });

  // 他の既存テストは全く変わらない
});
```

---

## 🎯 OCP チェックリスト

```
✅ 新機能追加で既存クラスを修正せずに済むか
✅ インターフェースで抽象化されているか
✅ ファクトリパターンで生成が隔離されているか
✅ 既存テストが全て通るか（修正なしで）
✅ 拡張ポイントが明確か
```

---

## 📋 まとめ

| ポイント | 説明 |
|---------|------|
| **本質** | 拡張は追加、修正は少なく |
| **実装** | インターフェース、抽象クラス |
| **メリット** | 既存コード保護、テスト安定性 |
| **キー** | 抽象化が鍵 |

---

## ➡️ 次のステップ

次は、サブタイプはスーパータイプと置き換え可能であるべき、という **リスコフの置換原則** を学びます。

[次: リスコフの置換原則 →](./03-liskov-substitution.md)
