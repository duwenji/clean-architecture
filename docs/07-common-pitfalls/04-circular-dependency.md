# 04: 循環依存（Circular Dependency）

モジュール間の循環参照を検出・排除する。

---

## 🎯 問題

A → B → A のような循環依存があると：
- ビルドが失敗する可能性
- モジュール分離の意味がない
- 依存関係が不明確

---

## 📍 具体例：循環依存

```typescript
// 🚫 相互参照による循環

// domain/User.ts
import { Account } from './Account';  // ← Account を参照

export class User {
  accounts: Account[] = [];

  getTotalBalance(): number {
    return this.accounts.reduce((sum, acc) => sum + acc.getBalance(), 0);
  }
}

// domain/Account.ts
import { User } from './User';  // ← User を参照（循環！）

export class Account {
  owner: User;

  constructor(owner: User) {
    this.owner = owner;
    owner.accounts.push(this);  // 双方向参照
  }

  getBalance(): number {
    return this.balance;
  }
}

// 🔴 問題：
// 1. User と Account が完全に結合
// 2. User のテストに Account が必須
// 3. Account の変更が User に影響
// 4. import 順序がランダムだとビルド失敗の可能性
```

---

## ✅ 解決策1：インターフェースで分離

```typescript
// domain/ports/Account.ts（ポート/インターフェース）
export interface IAccount {
  getBalance(): number;
  getOwnerId(): string;
}

// domain/User.ts（Account を参照しない）
export class User {
  private accounts: IAccount[] = [];

  constructor(public id: string) {}

  addAccount(account: IAccount): void {
    this.accounts.push(account);
  }

  getTotalBalance(): number {
    return this.accounts.reduce(
      (sum, acc) => sum + acc.getBalance(),
      0
    );
  }

  getAccounts(): IAccount[] {
    return this.accounts;
  }
}

// domain/Account.ts
export class Account implements IAccount {
  constructor(
    public id: string,
    public balance: number,
    private userId: string
  ) {}

  getBalance(): number {
    return this.balance;
  }

  getOwnerId(): string {
    return this.userId;
  }

  // User は参照しない ✅
}

// application/services/UserAccountService.ts
export class UserAccountService {
  constructor(
    private userRepository: UserRepository,
    private accountRepository: AccountRepository
  ) {}

  async createUserWithAccount(
    userId: string,
    initialBalance: number
  ): Promise<void> {
    const user = new User(userId);
    const account = new Account(uuid(), initialBalance, userId);

    // User と Account の関連は Service 層で管理
    user.addAccount(account);

    await this.userRepository.save(user);
    await this.accountRepository.save(account);
  }
}
```

---

## ✅ 解決策2：中間層で参照を遅延

```typescript
// domain/User.ts（Account を参照しない）
export class User {
  constructor(public id: string) {}

  // Account の情報は持たない
  // 合計残高は query で外部から取得してもらう
}

// domain/Account.ts
export class Account {
  constructor(
    public id: string,
    public balance: number,
    public userId: string
  ) {}
}

// application/queries/GetUserTotalBalanceQuery.ts
export class GetUserTotalBalanceQuery {
  constructor(private accountRepository: AccountRepository) {}

  async execute(userId: string): Promise<number> {
    const accounts = await this.accountRepository.findByUserId(userId);
    return accounts.reduce((sum, acc) => sum + acc.balance, 0);
  }
}

// presentation/controllers/UserController.ts
export class UserController {
  constructor(
    private getUserUseCase: GetUserUseCase,
    private getTotalBalanceQuery: GetUserTotalBalanceQuery
  ) {}

  async getUserWithBalance(req: Request, res: Response): Promise<void> {
    const userId = req.params.id;

    const user = await this.getUserUseCase.execute(userId);
    const totalBalance = await this.getTotalBalanceQuery.execute(userId);

    res.json({
      user,
      totalBalance
    });
  }
}

// ✅ User と Account が独立
```

---

## ✅ 解決策3：イベント駆動で分離

```typescript
// domain/events/UserCreatedEvent.ts
export class UserCreatedEvent {
  constructor(public userId: string) {}
}

// domain/User.ts（Account を参照しない）
export class User {
  constructor(public id: string) {}
}

// domain/Account.ts（User を参照しない）
export class Account {
  constructor(
    public id: string,
    public userId: string,
    public balance: number
  ) {}
}

// application/usecases/CreateUserUseCase.ts
export class CreateUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private eventPublisher: EventPublisher
  ) {}

  async execute(userId: string): Promise<void> {
    const user = new User(userId);
    await this.userRepository.save(user);

    // イベントをパブリッシュ
    this.eventPublisher.publish(new UserCreatedEvent(userId));
  }
}

// application/services/AccountCreationService.ts
export class AccountCreationService {
  constructor(
    private accountRepository: AccountRepository,
    private eventListener: EventListener
  ) {
    // User 作成イベントをリッスン
    this.eventListener.on(UserCreatedEvent, (event) => {
      this.onUserCreated(event);
    });
  }

  private async onUserCreated(event: UserCreatedEvent): Promise<void> {
    // User 作成イベント発火時に Account を作成
    const account = new Account(uuid(), event.userId, 0);
    await this.accountRepository.save(account);
  }
}

// ✅ User と Account は完全に独立
// イベント駆動で協調
```

---

## 🔍 循環依存の検出方法

### Tool: madge（循環依存検出）

```bash
npm install --save-dev madge
npm install --save-dev @types/madge
```

### 使用方法

```bash
# 1. 循環依存をリスト表示
npx madge --circular src/

# 出力例
⚠️  Circular dependencies found:
  src/domain/User.ts → src/domain/Account.ts → src/domain/User.ts
  src/application/Service1.ts → src/infrastructure/Adapter.ts → src/application/Service1.ts

# 2. グラフを画像で可視化
npx madge --image dependency-graph.png src/

# 3. 詳細表示
npx madge --dependencies src/ | grep -E "circular|→"

# 4. 特定のモジュール配下のみ検査
npx madge --circular src/domain/
```

### Webpack/TypeScript での検出

```typescript
// webpack.config.js
const CircularDependencyPlugin = require('circular-dependency-plugin');

module.exports = {
  // ...
  plugins: [
    new CircularDependencyPlugin({
      exclude: /node_modules/,
      include: /src/,
      failOnError: true,          // 循環依存で build 失敗
      allowAsyncCycles: false,     // async の循環は許可しない
      cwd: process.cwd()
    })
  ]
};
```

### TypeScript での検出（tsc --diagnostics）

```bash
tsc --diagnostics --listFiles 2>&1 | grep -i circular
```

---

## 📊 依存方向の一般的なパターン

### ✅ 良いパターン（DAG）

```
Presentation → Application → Domain ← Infrastructure
                                ↑
                            依存方向
```

**各層が参照可能：**
- Presentation: Application, Infrastructure
- Application: Domain, Infrastructure
- Domain: Domain のみ
- Infrastructure: 外部ライブラリのみ

### ❌ 悪いパターン（循環）

```
User ←→ Account       // 双方向
  ↓      ↓
Service  Adapter      // 同じインターフェース参照
  ↓      ↓
  ←---←-- (循環)
```

---

## 📋 チェックリスト

### 設計フェーズ

```
✅ 依存方向を DAG（有向非巡回グラフ）で設計
✅ インターフェース経由の依存を使用
✅ 各モジュールの責務が明確
✅ モジュール境界が定義されている
```

### 実装フェーズ

```
✅ madge で循環依存がない
✅ インポート文が「下位層へのみ」
✅ 相互参照がない
✅ イベント駆動で遠い層を結合しない
```

### テスト・レビュー

```
✅ 各モジュールが独立してテスト可能
✅ モック化に支障がない
✅ コードレビューで循環参照が指摘される
✅ build に失敗することがない
```

---

## 🔗 関連セクション

- [密結合の回避](./02-tight-coupling.md) - インターフェース設計
- [実装ガイド](../05-implementation-guide/) - 正しい層構造

---

**完了！アンチパターンマスター 🎓**
