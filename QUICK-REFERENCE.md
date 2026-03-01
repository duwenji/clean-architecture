# クイックリファレンス

> 30秒で理解するクリーンアーキテクチャの全体像

---

## 🎯 コアコンセプト（3つ）

### 1️⃣ 4層アーキテクチャ

```
┌─────────────────────────────────────┐
│  🖥️ Presentation Layer             │  UI・Controller・HTTP処理
├─────────────────────────────────────┤
│  📋 Application Layer               │  UseCase・ビジネスプロセス
├─────────────────────────────────────┤
│  💼 Domain Layer ⭐ (独立)          │  ビジネスルール・エンティティ
├─────────────────────────────────────┤
│  🔧 Infrastructure Layer            │  DB・外部サービス・実装
└─────────────────────────────────────┘

✅ 重要: 上層は下層に依存 ⬇️
        下層は上層を参照しない ❌
```

### 2️⃣ SOLID原則（5つ）

| 原則 | 意味 | キーワード |
|-----|------|----------|
| **S** | Single Responsibility | 1つの責務 |
| **O** | Open/Closed | 拡張に開く、変更に閉じる |
| **L** | Liskov Substitution | 親の代わりに子が使える |
| **I** | Interface Segregation | 不要なインターフェースは実装しない |
| **D** | Dependency Inversion | 具象でなく抽象に依存 |

### 3️⃣ 3つの重要性

```
独立性       = フレームワークや DB に依存しない
          → テストが容易
          → 保守が簡単

テスト容易性  = ビジネスロジックを単体テストできる
          → 品質が上がる
          → 信頼性が高い

保守性      = 変更の影響範囲を最小化
          → 新機能追加が簡単
          → バグが減る
```

---

## 📝 実装のポイント（5つ）

### 1. リポジトリパターン
```typescript
// DB を抽象化（実装を隠す）
interface UserRepository {
  save(user: User): Promise<void>;
  getById(id: string): Promise<User | null>;
}

// MySQL, MongoDB どちらでも対応
class MySQLUserRepository implements UserRepository { ... }
class MongoDBUserRepository implements UserRepository { ... }
```

### 2. 依存性注入（DI）
```typescript
// ❌ 直接生成（NG）
const service = new UserService(new MySQLRepository());

// ✅ 外部から注入（OK）
constructor(private repo: UserRepository) {}
```

### 3. ユースケース
```typescript
// Use Case = ビジネスシーン 1つ
class CreateUserUseCase {
  execute(email: string): Promise<User>
}

class UpdateUserUseCase {
  execute(id: string, newEmail: string): Promise<void>
}

// ビジネスロジック ≠ テクニカルロジック
// 注文処理 ≠ DB接続
```

### 4. エンティティ
```typescript
// ドメイン層: ビジネスルール + データ
class User {
  constructor(id: string, email: Email) {
    this.id = id;
    this.email = email;
  }
  
  // ビジネスルール（いつ？）
  changeEmail(newEmail: Email): void {
    if (!this.email.canChangeTo(newEmail)) {
      throw new EmailChangeError();
    }
    this.email = newEmail;
  }
}
```

### 5. DTO（Data Transfer Object）
```typescript
// 層間の通信用（データだけ）
export class CreateUserRequest {
  email: string;
  password: string;
}

export class UserResponse {
  id: string;
  email: string;
  createdAt: Date;
}

// マッピング
const dto = new UserResponse(user.id, user.email.value, user.createdAt);
```

---

## ⚠️ よくある間違い（4つ）

| 間違い | 症状 | 解決策 |
|------|------|------|
| **過度な設計** | 単純な機能に複雑な層 | 規模に応じて段階的に |
| **密結合** | ドメイン層が DB を参照 | インターフェース経由に |
| **貧血モデル** | Entity がただのデータ | ビジネスロジックを含める |
| **循環依存** | A→B→A の参照 | インターフェースで分離 |

---

## 🚀 始める順番

```
Step 1: ドメイン層
  ↓
  エンティティとビジネスルールを設計
  例: User（ID, Email）、changeEmail()メソッド

Step 2: リポジトリ
  ↓
  DB抽象化（インターフェースと実装）
  例: UserRepository インターフェース → MySQLUserRepository

Step 3: Use Case
  ↓
  ビジネス処理を記述
  例: CreateUserUseCase → userRepository.save(user)

Step 4: Controller
  ↓
  HTTP エンドポイント
  例: POST /users → new CreateUserUseCase(repo).execute()

Step 5: テスト
  ↓
  Mock でリポジトリを置き換え
  例: const mockRepo = { save: jest.fn() }
```

---

## 📊 チェックリスト

```
✅ ドメイン層は独立している
✅ エンティティがビジネスロジックを持つ
✅ リポジトリで DB を抽象化
✅ Use Case で層を仲介
✅ DI で依存関係を管理
✅ エラーをドメイン例外で表現
✅ ユニットテストできる
✅ 他のプロジェクトにコピーできる
```

---

## 🔗 各セクションへのリンク

**初心者向け:**
- [01-introduction](../01-introduction/) - 基本を理解
- [02-core-principles](../02-core-principles/) - 原則を学ぶ
- [03-architecture-layers](../03-architecture-layers/) - 層を把握

**実装向け:**
- [04-design-patterns](../04-design-patterns/) - パターン習得
- [05-implementation-guide](../05-implementation-guide/) - 実装方法
- [06-best-practices](../06-best-practices/) - 品質向上

**応用向け:**
- [07-common-pitfalls](../07-common-pitfalls/) - アンチパターン
- [08-case-studies](../08-case-studies/) - 実装例
- [09-tools-and-resources](../09-tools-and-resources/) - ツール・リソース

---

## 💡 本当の違い（Before/After）

### ❌ Before: スパゲッティコード
```typescript
app.post('/users', async (req, res) => {
  try {
    const user = await db.query('INSERT INTO users ...');  // 技術的関心
    await sendEmail(user.email);  // メール送信も同時
    await updateCache(user);      // キャッシュ更新も同時
    res.json(user);
  } catch (e) {
    res.status(500).json({ error: e });
  }
});
```

### ✅ After: クリーンアーキテクチャ
```typescript
// 1. ドメイン層（ビジネスルール）
class User {
  changeEmail(email: Email) {
    if (!email.isValid()) throw new InvalidEmailError();
    this.email = email;
  }
}

// 2. Use Case（ビジネスプロセス）
async execute(email: string) {
  const user = new User(uuid(), new Email(email));
  await this.userRepository.save(user);
  await this.notificationService.notify(user);
  return user;
}

// 3. Controller（HTTP処理）
@Post('/users')
async create(@Body() req: CreateUserRequest) {
  const result = await this.createUserUseCase.execute(req.email);
  return result;
}

// ✅ 利点: テスト可能、変更容易、独立している
```

---

**最初に読むべきファイル: [01-introduction](../01-introduction/01-overview.md)**
