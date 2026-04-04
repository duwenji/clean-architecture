# 07: よくある間違い - アンチパターンの認識と回避

クリーンアーキテクチャの実装でよく陥りやすい落とし穴をまとめます。

---

## 📚 セクション構成

| # | アンチパターン | 特徴 | 対策 |
|---|-------------|------|------|
| [01](./01-over-engineering.md) | **過度な設計** | 必要以上に分層・複雑化 | 段階的な設計 |
| [02](./02-tight-coupling.md) | **密結合** | 層間の依存関係が逆向き | 依存関係の逆転 |
| [03](./03-anemic-model.md) | **貧血モデル** | データホルダーのみ | リッチモデル化 |
| [04](./04-circular-dependency.md) | **循環依存** | A→B→A トマムシ | インターフェース分離 |

---

## ❌ 1. 過度な設計（Over-Engineering）

### 🎯 問題

小規模プロジェクトに不必要なレイヤーを追加し、複雑化させる。

### 📍 具体例

```typescript
// 🚫 小規模プロジェクトに対して不適切
├─ presentation/
│   ├─ controllers/
│   ├─ dtos/
│   └─ validators/
├─ application/
│   ├─ usecases/
│   ├─ services/
│   └─ mappers/
├─ domain/
│   ├─ entities/
│   ├─ values/
│   └─ services/
└─ infrastructure/
    ├─ repositories/
    ├─ adapters/
    ├─ cache/
    └─ config/

// 計20ファイル 20クラス その割に機能は以下
// - ユーザー一覧表示
// - ユーザー詳細表示
```

### ✅ 解決策

```typescript
// プロジェクト規模に応じた段階的な設計

📐 MVP（最小限）
├─ index.ts      // 全ロジック統合
└─ db.ts         // データベース

🏗️  成長期（機能30個程度）
├─ services/     // ビジネスロジック
├─ controllers/  // HTTP処理
└─ models/       // データモデル

🏭 スケール期（機能100個以上）
├─ presentation/
├─ application/
├─ domain/
└─ infrastructure/
```

### 📋 判断基準

```TypeScript
// チェック
✅ 現在のチーム規模に適切か
✅ 機能追加・変更が頻繁か
✅ 複数人が並行開発するか
✅ テストが必須になっているか

少ないなら → シンプルな構造から開始
多いなら → フル層分離を検討
```

---

## ❌ 2. 密結合（Tight Coupling）

### 🎯 問題

層間の依存関係が逆向きになり、下位層が上位層を参照する。

### 📍 具体例

```typescript
// 🚫 アンチパターン：密結合

// domain/User.ts（ドメイン層）
import { Database } from '../infrastructure/database'; // ❌ 上位層への依存

export class User {
  id: string;
  email: string;

  async save() {
    // ドメイン層が DB を直接操作
    await Database.instance.query(
      'INSERT INTO users (id, email) VALUES (?, ?)',
      [this.id, this.email]
    );
  }
}

// application/SaveUserUseCase.ts（アプリケーション層）
import { User } from '../domain/User';
import { NotificationService } from '../infrastructure/NotificationService';

export class SaveUserUseCase {
  async execute(email: string) {
    const user = new User(email);
    // インフラ層の具体的な実装に依存
    await user.save();
    
    // その他のインフラも直接参照
    await NotificationService.send(email);
  }
}
```

### ✅ 解決策

```typescript
// 依存関係を逆転させる

// domain/User.ts（ドメイン層）
export class User {
  constructor(
    public id: string,
    public email: Email
  ) {}

  // ドメインロジックのみ
  isActive(): boolean {
    return !!this.email;
  }
}

// domain/ports/UserRepository.ts（インターフェース）
export interface UserRepository {
  save(user: User): Promise<void>;
  getById(id: string): Promise<User | null>;
}

// application/SaveUserUseCase.ts（アプリケーション層）
export class SaveUserUseCase {
  constructor(
    private userRepository: UserRepository,  // 抽象に依存
    private notificationService: NotificationService
  ) {}

  async execute(email: string): Promise<void> {
    const user = new User(uuid(), new Email(email));
    await this.userRepository.save(user);
    await this.notificationService.notifyUserCreated(user);
  }
}

// infrastructure/repositories/MySQLUserRepository.ts（実装）
export class MySQLUserRepository implements UserRepository {
  constructor(private connection: Pool) {}

  async save(user: User): Promise<void> {
    await this.connection.query(
      'INSERT INTO users (id, email) VALUES (?, ?)',
      [user.id, user.email.value]
    );
  }
}
```

### 📋 検出方法

```bash
# 循環依存をチェック
npm install --save-dev madge
npx madge --circular src/

# 依存グラフを可視化
npx madge --image graph.png src/
```

---

## ❌ 3. 貧血モデル（Anemic Model）

### 🎯 問題

エンティティがデータフィールドのみで、ビジネスロジックを持たない。ロジックが Use Case や Service に散在。

### 📍 具体例

```typescript
// 🚫 アンチパターン：貧血モデル

// domain/Account.ts
export class Account {
  id: string;
  userId: string;
  balance: number;  // ただのデータ
  createdAt: Date;

  constructor(id: string, userId: string, balance: number) {
    this.id = id;
    this.userId = userId;
    this.balance = balance;
    this.createdAt = new Date();
  }
}

// ビジネスロジックかSERVICEに散在
// application/TransferUseCase.ts
export class TransferUseCase {
  async execute(fromId: string, toId: string, amount: number) {
    const from = await this.accountRepository.getById(fromId);
    const to = await this.accountRepository.getById(toId);

    // ロジックがユースケースに散在 ❌
    if (from.balance < amount) {
      throw new Error('Insufficient balance');
    }
    
    from.balance -= amount;  // データを直接変更
    to.balance += amount;

    await this.accountRepository.update(from);
    await this.accountRepository.update(to);
  }
}

// 別のサービスでも同じロジック...
// domain/AccountService.ts
export class AccountService {
  calculateInterest(account: Account): number {
    return account.balance * 0.05;  // 利息計算
  }
}
```

### ✅ 解決策

```typescript
// ✅ リッチモデル：ロジックをエンティティに集約

// domain/Account.ts
export class Account {
  constructor(
    public id: string,
    public userId: string,
    private balance: Money  // 値オブジェクト
  ) {}

  // ビジネスロジックをメソッド化
  transfer(amount: Money): void {
    if (this.balance.isLessThan(amount)) {
      throw new InsufficientBalanceError(
        `Required: ${amount.value}, Available: ${this.balance.value}`
      );
    }
    this.balance = this.balance.subtract(amount);
  }

  deposit(amount: Money): void {
    this.balance = this.balance.add(amount);
  }

  calculateInterest(rate: number): Money {
    return this.balance.multiply(rate);
  }

  // クエリメソッド
  getBalance(): Money {
    return this.balance;
  }
}

// application/TransferUseCase.ts
export class TransferUseCase {
  constructor(
    private accountRepository: AccountRepository
  ) {}

  async execute(fromId: string, toId: string, amount: Money): Promise<void> {
    const from = await this.accountRepository.getById(fromId);
    const to = await this.accountRepository.getById(toId);

    // エンティティがロジックを持つ
    from.transfer(amount);
    to.deposit(amount);

    await this.accountRepository.update(from);
    await this.accountRepository.update(to);
  }
}
```

### 📋 判断基準

```
✅ リッチモデルに向く場合
- ビジネスロジックが複雑
- ドメインルールが増加傾向
- 複数のエンティティで同じロジック

❌ 貧血モデルが許容される場合
- CRUD アプリケーション
- ロジックほぼなし
- プロトタイプ段階
```

---

## ❌ 4. 循環依存（Circular Dependency）

### 🎯 問題

A が B を参照し、B が A を参照する或いは複数モジュールで循環している。

### 📍 具体例

```typescript
// 🚫 アンチパターン：循環依存

// domain/User.ts
import { Account } from './Account';  // ← Account を参照

export class User {
  accounts: Account[] = [];

  getBalance(): number {
    return this.accounts.reduce((sum, acc) => sum + acc.getBalance(), 0);
  }
}

// domain/Account.ts
import { User } from './User';  // ← User を参照（循環！）

export class Account {
  owner: User;

  constructor(owner: User) {
    this.owner = owner;
    owner.accounts.push(this);  // 相互参照
  }
}
```

### ✅ 解決策

```typescript
// 方法1：インターフェースで分離
// domain/ports/Account.ts
export interface Account {
  getBalance(): number;
}

// domain/User.ts
export class User {
  constructor(private accounts: Account[]) {}

  getTotalBalance(): number {
    return this.accounts.reduce((sum, acc) => sum + acc.getBalance(), 0);
  }
}

// domain/UserAccount.ts
export class UserAccount implements Account {
  constructor(
    public id: string,
    public balance: number,
    public userId: string
  ) {}

  getBalance(): number {
    return this.balance;
  }
}

// 方法2：中間層で参照を遅延
// application/services/UserAccountService.ts
export class UserAccountService {
  constructor(
    private userRepository: UserRepository,
    private accountRepository: AccountRepository
  ) {}

  async getTotalBalance(userId: string): Promise<number> {
    const accounts = await this.accountRepository.findByUserId(userId);
    return accounts.reduce((sum, acc) => sum + acc.balance, 0);
  }
}
```

---

## 📋 総合チェックリスト

```
循環依存の検出
✅ madge で循環参照なし
✅ モジュール分割が明確
✅ 依存関係が一方向

密結合の排除
✅ ドメイン層が上位層を参照していない
✅ インターフェース経由の依存
✅ DI コンテナの活用

豊富なドメインモデル
✅ ビジネスロジックをエンティティに含む
✅ 値オブジェクトが使われている
✅ Use Case は層の仲介のみ

適切な複雑さ
✅ 現在のプロジェクト規模に合った設計
✅ 過度な抽象化がない
✅ チーム全体で理解できている
```

---

## 🔗 関連セクション

- [実装ガイド](../05-implementation-guide/) - 正しい実装方法
- [ベストプラクティス](../06-best-practices/) - 品質向上
- [ケーススタディ](../08-case-studies/) - 実装例

---

**次: [ケーススタディ →](../08-case-studies/)**
