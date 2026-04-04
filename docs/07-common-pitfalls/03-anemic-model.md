# 03: 貧血モデル（Anemic Model）

ビジネスロジックをエティティに戻す（リッチモデル設計）。

---

## 🎯 問題

エンティティがデータフィールドのみで、ビジネスロジックを持たない。

**結果：**
- ロジックが Use Case や Service に散在
- ロジックの重複
- バグが増加（検証が漏れる）
- ドメイン知識が散在

---

## 📍 具体例：貧血モデル

```typescript
// 🚫 エンティティがただのデータホルダー

// domain/Account.ts
export class Account {
  id: string;
  userId: string;
  balance: number;        // ただのフィールド
  createdAt: Date;

  constructor(id: string, userId: string, balance: number) {
    this.id = id;
    this.userId = userId;
    this.balance = balance;
    this.createdAt = new Date();
  }
}

// ビジネスロジックが各所に散在

// application/TransferUseCase.ts
export class TransferUseCase {
  async execute(fromId: string, toId: string, amount: number) {
    const from = await this.accountRepository.getById(fromId);
    const to = await this.accountRepository.getById(toId);

    // ロジックがユースケースに ❌
    if (from.balance < amount) {
      throw new Error('Insufficient balance');
    }

    from.balance -= amount;   // データ直操作
    to.balance += amount;

    await this.accountRepository.update(from);
    await this.accountRepository.update(to);
  }
}

// application/WithdrawUseCase.ts
export class WithdrawUseCase {
  async execute(accountId: string, amount: number) {
    const account = await this.accountRepository.getById(accountId);

    // 同じロジックを重複
    if (account.balance < amount) {
      throw new Error('Insufficient balance');
    }

    account.balance -= amount;   // 毎回同じ処理

    await this.accountRepository.update(account);
  }
}

// domain/AccountService.ts（さらにロジックが分散）
export class AccountService {
  calculateInterest(account: Account): number {
    return account.balance * 0.05;
  }

  applyMonthlyFee(account: Account): void {
    account.balance -= 10;  // 手数料
  }
}

// 🔴 問題：
// 1. 検証ロジックが複数箇所に存在 → バグ削減困難
// 2. ロジックが一貫していない（TransferUseCase では < だが、別の場所では ≤ かもしれない）
// 3. ビジネスルールがどこにあるか不明
// 4. テストが複雑（モック設定多い）
```

---

## ✅ 解決策：リッチモデル

### ステップ1：値オブジェクトを導入

```typescript
// domain/value-objects/Money.ts
export class Money {
  constructor(public readonly value: number) {
    if (value < 0) {
      throw new Error('Money cannot be negative');
    }
  }

  add(other: Money): Money {
    return new Money(this.value + other.value);
  }

  subtract(other: Money): Money {
    if (other.value > this.value) {
      throw new InsufficientBalanceError(
        `Cannot subtract ${other.value} from ${this.value}`
      );
    }
    return new Money(this.value - other.value);
  }

  multiply(rate: number): Money {
    return new Money(this.value * rate);
  }

  isLessThan(other: Money): boolean {
    return this.value < other.value;
  }

  isGreaterThanOrEqual(other: Money): boolean {
    return this.value >= other.value;
  }
}
```

### ステップ2：ロジックをエンティティに移動

```typescript
// domain/Account.ts（リッチモデル）
export class Account {
  constructor(
    public id: string,
    public userId: string,
    private balance: Money,  // 値オブジェクト
    public createdAt: Date
  ) {}

  // ✅ ビジネスロジックをメソッド化

  /**
   * 出金処理
   * @throws InsufficientBalanceError
   */
  withdraw(amount: Money): void {
    this.balance = this.balance.subtract(amount);  // 検証含む
  }

  /**
   * 入金処理
   */
  deposit(amount: Money): void {
    this.balance = this.balance.add(amount);
  }

  /**
   * 振替処理（出金側）
   */
  withdrawForTransfer(amount: Money): void {
    this.withdraw(amount);
  }

  /**
   * 振替処理（入金側）
   */
  receiveTransfer(amount: Money): void {
    this.deposit(amount);
  }

  /**
   * 利息計算
   */
  calculateInterest(annualRate: number): Money {
    return this.balance.multiply(annualRate / 12);  // 月利
  }

  /**
   * 月次手数料適用
   */
  applyMonthlyFee(fee: Money): void {
    this.balance = this.balance.subtract(fee);
  }

  /**
   * 残高クエリ
   */
  getBalance(): Money {
    return this.balance;
  }
}

// ドメイン例外
export class InsufficientBalanceError extends DomainError {
  constructor(message: string) {
    super(message);
  }
}
```

### ステップ3：ユースケースは層の仲介のみ

```typescript
// application/TransferUseCase.ts（シンプルになった）
export class TransferUseCase {
  constructor(private accountRepository: AccountRepository) {}

  async execute(fromId: string, toId: string, amount: Money): Promise<void> {
    const from = await this.accountRepository.getById(fromId);
    const to = await this.accountRepository.getById(toId);

    // ✅ ドメイン層がロジックを持つ
    from.withdrawForTransfer(amount);  // 検証も含む
    to.receiveTransfer(amount);

    // 永続化
    await this.accountRepository.update(from);
    await this.accountRepository.update(to);
  }
}

// application/WithdrawUseCase.ts（同様にシンプル）
export class WithdrawUseCase {
  constructor(private accountRepository: AccountRepository) {}

  async execute(accountId: string, amount: Money): Promise<void> {
    const account = await this.accountRepository.getById(accountId);

    // ✅ エンティティを信頼
    account.withdraw(amount);

    await this.accountRepository.update(account);
  }
}

// application/ApplyMonthlyInterestUseCase.ts
export class ApplyMonthlyInterestUseCase {
  constructor(private accountRepository: AccountRepository) {}

  async execute(accountId: string): Promise<void> {
    const account = await this.accountRepository.getById(accountId);

    // 月利計算と手数料を一度に処理
    const interest = account.calculateInterest(0.02);  // 2% 年利
    account.deposit(interest);

    const monthlyFee = new Money(10);
    account.applyMonthlyFee(monthlyFee);

    await this.accountRepository.update(account);
  }
}
```

---

## 🧪 テスト：ドメイン層のテスト

```typescript
// tests/domain/Account.test.ts
describe('Account', () => {
  let account: Account;

  beforeEach(() => {
    account = new Account(
      '1',
      'user-1',
      new Money(1000),
      new Date()
    );
  });

  describe('withdraw', () => {
    it('should withdraw money successfully', () => {
      account.withdraw(new Money(100));
      expect(account.getBalance().value).toBe(900);
    });

    it('should throw error if insufficient balance', () => {
      expect(() => {
        account.withdraw(new Money(2000));
      }).toThrow(InsufficientBalanceError);
    });
  });

  describe('deposit', () => {
    it('should deposit money successfully', () => {
      account.deposit(new Money(500));
      expect(account.getBalance().value).toBe(1500);
    });
  });

  describe('calculateInterest', () => {
    it('should calculate monthly interest correctly', () => {
      const interest = account.calculateInterest(0.12);  // 12% 年利
      expect(interest.value).toBeCloseTo(10, 1);  // 月利1%
    });
  });

  describe('applyMonthlyFee', () => {
    it('should apply monthly fee', () => {
      account.applyMonthlyFee(new Money(10));
      expect(account.getBalance().value).toBe(990);
    });

    it('should throw error if fee exceeds balance', () => {
      expect(() => {
        account.applyMonthlyFee(new Money(2000));
      }).toThrow(InsufficientBalanceError);
    });
  });
});
```

---

## 📊 比較：貧血 vs リッチモデル

| 側面 | 貧血モデル | リッチモデル |
|------|----------|-----------|
| **ロジック** | Service に散在 | Entity に集約 |
| **検証** | ユースケース毎に異なる | 一貫性保証 |
| **テスト** |複雑で fragile | シンプルで堅牢 |
| **ドメイン知識** | コードとドキュメントが乖離 | 自己説明的 |
| **保守性** | 困難（重複削減） | 容易（SSOT） |
| **再利用** | 困難（ユースケース依存） | 容易（エンティティ使用） |

---

## 📋 チェックリスト

```
エンティティ設計
✅ データと振る舞いが一緒に定義
✅ 値オブジェクトを活用
✅ 検証ロジックが Entity に含まれる
✅ query メソッド（isActive() など）がある

ビジネスロジック
✅ ドメイン層に属するロジックは Entity に
✅ Use Case は層の仲介のみ
✅ Service は domain service（型チェック） のみ

テスト
✅ ドメイン層のテストが簡潔
✅ インフラ依存がない
✅ 検証が徹底されている
```

---

**次: [循環依存の回避 →](./04-circular-dependency.md)**
