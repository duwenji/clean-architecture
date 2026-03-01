# 03. サービスパターン (Service Pattern)

> **パターン**: ビジネスロジックをサービスクラスで実装。ドメイン層とアプリケーション層で使用。

## 🎯 2種類のサービス

### ドメインサービス（ドメイン層）

```typescript
// 複数のエンティティを関連付けるビジネスロジック
export class TransferDomainService {
  transfer(
    fromAccount: Account,
    toAccount: Account,
    amount: Money
  ): Transfer {
    // ビジネスルール：残高チェック
    if (fromAccount.getBalance().getAmount() < amount.getAmount()) {
      throw new InsufficientBalanceError();
    }

    // ビジネスルール：通貨チェック
    if (fromAccount.getBalance().getCurrency() !== amount.getCurrency()) {
      throw new CurrencyMismatchError();
    }

    // トランザクション作成
    const transfer = new Transfer(uuid(), fromAccount.getId(), toAccount.getId(), amount);

    // アカウント更新
    fromAccount.debit(amount);
    toAccount.credit(amount);

    return transfer;
  }
}
```

### アプリケーションサービス（アプリケーション層）

```typescript
// ユースケースのロジック
export class ProcessPaymentApplicationService {
  constructor(
    private accountRepository: AccountRepository,
    private transferRepository: TransferRepository,
    private notificationService: NotificationService
  ) {}

  async processTransfer(
    fromAccountId: string,
    toAccountId: string,
    amount: Money
  ): Promise<void> {
    // Step 1: エンティティ取得
    const fromAccount = await this.accountRepository.getById(fromAccountId);
    const toAccount = await this.accountRepository.getById(toAccountId);

    // Step 2: ドメインサービス呼び出し
    const transfer = this.transferDomainService.transfer(
      fromAccount,
      toAccount,
      amount
    );

    // Step 3: 永続化
    await this.accountRepository.update(fromAccount);
    await this.accountRepository.update(toAccount);
    await this.transferRepository.save(transfer);

    // Step 4: 副作用（通知）
    await this.notificationService.notifyTransferComplete(transfer);
  }
}
```

---

## 📊 ドメインサービス vs アプリケーションサービス

| 層 | サービス | 責務 | 依存関係 |
|----|---------|------|---------|
| **ドメイン** | Domain Service | ビジネスルール | インターフェースのみ |
| **アプリケーション** | Use Case | プロセス実行 | リポジトリ、外部サービス |

---

## 🧪 テスト

```typescript
describe('TransferDomainService', () => {
  test('should transfer money', () => {
    const fromAccount = new Account('from', new Money(1000));
    const toAccount = new Account('to', new Money(500));

    const service = new TransferDomainService();
    const transfer = service.transfer(fromAccount, toAccount, new Money(100));

    expect(fromAccount.getBalance().getAmount()).toBe(900);
    expect(toAccount.getBalance().getAmount()).toBe(600);
    expect(transfer.getAmount().getAmount()).toBe(100);
  });
});
```

---

[次: DTO パターン →](./04-dto-pattern.md)
