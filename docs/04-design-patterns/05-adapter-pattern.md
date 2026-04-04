# 05. アダプタパターン (Adapter Pattern)

> **パターン**: 異なるインターフェースを適合させる。外部ライブラリやAPIを統一インターフェースで扱う。

## 🎯 コンセプト

```
外部ライブラリAのインターフェース
         ↓ アダプタ
統一されたインターフェース
         ↑ アダプタ
外部ライブラリBのインターフェース
```

---

## 💻 実装例1：メールサービスの統一

### 複数のメールプロバイダーがある

```typescript
// SendGrid API
export interface SendGridClient {
  send(to: string, subject: string, html: string): Promise<SendGridResponse>;
}

// AWS SES API
export interface AWSEmailService {
  sendEmail(params: SESParams): Promise<SESResult>;
}

// アプリケーション層は統一インターフェースを期待
export interface EmailService {
  send(email: string, subject: string, body: string): Promise<void>;
}
```

### SendGrid アダプタ

```typescript
export class SendGridEmailAdapter implements EmailService {
  constructor(private sendGridClient: SendGridClient) {}

  async send(email: string, subject: string, body: string): Promise<void> {
    const response = await this.sendGridClient.send(email, subject, body);
    if (!response.success) {
      throw new EmailSendError(response.error);
    }
  }
}
```

### AWS SES アダプタ

```typescript
export class AWSSESEmailAdapter implements EmailService {
  constructor(private sesService: AWSEmailService) {}

  async send(email: string, subject: string, body: string): Promise<void> {
    const result = await this.sesService.sendEmail({
      Source: 'noreply@example.com',
      Destination: { ToAddresses: [email] },
      Message: {
        Subject: { Data: subject },
        Body: { Html: { Data: body } }
      }
    });

    if (!result.success) {
      throw new EmailSendError(result.error);
    }
  }
}
```

### アプリケーション層（変わらない）

```typescript
export class NotificationUseCase {
  constructor(private emailService: EmailService) {}

  async notifyUser(email: string, message: string): Promise<void> {
    // SendGrid든 AWS든 関係なく使用できる
    await this.emailService.send(
      email,
      'Notification',
      message
    );
  }
}
```

---

## 💻 実装例2：決済ゲートウェイの統一

### 複数の決済プロバイダー

```typescript
// Stripe API
export interface StripeAPI {
  paymentIntents: {
    create(params: StripeParams): Promise<PaymentIntent>;
  };
}

// PayPal API
export class PayPalAPI {
  async executePayment(request: PayPalRequest): Promise<PayPalResponse>;
}

// 統一インターフェース
export interface PaymentGateway {
  charge(amount: number, paymentMethod: string): Promise<ChargeResult>;
}
```

### Stripe アダプタ

```typescript
export class StripePaymentAdapter implements PaymentGateway {
  constructor(private stripe: StripeAPI) {}

  async charge(amount: number, paymentMethodId: string): Promise<ChargeResult> {
    const result = await this.stripe.paymentIntents.create({
      amount: amount * 100,
      payment_method: paymentMethodId,
      confirm: true
    });

    return {
      success: result.status === 'succeeded',
      transactionId: result.id,
      amount
    };
  }
}
```

### PayPal アダプタ

```typescript
export class PayPalPaymentAdapter implements PaymentGateway {
  constructor(private paypal: PayPalAPI) {}

  async charge(amount: number, paymentMethodId: string): Promise<ChargeResult> {
    const response = await this.paypal.executePayment({
      amount,
      paymentSource: paymentMethodId
    });

    return {
      success: response.status === 'COMPLETED',
      transactionId: response.id,
      amount
    };
  }
}
```

---

## 🏭 実装の切り替え

```typescript
// 環境に応じて使い分ける
export class PaymentGatewayFactory {
  static create(): PaymentGateway {
    if (process.env.PAYMENT_PROVIDER === 'stripe') {
      return new StripePaymentAdapter(new StripeAPI());
    } else if (process.env.PAYMENT_PROVIDER === 'paypal') {
      return new PayPalPaymentAdapter(new PayPalAPI());
    }
    throw new Error('Unknown payment provider');
  }
}

// または DI コンテナで設定
const container = new Container();

if (process.env.PAYMENT_PROVIDER === 'stripe') {
  container.bind<PaymentGateway>('PaymentGateway')
    .to(StripePaymentAdapter);
} else {
  container.bind<PaymentGateway>('PaymentGateway')
    .to(PayPalPaymentAdapter);
}
```

---

## 🧪 テスト

```typescript
describe('PaymentGatewayAdapters', () => {
  test('should work with Stripe adapter', async () => {
    const mockStripe = {
      paymentIntents: {
        create: jest.fn().mockResolvedValue({
          status: 'succeeded',
          id: 'pi_123'
        })
      }
    };

    const adapter = new StripePaymentAdapter(mockStripe);
    const result = await adapter.charge(100, 'pm_123');

    expect(result.success).toBe(true);
  });

  test('should work with PayPal adapter', async () => {
    const mockPaypal = {
      executePayment: jest.fn().mockResolvedValue({
        status: 'COMPLETED',
        id: 'sale_123'
      })
    };

    const adapter = new PayPalPaymentAdapter(mockPaypal);
    const result = await adapter.charge(100, 'payid_123');

    expect(result.success).toBe(true);
  });

  test('should use same interface', async () => {
    const stripe = new StripePaymentAdapter(...);
    const paypal = new PayPalPaymentAdapter(...);

    // 同じインターフェース、異なる実装
    const r1 = await stripe.charge(100, 'pm_123');
    const r2 = await paypal.charge(100, 'payid_123');

    expect(r1).toHaveProperty('transactionId');
    expect(r2).toHaveProperty('transactionId');
  });
});
```

---

## 📋 チェックリスト

```
✅ 外部ライブラリが隔離されている
✅ 統一インターフェースで扱える
✅ 実装を切り替え可能
✅ テストで容易にモック化
✅ 複数プロバイダーに対応
```

---

## ➡️ 次のステップ

デザインパターンを学んだので、次は **実装ガイド**で、これらのパターンを実際のプロジェクトにどう適用するか学びます。

[次: 実装ガイド →](../05-implementation-guide/)
