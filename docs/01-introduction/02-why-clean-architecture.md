# 02. なぜクリーンアーキテクチャが必要か？

> **コンセプト**: ソフトウェアの複雑性が増すほど、設計の重要性は高まる。クリーンアーキテクチャは、その複雑性に対処するための実証済みの方法。

## 🚨 実際の問題：レガシーコードの悪循環

### シナリオ：スタートアップから成長段階へ

#### **Phase 1: MVP（最小限の製品）- 最初は快適**

```
初期段階
  ↓
機能数: 少ない
コード量: 小規模
チーム: 1-2人
アーキテクチャ: なし（単純なMVCでOK）
開発速度: 最高
  ↓
「これで十分」と思われていた...
```

#### **Phase 2: 成長段階 - 問題が顕在化**

```
3ヶ月経過...
  ↓
機能数: 50+
コード量: 100,000行以上
チーム: 10人
アーキテクチャ: 元々なし
開発速度: ↓ (大幅に低下)
  ↓
「なぜこんなに遅いんだ？」
└─ 新機能追加に2週間かかるように
└─ バグ修正で新しいバグが入る
└─ テストは手動のみ（不安定）
```

---

## 📉 典型的な問題パターン

### 問題1️⃣: スパゲッティコード

```typescript
// ❌ 悪い例：責任が混在

class UserController {
  private db: Database;
  private emailService: EmailService;

  async register(req: Request, res: Response) {
    // UI層の責任
    const email = req.body.email;
    const password = req.body.password;

    // ❌ DBアクセス（本来はRepository層）
    const user = await this.db.query(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );

    if (user) {
      // ❌ ビジネスロジック（本来はドメイン層）
      res.status(400).json({ error: 'Already registered' });
      return;
    }

    // ❌ パスワードのハッシング化（セキュリティロジック）
    const hashedPassword = await bcrypt.hash(password, 10);

    // ❌ ユーザー作成（ドメイン層の責任）
    const newUser = {
      id: uuid(),
      email,
      password: hashedPassword,
      createdAt: new Date()
    };

    // ❌ DBに直接insert
    await this.db.query(
      'INSERT INTO users (id, email, password, created_at) VALUES (?, ?, ?, ?)',
      [newUser.id, newUser.email, newUser.password, newUser.createdAt]
    );

    // ❌ メール送信（外部サービス）
    await this.emailService.sendWelcomeEmail(email);

    // ❌ メール送信結果のハンドリング（アプリケーション層の責任）
    if (!result) {
      // でも既にDBには保存されている...
      res.status(500).json({ error: 'Email failed' });
      return;
    }

    res.json(newUser);
  }
}
```

**結果:**
- 🔴 Controller = 500行以上の巨大クラス
- 🔴 テストが不可能（DBとメールサービスが必須）
- 🔴 変更が困難（1行の変更で複数の層に影響）

---

### 問題2️⃣: テストの困難さ

```typescript
// ❌ テストできない例

describe('UserController.register', () => {
  test('should register user', async () => {
    // DB立ち上げが必要
    const db = await startTestDatabase();
    
    // メールサービスも立ち上げが必要
    const emailService = await startEmailService();
    
    // コントローラー作成（外部依存が必須）
    const controller = new UserController(db, emailService);

    // テスト実行（遅い、不安定）
    const result = await controller.register(
      { body: { email: 'test@example.com', password: 'pass' } },
      mockResponse
    );

    // テスト終了後の後片付けが複雑
    await db.close();
    await emailService.close();
    
    expect(result).toBe(200);
    // 実時間で30秒かかった...
  });
});
```

**結果:**
- 🔴 テスト実行時間が長い（外部依存が多いため）
- 🔴 テストが脆弱（DB接続エラーでテストが失敗）
- 🔴 テストを避けるようになる

---

### 問題3️⃣: 変更への脆弱性

```
「DBをMySQLからPostgreSQLに変える」という要件
  ↓
プレゼンテーション層のコードを修正する必要がある
  ↓
ドメイン層のコードも修正する必要がある
  ↓
アプリケーション層のコードも修正する必要がある
  ↓
全体で50ファイル以上修正
  ↓
テストを走らせる（30分かかる）
  ↓
どこかで壊れている
  ↓
デバッグに2日費やす
```

---

### 問題4️⃣: ビジネスロジックの散在

```
「ユーザー登録の条件を変更する」という要件
  ↓
コントローラーに散在したバリデーションを探す
  ↓
DBログに仕込まれたロジックを確認
  ↓
メールサービス側でも条件チェックがある
  ↓
全体で15ファイルを修正
  ↓
どこか1つ修正漏れがあるとバグになる
```

---

## ✅ クリーンアーキテクチャが解決すること

### 解決1️⃣: 関心事の分離

```typescript
// ✅ クリーンアーキテクチャ

// domain/User.ts - ビジネスロジックのみ
export class User {
  constructor(email: string, password: string) {
    if (!this.isValidEmail(email)) {
      throw new Error('Invalid email');
    }
  }
}

// application/CreateUserUseCase.ts - ユースケース
export class CreateUserUseCase {
  async execute(request) {
    const user = new User(request.email, request.password);
    await this.userRepository.save(user);
    await this.notificationService.sendWelcomeEmail(user.email);
  }
}

// presentation/UserController.ts - UI層
export class UserController {
  async register(req: Request, res: Response) {
    const result = await this.createUserUseCase.execute(req.body);
    res.json(result);
  }
}
```

**メリット:**
- ✅ 各層は単一の責任のみ
- ✅ ビジネスロジックが集約されている
- ✅ 変更時の影響が最小限

---

### 解決2️⃣: テストの容易性

```typescript
// ✅ 簡単にテストできる

describe('CreateUserUseCase', () => {
  test('should create user', async () => {
    // モックを使用（DBは不要）
    const mockRepository = new MockUserRepository();
    const useCase = new CreateUserUseCase(mockRepository);

    // テスト実行（1秒）
    await useCase.execute({
      email: 'test@example.com',
      password: 'pass123'
    });

    // 検証
    expect(mockRepository.savedUsers).toHaveLength(1);
  });
});
```

**メリット:**
- ✅ 高速（外部依存なし）
- ✅ 安定（ネットワークに依存しない）
- ✅ 並列実行可能

---

### 解決3️⃣: 変更への強さ

```
「DBをMySQLからPostgreSQLに変える」

クリーンアーキテクチャ:
  ↓
インフラストラクチャ層の1つのファイル（MySQLUserRepository.ts）を修正
  ↓
それだけ
```

**比較:**
| 項目 | 従来設計 | クリーン設計 |
|-----|--------|----------|
| 修正ファイル数 | 50+ | 1 |
| 修正時間 | 2日 | 1時間 |
| 回帰テスト | 複雑 | シンプル |

---

### 解決4️⃣: ビジネスロジックの集約

```
「ユーザー登録の条件を変更」

クリーンアーキテクチャ:
  ↓
User エンティティ（ドメイン層）の1ファイルを修正
  ↓
それだけ（変更が集約されている）
```

---

## 📊 開発速度の比較

```
従来設計              クリーンアーキテクチャ

機能追加速度          機能追加速度
    ↑                     ↑
    │     ╱╲               │        ╱
    │   ╱  │              │      ╱
    │ ╱    │              │    ╱
    └──────┴──  時間      └─ ─────── 時間
    
初期は快適          最初は遅いが、
でも段々遅く...     長期には高速を維持
```

---

## 💼 実務での重要性

### 小規模プロジェクト
```
クリーンアーキテクチャはやり過ぎか？
  → No。基盤をしっかり作ることで、後の成長が容易
```

### 中規模プロジェクト
```
複雑性が増している？
  → クリーンアーキテクチャが本当の価値を発揮し始める
```

### 大規模プロジェクト
```
複数チームが開発？
  → クリーンアーキテクチャは必須（チームの独立性を保証）
```

---

## 🎓 キーポイント

| 問題 | クリーンアーキテクチャの解決策 |
|-----|---------------------------|
| スパゲッティコード | 層による関心事の分離 |
| テスト困難 | 依存性注入とモック化可能性 |
| 変更への脆弱性 | 依存性の一方向化 |
| ビジネスロジック散在 | ドメイン層への集約 |

---

## ➡️ 次のステップ

次のセクションでは、クリーンアーキテクチャの**3つの重要な特性**を詳しく学びます。

[次: 主要概念 →](./03-key-concepts.md)
