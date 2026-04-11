# クリーンアーキテクチャ完全ガイド {#cover-00-cover}

**実務で使える設計原則と実装パターン**

スケーラブルで保守しやすいソフトウェアを作るための、
クリーンアーキテクチャ実践ガイドです。

> 💡 ブラウザで https://duwenji.github.io/spa-quiz-app/ を開くと、関連トピックをクイズ形式で復習できます。

- 著者: 杜 文吉
- 対象: アプリ設計を深めたい開発者 / Tech Lead / アーキテクト
- テーマ: domain / dependency rule / testing / maintainability

**この教材で学べること**
- クリーンアーキテクチャの全体像と判断軸
- 実務に適用できる設計パターンと実装手順
- テスト容易性・保守性・拡張性の高め方
- よくある失敗パターンと改善アプローチ

# Introduction {#chapter-01-introduction}

## 01. クリーンアーキテクチャ概要 {#section-01-introduction-01-overview}


> **コンセプト**: アプリケーションを独立した関心事の層に分けることで、テストしやすく、保守しやすいシステムを構築する。

### 🎯 このセクションで学べること

- クリーンアーキテクチャとは何か
- 従来の設計との違い
- 基本的な層構造
- なぜ今必要なのか

---

### クリーンアーキテクチャとは？

**クリーンアーキテクチャ** (Clean Architecture) は、ロバート・C・マーチン（Uncle Bob）が著書「Clean Architecture」で提唱した設計手法です。

#### 🔑 核となる考え方

```
ビジネスロジック（ドメイン）
       ↑
   (依存する)
       ↓
アプリケーションロジック（ユースケース）
       ↑
   (依存する)
       ↓
外部フレームワーク・ツール（DB、Web、API）
```

**重要**: 外側が内側に依存する（内側は外側に依存しない）

---

### 📊 典型的なアーキテクチャ図

#### クリーンアーキテクチャの4層構造

```
┌────────────────────────────────────┐
│    プレゼンテーション層              │
│  (UI, Web Controller, API, CLI)    │
│────────────────────────────────────│
│      アプリケーション層              │
│   (ユースケース, サービス)          │
│────────────────────────────────────│
│        ドメイン層                    │
│   (エンティティ, ビジネスロジック)  │
│────────────────────────────────────│
│    インフラストラクチャ層            │
│  (DB, 外部API, ファイルシステム)   │
└────────────────────────────────────┘

      ↑
  依存の方向
```

---

### 🔄 具体例：ユーザー登録機能

#### ❌ 従来の設計（よくある悪い例）

```typescript
// controller.ts
class UserController {
  createUser(req, res) {
    // DBに直接接続
    const db = new Database();
    
    // ビジネスロジックとUIが混在
    if (!req.body.email) {
      res.status(400).send('メール必須');
      return;
    }
    
    const user = {
      id: Math.random(),
      email: req.body.email,
      password: req.body.password,
      createdAt: new Date()
    };
    
    // DBに直接保存
    db.insert('users', user);
    
    res.json(user);
  }
}
```

**問題点:**
- ❌ UI層（Controller）にビジネスロジック混在
- ❌ DBに強く依存している
- ❌ テストが困難（DBが必要）
- ❌ 変更に弱い（DBを変更したらテスト全体が影響）

---

#### ✅ クリーンアーキテクチャ設計

```
プレゼンテーション層（外側）
      ↓
   controller.ts  ← HTTPリクエストを受け取る
      ↓
アプリケーション層
      ↓
   CreateUserUseCase.ts  ← ビジネスロジック実行
      ↓
ドメイン層
      ↓
   User エンティティ  ← ビジネスルール
   UserRepository インターフェース
      ↓
インフラストラクチャ層（内側）
      ↓
   MySQLUserRepository.ts  ← 実装詳細
```

##### **ドメイン層** - ビジネスルール

```typescript
// domain/entity/User.ts
export class User {
  id: string;
  email: string;
  password: string;
  createdAt: Date;

  constructor(id: string, email: string, password: string) {
    // ビジネスルール：メールのバリデーション
    if (!this.isValidEmail(email)) {
      throw new Error('Invalid email format');
    }
    
    this.id = id;
    this.email = email;
    this.password = password;
    this.createdAt = new Date();
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }
}

// domain/repository/UserRepository.ts
export interface UserRepository {
  save(user: User): Promise<void>;
  findByEmail(email: string): Promise<User | null>;
}
```

##### **アプリケーション層** - ユースケース

```typescript
// application/usecase/CreateUserUseCase.ts
export class CreateUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private generateId: () => string
  ) {}

  async execute(request: CreateUserRequest): Promise<CreateUserResponse> {
    // 既存ユーザーをチェック
    const existingUser = await this.userRepository.findByEmail(request.email);
    if (existingUser) {
      throw new Error('Email already registered');
    }

    // ユーザーを作成（ビジネスルールはドメイン層で実行）
    const user = new User(
      this.generateId(),
      request.email,
      request.password
    );

    // リポジトリを通じて保存
    await this.userRepository.save(user);

    return {
      id: user.id,
      email: user.email
    };
  }
}
```

##### **プレゼンテーション層** - Controller

```typescript
// presentation/controller/UserController.ts
export class UserController {
  constructor(private createUserUseCase: CreateUserUseCase) {}

  async createUser(req: Request, res: Response) {
    try {
      const result = await this.createUserUseCase.execute({
        email: req.body.email,
        password: req.body.password
      });
      
      res.status(201).json(result);
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }
}
```

##### **インフラストラクチャ層** - 実装

```typescript
// infrastructure/persistence/MySQLUserRepository.ts
export class MySQLUserRepository implements UserRepository {
  constructor(private db: Database) {}

  async save(user: User): Promise<void> {
    await this.db.query(
      'INSERT INTO users (id, email, password, created_at) VALUES (?, ?, ?, ?)',
      [user.id, user.email, user.password, user.createdAt]
    );
  }

  async findByEmail(email: string): Promise<User | null> {
    const row = await this.db.query(
      'SELECT * FROM users WHERE email = ?',
      [email]
    );
    
    if (!row) return null;
    
    return new User(row.id, row.email, row.password);
  }
}
```

---

### 📈 メリットの比較表

| 項目 | 従来設計 | クリーンアーキテクチャ |
|-----|--------|------------------|
| **テスト** | DB必須、遅い | モック使用、高速 |
| **変更对応** | 影響大きい | 局所的な影響 |
| **ビジネスロジック** | 複数の層に散在 | ドメイン層に集約 |
| **再利用性** | 低い | 高い |
| **保守性** | 困難 | 容易 |
| **学習曲線** | 浅い | 深い（最初） |

---

### 🧪 テストコード例

#### クリーンアーキテクチャならテストが簡単

```typescript
// __tests__/application/CreateUserUseCase.test.ts
describe('CreateUserUseCase', () => {
  let useCase: CreateUserUseCase;
  let mockRepository: MockUserRepository;

  beforeEach(() => {
    // モックリポジトリを使用（DBは不要）
    mockRepository = new MockUserRepository();
    useCase = new CreateUserUseCase(
      mockRepository,
      () => 'generated-id'
    );
  });

  test('should create user successfully', async () => {
    const result = await useCase.execute({
      email: 'user@example.com',
      password: 'password123'
    });

    expect(result.email).toBe('user@example.com');
    expect(mockRepository.savedUsers).toHaveLength(1);
  });

  test('should reject duplicate email', async () => {
    mockRepository.addUser(new User('1', 'user@example.com', 'pass'));

    expect(async () => {
      await useCase.execute({
        email: 'user@example.com',
        password: 'password123'
      });
    }).rejects.toThrow('Email already registered');
  });

  test('should reject invalid email', async () => {
    expect(async () => {
      await useCase.execute({
        email: 'invalid-email',
        password: 'password123'
      });
    }).rejects.toThrow('Invalid email format');
  });
});
```

---

### 🎓 クリーンアーキテクチャの3つの特徴

1. **独立性** - ビジネスロジックがフレームワークに依存しない
2. **テスト性** - 外部依存なしにテスト可能
3. **保守性** - 変更が局所的で、相互的な影響が少ない

---

### 📋 まとめ

| ポイント | 説明 |
|---------|------|
| **本質** | 関心事の分離と依存方向の制御 |
| **4層構造** | Presentation → Application → Domain → Infrastructure |
| **依存性** | 外→内（内は外に依存しない） |
| **目的** | テスト性、保守性、再利用性の向上 |

---

### ➡️ 次のステップ

次のセクションでは、**なぜクリーンアーキテクチャが必要か** - 実際の問題と解決方法を詳しく見てみます。

[次: 導入のメリット →](#section-01-introduction-02-why-clean-architecture)

## 02. なぜクリーンアーキテクチャが必要か？ {#section-01-introduction-02-why-clean-architecture}


> **コンセプト**: ソフトウェアの複雑性が増すほど、設計の重要性は高まる。クリーンアーキテクチャは、その複雑性に対処するための実証済みの方法。

### 🚨 実際の問題：レガシーコードの悪循環

#### シナリオ：スタートアップから成長段階へ

##### **Phase 1: MVP（最小限の製品）- 最初は快適**

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

##### **Phase 2: 成長段階 - 問題が顕在化**

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

### 📉 典型的な問題パターン

#### 問題1️⃣: スパゲッティコード

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

#### 問題2️⃣: テストの困難さ

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

#### 問題3️⃣: 変更への脆弱性

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

#### 問題4️⃣: ビジネスロジックの散在

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

### ✅ クリーンアーキテクチャが解決すること

#### 解決1️⃣: 関心事の分離

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

#### 解決2️⃣: テストの容易性

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

#### 解決3️⃣: 変更への強さ

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

#### 解決4️⃣: ビジネスロジックの集約

```
「ユーザー登録の条件を変更」

クリーンアーキテクチャ:
  ↓
User エンティティ（ドメイン層）の1ファイルを修正
  ↓
それだけ（変更が集約されている）
```

---

### 📊 開発速度の比較

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

### 💼 実務での重要性

#### 小規模プロジェクト
```
クリーンアーキテクチャはやり過ぎか？
  → No。基盤をしっかり作ることで、後の成長が容易
```

#### 中規模プロジェクト
```
複雑性が増している？
  → クリーンアーキテクチャが本当の価値を発揮し始める
```

#### 大規模プロジェクト
```
複数チームが開発？
  → クリーンアーキテクチャは必須（チームの独立性を保証）
```

---

### 🎓 キーポイント

| 問題 | クリーンアーキテクチャの解決策 |
|-----|---------------------------|
| スパゲッティコード | 層による関心事の分離 |
| テスト困難 | 依存性注入とモック化可能性 |
| 変更への脆弱性 | 依存性の一方向化 |
| ビジネスロジック散在 | ドメイン層への集約 |

---

### ➡️ 次のステップ

次のセクションでは、クリーンアーキテクチャの**3つの重要な特性**を詳しく学びます。

[次: 主要概念 →](#section-01-introduction-03-key-concepts)

## 03. クリーンアーキテクチャの3つの主要概念 {#section-01-introduction-03-key-concepts}


> **コンセプト**: クリーンアーキテクチャは3つの重要な特性で成り立っている：独立性、テスト性、保守性。

### 🎯 3つの主要概念

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

### 1️⃣ 独立性 (Independence)

#### コンセプト
ビジネスロジック（ドメイン層）は、フレームワーク、DB、Webサーバーなどの外部ツールに**依存しない**という特性。

#### ❌ 独立性がない例

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

#### ✅ 独立性がある例

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

#### 📊 独立性の利点

| シナリオ | 影響 |
|---------|-----|
| **ExpressからFastifyに移行** | UI層のみ変更 |
| **MySQLからPostgreSQLに移行** | インフラ層のみ変更 |
| **Webからモバイルに追加展開** | ドメイン・アプリケーション層は流用 |
| **テスト環境での実行** | モックで十分 |

---

### 2️⃣ テスト性 (Testability)

#### コンセプト
単体テスト（ユニットテスト）が簡単に書けて、高速に実行できる特性。

#### ❌ テスト性が低い例

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

#### ✅ テスト性が高い例

##### **Step 1: リポジトリで抽象化**

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

##### **Step 2: 依存性注入**

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

##### **Step 3: モックを使ったテスト**

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

#### 📊 テスト性の改善効果

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

### 3️⃣ 保守性 (Maintainability)

#### コンセプト
コードを修正や拡張する際に、変更が局所的で、他の部分への影響が最小限である特性。

#### ❌ 保守性が低い例

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

#### ✅ 保守性が高い例

##### **修正例1: メールバリデーション形式を変更**

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

##### **修正例2: DBをPostgreSQLに変更**

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

##### **修正例3: パスワード要件を変更**

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

#### 📊 保守性の改善効果

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

### 🎓 まとめ：3つの概念の相互関係

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

### 📋 各概念のチェックリスト

#### 独立性のチェック

- [ ] ドメイン層がフレームワーク（Express, Django等）をインポートしていない
- [ ] ドメイン層がDB操作を直接行なっていない
- [ ] ドメイン層が外部APIを直接呼び出していない
- [ ] ドメイン層がファイルシステムに直接アクセスしていない

#### テスト性のチェック

- [ ] ドメイン層は外部依存なしにテスト可能
- [ ] リポジトリがインターフェースで定義されている
- [ ] 外部サービスがインターフェースで抽象化されている
- [ ] テストに外部ツール（DBサーバー等）が不要

#### 保住性のチェック

- [ ] 同じビジネスロジックが複数ファイルに散在していない
- [ ] 層の責任が明確に分かれている
- [ ] 1つの変更で影響を受けるファイルが3ファイル以下
- [ ] 名前から責任が推測できる

---

### ➡️ 次のステップ

さて、クリーンアーキテクチャの基本概念がわかったところで、具体的な**SOLID原則**を学びます。これらの原則がクリーンアーキテクチャを実現するための設計ルールです。

[次: SOLID原則 →](#chapter-02-core-principles)

# Core Principles {#chapter-02-core-principles}

## 01. 単一責任の原則 (SRP) - Single Responsibility Principle {#section-02-core-principles-01-single-responsibility}


> **原則**: クラスは変更する理由が1つだけであるべき。言い換えれば、クラスは1つの責任だけを持つべき。

### 🎯 コンセプト

```
┌──────────────────────────────────────────┐
│ 1つのクラス = 1つの変更理由               │
├──────────────────────────────────────────┤
│ "変更する理由"とは：要件変更のこと       │
│                                          │
│ 例：                                     │
│ ・ UI形式を変更したい                   │
│ ・ ビジネスルールを変更したい           │
│ ・ DBを変更したい                       │
│                                          │
│ → 各々が別のクラスの責任                │
└──────────────────────────────────────────┘
```

---

### ❌ SRPに違反する例

#### 例：複数の責任が1つのクラスに

```typescript
// ❌ 悪い例：UserService が複数の責任を持っている

export class UserService {
  // 責任1: ユーザー情報の管理
  async getUserInfo(userId: string) {
    const user = await this.db.query(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );
    return user;
  }

  // 責任2: パスワードの処理
  async changePassword(userId: string, newPassword: string) {
    const hashedPassword = bcrypt.hashSync(newPassword, 10);
    await this.db.query(
      'UPDATE users SET password = ? WHERE id = ?',
      [hashedPassword, userId]
    );
  }

  // 責任3: ユーザーのバリデーション
  validateEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  // 責任4: メール送信
  async sendWelcomeEmail(email: string) {
    await this.emailService.send(
      email,
      'Welcome!',
      'Welcome to our service!'
    );
  }

  // 責任5: ユーザーの削除
  async deleteUser(userId: string) {
    await this.db.query('DELETE FROM users WHERE id = ?', [userId]);
  }

  // 責任6: ユーザー検索
  async searchUsers(query: string) {
    return await this.db.query(
      'SELECT * FROM users WHERE name LIKE ?',
      [`%${query}%`]
    );
  }
}
```

**問題:**
- 🔴 500行以上のクラス
- 🔴 メールサービス仕様を変更
  → UserServiceを修正 ❌
- 🔴 パスワード暗号化方式を変更
  → UserServiceを修正 ❌
- 🔴 DBをPostgreSQLに変更
  → UserServiceを修正 ❌
- 🔴 テストが複雑（全ての責任をモックする必要）

---

### ✅ SRP を適用した設計

```
UserService (複数の責任)
       ↓ 分割
    ┌──┴──┐
    │     │
    ↓     ↓
UserRepository   PasswordService   EmailService   ...
(ユーザー管理)    (パスワード処理)   (メール送信)
```

#### Step 1: 責任ごとにクラスを分割

```typescript
// ##### ドメイン層 #####

// 責任1: ユーザー情報の保持・検証
export class User {
  private id: string;
  private email: string;
  private hashedPassword: string;

  constructor(id: string, email: string, hashedPassword: string) {
    if (!this.isValidEmail(email)) {
      throw new InvalidEmailError(email);
    }
    this.id = id;
    this.email = email;
    this.hashedPassword = hashedPassword;
  }

  getId(): string {
    return this.id;
  }

  getEmail(): string {
    return this.email;
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }
}

// ##### アプリケーション層 #####

// 責任2: パスワード処理
export class PasswordService {
  // パスワードのハッシング
  hashPassword(password: string): string {
    return bcrypt.hashSync(password, 10);
  }

  // パスワードの検証
  verifyPassword(plainPassword: string, hashedPassword: string): boolean {
    return bcrypt.compareSync(plainPassword, hashedPassword);
  }
}

// 責任3: メール送信
export class EmailService {
  async sendWelcomeEmail(email: string): Promise<void> {
    await this.sendEmail(
      email,
      'Welcome!',
      'Welcome to our service!'
    );
  }

  async sendPasswordResetEmail(email: string, resetToken: string): Promise<void> {
    await this.sendEmail(
      email,
      'Password Reset',
      `Click here to reset: ${resetToken}`
    );
  }

  private async sendEmail(to: string, subject: string, body: string): Promise<void> {
    // メール送信実装
  }
}

// 責任4: ユーザー保存・取得（リポジトリ）
export interface UserRepository {
  save(user: User): Promise<void>;
  findById(userId: string): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  delete(userId: string): Promise<void>;
  search(query: string): Promise<User[]>;
}

// ##### インフラストラクチャ層 #####

// 責任5: MySQL実装
export class MySQLUserRepository implements UserRepository {
  constructor(private db: Database) {}

  async save(user: User): Promise<void> {
    await this.db.query(
      'INSERT INTO users (id, email, password) VALUES (?, ?, ?)',
      [user.getId(), user.getEmail(), user.hashedPassword]
    );
  }

  async findById(userId: string): Promise<User | null> {
    const row = await this.db.query(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );
    return row ? new User(row.id, row.email, row.password) : null;
  }

  // ... 他のメソッド
}
```

#### Step 2: ユースケースで統合

```typescript
// ##### アプリケーション層 #####

// ユーザー登録のユースケース
export class RegisterUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private passwordService: PasswordService,
    private emailService: EmailService,
    private generateId: () => string
  ) {}

  async execute(request: RegisterUserRequest): Promise<RegisterUserResponse> {
    // 既存ユーザーをチェック
    const existing = await this.userRepository.findByEmail(request.email);
    if (existing) {
      throw new UserAlreadyExistsError(request.email);
    }

    // ユーザーを作成（ドメイン層は自動的にバリデーション）
    const user = new User(
      this.generateId(),
      request.email,
      this.passwordService.hashPassword(request.password)
    );

    // 保存
    await this.userRepository.save(user);

    // メール送信
    await this.emailService.sendWelcomeEmail(user.getEmail());

    return {
      id: user.getId(),
      email: user.getEmail()
    };
  }
}
```

---

### 📊 SRP適用前後の比較

```
適用前：UserService
├─ getUserInfo()
├─ changePassword()
├─ validateEmail()
├─ sendWelcomeEmail()
├─ deleteUser()
├─ searchUsers()
└─ その他多数...
→ 500行以上、変更理由が6個以上

適用後：各クラスが1つの責任
├─ User (ユーザー情報、バリデーション)
├─ PasswordService (パスワード処理)
├─ EmailService (メール送信)
├─ UserRepository (ユーザーの永続化)
└─ RegisterUserUseCase (統合)
→ 各クラスが40-100行、変更理由が1つ
```

---

### 📊 テストの容易性

#### SRP適用後のテスト

```typescript
// PasswordService のテスト（インフラ依存なし）
describe('PasswordService', () => {
  test('should hash password', () => {
    const service = new PasswordService();
    const hashed = service.hashPassword('password123');
    
    expect(hashed).not.toBe('password123');
    expect(service.verifyPassword('password123', hashed)).toBe(true);
  });
});

// EmailService のテスト（実メール送信なし）
describe('EmailService', () => {
  test('should send welcome email', async () => {
    const mockSender = jest.fn();
    const service = new EmailService(mockSender);
    
    await service.sendWelcomeEmail('user@example.com');
    
    expect(mockSender).toHaveBeenCalledWith(
      expect.objectContaining({
        to: 'user@example.com',
        subject: 'Welcome!'
      })
    );
  });
});

// RegisterUserUseCase のテスト（各部品をモック）
describe('RegisterUserUseCase', () => {
  test('should register new user', async () => {
    const mockRepository = {
      findByEmail: jest.fn().mockResolvedValue(null),
      save: jest.fn()
    };
    const mockPasswordService = {
      hashPassword: jest.fn().mockReturnValue('hashed')
    };
    const mockEmailService = {
      sendWelcomeEmail: jest.fn()
    };

    const useCase = new RegisterUserUseCase(
      mockRepository,
      mockPasswordService,
      mockEmailService,
      () => 'user-id'
    );

    await useCase.execute({
      email: 'new@example.com',
      password: 'pass123'
    });

    expect(mockRepository.save).toHaveBeenCalled();
    expect(mockEmailService.sendWelcomeEmail).toHaveBeenCalled();
  });
});
```

---

### 🎯 SRP チェックリスト

```
✅ クラスを説明するとき、"かつ" や "および" が出ないか確認
✅ クラスの変更理由が1つだけか
✅ クラスのテストに1つのテストクラスで十分か
✅ クラスの行数が100行以下か
✅ メソッドが5個以下か
✅ クラスの名前が簡潔か
```

---

### 📋 まとめ

| ポイント | 説明 |
|---------|------|
| **本質** | 1つの理由だけで変更すべき |
| **単位** | クラス、メソッド、モジュール |
| **メリット** | テスト容易、保守容易、再利用性 |
| **見分け方** | 変更理由が複数あるか |

---

### ➡️ 次のステップ

次は、拡張に対しては開放的に、修正に対しては閉鎖的であるべき、という **開放閉鎖の原則** を学びます。

[次: 開放閉鎖の原則 →](#section-02-core-principles-02-open-closed)

## 02. 開放閉鎖の原則 (OCP) - Open/Closed Principle {#section-02-core-principles-02-open-closed}


> **原則**: ソフトウェアは拡張に対して開かれていて、修正に対して閉じられているべき。新機能追加では既存コードを修正せず、新しいコードを追加する。

### 🎯 コンセプト

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

### ❌ OCPに違反する例

#### シナリオ：決済方法を追加したい

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

### ✅ OCP を適用した設計

#### Step 1: インターフェースを定義

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

#### Step 2: インターフェース実装

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

#### Step 3: アプリケーション層で抽象化を使用

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

### 📊 修正の比較

#### ❌ OCP違反：新しい決済方法を追加

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

#### ✅ OCP適用：新しい決済方法を追加

```
新しいクラスを追加するだけ
  ↓
CryptoCurrencyPayment implements PaymentMethod { ... }
  
既存コード（PaymentProcessor）は一切修正なし
  
リスク：
- なし（既存テストはそのまま動く）
```

---

### 🎓 実装パターン

#### パターン1: インターフェース/抽象クラス

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

#### パターン2: Strategy パターン

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

#### パターン3: Template Method パターン

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

### 📊 テスト

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

### 🎯 OCP チェックリスト

```
✅ 新機能追加で既存クラスを修正せずに済むか
✅ インターフェースで抽象化されているか
✅ ファクトリパターンで生成が隔離されているか
✅ 既存テストが全て通るか（修正なしで）
✅ 拡張ポイントが明確か
```

---

### 📋 まとめ

| ポイント | 説明 |
|---------|------|
| **本質** | 拡張は追加、修正は少なく |
| **実装** | インターフェース、抽象クラス |
| **メリット** | 既存コード保護、テスト安定性 |
| **キー** | 抽象化が鍵 |

---

### ➡️ 次のステップ

次は、サブタイプはスーパータイプと置き換え可能であるべき、という **リスコフの置換原則** を学びます。

[次: リスコフの置換原則 →](#section-02-core-principles-03-liskov-substitution)

## 03. リスコフの置換原則 (LSP) - Liskov Substitution Principle {#section-02-core-principles-03-liskov-substitution}


> **原則**: サブタイプはスーパータイプと置き換え可能であるべき。派生クラスがベースクラスのインターフェースを破ってはいけない。

### 🎯 コンセプト

```
インターフェース PaymentMethod がある
  ↓
CreditCardPayment, PayPalPayment など
複数の実装がある
  ↓
どの実装を使っても同じ結果が得られるべき
  ↓
「PaymentMethod を使う側」は
実装の違いを意識する必要がない
```

---

### ❌ LSPに違反する例

#### シナリオ：矩形と正方形

```typescript
// ❌ 悪い例：正方形が矩形の契約を破っている

class Rectangle {
  protected width: number;
  protected height: number;

  constructor(width: number, height: number) {
    this.width = width;
    this.height = height;
  }

  setWidth(width: number): void {
    this.width = width;
  }

  setHeight(height: number): void {
    this.height = height;
  }

  getArea(): number {
    return this.width * this.height;
  }
}

// 正方形は矩形の特殊ケース
class Square extends Rectangle {
  setWidth(width: number): void {
    // ❌ 正方形は幅と高さが常に同じ
    // つまり幅だけ変えると矩形の契約を破る
    this.width = width;
    this.height = width;  // 互いに依存している
  }

  setHeight(height: number): void {
    // ❌ 
    this.width = height;
    this.height = height;
  }
}

// クライアント側
function printArea(rectangle: Rectangle) {
  rectangle.setWidth(5);
  rectangle.setHeight(10);
  const area = rectangle.getArea();
  console.log(`Area: ${area}`);  // 期待値: 50
}

// 使用
const square = new Square(10, 10);
printArea(square);  // ❌ 出力: 100（期待値：50）
// 矩形のコントラクトが破られている
```

**問題:**
- 🔴 Square は Rectangle と置き換え不可能
- 🔴 クライアント側で型チェックが必要
- 🔴 予期しない動作をする

---

#### シナリオ2：鳥の飛行

```typescript
// ❌ 悪い例：全ての鳥が飛べると仮定

interface Bird {
  fly(): void;
  eat(): void;
}

class Sparrow implements Bird {
  fly(): void {
    console.log('Sparrow flying');
  }
  eat(): void {
    console.log('Sparrow eating');
  }
}

class Penguin implements Bird {
  fly(): void {
    // ❌ ペンギンは飛べない
    throw new Error('Penguins cannot fly!');
  }
  eat(): void {
    console.log('Penguin eating');
  }
}

// クライアント側
function makeBirdFly(bird: Bird) {
  bird.fly();  // ❌ ペンギンを渡すと実行時エラー
}

const birds: Bird[] = [new Sparrow(), new Penguin()];
birds.forEach(bird => makeBirdFly(bird));  // エラーで落ちる
```

**問題:**
- 🔴 実装時にはエラーが出ない（コンパイルエラーなし）
- 🔴 実行時まで問題が発覚しない
- 🔴 クライアント側で各バリエーションをチェックする必要

---

### ✅ LSP を適用した設計

#### 解決1：矩形と正方形の問題

```typescript
// ##### 適切な設計：矩形と正方形を分離 #####

// 共通インターフェース
export interface Shape {
  getArea(): number;
}

// 矩形（幅と高さが独立）
export class Rectangle implements Shape {
  constructor(
    private width: number,
    private height: number
  ) {}

  getArea(): number {
    return this.width * this.height;
  }

  // 幅と高さを独立して設定できる
  setDimensions(width: number, height: number): Rectangle {
    return new Rectangle(width, height);
  }
}

// 正方形（幅と高さが常に同じ）
export class Square implements Shape {
  constructor(private side: number) {}

  getArea(): number {
    return this.side * this.side;
  }

  // 辺の長さを設定
  setSide(side: number): Square {
    return new Square(side);
  }
}

// クライアント側
function calculateArea(shape: Shape): number {
  return shape.getArea();
}

// ✅ どちらを渡してもコントラクトを守る
const rect = new Rectangle(5, 10);
console.log(calculateArea(rect));  // 50

const square = new Square(7);
console.log(calculateArea(square));  // 49
```

#### 解決2：鳥の飛行の問題

```typescript
// ##### 適切な設計：鳥を分類 #####

// 共通インターフェース：全ての鳥が持つ能力
export interface Bird {
  eat(): void;
  sleep(): void;
}

// 飛べる鳥用インターフェース
export interface FlyingBird extends Bird {
  fly(): void;
}

// 飛べない鳥用インターフェース
export interface SwimmingBird extends Bird {
  swim(): void;
}

// 実装：スズメ（飛べる）
export class Sparrow implements FlyingBird {
  eat(): void {
    console.log('Sparrow eating');
  }

  sleep(): void {
    console.log('Sparrow sleeping');
  }

  fly(): void {
    console.log('Sparrow flying');
  }
}

// 実装：ペンギン（泳げる、飛べない）
export class Penguin implements SwimmingBird {
  eat(): void {
    console.log('Penguin eating');
  }

  sleep(): void {
    console.log('Penguin sleeping');
  }

  swim(): void {
    console.log('Penguin swimming');
  }
}

// クライアント側
function makeBirdFly(bird: FlyingBird) {
  bird.fly();  // ✅ FlyingBirdのみを受け付ける
}

function makeBirdSwim(bird: SwimmingBird) {
  bird.swim();  // ✅ SwimmingBirdのみを受け付ける
}

// 使用
makeBirdFly(new Sparrow());  // ✅ OK
makeBirdFly(new Penguin());  // ❌ コンパイルエラー（事前に検出）

makeBirdSwim(new Penguin());  // ✅ OK
makeBirdSwim(new Sparrow());  // ❌ コンパイルエラー
```

---

### 📊 LSP 違反のパターン

#### パターン1: 例外をスロー

```typescript
// ❌ LSP違反
interface PaymentMethod {
  process(amount: number): Promise<PaymentResult>;
}

class MockPaymentMethod implements PaymentMethod {
  async process(amount: number): Promise<PaymentResult> {
    throw new Error('This is a mock method');  // ❌
  }
}

// ✅ LSP準拠
class MockPaymentMethod implements PaymentMethod {
  async process(amount: number): Promise<PaymentResult> {
    return {
      success: true,
      transactionId: 'mock-tx-123',
      amount,
      timestamp: new Date()
    };
  }
}
```

#### パターン2: 事前条件を厳しくする

```typescript
// ❌ LSP違反
class Database {
  query(sql: string): Promise<any> {
    // SQLスタートメント以上を処理できる
  }
}

class RestrictedDatabase extends Database {
  async query(sql: string): Promise<any> {
    // ❌ 事前条件を厳しくしている
    if (!sql.startsWith('SELECT')) {
      throw new Error('Only SELECT allowed');
    }
    return super.query(sql);
  }
}
```

#### パターン3: 事後条件を弱くする

```typescript
// ❌ LSP違反
interface SavingsAccount {
  deposit(amount: number): void;
  withdraw(amount: number): void;  // 残高より多く引き出せない
  getBalance(): number;
}

class LoanAccount implements SavingsAccount {
  async withdraw(amount: number): void {
    // ❌ 事後条件を弱くしている
    // 残高以上でも引き出せる（負債になる）
    this.balance -= amount;
  }
}
```

---

### 🧪 テストで LSP を検証

```typescript
// LSP 違反をテストで検出
describe('Shape implementations', () => {
  function testShape(shape: Shape) {
    const area1 = shape.getArea();
    const area2 = shape.getArea();
    
    // ✅ 同じ結果が返される（メンタルモデルの一貫性）
    expect(area1).toBe(area2);
  }

  test('Rectangle substitution', () => {
    testShape(new Rectangle(5, 10));
  });

  test('Square substitution', () => {
    testShape(new Square(7));
  });
});

// LSP準拠のユースケーステスト
describe('PaymentProcessor LSP compliance', () => {
  async function testPaymentMethod(method: PaymentMethod) {
    const processor = new PaymentProcessor();
    const result = await processor.process(100, method);
    
    // ✅ 全ての実装が同じコントラクトを守っている
    expect(result).toHaveProperty('success');
    expect(result).toHaveProperty('transactionId');
    expect(result).toHaveProperty('amount');
    expect(result.amount).toBe(100);
  }

  test('CreditCard substitution', () => {
    return testPaymentMethod(new CreditCardPayment(...));
  });

  test('PayPal substitution', () => {
    return testPaymentMethod(new PayPalPayment(...));
  });

  test('BankTransfer substitution', () => {
    return testPaymentMethod(new BankTransferPayment(...));
  });
});
```

---

### 🎯 LSP チェックリスト

```
✅ 派生クラスが例外をスローしていないか
✅ 事前条件を厳しくしていないか
✅ 事後条件を弱くしていないか
✅ 契約不変条件を守っているか
✅ どの実装を代入しても挙動が予測可能か
```

---

### 📋 まとめ

| ポイント | 説明 |
|---------|------|
| **本質** | 入れ替え可能性の保証 |
| **チェック方法** | 派生クラスでコントラクト破っていないか |
| **メリット** | 予期しない動作の防止 |
| **キー** | インターフェースの契約を守る |

---

### ➡️ 次のステップ

次は、クライアントが必要のないメソッドに依存してはいけない、という **インターフェース分離の原則** を学びます。

[次: インターフェース分離の原則 →](#section-02-core-principles-04-interface-segregation)

## 04. インターフェース分離の原則 (ISP) - Interface Segregation Principle {#section-02-core-principles-04-interface-segregation}


> **原則**: クライアントは自分が使わないメソッドに依存してはいけない。大きなインターフェースは小さな専門的インターフェースに分割すべき。

### 🎯 コンセプト

```
大きなインターフェース
├─ メソッドA（使いたい）
├─ メソッドB（使いたい）
├─ メソッドC（使いたくない）
├─ メソッドD（使いたくない）
└─ メソッドE（使いたくない）

      ↓ 分割

小さな専門的インターフェース
├─ InterfaceX（メソッドA, B）
└─ InterfaceY（メソッドC, D, E）
```

---

### ❌ ISPに違反する例

#### シナリオ：複数機能を持つWorkerインターフェース

```typescript
// ❌ 悪い例：大きすぎるインターフェース

interface Worker {
  work(): void;
  eat(): void;
  manage(): void;
  reportToHR(): void;
  approveLeave(): void;
  codereview(): void;
}

// マネージャー：全部実装できる
class Manager implements Worker {
  work(): void { console.log('Manager working'); }
  eat(): void { console.log('Manager eating'); }
  manage(): void { console.log('Manager managing'); }
  reportToHR(): void { console.log('Manager reports'); }
  approveLeave(): void { console.log('Manager approves'); }
  codereview(): void { console.log('Manager reviewing code'); }
}

// 一般的なエンジニア：全部実装しなければならない
class Engineer implements Worker {
  work(): void { console.log('Engineer working'); }
  eat(): void { console.log('Engineer eating'); }
  manage(): void { throw new Error('Engineer cannot manage'); }  // ❌
  reportToHR(): void { throw new Error('Engineer cannot report'); }  // ❌
  approveLeave(): void { throw new Error('Engineer cannot approve'); }  // ❌
  codereview(): void { console.log('Engineer reviewing code'); }
}

// インターン：使えないメソッドばかり
class Intern implements Worker {
  work(): void { console.log('Intern working'); }
  eat(): void { console.log('Intern eating'); }
  manage(): void { throw new Error('Intern cannot manage'); }  // ❌
  reportToHR(): void { throw new Error('Intern cannot report'); }  // ❌
  approveLeave(): void { throw new Error('Intern cannot approve'); }  // ❌
  codereview(): void { console.log('Intern learning code'); }
}
```

**問題:**
- 🔴 全員が全メソッド実装を強要される
- 🔴 使わないメソッドに依存させられる
- 🔴 例外スローが多発
- 🔴 型安全性がない
- 🔴 動作が予測できない

---

### ✅ ISP を適用した設計

#### Step 1: 責任ごとインターフェースを分割

```typescript
// ##### 小さな専門的インターフェース #####

// 基本的な作業インターフェース
export interface Workable {
  work(): void;
  eat(): void;
}

// 管理機能のインターフェース
export interface Manageable {
  manage(): void;
  approveLeave(): void;
}

// HR報告のインターフェース
export interface HRReportable {
  reportToHR(): void;
}

// コードレビューのインターフェース
export interface Reviewable {
  codeReview(): void;
}
```

#### Step 2: インターフェースを組み合わせて実装

```typescript
// ##### 実装：各役割に必要なインターフェースのみ #####

// マネージャー：複数インターフェース実装
export class Manager implements Workable, Manageable, HRReportable, Reviewable {
  work(): void {
    console.log('Manager working');
  }

  eat(): void {
    console.log('Manager eating');
  }

  manage(): void {
    console.log('Manager managing team');
  }

  approveLeave(): void {
    console.log('Manager approves leave');
  }

  reportToHR(): void {
    console.log('Manager reports to HR');
  }

  codeReview(): void {
    console.log('Manager reviewing code');
  }
}

// エンジニア：必要なインターフェースのみ実装
export class Engineer implements Workable, Reviewable {
  work(): void {
    console.log('Engineer working');
  }

  eat(): void {
    console.log('Engineer eating');
  }

  codeReview(): void {
    console.log('Engineer reviewing code');
  }

  // ✅ 不要なメソッドに依存しない
}

// インターン：必要最小限のインターフェース
export class Intern implements Workable {
  work(): void {
    console.log('Intern working');
  }

  eat(): void {
    console.log('Intern eating');
  }

  // ✅ 必要なメソッドだけ実装
}
```

#### Step 3: クライアント側でも分割

```typescript
// ##### クライアント側でも適切なインターフェースのみ依存 #####

// 作業を割り当てるシステム
export class TaskAssigner {
  assignWork(worker: Workable): void {
    // ✅ Workable のみ必要
    worker.work();
  }
}

// レビュープロセス
export class CodeReviewProcess {
  requestReview(reviewer: Reviewable): void {
    // ✅ Reviewable のみ必要
    reviewer.codeReview();
  }
}

// 休暇承認システム
export class LeaveApprovalSystem {
  approveLeave(approver: Manageable): void {
    // ✅ Manageable のみ必要
    approver.approveLeave();
  }
}

// HR システム
export class HRSystem {
  receiveReport(reporter: HRReportable): void {
    // ✅ HRReportable のみ必要
    reporter.reportToHR();
  }
}
```

#### Step 4: 実装例

```typescript
// 使用例
const manager = new Manager();
const engineer = new Engineer();
const intern = new Intern();

// TaskAssigner は全員を処理できる
const taskAssigner = new TaskAssigner();
taskAssigner.assignWork(manager);    // ✅
taskAssigner.assignWork(engineer);   // ✅
taskAssigner.assignWork(intern);     // ✅

// CodeReviewProcess は Reviewable を実装した人のみ
const reviewProcess = new CodeReviewProcess();
reviewProcess.requestReview(manager);    // ✅
reviewProcess.requestReview(engineer);   // ✅
reviewProcess.requestReview(intern);     // ❌ コンパイルエラー（正しい）

// LeaveApprovalSystem は Manageable を実装した人のみ
const leaveSystem = new LeaveApprovalSystem();
leaveSystem.approveLeave(manager);     // ✅
leaveSystem.approveLeave(engineer);    // ❌ コンパイルエラー（正しい）
leaveSystem.approveLeave(intern);      // ❌ コンパイルエラー（正しい）
```

---

### 📊 ISP違反のパターン

#### パターン1: God インターフェース

```typescript
// ❌ ISP違反：疲れモジュール
interface Document {
  open(): void;
  close(): void;
  save(): void;
  print(): void;
  fax(): void;
  replicate(): void;
  bind(): void;
}

// すべてのドキュメント実装前に全部作成する必要がある
class PDFDocument implements Document {
  // ...
}

// すべてを実装する必要がある
class SimpleTextDocument implements Document {
  print(): void { console.log('Printing'); }
  fax(): void { throw new Error('Cannot fax text'); }  // ❌ 不要なメソッド
  // ...
}
```

#### パターン2: 責務が混在

```typescript
// ❌ ISP違反
interface UserService {
  // ユーザー管理
  getUser(id: string): User;
  saveUser(user: User): void;

  // メール送信
  sendEmail(to: string, message: string): void;

  // ロギング
  logActivity(userId: string, action: string): void;

  // キャッシュ管理
  clearCache(): void;
}

// ✅ ISP準拠：責務ごとに分割
interface UserRepository {
  getUser(id: string): User;
  saveUser(user: User): void;
}

interface EmailService {
  sendEmail(to: string, message: string): void;
}

interface ActivityLogger {
  logActivity(userId: string, action: string): void;
}

interface CacheManager {
  clearCache(): void;
}
```

---

### 🧪 テスト

ISP を適用すると、テストが容易になります：

```typescript
describe('ISP - Interface Segregation', () => {
  // 個別にテスト可能
  describe('TaskAssigner', () => {
    test('should assign work to any Workable', () => {
      const mockWorker: Workable = {
        work: jest.fn(),
        eat: jest.fn()
      };

      const assigner = new TaskAssigner();
      assigner.assignWork(mockWorker);

      expect(mockWorker.work).toHaveBeenCalled();
    });
  });

  describe('CodeReviewProcess', () => {
    test('should request review from Reviewable', () => {
      const mockReviewer: Reviewable = {
        codeReview: jest.fn()
      };

      const process = new CodeReviewProcess();
      process.requestReview(mockReviewer);

      expect(mockReviewer.codeReview).toHaveBeenCalled();
    });
  });

  // モック作成が簡単（必要なメソッドだけ）
  describe('LeaveApprovalSystem', () => {
    test('should approve leave from Manageable', () => {
      const mockManager: Manageable = {
        manage: jest.fn(),
        approveLeave: jest.fn()
      };

      const system = new LeaveApprovalSystem();
      system.approveLeave(mockManager);

      expect(mockManager.approveLeave).toHaveBeenCalled();
    });
  });
});
```

---

### 🎯 ISP チェックリスト

```
✅ インターフェースに「実装する必要がないメソッド」がないか
✅ インターフェースが1つの責務を表現しているか
✅ インターフェース利用者が必要なメソッドだけ実装するか
✅ 小さなインターフェースの組み合わせで構成されているか
✅ モック作成が簡単か（必要なメソッドだけ）
```

---

### 📋 まとめ

| ポイント | 説明 |
|---------|------|
| **本質** | 不要な依存を避ける |
| **実装** | インターフェース分割 |
| **単位** | 責務 or 能力 |
| **メリット** | テスト容易、柔軟性 |
| **反対** | God インターフェース |

---

### ➡️ 次のステップ

最後の原則 **依存性逆転の原則** は、高レベルモジュールが低レベルモジュールに依存してはいけない、という最も重要な原則です。

[次: 依存性逆転の原則 →](#section-02-core-principles-05-dependency-inversion)

## 05. 依存性逆転の原則 (DIP) - Dependency Inversion Principle {#section-02-core-principles-05-dependency-inversion}


> **原則**: 高レベルモジュール（ビジネスロジック）は低レベルモジュール（実装詳細）に依存してはいけない。両方とも抽象化に依存すべき。

### 🎯 コンセプト

```
❌ 従来の依存関係（上から下へ）
UserService
  ↓ 依存
MySQLDatabase
  ↓ 依存
MySQLDriver

問題：データベースを変更したら全て変更する必要

✅ 逆転した依存関係（抽象化に依存）
UserService
  ↓ 依存
Database インターフェース
  ↑ 実装
MySQLDatabase  or  PostgreSQLDatabase

メリット：どのDBを使うか選べる
```

---

### ❌ DIPに違反する例

#### シナリオ：ユーザーリポジトリ

```typescript
// ❌ 悪い例：高レベルモジュールが低レベルモジュール（MySQL）に依存

import mysql = require('mysql');

// UserService（高レベル：ビジネスロジック）
export class UserService {
  private mysqlConnection: mysql.Connection;

  constructor() {
    // ❌ 直接MySQL実装に依存
    this.mysqlConnection = mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: 'password',
      database: 'myapp'
    });
  }

  async getUser(userId: string) {
    // ❌ SQLクエリを直接実装
    return new Promise((resolve, reject) => {
      this.mysqlConnection.query(
        'SELECT * FROM users WHERE id = ?',
        [userId],
        (error, results) => {
          if (error) reject(error);
          resolve(results[0]);
        }
      );
    });
  }

  async saveUser(user: User) {
    // ❌ SQL操作が漏れている
    return new Promise((resolve, reject) => {
      this.mysqlConnection.query(
        'INSERT INTO users (id, name, email) VALUES (?, ?, ?)',
        [user.id, user.name, user.email],
        (error, results) => {
          if (error) reject(error);
          resolve(results);
        }
      );
    });
  }
}

// UI層が直接UserServiceに依存
class UserController {
  private userService: UserService;

  constructor() {
    // ❌ 各階層が下位階層に依存
    this.userService = new UserService();
  }

  async getUser(userId: string) {
    return this.userService.getUser(userId);
  }
}
```

**問題:**
- 🔴 UserService が MySQL に強く依存している
- 🔴 PostgreSQL に変更するには？
  → UserService の全体を書き直す必要
- 🔴 テスト時に MySQL を起動が必須
- 🔴 別の DB（MongoDB など）に対応できない

---

### ✅ DIP を適用した設計

#### Step 1: 抽象化（インターフェース）を定義

```typescript
// ##### ドメイン層：抽象化 #####

// 抽象リポジトリ（高レベルモジュールが依存する）
export interface UserRepository {
  getUser(userId: string): Promise<User | null>;
  saveUser(user: User): Promise<void>;
  deleteUser(userId: string): Promise<void>;
  findByEmail(email: string): Promise<User | null>;
}
```

#### Step 2: 高レベルモジュール（ビジネスロジック）

```typescript
// ##### アプリケーション層：高レベルモジュール #####

export class UserService {
  // ✅ インターフェースに依存（実装詳細は知らない）
  constructor(private userRepository: UserRepository) {}

  async getUserProfile(userId: string): Promise<UserProfile> {
    const user = await this.userRepository.getUser(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }
    return {
      id: user.id,
      name: user.name,
      email: user.email
    };
  }

  async updateUser(userId: string, updates: Partial<User>): Promise<void> {
    const user = await this.userRepository.getUser(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }

    const updatedUser = { ...user, ...updates };
    await this.userRepository.saveUser(updatedUser);
  }
}

// ✅ UseCase層も同じ
export class RegisterUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private passwordService: PasswordService,
    private emailService: EmailService
  ) {}

  async execute(request: RegisterRequest): Promise<RegisterResponse> {
    // ビジネスロジック（実装詳細に依存しない）
    const existingUser = await this.userRepository.findByEmail(request.email);
    if (existingUser) {
      throw new UserAlreadyExistsError(request.email);
    }

    const user = new User(
      this.generateId(),
      request.email,
      this.passwordService.hashPassword(request.password)
    );

    await this.userRepository.saveUser(user);
    await this.emailService.sendWelcomeEmail(user.email);

    return { id: user.id, email: user.email };
  }
}
```

#### Step 3: 低レベルモジュール（実装詳細）

```typescript
// ##### インフラストラクチャ層：低レベルモジュール #####

// MySQL実装
export class MySQLUserRepository implements UserRepository {
  constructor(private db: MySQLConnection) {}

  async getUser(userId: string): Promise<User | null> {
    const row = await this.db.query(
      'SELECT * FROM users WHERE id = ?',
      [userId]
    );
    return row ? this.mapRowToUser(row) : null;
  }

  async saveUser(user: User): Promise<void> {
    await this.db.query(
      'INSERT INTO users (id, email, password) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE email=?, password=?',
      [user.id, user.email, user.password, user.email, user.password]
    );
  }

  // ... 他のメソッド
}

// PostgreSQL実装
export class PostgreSQLUserRepository implements UserRepository {
  constructor(private db: PostgreSQLConnection) {}

  async getUser(userId: string): Promise<User | null> {
    const row = await this.db.query(
      'SELECT * FROM users WHERE id = $1',
      [userId]
    );
    return row ? this.mapRowToUser(row) : null;
  }

  async saveUser(user: User): Promise<void> {
    await this.db.query(
      'INSERT INTO users (id, email, password) VALUES ($1, $2, $3) ON CONFLICT (id) DO UPDATE SET email=$2, password=$3',
      [user.id, user.email, user.password]
    );
  }

  // ... 他のメソッド
}

// MongoDB実装
export class MongoDBUserRepository implements UserRepository {
  constructor(private db: MongoDBConnection) {}

  async getUser(userId: string): Promise<User | null> {
    const doc = await this.db.collection('users').findOne({ _id: userId });
    return doc ? this.mapDocToUser(doc) : null;
  }

  async saveUser(user: User): Promise<void> {
    await this.db.collection('users').updateOne(
      { _id: user.id },
      { $set: user },
      { upsert: true }
    );
  }

  // ... 他のメソッド
}
```

#### Step 4: 依存性注入で組み立て

```typescript
// ##### 依存性解決（ファクトリやコンテナ） #####

export class ApplicationFactory {
  static createUserService(dbType: 'mysql' | 'postgresql' | 'mongodb'): UserService {
    const repository = this.createUserRepository(dbType);
    return new UserService(repository);
  }

  static createRegisterUseCase(
    dbType: 'mysql' | 'postgresql' | 'mongodb'
  ): RegisterUserUseCase {
    const repository = this.createUserRepository(dbType);
    const passwordService = new PasswordService();
    const emailService = new EmailService();

    return new RegisterUserUseCase(
      repository,
      passwordService,
      emailService
    );
  }

  private static createUserRepository(dbType: string): UserRepository {
    switch (dbType) {
      case 'mysql':
        return new MySQLUserRepository(new MySQLConnection());
      case 'postgresql':
        return new PostgreSQLUserRepository(new PostgreSQLConnection());
      case 'mongodb':
        return new MongoDBUserRepository(new MongoDBConnection());
      default:
        throw new Error(`Unknown database type: ${dbType}`);
    }
  }
}

// または、依存性注入コンテナを使用
import { Container } from 'inversify';

const container = new Container();

// バインディング
container.bind<UserRepository>('UserRepository')
  .to(MySQLUserRepository);  // またはPostgreSQLUserRepository

container.bind<UserService>(UserService)
  .toSelf();

// 取得
const userService = container.get<UserService>(UserService);
```

---

### 📊 依存方向の比較

#### ❌ DIP違反（上から下へ）

```
  UI層
    ↓ 依存
Application層
    ↓ 依存
MySQL実装

→ 下位層を変更すると上位層全て影響
```

#### ✅ DIP適用（両方が抽象化に依存）

```
  UI層          Application層          インフラ層
     ↓            ↓                        ↓
     └─────────→ 抽象化 ←─────────────┘
              (UserRepository)

→ インフラ層の実装を変更しても上位層は影響なし
```

---

### 🧪 テストでの利点

#### DIP違反の場合

```typescript
// ❌ MySQLが必須
describe('UserService without DIP', () => {
  test('should get user', async () => {
    // MySQL起動が必須
    const db = new MySQLConnection();
    const service = new UserService();  // ❌ 内部でMySQL接続

    // テストが遅い、不安定
    const user = await service.getUser('user-123');
    expect(user.name).toBe('John');
  });
});
```

#### DIP適用の場合

```typescript
// ✅ モックで十分
describe('UserService with DIP', () => {
  test('should get user', async () => {
    // モックリポジトリ（高速、安定）
    const mockRepository: UserRepository = {
      getUser: jest.fn().mockResolvedValue({
        id: 'user-123',
        name: 'John',
        email: 'john@example.com'
      })
    };

    const service = new UserService(mockRepository);
    const user = await service.getUserProfile('user-123');

    expect(user.name).toBe('John');
    expect(mockRepository.getUser).toHaveBeenCalledWith('user-123');
  });

  test('should throw when user not found', async () => {
    const mockRepository: UserRepository = {
      getUser: jest.fn().mockResolvedValue(null)
    };

    const service = new UserService(mockRepository);

    expect(async () => {
      await service.getUserProfile('nonexistent');
    }).rejects.toThrow(UserNotFoundError);
  });
});
```

---

### 📊 SOLID原則と DIP の関係

```
DIP（依存性逆転の原則）
  ↑
  実装に必要な他の4つの原則
  
SRP（単一責任）→ 変更理由が明確
  ↓
OCP（開放閉鎖）→ 拡張ポイントが定まる
  ↓
LSP（リスコフ置換）→ インターフェース契約
  ↓
ISP（インターフェース分離）→ 必要な機能のみ
  ↓
DIP（依存性逆転）→ 抽象化に依存する設計
```

---

### 🎯 DIP チェックリスト

```
✅ 高レベルモジュールが低レベルモジュールに直接依存していないか
✅ 両方が抽象化（インターフェース）に依存しているか
✅ 依存性注入（コンストラクタ引数など）が使われているか
✅ モックで簡単にテスト可能か
✅ 実装を変更しても上位層への影響がないか
```

---

### 📋 SOLID原則 全体まとめ

| 原則 | 意味 | メリット |
|-----|------|---------|
| **S** | 1つの責任 | テスト容易、再利用性 |
| **O** | 拡張に開放、修正に閉鎖 | 既存コード保護 |
| **L** | リスコフ置換可能 | 予測可能な動作 |
| **I** | インターフェース分離 | 不要な依存回避 |
| **D** | 依存性逆転 | テスト性、柔軟性 |

---

### 📈 実装レベルの段階

```
段階1: SRP + OCP
  → 各クラスが明確な責任を持つ

段階2: + LSP + ISP
  → インターフェースが適切に定義される

段階3: + DIP
  → 完全なテスト可能設計が実現
```

---

### ➡️ 次のステップ

さて、SOLID原則を理解したので、次は **アーキテクチャ層**を学びます。SOLID原則は設計の基本ですが、アーキテクチャ層はそれらの原則を実際のシステムに適用する大きな枠組みです。

[次: アーキテクチャ層 →](#chapter-03-architecture-layers)

# Architecture Layers {#chapter-03-architecture-layers}

## 01. プレゼンテーション層 (Presentation Layer) {#section-03-architecture-layers-01-presentation-layer}


> **責務**: ユーザーインターフェース。HTTP リクエストを受け取ってレスポンスを返す。ビジネスロジックは持たない。

### 🎯 層の位置付け

```
┌──────────────────────────┐
│  プレゼンテーション層      │ ← ここ
│ (Web Controller, API)    │
├──────────────────────────┤
│  アプリケーション層       │
│ (ユースケース)            │
├──────────────────────────┤
│  ドメイン層              │
│ (ビジネスロジック)       │
├──────────────────────────┤
│  インフラストラクチャ層   │
│ (DB, 外部API)           │
└──────────────────────────┘
```

---

### 📋 プレゼンテーション層の責務

```
✅ プレゼンテーション層が担当：
  - HTTPリクエストの受け取り
  - リクエストデータの検証
  - エラーハンドリング
  - HTTPレスポンスの返却
  - ステータスコード管理
  - ログイン認証チェック

❌ プレゼンテーション層がしてはいけない：
  - ビジネスロジック
  - データベース直接アクセス
  - ドメイン知識の埋め込み
```

---

### 🏗️ 典型的なプレゼンテーション層の構成

```
presentation/
├── controller/
│   ├── UserController.ts
│   ├── ProductController.ts
│   └── OrderController.ts
├── dto/
│   ├── request/
│   │   └── CreateUserRequest.ts
│   └── response/
│       └── UserResponse.ts
├── middleware/
│   ├── AuthenticationMiddleware.ts
│   ├── ValidationMiddleware.ts
│   └── ErrorHandlingMiddleware.ts
└── mapper/
    └── UserMapper.ts
```

---

### 💻 実装例：ユーザー作成エンドポイント

#### Step 1: リクエスト/レスポンスDTO

```typescript
// presentation/dto/request/CreateUserRequest.ts
export interface CreateUserRequest {
  email: string;
  password: string;
  name: string;
}

// presentation/dto/response/UserResponse.ts
export interface UserResponse {
  id: string;
  email: string;
  name: string;
  createdAt: string;
}

// 検証スキーマ
export class CreateUserRequestValidator {
  validate(data: any): CreateUserRequest {
    if (!data.email || !data.password || !data.name) {
      throw new ValidationError('Missing required fields');
    }

    if (typeof data.email !== 'string' || !data.email.includes('@')) {
      throw new ValidationError('Invalid email format');
    }

    if (typeof data.password !== 'string' || data.password.length < 8) {
      throw new ValidationError('Password must be at least 8 characters');
    }

    return {
      email: data.email.trim().toLowerCase(),
      password: data.password,
      name: data.name.trim()
    };
  }
}
```

#### Step 2: Controller

```typescript
// presentation/controller/UserController.ts
export class UserController {
  constructor(
    private registerUserUseCase: RegisterUserUseCase,
    private getUserUseCase: GetUserUseCase,
    private validator: CreateUserRequestValidator,
    private mapper: UserMapper
  ) {}

  // ✅ HTTPハンドラー
  async createUser(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      // 1️⃣ リクエストの検証
      const validatedRequest = this.validator.validate(req.body);

      // 2️⃣ ユースケース実行（ビジネスロジックはここから）
      const user = await this.registerUserUseCase.execute(validatedRequest);

      // 3️⃣ ドメインモデルをDTOにマッピング
      const response = this.mapper.toUserResponse(user);

      // 4️⃣ レスポンス返却
      res.status(201).json(response);
    } catch (error) {
      // エラーハンドリング（詳細は後章）
      next(error);
    }
  }

  // ✅ ユーザー取得エンドポイント
  async getUser(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.params.id;

      if (!userId) {
        res.status(400).json({ error: 'User ID is required' });
        return;
      }

      const user = await this.getUserUseCase.execute(userId);
      const response = this.mapper.toUserResponse(user);

      res.status(200).json(response);
    } catch (error) {
      next(error);
    }
  }

  // ✅ ユーザー削除エンドポイント
  async deleteUser(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.params.id;

      if (!userId) {
        res.status(400).json({ error: 'User ID is required' });
        return;
      }

      await this.deleteUserUseCase.execute(userId);

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }
}
```

#### Step 3: マッピング（ドメイン層 ↔ プレゼンテーション層）

```typescript
// presentation/mapper/UserMapper.ts
export class UserMapper {
  // ドメインモデル → レスポンスDTO
  toUserResponse(user: User): UserResponse {
    return {
      id: user.getId(),
      email: user.getEmail(),
      name: user.getName(),
      createdAt: user.getCreatedAt().toISOString()
    };
  }

  // リクエストDTO → ドメインモデル（アプリケーション層で実施）
  // ※ ここでは変換ロジックは簡潔に
}
```

#### Step 4: ルーティング設定

```typescript
// presentation/routes/userRoutes.ts
import { Router } from 'express';

export function createUserRoutes(userController: UserController): Router {
  const router = Router();

  // POST /users
  router.post('/', (req, res, next) => {
    userController.createUser(req, res, next);
  });

  // GET /users/:id
  router.get('/:id', (req, res, next) => {
    userController.getUser(req, res, next);
  });

  // DELETE /users/:id
  router.delete('/:id', (req, res, next) => {
    userController.deleteUser(req, res, next);
  });

  return router;
}
```

---

### 🔐 プレゼンテーション層でのセキュリティ

#### 認証ミドルウェア

```typescript
// presentation/middleware/AuthenticationMiddleware.ts
export class AuthenticationMiddleware {
  execute(req: Request, res: Response, next: NextFunction): void {
    const token = req.headers.authorization?.split(' ')[1];

    if (!token) {
      res.status(401).json({ error: 'No token provided' });
      return;
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET!);
      req.user = decoded;  // リクエストに認証情報を付与
      next();
    } catch (error) {
      res.status(403).json({ error: 'Invalid token' });
    }
  }
}
```

#### リクエスト検証ミドルウェア

```typescript
// presentation/middleware/ValidationMiddleware.ts
export function createValidationMiddleware(schema: Joi.Schema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const { error, value } = schema.validate(req.body);

    if (error) {
      res.status(400).json({
        error: 'Validation failed',
        details: error.details.map(d => d.message)
      });
      return;
    }

    req.body = value;  // 検証済みデータに置き換え
    next();
  };
}
```

---

### 📊 複数の UI メディア対応

クリーンアーキテクチャでは、複数の UI をサポートできます：

```
同じユースケース層を使用
      ↓
┌─────────────────────────────────────┐
│  Web API (REST/GraphQL)            │
│  UI（React SPA）                    │
│  モバイルAPI                        │
│  CLI                                │
└─────────────────────────────────────┘
      ↑ 全て同じビジネスロジック
      └─ RegisterUserUseCase など
```

#### 複数の Controller 実装例

```typescript
// presentation/controller/WebUserController.ts（REST API）
export class WebUserController {
  async createUser(req: Request, res: Response): Promise<void> {
    const result = await this.registerUserUseCase.execute(req.body);
    res.status(201).json(result);
  }
}

// presentation/controller/GraphQLUserResolver.ts（GraphQL）
export class GraphQLUserResolver {
  @Mutation()
  async createUser(@Args('input') input: CreateUserInput): Promise<UserResponse> {
    const result = await this.registerUserUseCase.execute(input);
    return result;
  }
}

// presentation/controller/CLIUserCommand.ts（CLI）
export class CLIUserCommand {
  async createUser(email: string, password: string, name: string): Promise<void> {
    const result = await this.registerUserUseCase.execute({
      email,
      password,
      name
    });
    console.log(`User created: ${result.id}`);
  }
}

// 全て同じ RegisterUserUseCase を使用している！
```

---

### 🧪 テスト例

```typescript
describe('UserController', () => {
  let controller: UserController;
  let mockRegisterUseCase: MockRegisterUserUseCase;
  let mockValidator: MockValidator;
  let mockMapper: MockMapper;

  beforeEach(() => {
    mockRegisterUseCase = new MockRegisterUserUseCase();
    mockValidator = new MockValidator();
    mockMapper = new MockMapper();

    controller = new UserController(
      mockRegisterUseCase,
      mockValidator,
      mockMapper
    );
  });

  test('should create user successfully', async () => {
    const req = {
      body: {
        email: 'user@example.com',
        password: 'password123',
        name: 'John Doe'
      }
    } as Request;

    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    } as unknown as Response;

    await controller.createUser(req, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalled();
  });

  test('should handle validation error', async () => {
    mockValidator.throwError(new ValidationError('Invalid email'));

    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    } as unknown as Response;

    const next = jest.fn();

    await controller.createUser({} as Request, res, next);

    expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
  });
});
```

---

### 📋 プレゼンテーション層のチェックリスト

```
✅ ビジネスロジックがない
✅ DB直接アクセスがない
✅ リクエスト検証がある
✅ レスポンスマッピングがある
✅ エラーハンドリングがある
✅ 認証・認可チェックがある
✅ ログが適切にある
```

---

### ➡️ 次のステップ

次は、**アプリケーション層**を学びます。これはビジネスロジックの実行層です。

[次: アプリケーション層 →](#section-03-architecture-layers-02-application-layer)

## 02. アプリケーション層 (Application Layer) {#section-03-architecture-layers-02-application-layer}


> **責務**: ユースケース（ビジネスフロー）の実行。複数のドメインオブジェクトを組み合わせてビジネスプロセスを実現する。

### 🎯 層の位置付け

```
┌──────────────────────────┐
│  プレゼンテーション層     │
├──────────────────────────┤
│  アプリケーション層       │  ← ここ
│ (ユースケース)            │
├──────────────────────────┤
│  ドメイン層              │
│ (ビジネスロジック)       │
├──────────────────────────┤
│  インフラストラクチャ層   │
│ (DB, 外部API)           │
└──────────────────────────┘
```

---

### 📋 アプリケーション層の責務

```
✅ アプリケーション層が担当：
  - ユースケースの実行
  - トランザクション管理
  - 異なるドメインモデルの組み合わせ
  - 外部サービスの呼び出し調整
  - DTO の変換
  - ビジネスプロセスの順序制御

❌ アプリケーション層がしてはいけない：
  - 複雑なビジネスルール制定（ドメイン層で）
  - データベース方言固有のロジック（インフラ層で）
```

---

### 🏗️ 典型的なアプリケーション層の構成

```
application/
├── usecase/
│   ├── user/
│   │   ├── RegisterUserUseCase.ts
│   │   ├── GetUserUseCase.ts
│   │   ├── UpdateUserUseCase.ts
│   │   └── DeleteUserUseCase.ts
│   ├── order/
│   │   ├── CreateOrderUseCase.ts
│   │   ├── CancelOrderUseCase.ts
│   │   └── GetOrderHistoryUseCase.ts
│   └── ...
├── service/
│   ├── UserApplicationService.ts
│   ├── NotificationService.ts
│   └── ...
├── dto/
│   ├── UserDto.ts
│   ├── OrderDto.ts
│   └── ...
└── port/
    ├── UserRepository.ts
    └── ...
```

---

### 💻 実装例：ユースケース

#### シンプルなユースケース：ユーザー登録

```typescript
// application/usecase/user/RegisterUserUseCase.ts

export interface RegisterUserRequest {
  email: string;
  password: string;
  name: string;
}

export interface RegisterUserResponse {
  id: string;
  email: string;
  name: string;
  createdAt: Date;
}

export class RegisterUserUseCase {
  constructor(
    private userRepository: UserRepository,           // ドメイン層の業務
    private passwordService: PasswordService,         // ドメイン層の業務
    private notificationService: NotificationService  // 外部サービス呼び出し
  ) {}

  async execute(request: RegisterUserRequest): Promise<RegisterUserResponse> {
    // Step 1: 事前チェック
    const existingUser = await this.userRepository.findByEmail(request.email);
    if (existingUser) {
      throw new UserAlreadyExistsError(request.email);
    }

    // Step 2: ドメインモデル作成（ビジネスルール適用）
    const user = new User(
      this.generateId(),
      request.email,
      this.passwordService.hashPassword(request.password),
      request.name
    );

    // Step 3: 永続化
    await this.userRepository.save(user);

    // Step 4: 外部サービス呼び出し（エラーは記録するが無視）
    try {
      await this.notificationService.sendWelcomeEmail(user.getEmail());
    } catch (error) {
      console.error('Failed to send welcome email:', error);
      // ウェルカムメール送信失敗でも、ユーザー作成は成功
    }

    // Step 5: レスポンス返却
    return {
      id: user.getId(),
      email: user.getEmail(),
      name: user.getName(),
      createdAt: user.getCreatedAt()
    };
  }

  private generateId(): string {
    return uuid();
  }
}
```

#### 複雑なユースケース：注文作成

```typescript
// application/usecase/order/CreateOrderUseCase.ts

export interface CreateOrderRequest {
  userId: string;
  items: Array<{ productId: string; quantity: number }>;
  shippingAddress: string;
}

export interface CreateOrderResponse {
  orderId: string;
  totalPrice: number;
  estimatedDeliveryDate: Date;
}

export class CreateOrderUseCase {
  constructor(
    private orderRepository: OrderRepository,
    private productRepository: ProductRepository,
    private userRepository: UserRepository,
    private inventoryService: InventoryService,
    private paymentService: PaymentService,
    private shippingService: ShippingService,
    private emailService: EmailService
  ) {}

  async execute(request: CreateOrderRequest): Promise<CreateOrderResponse> {
    // Step 1: ユーザー存在確認
    const user = await this.userRepository.getUser(request.userId);
    if (!user) {
      throw new UserNotFoundError(request.userId);
    }

    // Step 2: 商品情報と在庫確認
    const orderItems = [];
    let totalPrice = 0;

    for (const item of request.items) {
      const product = await this.productRepository.getProduct(item.productId);
      if (!product) {
        throw new ProductNotFoundError(item.productId);
      }

      const available = await this.inventoryService.checkAvailability(
        item.productId,
        item.quantity
      );
      if (!available) {
        throw new InsufficientInventoryError(item.productId);
      }

      orderItems.push({
        productId: product.getId(),
        quantity: item.quantity,
        price: product.getPrice()
      });

      totalPrice += product.getPrice() * item.quantity;
    }

    // Step 3: 配送予定日の計算
    const estimatedDeliveryDate = this.calculateEstimatedDelivery(request.shippingAddress);

    // Step 4: 支払い処理
    const paymentResult = await this.paymentService.charge(
      user.getPaymentMethod(),
      totalPrice
    );

    if (!paymentResult.success) {
      throw new PaymentFailedError(paymentResult.reason);
    }

    // Step 5: 在庫減少
    for (const item of request.items) {
      await this.inventoryService.decreaseStock(item.productId, item.quantity);
    }

    // Step 6: 注文作成（ドメインモデル）
    const order = new Order(
      this.generateOrderId(),
      user.getId(),
      orderItems,
      totalPrice,
      request.shippingAddress,
      estimatedDeliveryDate,
      paymentResult.transactionId
    );

    // Step 7: 注文を保存
    await this.orderRepository.save(order);

    // Step 8: 配送指示
    try {
      await this.shippingService.createShipment(
        order.getId(),
        request.shippingAddress,
        estimatedDeliveryDate
      );
    } catch (error) {
      // 配送失敗時の処理（重要な業務）
      // キャンセルして返金
      await this.paymentService.refund(paymentResult.transactionId, totalPrice);
      await this.orderRepository.delete(order.getId());
      throw new ShippingFailedError();
    }

    // Step 9: 確認メール
    try {
      await this.emailService.sendOrderConfirmation(
        user.getEmail(),
        order.getId(),
        totalPrice
      );
    } catch (error) {
      // メール送信失敗は無視（重要ではない）
      console.warn('Failed to send confirmation email');
    }

    return {
      orderId: order.getId(),
      totalPrice,
      estimatedDeliveryDate
    };
  }

  private calculateEstimatedDelivery(shippingAddress: string): Date {
    // 実装
  }

  private generateOrderId(): string {
    return uuid();
  }
}
```

---

### 📊 アプリケーション層の特性

#### トランザクション管理

```typescript
export class UpdateUserProfileUseCase {
  async execute(userId: string, updates: UpdateProfileRequest): Promise<void> {
    // トランザクション開始
    const transaction = await this.db.beginTransaction();

    try {
      // Step 1: ユーザー取得
      const user = await this.userRepository.getUser(userId, transaction);

      // Step 2: プロフィール更新
      user.updateProfile(updates.name, updates.bio, updates.avatarUrl);

      // Step 3: 変更履歴記録
      await this.auditService.recordChange(
        userId,
        'PROFILE_UPDATE',
        updates,
        transaction
      );

      // Step 4: 通知送信
      await this.notificationService.notifyProfileUpdate(
        user.getEmail(),
        transaction
      );

      // トランザクション確定
      await transaction.commit();
    } catch (error) {
      // ロールバック
      await transaction.rollback();
      throw error;
    }
  }
}
```

#### エラーハンドリング

```typescript
export class TransferMoneyUseCase {
  async execute(request: TransferRequest): Promise<TransferResponse> {
    // ビジネスエラー：回復可能
    if (request.amount <= 0) {
      throw new InvalidAmountError('Amount must be positive');
    }

    const fromAccount = await this.accountRepository.getAccount(request.fromAccountId);
    if (!fromAccount) {
      throw new AccountNotFoundError(request.fromAccountId);
    }

    if (fromAccount.getBalance() < request.amount) {
      throw new InsufficientBalanceError(fromAccount.getBalance(), request.amount);
    }

    // システムエラー：回復不可
    try {
      await this.externalBankService.validateAccountNumber(request.toAccountId);
    } catch (error) {
      throw new ExternalServiceError('Bank service unavailable', error);
    }

    // 正常処理
    const transaction = await this.transactionService.execute(
      fromAccount,
      request.toAccountId,
      request.amount
    );

    return {
      transactionId: transaction.getId(),
      timestamp: transaction.getTimestamp()
    };
  }
}
```

---

### 🧪 テスト例

```typescript
describe('RegisterUserUseCase', () => {
  let useCase: RegisterUserUseCase;
  let mockUserRepository: MockUserRepository;
  let mockPasswordService: MockPasswordService;
  let mockNotificationService: MockNotificationService;

  beforeEach(() => {
    mockUserRepository = new MockUserRepository();
    mockPasswordService = new MockPasswordService();
    mockNotificationService = new MockNotificationService();

    useCase = new RegisterUserUseCase(
      mockUserRepository,
      mockPasswordService,
      mockNotificationService
    );
  });

  test('should register new user', async () => {
    const result = await useCase.execute({
      email: 'user@example.com',
      password: 'password123',
      name: 'John Doe'
    });

    expect(result.email).toBe('user@example.com');
    expect(result.id).toBeDefined();
    expect(mockUserRepository.savedUsers).toHaveLength(1);
  });

  test('should reject duplicate email', async () => {
    mockUserRepository.addUser({
      id: '1',
      email: 'user@example.com',
      password: 'hashed',
      name: 'Existing'
    });

    expect(async () => {
      await useCase.execute({
        email: 'user@example.com',
        password: 'password123',
        name: 'New User'
      });
    }).rejects.toThrow(UserAlreadyExistsError);
  });

  test('should send welcome email', async () => {
    await useCase.execute({
      email: 'user@example.com',
      password: 'password123',
      name: 'John Doe'
    });

    expect(mockNotificationService.emailsSent).toContain('user@example.com');
  });
});
```

---

### 📋 アプリケーション層のチェックリスト

```
✅ ユースケースが明確に定義されている
✅ トランザクション管理がある
✅ エラーハンドリングが適切
✅ ビジネスロジックがドメイン層に移譲
✅ DTOへの変換がある
✅ 外部サービス呼び出しが適切に処理
✅ テストが容易なインターフェース設計
```

---

### ➡️ 次のステップ

次は、**ドメイン層**を学びます。これはビジネスルールの実装層です。

[次: ドメイン層 →](#section-03-architecture-layers-03-domain-layer)

## 03. ドメイン層 (Domain Layer) {#section-03-architecture-layers-03-domain-layer}


> **責務**: ビジネスルール。金銭計算、バリデーション、状態管理など、ビジネスに必要なロジックを実装する。最も重要な層。

### 🎯 層の位置付け

```
┌──────────────────────────┐
│  プレゼンテーション層     │
├──────────────────────────┤
│  アプリケーション層       │
├──────────────────────────┤
│  ドメイン層              │  ← ここ
│ (ビジネスロジック)       │
├──────────────────────────┤
│  インフラストラクチャ層   │
│ (DB, 外部API)           │
└──────────────────────────┘
```

---

### 📋 ドメイン層の責務

```
✅ ドメイン層が担当：
  - ビジネスルール実装
  - エンティティの定義
  - 値オブジェクト
  - ドメインロジック
  - バリデーション
  - 状態管理

❌ ドメイン層がしてはいけない：
  - フレームワークに依存
  - DBアクセス
  - HTTPスタッフの知識
  - UI の知識
```

---

### 🏗️ 典型的なドメイン層の構成

```
domain/
├── entity/
│   ├── User.ts
│   ├── Order.ts
│   ├── Product.ts
│   └── ...
├── value-object/
│   ├── Email.ts
│   ├── Money.ts
│   ├── Address.ts
│   └── ...
├── repository/
│   ├── UserRepository.ts  (インターフェース)
│   ├── OrderRepository.ts
│   └── ...
├── service/
│   ├── UserDomainService.ts
│   ├── OrderDomainService.ts
│   └── ...
└── exception/
    ├── InvalidEmailError.ts
    ├── InsufficientBalanceError.ts
    └── ...
```

---

### 💻 実装例1：値オブジェクト

#### Email 値オブジェクト

```typescript
// domain/value-object/Email.ts

export class Email {
  private value: string;

  constructor(value: string) {
    if (!this.isValid(value)) {
      throw new InvalidEmailError(value);
    }
    // 不変性：大文字小文字を正規化して保存
    this.value = value.toLowerCase().trim();
  }

  getValue(): string {
    return this.value;
  }

  // 値オブジェクトは値で比較
  equals(other: Email): boolean {
    return this.value === other.getValue();
  }

  private isValid(email: string): boolean {
    const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return regex.test(email);
  }
}
```

#### Money 値オブジェクト

```typescript
// domain/value-object/Money.ts

export class Money {
  private amount: number;
  private currency: string;

  constructor(amount: number, currency: string = 'JPY') {
    if (amount < 0) {
      throw new NegativeMoneyError(amount);
    }
    this.amount = Math.round(amount * 100) / 100;  // 小数点以下2位まで
    this.currency = currency;
  }

  add(other: Money): Money {
    if (this.currency !== other.currency) {
      throw new CurrencyMismatchError(this.currency, other.currency);
    }
    return new Money(this.amount + other.amount, this.currency);
  }

  subtract(other: Money): Money {
    if (this.currency !== other.currency) {
      throw new CurrencyMismatchError(this.currency, other.currency);
    }
    if (this.amount < other.amount) {
      throw new InsufficientFundsError(this.amount, other.amount);
    }
    return new Money(this.amount - other.amount, this.currency);
  }

  multiply(factor: number): Money {
    return new Money(this.amount * factor, this.currency);
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency;
  }

  getAmount(): number {
    return this.amount;
  }

  getCurrency(): string {
    return this.currency;
  }
}
```

#### Address 値オブジェクト

```typescript
// domain/value-object/Address.ts

export class Address {
  private prefecture: string;
  private city: string;
  private street: string;
  private postalCode: string;

  constructor(prefecture: string, city: string, street: string, postalCode: string) {
    if (!prefecture || !city || !street || !postalCode) {
      throw new InvalidAddressError('All fields required');
    }
    this.prefecture = prefecture;
    this.city = city;
    this.street = street;
    this.postalCode = postalCode;
  }

  getFullAddress(): string {
    return `${this.postalCode} ${this.prefecture}${this.city}${this.street}`;
  }

  equals(other: Address): boolean {
    return (
      this.prefecture === other.prefecture &&
      this.city === other.city &&
      this.street === other.street &&
      this.postalCode === other.postalCode
    );
  }

  // 配送可能かチェック（ビジネスルール）
  isShippableRegion(): boolean {
    const unshippableRegions = ['北方領土', '占守島'];
    return !unshippableRegions.includes(this.prefecture);
  }
}
```

---

### 💻 実装例2：エンティティ

#### User エンティティ

```typescript
// domain/entity/User.ts

export class User {
  private id: string;
  private email: Email;  // 値オブジェクト
  private password: HashedPassword;  // 値オブジェクト
  private name: string;
  private status: UserStatus;  // enum または値オブジェクト
  private createdAt: Date;
  private updatedAt: Date;

  constructor(
    id: string,
    email: Email,
    password: HashedPassword,
    name: string
  ) {
    // バリデーション
    if (!id || !email || !password || !name) {
      throw new InvalidUserError('All fields required');
    }

    if (name.length > 100) {
      throw new InvalidUserError('Name too long');
    }

    // 初期化
    this.id = id;
    this.email = email;
    this.password = password;
    this.name = name;
    this.status = UserStatus.ACTIVE;
    this.createdAt = new Date();
    this.updatedAt = new Date();
  }

  // ID による比較（エンティティは ID で比較）
  equals(other: User): boolean {
    return this.id === other.id;
  }

  // ビジネスロジック：ユーザーアクティブ化
  activate(): void {
    if (this.status === UserStatus.ACTIVE) {
      throw new UserAlreadyActiveError(this.id);
    }
    this.status = UserStatus.ACTIVE;
    this.updatedAt = new Date();
  }

  // ビジネスロジック：ユーザー削除
  deactivate(): void {
    if (this.status === UserStatus.INACTIVE) {
      throw new UserAlreadyInactiveError(this.id);
    }
    this.status = UserStatus.INACTIVE;
    this.updatedAt = new Date();
  }

  // ビジネスロジック：プロフィール更新（制約がある）
  updateProfile(newName: string): void {
    if (this.status !== UserStatus.ACTIVE) {
      throw new CannotUpdateInactiveUserError(this.id);
    }

    if (newName.length > 100) {
      throw new InvalidNameError('Name too long');
    }

    this.name = newName;
    this.updatedAt = new Date();
  }

  // Getter（読み取り専用）
  getId(): string {
    return this.id;
  }

  getEmail(): Email {
    return this.email;
  }

  getPassword(): HashedPassword {
    return this.password;
  }

  getName(): string {
    return this.name;
  }

  getStatus(): UserStatus {
    return this.status;
  }

  getCreatedAt(): Date {
    return this.createdAt;
  }
}

// User の状態を表すEnum
export enum UserStatus {
  ACTIVE = 'ACTIVE',
  INACTIVE = 'INACTIVE',
  SUSPENDED = 'SUSPENDED'
}
```

#### Order エンティティ（複雑な例）

```typescript
// domain/entity/Order.ts

export class Order {
  private id: string;
  private userId: string;
  private items: OrderItem[];  // 値オブジェクトの配列
  private totalPrice: Money;  // 値オブジェクト
  private shippingAddress: Address;  // 値オブジェクト
  private status: OrderStatus;
  private createdAt: Date;
  private estimatedDelivery: Date;

  constructor(
    id: string,
    userId: string,
    items: OrderItem[],
    totalPrice: Money,
    shippingAddress: Address,
    estimatedDelivery: Date
  ) {
    // バリデーション
    if (items.length === 0) {
      throw new InvalidOrderError('Order must have at least one item');
    }

    if (!shippingAddress.isShippableRegion()) {
      throw new UnshippableRegionError(shippingAddress);
    }

    // 合計金額の検証
    const calculatedTotal = this.calculateTotal(items);
    if (!calculatedTotal.equals(totalPrice)) {
      throw new InvalidOrderPriceError();
    }

    this.id = id;
    this.userId = userId;
    this.items = items;
    this.totalPrice = totalPrice;
    this.shippingAddress = shippingAddress;
    this.status = OrderStatus.PENDING;
    this.createdAt = new Date();
    this.estimatedDelivery = estimatedDelivery;
  }

  // ビジネスロジック：注文確定
  confirm(): void {
    if (this.status !== OrderStatus.PENDING) {
      throw new InvalidOrderStatusError('Can only confirm pending orders');
    }
    this.status = OrderStatus.CONFIRMED;
  }

  // ビジネスロジック：注文キャンセル（制約あり）
  cancel(): void {
    const cancellableStatuses = [
      OrderStatus.PENDING,
      OrderStatus.CONFIRMED
    ];

    if (!cancellableStatuses.includes(this.status)) {
      throw new NonCancellableOrderError(this.id, this.status);
    }

    this.status = OrderStatus.CANCELLED;
  }

  // ビジネスロジック：割引の適用
  applyDiscount(discountPercentage: number): void {
    if (discountPercentage < 0 || discountPercentage > 100) {
      throw new InvalidDiscountError(discountPercentage);
    }

    const discountAmount = this.totalPrice.multiply(discountPercentage / 100);
    this.totalPrice = this.totalPrice.subtract(discountAmount);
  }

  // Getter
  getId(): string {
    return this.id;
  }

  getUserId(): string {
    return this.userId;
  }

  getItems(): OrderItem[] {
    return this.items;
  }

  getTotalPrice(): Money {
    return this.totalPrice;
  }

  getStatus(): OrderStatus {
    return this.status;
  }

  private calculateTotal(items: OrderItem[]): Money {
    return items.reduce(
      (sum, item) => sum.add(item.price.multiply(item.quantity)),
      new Money(0)
    );
  }
}

export interface OrderItem {
  productId: string;
  quantity: number;
  price: Money;
}

export enum OrderStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  SHIPPED = 'SHIPPED',
  DELIVERED = 'DELIVERED',
  CANCELLED = 'CANCELLED'
}
```

---

### 💻 実装例3：ドメインサービス

```typescript
// domain/service/TransferDomainService.ts

export class TransferDomainService {
  // 2つのアカウント間でお金を移動
  transfer(
    fromAccount: Account,
    toAccount: Account,
    amount: Money
  ): Transfer {
    // ビジネスルール：出金元が十分なお金を持っているか
    if (fromAccount.getBalance().getAmount() < amount.getAmount()) {
      throw new InsufficientBalanceError(
        fromAccount.getBalance(),
        amount
      );
    }

    // ビジネスルール：同じ通貨か
    if (fromAccount.getBalance().getCurrency() !== amount.getCurrency()) {
      throw new CurrencyMismatchError(
        fromAccount.getBalance().getCurrency(),
        amount.getCurrency()
      );
    }

    // ビジネスルール：両方が活動中か
    if (!fromAccount.isActive() || !toAccount.isActive()) {
      throw new InactiveAccountError();
    }

    // トランザクション作成
    const transfer = new Transfer(
      uuid(),
      fromAccount.getId(),
      toAccount.getId(),
      amount,
      new Date()
    );

    // アカウント残高を更新
    fromAccount.debit(amount);
    toAccount.credit(amount);

    return transfer;
  }
}
```

---

### 🧪 テスト例

```typescript
describe('Order Domain Entity', () => {
  describe('creation', () => {
    test('should create order with valid data', () => {
      const items = [
        new OrderItem('product-1', 2, new Money(1000)),
        new OrderItem('product-2', 1, new Money(500))
      ];
      const totalPrice = new Money(2500);
      const address = new Address('東京都', '渋谷区', '1-2-3', '150-0001');

      const order = new Order(
        'order-1',
        'user-1',
        items,
        totalPrice,
        address,
        new Date('2025-01-10')
      );

      expect(order.getId()).toBe('order-1');
      expect(order.getStatus()).toBe(OrderStatus.PENDING);
    });

    test('should reject empty items', () => {
      expect(() => {
        new Order(
          'order-1',
          'user-1',
          [],  // 空
          new Money(0),
          new Address('東京都', '渋谷区', '1-2-3', '150-0001'),
          new Date('2025-01-10')
        );
      }).toThrow(InvalidOrderError);
    });

    test('should reject incorrect total price', () => {
      const items = [
        new OrderItem('product-1', 2, new Money(1000))
      ];
      const wrongTotal = new Money(5000);  // 正解は2000

      expect(() => {
        new Order(
          'order-1',
          'user-1',
          items,
          wrongTotal,
          new Address('東京都', '渋谷区', '1-2-3', '150-0001'),
          new Date('2025-01-10')
        );
      }).toThrow(InvalidOrderPriceError);
    });
  });

  describe('business logic', () => {
    test('should apply discount', () => {
      const order = createValidOrder(new Money(10000));

      order.applyDiscount(10);  // 10% 割引

      expect(order.getTotalPrice().getAmount()).toBe(9000);
    });

    test('should reject invalid discount', () => {
      const order = createValidOrder(new Money(10000));

      expect(() => {
        order.applyDiscount(150);  // 150% は不可
      }).toThrow(InvalidDiscountError);
    });

    test('should allow cancellation only in certain states', () => {
      const order = createValidOrder(new Money(10000));
      order.confirm();

      expect(() => {
        order.cancel();  // 確認済み注文はキャンセル可能
      }).not.toThrow();

      order.ship();  // 発送済みに変更

      expect(() => {
        order.cancel();  // 発送済み注文はキャンセル不可
      }).toThrow(NonCancellableOrderError);
    });
  });
});
```

---

### 📋 ドメイン層のチェックリスト

```
✅ ビジネスルールが集約されている
✅ 値オブジェクトが使われている
✅ エンティティが正しく定義されている
✅ インターフェースで外部依存を隔離
✅ 例外が明確（ビジネス例外）
✅ テストがビジネスロジック中心
✅ フレームワーク依存がない
```

---

### ➡️ 次のステップ

次は、**インフラストラクチャ層**を学びます。ここでビジネスロジックは外部ツール（DB、メール、API）と連携します。

[次: インフラストラクチャ層 →](#section-03-architecture-layers-04-infrastructure-layer)

## 04. インフラストラクチャ層 (Infrastructure Layer) {#section-03-architecture-layers-04-infrastructure-layer}


> **責務**: 外部システムとの連携。データベース、メール、外部API、ファイルシステムなど、ビジネスロジックの外部にある実装詳細をカプセル化する。

### 🎯 層の位置付け

```
┌──────────────────────────┐
│  プレゼンテーション層     │
├──────────────────────────┤
│  アプリケーション層       │
├──────────────────────────┤
│  ドメイン層              │
├──────────────────────────┤
│  インフラストラクチャ層   │  ← ここ
│ (DB, 外部API)           │
└──────────────────────────┘
```

---

### 📋 インフラストラクチャ層の責務

```
✅ インフラストラクチャ層が担当：
  - リポジトリ実装（DB操作）
  - 外部API連携
  - ファイルシステム操作
  - キャッシュ管理
  - ロギング実装
  - メール送信実装

❌ インフラストラクチャ層がしてはいけない：
  - ビジネスロジック
  - ユースケース管理
  - 直接的なプレゼンテーション
```

---

### 🏗️ 典型的なインフラストラクチャ層の構成

```
infrastructure/
├── persistence/
│   ├── repository/
│   │   ├── MySQLUserRepository.ts
│   │   ├── MongoDBOrderRepository.ts
│   │   └── ...
│   ├── database/
│   │   ├── MySQLConnection.ts
│   │   ├── MongoDBConnection.ts
│   │   └── ...
│   └── migration/
│       ├── 001_create_users_table.ts
│       └── ...
├── external/
│   ├── EmailService.ts
│   ├── PaymentProvider.ts
│   ├── SMSService.ts
│   └── ...
├── cache/
│   ├── RedisCache.ts
│   └── MemoryCache.ts
└── storage/
    ├── FileStorage.ts
    └── S3Storage.ts
```

---

### 💻 実装例1：リポジトリ実装

#### MySQL リポジトリ

```typescript
// infrastructure/persistence/repository/MySQLUserRepository.ts

export class MySQLUserRepository implements UserRepository {
  constructor(private db: MySQLDatabase) {}

  async save(user: User): Promise<void> {
    const query = `
      INSERT INTO users (id, email, password, name, status, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        name = VALUES(name),
        status = VALUES(status),
        updated_at = NOW()
    `;

    await this.db.query(query, [
      user.getId(),
      user.getEmail().getValue(),
      user.getPassword().getHashed(),
      user.getName(),
      user.getStatus(),
      new Date()
    ]);
  }

  async getUser(userId: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE id = ?';
    const row = await this.db.query(query, [userId]);

    if (!row) return null;

    return this.mapRowToUserEntity(row);
  }

  async findByEmail(email: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE email = ?';
    const row = await this.db.query(query, [email]);

    if (!row) return null;

    return this.mapRowToUserEntity(row);
  }

  async delete(userId: string): Promise<void> {
    const query = 'DELETE FROM users WHERE id = ?';
    await this.db.query(query, [userId]);
  }

  async search(criteria: {
    status?: UserStatus;
    limit?: number;
    offset?: number;
  }): Promise<User[]> {
    let query = 'SELECT * FROM users WHERE 1=1';
    const params: any[] = [];

    if (criteria.status) {
      query += ' AND status = ?';
      params.push(criteria.status);
    }

    query += ' LIMIT ? OFFSET ?';
    params.push(criteria.limit || 10);
    params.push(criteria.offset || 0);

    const rows = await this.db.query(query, params);
    return rows.map(row => this.mapRowToUserEntity(row));
  }

  // ドメインモデルへのマッピング
  private mapRowToUserEntity(row: any): User {
    return new User(
      row.id,
      new Email(row.email),
      new HashedPassword(row.password),
      row.name
    );
  }
}
```

#### MongoDB リポジトリ

```typescript
// infrastructure/persistence/repository/MongoDBUserRepository.ts

export class MongoDBUserRepository implements UserRepository {
  private collection: MongoCollection;

  constructor(db: MongoDatabase) {
    this.collection = db.collection('users');
  }

  async save(user: User): Promise<void> {
    const doc = {
      _id: user.getId(),
      email: user.getEmail().getValue(),
      password: user.getPassword().getHashed(),
      name: user.getName(),
      status: user.getStatus(),
      createdAt: new Date(),
      updatedAt: new Date()
    };

    await this.collection.updateOne(
      { _id: user.getId() },
      { $set: doc },
      { upsert: true }
    );
  }

  async getUser(userId: string): Promise<User | null> {
    const doc = await this.collection.findOne({ _id: userId });

    if (!doc) return null;

    return this.mapDocToUserEntity(doc);
  }

  async findByEmail(email: string): Promise<User | null> {
    const doc = await this.collection.findOne({
      email: email.toLowerCase()
    });

    if (!doc) return null;

    return this.mapDocToUserEntity(doc);
  }

  async delete(userId: string): Promise<void> {
    await this.collection.deleteOne({ _id: userId });
  }

  async search(criteria: any): Promise<User[]> {
    const filter: any = {};

    if (criteria.status) {
      filter.status = criteria.status;
    }

    const docs = await this.collection
      .find(filter)
      .skip(criteria.offset || 0)
      .limit(criteria.limit || 10)
      .toArray();

    return docs.map(doc => this.mapDocToUserEntity(doc));
  }

  private mapDocToUserEntity(doc: any): User {
    return new User(
      doc._id,
      new Email(doc.email),
      new HashedPassword(doc.password),
      doc.name
    );
  }
}
```

---

### 💻 実装例2：外部サービス実装

#### メール送信サービス

```typescript
// infrastructure/external/EmailService.ts

export class EmailService implements NotificationService {
  constructor(private emailProvider: EmailProvider) {}

  async sendWelcomeEmail(email: string): Promise<void> {
    const result = await this.emailProvider.send({
      to: email,
      subject: 'Welcome to Our Service',
      templateId: 'welcome-email',
      variables: {
        name: email.split('@')[0]
      }
    });

    if (!result.success) {
      throw new EmailSendError(result.errorMessage);
    }

    // ロギング
    console.log(`Welcome email sent to ${email}`);
  }

  async sendOrderConfirmation(
    email: string,
    orderId: string,
    total: number
  ): Promise<void> {
    await this.emailProvider.send({
      to: email,
      subject: 'Order Confirmation',
      templateId: 'order-confirmation',
      variables: {
        orderId,
        total
      }
    });
  }

  async sendPasswordReset(email: string, resetToken: string): Promise<void> {
    await this.emailProvider.send({
      to: email,
      subject: 'Password Reset Request',
      templateId: 'password-reset',
      variables: {
        resetUrl: `https://example.com/reset/${resetToken}`
      }
    });
  }
}
```

#### 支払いサービス

```typescript
// infrastructure/external/StripePaymentService.ts

export class StripePaymentService implements PaymentService {
  constructor(private stripeClient: Stripe) {}

  async charge(
    paymentMethodId: string,
    amount: Money
  ): Promise<PaymentResult> {
    try {
      const result = await this.stripeClient.paymentIntents.create({
        amount: amount.getAmount() * 100,  // セント単位
        currency: amount.getCurrency().toLowerCase(),
        payment_method: paymentMethodId,
        confirm: true
      });

      if (result.status === 'succeeded') {
        return {
          success: true,
          transactionId: result.id,
          amount: amount.getAmount(),
          timestamp: new Date()
        };
      } else {
        return {
          success: false,
          reason: result.last_payment_error?.message || 'Unknown error',
          timestamp: new Date()
        };
      }
    } catch (error) {
      throw new PaymentProviderError(
        'Stripe API error',
        error
      );
    }
  }

  async refund(transactionId: string, amount: Money): Promise<RefundResult> {
    try {
      const result = await this.stripeClient.refunds.create({
        payment_intent: transactionId,
        amount: amount.getAmount() * 100
      });

      return {
        success: result.status === 'succeeded',
        refundId: result.id,
        amount: amount.getAmount(),
        timestamp: new Date()
      };
    } catch (error) {
      throw new PaymentProviderError(
        'Stripe refund error',
        error
      );
    }
  }
}
```

---

### 💻 実装例3：キャッシュ層

```typescript
// infrastructure/cache/CachedUserRepository.ts

export class CachedUserRepository implements UserRepository {
  constructor(
    private baseRepository: UserRepository,
    private cache: CacheProvider
  ) {}

  async getUser(userId: string): Promise<User | null> {
    // キャッシュから取得を試す
    const cacheKey = `user:${userId}`;
    const cached = await this.cache.get(cacheKey);

    if (cached) {
      return this.deserializeUser(cached);
    }

    // キャッシュミス：DB から取得
    const user = await this.baseRepository.getUser(userId);

    if (user) {
      // キャッシュに保存（1時間有効）
      await this.cache.set(
        cacheKey,
        this.serializeUser(user),
        3600
      );
    }

    return user;
  }

  async save(user: User): Promise<void> {
    // DB に保存
    await this.baseRepository.save(user);

    // キャッシュを無効化
    const cacheKey = `user:${user.getId()}`;
    await this.cache.invalidate(cacheKey);
  }

  // 他のメソッド...

  private serializeUser(user: User): string {
    return JSON.stringify({
      id: user.getId(),
      email: user.getEmail().getValue(),
      name: user.getName()
    });
  }

  private deserializeUser(data: string): User {
    const obj = JSON.parse(data);
    return new User(
      obj.id,
      new Email(obj.email),
      // ... パスワードはキャッシュしないため不完全
    );
  }
}
```

---

### 📊 DB抽象化のメリット

```
インターフェース：UserRepository
        ↑
    実装1: MySQLUserRepository
    実装2: MongoDBUserRepository
    実装3: PostgreSQLUserRepository
    実装4: CachedUserRepository

メリット：
- DB を切り替え可能
- テスト時にモック可能
- キャッシュレイアーを透過的に追加可能
```

---

### 🧪 テスト

```typescript
describe('MySQLUserRepository', () => {
  let repository: MySQLUserRepository;
  let db: MySQLDatabase;

  beforeAll(async () => {
    db = await startTestDatabase();
    await db.runMigrations();
    repository = new MySQLUserRepository(db);
  });

  afterEach(async () => {
    await db.truncateTable('users');
  });

  test('should save and retrieve user', async () => {
    const user = new User(
      'user-123',
      new Email('test@example.com'),
      new HashedPassword('hashed'),
      'John Doe'
    );

    await repository.save(user);
    const retrieved = await repository.getUser('user-123');

    expect(retrieved).not.toBeNull();
    expect(retrieved?.getEmail().getValue()).toBe('test@example.com');
  });

  test('should find user by email', async () => {
    const user = new User(
      'user-123',
      new Email('test@example.com'),
      new HashedPassword('hashed'),
      'John Doe'
    );

    await repository.save(user);
    const found = await repository.findByEmail('test@example.com');

    expect(found?.getId()).toBe('user-123');
  });
});
```

---

### 📋 インフラストラクチャ層のチェックリスト

```
✅ インターフェースで抽象化されている
✅ ドメインロジックがない
✅ DB方言に特化したコード
✅ エラーハンドリングが適切
✅ ロギングがある
✅ トランザクション管理がある
```

---

### ➡️ 次のステップ

最後に、**層間の依存関係**を定義するルールを学びます。これがクリーンアーキテクチャの最も重要なルールです。

[次: 層の依存関係 →](#section-03-architecture-layers-05-layer-dependencies)

## 05. 層の依存関係ルール (Layer Dependency Rules) {#section-03-architecture-layers-05-layer-dependencies}


> **最も重要なルール**: 内側の層は外側の層に依存しない。外側の層が内側の層に依存する一方向のみ。

### 🎯 依存方向の基本ルール

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

### ❌ 違反パターン

#### 違反1：ドメイン層が外部フレームワークに依存

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

#### 違反2：ドメイン層が DB に直接依存

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

#### 違反3：アプリケーション層がプレゼンテーション層に依存

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

### ✅ 正しいパターン

#### 正しいパターン1：依存性逆転で抽象化

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

### 📊 依存関係の図解

#### ❌ 違反設計

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

#### ✅ 正しい設計（依存性逆転）

```
    UI層 ←── インターフェース ──→ DB層
       ↖          ↙
         ビジネス層
         
すべてがインターフェースに依存
```

---

### 💻 実装例：複雑なユースケース

#### ステップ1：ドメイン層（フレームワーク独立）

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

#### ステップ2：アプリケーション層

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

#### ステップ3：インフラストラクチャ層

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

#### ステップ4：プレゼンテーション層

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

### 🧪 依存関係を意識したテスト

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

### 📋 層の依存関係チェックリスト

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

### 📊 全4層の依存関係まとめ

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

### ➡️ 次のステップ

4層の理論を理解したので、次は **デザインパターン**を学びます。これらはクリーンアーキテクチャを実装するための具体的なパターンです。

[次: デザインパターン →](#chapter-04-design-patterns)

# Design Patterns {#chapter-04-design-patterns}

## 01. 依存性注入 (Dependency Injection) {#section-04-design-patterns-01-dependency-injection}


> **パターン**: オブジェクトの依存関係を外部から注入する。テスト性と柔軟性を大幅に向上させる。

### 🎯 コンセプト

```
❌ 自分で依存関係を作成
class UserService {
  private repository = new MySQLUserRepository();
}

✅ 外部から注入されて受け取る
class UserService {
  constructor(private repository: UserRepository) {}
}
```

---

### 📊 3つの DI パターン

#### パターン1：コンストラクタインジェクション（推奨）

```typescript
// 依存関係がコンストラクタのパラメータ
export class UserService {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService,
    private passwordService: PasswordService
  ) {}

  async registerUser(request: RegisterRequest): Promise<void> {
    // 注入された依存関係を使用
    const user = new User(...);
    await this.userRepository.save(user);
    await this.emailService.send(...);
  }
}

// 使用方法
const repository = new MySQLUserRepository(db);
const emailService = new EmailService(mailClient);
const passwordService = new PasswordService();

const userService = new UserService(
  repository,
  emailService,
  passwordService
);

userService.registerUser(request);
```

**メリット:**
- 依存関係が明確
- 不変（immutable）
- テストが簡単

#### パターン2：セッターインジェクション

```typescript
export class UserService {
  private userRepository: UserRepository;
  private emailService: EmailService;

  setUserRepository(repo: UserRepository): void {
    this.userRepository = repo;
  }

  setEmailService(service: EmailService): void {
    this.emailService = service;
  }
}

// 使用
const service = new UserService();
service.setUserRepository(new MySQLUserRepository(db));
service.setEmailService(new EmailService());
```

**欠点:**
- 依存関係を忘れることがある
- 可変でテストしにくい

#### パターン3：インターフェースインジェクション

```typescript
export interface Injector {
  inject(service: any, dependencies: any): void;
}

export class ContainerInjector implements Injector {
  inject(service: any, dependencies: any): void {
    for (const key in dependencies) {
      service[key] = dependencies[key];
    }
  }
}
```

---

### 🏭 DI コンテナの使用

#### 手動での組み立て

```typescript
// factory.ts
export class ApplicationFactory {
  static createUserService(): UserService {
    const db = new Database();
    const userRepository = new MySQLUserRepository(db);
    const emailService = new EmailService();
    const passwordService = new PasswordService();

    return new UserService(
      userRepository,
      emailService,
      passwordService
    );
  }

  static createOrderService(): OrderService {
    const db = new Database();
    const orderRepository = new MySQLOrderRepository(db);
    const inventoryService = new InventoryService();

    return new OrderService(
      orderRepository,
      inventoryService
    );
  }
}

// 使用
const userService = ApplicationFactory.createUserService();
const orderService = ApplicationFactory.createOrderService();
```

#### InversifyJS を使った DI コンテナ

```typescript
// 依存関係を定義
import { Container, injectable, inject } from 'inversify';

@injectable()
export class UserService {
  constructor(
    @inject('UserRepository') private userRepository: UserRepository,
    @inject('EmailService') private emailService: EmailService
  ) {}
}

@injectable()
export class MySQLUserRepository implements UserRepository {
  constructor(@inject('Database') private db: Database) {}
}

// コンテナ設定
const container = new Container();

container.bind<Database>('Database').toConstantValue(new Database());
container.bind<UserRepository>('UserRepository')
  .to(MySQLUserRepository)
  .inSingletonScope();  // シングルトン
container.bind<EmailService>('EmailService')
  .to(EmailService);
container.bind<UserService>(UserService)
  .to(UserService);

// 取得
const userService = container.get<UserService>(UserService);
```

---

### 🧪 テストでの活用

```typescript
describe('DI with Testing', () => {
  test('should work with mock dependencies', async () => {
    // 本当のDB を使わずにモックを注入
    const mockRepository: UserRepository = {
      save: jest.fn(),
      findById: jest.fn().mockResolvedValue(null)
    };

    const mockEmailService: EmailService = {
      send: jest.fn()
    };

    const mockPasswordService: PasswordService = {
      hash: jest.fn().mockReturnValue('hashed')
    };

    // テスト用のサービスを作成
    const userService = new UserService(
      mockRepository,
      mockEmailService,
      mockPasswordService
    );

    // テスト実行（DBなしで高速）
    await userService.registerUser({
      email: 'test@example.com',
      password: 'pass123'
    });

    expect(mockRepository.save).toHaveBeenCalled();
    expect(mockEmailService.send).toHaveBeenCalled();
  });
});
```

---

### 📋 DI チェックリスト

```
✅ 依存関係がコンストラクタで明確
✅ インターフェースで抽象化されている
✅ 循環依存がない
✅ テストで簡単にモックできる
✅ DI コンテナの設定が集約されている
```

---

[次: リポジトリパターン →](#section-04-design-patterns-02-repository-pattern)

## 02. リポジトリパターン (Repository Pattern) {#section-04-design-patterns-02-repository-pattern}


> **パターン**: データベーク操作をカプセル化。ドメイン層がDB方言を知らない。

### 🎯 コンセプト

```
ドメイン層 ── インターフェース ── 実装層（DB）

ドメイン層は、データの保存・取得がどのように
行われるかを知らない。
```

---

### 💻 実装

#### Step 1: インターフェース定義（ドメイン層）

```typescript
export interface UserRepository {
  save(user: User): Promise<void>;
  getById(id: string): Promise<User | null>;
  getByEmail(email: string): Promise<User | null>;
  update(user: User): Promise<void>;
  delete(id: string): Promise<void>;
}
```

#### Step 2: 実装（インフラ層）

```typescript
// MySQL実装
export class MySQLUserRepository implements UserRepository {
  async save(user: User): Promise<void> {
    const query = `INSERT INTO users VALUES (?, ?, ?)`;
    await this.db.execute(query, [user.id, user.email, user.name]);
  }

  async getById(id: string): Promise<User | null> {
    const result = await this.db.query(`SELECT * FROM users WHERE id = ?`, [id]);
    return result ? this.mapToEntity(result) : null;
  }
}

// MongoDB実装
export class MongoDBUserRepository implements UserRepository {
  async save(user: User): Promise<void> {
    await this.collection.insertOne({
      _id: user.id,
      email: user.email,
      name: user.name
    });
  }

  async getById(id: string): Promise<User | null> {
    const doc = await this.collection.findOne({ _id: id });
    return doc ? this.mapToEntity(doc) : null;
  }
}
```

#### Step 3: 使用（アプリケーション層）

```typescript
export class GetUserUseCase {
  constructor(private userRepository: UserRepository) {}

  async execute(userId: string): Promise<User> {
    // DB実装を知らずに使用
    const user = await this.userRepository.getById(userId);
    if (!user) throw new UserNotFoundError();
    return user;
  }
}
```

---

### 🎯 メリット

```
✅ DB技術を隠蔽
✅ ビジネスロジックがDB方言に汚染されない
✅ テスト時にモック可能
✅ DB変更が容易（MySQLからPostgreSQLへ）
✅ 複数DB対応が簡単
```

---

### 📋 チェックリスト

```
✅ ドメイン層に依存関係がない
✅ インターフェース定義と実装が分離
✅ エンティティマッピングが適切
✅ テストでモック化できる
```

---

[次: サービスパターン →](#section-04-design-patterns-03-service-pattern)

## 03. サービスパターン (Service Pattern) {#section-04-design-patterns-03-service-pattern}


> **パターン**: ビジネスロジックをサービスクラスで実装。ドメイン層とアプリケーション層で使用。

### 🎯 2種類のサービス

#### ドメインサービス（ドメイン層）

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

#### アプリケーションサービス（アプリケーション層）

```typescript
// ユースケースのロジック
export class ProcessPaymentApplicationService {
  constructor(
    private accountRepository: AccountRepository,
    private transferRepository: TransferRepository,
    private transferDomainService: TransferDomainService,
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

### 📊 ドメインサービス vs アプリケーションサービス

| 層 | サービス | 責務 | 依存関係 |
|----|---------|------|---------|
| **ドメイン** | Domain Service | ビジネスルール | インターフェースのみ |
| **アプリケーション** | Use Case | プロセス実行 | リポジトリ、外部サービス |

---

### 🧪 テスト

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

[次: DTO パターン →](#section-04-design-patterns-04-dto-pattern)

## 04. DTO パターン (Data Transfer Object) {#section-04-design-patterns-04-dto-pattern}


> **パターン**: 層間でのデータ転送用オブジェクト。ドメインモデルと外部表現を分離。

### 🎯 コンセプト

```
プレゼンテーション層 ← DTO → アプリケーション層 ← ドメイン層

ドメインモデルを直接公開しない
```

---

### 💻 実装例

#### Request DTO

```typescript
// presentation/dto/request/CreateUserRequest.ts
export interface CreateUserRequest {
  email: string;
  password: string;
  name: string;
}

// バリデーション
export class CreateUserRequestValidator {
  validate(data: any): CreateUserRequest {
    if (!data.email || !data.password || !data.name) {
      throw new ValidationError('Missing required fields');
    }
    return data;
  }
}
```

#### Response DTO

```typescript
// presentation/dto/response/UserResponse.ts
export interface UserResponse {
  id: string;
  email: string;
  name: string;
  createdAt: string;  // ISO形式
}

// ドメインモデルから DTO に変換
export class UserMapper {
  toUserResponse(user: User): UserResponse {
    return {
      id: user.getId(),
      email: user.getEmail().getValue(),
      name: user.getName(),
      createdAt: user.getCreatedAt().toISOString()
    };
  }

  // Request DTO - ドメインモデル
  toDomainUser(request: CreateUserRequest): User {
    return new User(
      uuid(),
      new Email(request.email),
      new HashedPassword(request.password),
      request.name
    );
  }
}
```

#### Application DTO

```typescript
// application/dto/RegisterUserDTO.ts
export interface RegisterUserDTO {
  email: string;
  password: string;
  name: string;
}

export interface RegisterUserResponseDTO {
  userId: string;
  email: string;
  createdAt: Date;
}
```

---

### 📊 層間のデータフロー

```
1. HTTP Request
   ↓
2. Presentation DTO (CreateUserRequest)
   ↓ バリデーション・マッピング
3. Application DTO (RegisterUserDTO)
   ↓ ドメイン層へ
4. Domain (User Entity)
   ↓ 処理後
5. Application DTO (RegisterUserResponseDTO)
   ↓ マッピング
6. Presentation DTO (UserResponse)
   ↓
7. HTTP Response
```

---

### 🧪 テスト

```typescript
describe('UserMapper', () => {
  test('should map user to response', () => {
    const user = new User('1', new Email('test@example.com'), new HashedPassword('hashed'), 'John');
    const mapper = new UserMapper();

    const response = mapper.toUserResponse(user);

    expect(response.email).toBe('test@example.com');
    expect(response.name).toBe('John');
  });

  test('should validate request DTO', () => {
    const validator = new CreateUserRequestValidator();

    expect(() => {
      validator.validate({ email: 'test@example.com', password: 'pass' });
    }).toThrow(ValidationError);
  });
});
```

---

### 📋 チェックリスト

```
✅ ドメインモデルが公開されていない
✅ 層ごとに独立した DTO 定義
✅ マッピング責任が明確
✅ バリデーションが適切な層で実施
```

---

[次: アダプタパターン →](#section-04-design-patterns-05-adapter-pattern)

## 05. アダプタパターン (Adapter Pattern) {#section-04-design-patterns-05-adapter-pattern}


> **パターン**: 異なるインターフェースを適合させる。外部ライブラリやAPIを統一インターフェースで扱う。

### 🎯 コンセプト

```
外部ライブラリAのインターフェース
         ↓ アダプタ
統一されたインターフェース
         ↑ アダプタ
外部ライブラリBのインターフェース
```

---

### 💻 実装例1：メールサービスの統一

#### 複数のメールプロバイダーがある

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

#### SendGrid アダプタ

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

#### AWS SES アダプタ

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

#### アプリケーション層（変わらない）

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

### 💻 実装例2：決済ゲートウェイの統一

#### 複数の決済プロバイダー

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

#### Stripe アダプタ

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

#### PayPal アダプタ

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

### 🏭 実装の切り替え

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

### 🧪 テスト

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

### 📋 チェックリスト

```
✅ 外部ライブラリが隔離されている
✅ 統一インターフェースで扱える
✅ 実装を切り替え可能
✅ テストで容易にモック化
✅ 複数プロバイダーに対応
```

---

### ➡️ 次のステップ

デザインパターンを学んだので、次は **実装ガイド**で、これらのパターンを実際のプロジェクトにどう適用するか学びます。

[次: 実装ガイド →](#chapter-05-implementation-guide)

# 05: 実装ガイド - 完全マニュアル {#chapter-05-implementation-guide}

## 01: プロジェクト構造 {#section-05-implementation-guide-01-project-structure}


クリーンアーキテクチャを実装する際の、フォルダ・ファイル配置を学びます。

### 📁 推奨フォルダ構成

```
user-management-system/
├── src/
│   ├── domain/                    # ドメイン層（ビジネスロジック）
│   │   ├── entities/
│   │   │   ├── User.ts
│   │   │   ├── Password.ts        # 値オブジェクト
│   │   │   └── Email.ts           # 値オブジェクト
│   │   ├── interfaces/
│   │   │   └── IUserRepository.ts # リポジトリI/F
│   │   ├── errors/
│   │   │   ├── DomainError.ts
│   │   │   ├── InvalidEmailError.ts
│   │   │   └── UserNotFoundError.ts
│   │   └── services/
│   │       └── PasswordHashService.ts
│   │
│   ├── application/               # アプリケーション層（ユースケース）
│   │   ├── usecases/
│   │   │   ├── RegisterUserUseCase.ts
│   │   │   ├── GetUserUseCase.ts
│   │   │   ├── UpdateProfileUseCase.ts
│   │   │   └── LoginUserUseCase.ts
│   │   ├── dtos/
│   │   │   ├── RegisterUserDTO.ts
│   │   │   ├── UserResponseDTO.ts
│   │   │   └── LoginRequestDTO.ts
│   │   └── services/
│   │       └── EmailSendingService.ts
│   │
│   ├── presentation/              # プレゼンテーション層（UI）
│   │   ├── controllers/
│   │   │   ├── UserController.ts
│   │   │   └── AuthController.ts
│   │   ├── middlewares/
│   │   │   ├── AuthMiddleware.ts
│   │   │   ├── ErrorHandler.ts
│   │   │   └── ValidationMiddleware.ts
│   │   └── routes/
│   │       ├── userRoutes.ts
│   │       └── authRoutes.ts
│   │
│   ├── infrastructure/            # インフラ層（外部リソース）
│   │   ├── repositories/
│   │   │   └── UserRepository.ts  # MySQL実装
│   │   ├── database/
│   │   │   ├── connection.ts
│   │   │   └── migrations/
│   │   │       └── 001_create_users_table.sql
│   │   ├── external-services/
│   │   │   └── EmailAdapter.ts    # メール送信
│   │   └── cryptography/
│   │       └── BcryptHasher.ts    # パスワードハッシュ化
│   │
│   ├── config/                    # DI設定
│   │   ├── Container.ts
│   │   └── dependencies.ts
│   │
│   └── app.ts                     # Express アプリケーション
│
├── tests/                         # テスト
│   ├── unit/
│   │   ├── domain/
│   │   │   └── entities/
│   │   │       └── User.test.ts
│   │   ├── application/
│   │   │   └── usecases/
│   │   │       └── RegisterUserUseCase.test.ts
│   │   └── presentation/
│   │       └── controllers/
│   │           └── UserController.test.ts
│   │
│   ├── integration/
│   │   ├── repositories/
│   │   │   └── UserRepository.test.ts
│   │   └── usecases/
│   │       └── RegisterUserUseCase.integration.test.ts
│   │
│   └── e2e/
│       └── auth.test.ts
│
├── package.json
├── tsconfig.json
├── jest.config.js
└── README.md
```

---

### 🎯 各層の役割と責務

#### 1️⃣ Domain（ドメイン層）

**責務:** ビジネスロジック、ルール、制約

**独立性:** フレームワーク・DBに依存しない

**構成と何を置くか:**

```typescript
// domain/entities/User.ts
// パぐあいエンティティ
export class User {
  private id: string;
  private email: Email;       // 値オブジェクト
  private password: Password; // 値オブジェクト
  private name: string;
  private createdAt: Date;

  // ビジネスロジック
  isPasswordCorrect(plainPassword: string): boolean {
    return this.password.matches(plainPassword);
  }

  updateProfile(name: string, email: Email): void {
    this.name = name;
    this.email = email;
  }
}

// domain/entities/Email.ts
// 値オブジェクト（メールアドレス固有の業務ルール）
export class Email {
  private readonly value: string;

  constructor(value: string) {
    if (!this.isValid(value)) {
      throw new InvalidEmailError(`Invalid email: ${value}`);
    }
    this.value = value;
  }

  private isValid(email: string): boolean {
    // メール形式チェック（ビジネスルール）
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  getValue(): string {
    return this.value;
  }
}

// domain/interfaces/IUserRepository.ts
// リポジトリインターフェース（抽象化）
export interface IUserRepository {
  save(user: User): Promise<void>;
  findById(id: string): Promise<User | null>;
  findByEmail(email: Email): Promise<User | null>;
  delete(id: string): Promise<void>;
}
```

**特徴:**
- エンティティ（ビジネスオブジェクト）
- 値オブジェクト（ルールを持つ値）
- エラークラス
- リポジトリインターフェース（抽象化）
- ビジネスサービス

---

#### 2️⃣ Application（アプリケーション層）

**責務:** ユースケース実行、トランザクション管理

**特性:** ドメイン層に依存 ← インフラ層には依存しない（インターフェース経由）

**構成と何を置くか:**

```typescript
// application/usecases/RegisterUserUseCase.ts
export class RegisterUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private emailSendingService: IEmailSendingService,
    private passwordHasher: IPasswordHasher
  ) {}

  async execute(request: RegisterUserRequest): Promise<void> {
    // 1. ビジネスルールチェック
    const existingUser = await this.userRepository.findByEmail(
      new Email(request.email)
    );
    if (existingUser) {
      throw new UserAlreadyExistsError();
    }

    // 2. ドメインオブジェクト生成
    const password = new Password(request.password);
    const hashedPassword = await this.passwordHasher.hash(password.getValue());
    const user = new User(
      UUID.v4(),
      new Email(request.email),
      hashedPassword,
      request.name
    );

    // 3. リポジトリで保存
    await this.userRepository.save(user);

    // 4. 副作用（メール送信）
    await this.emailSendingService.send(
      request.email,
      "ユーザー登録完了",
      `ようこそ、${request.name}さん`
    );
  }
}

// application/dtos/RegisterUserDTO.ts
// データ転送オブジェクト（層間のデータ受け渡し）
export class RegisterUserDTO {
  constructor(
    public email: string,
    public password: string,
    public name: string
  ) {}
}
```

**特徴:**
- ユースケース（1機能 = 1クラス）
- DTO（Data Transfer Object）
- アプリケーションサービス
- トランザクション管理

---

#### 3️⃣ Presentation（プレゼンテーション層）

**責務:** HTTP リクエスト処理、HTTPレスポンス形成

**特性:** 最もフレームワークに依存する層

**構成と何を置くか:**

```typescript
// presentation/controllers/UserController.ts
export class UserController {
  constructor(
    private registerUserUseCase: RegisterUserUseCase,
    private getUserUseCase: GetUserUseCase,
    private updateProfileUseCase: UpdateProfileUseCase
  ) {}

  async register(req: Request, res: Response): Promise<void> {
    try {
      // 1. リクエストボディをDTO変換
      const dto = new RegisterUserDTO(
        req.body.email,
        req.body.password,
        req.body.name
      );

      // 2. ユースケース実行
      await this.registerUserUseCase.execute(dto);

      // 3. HTTPレスポンス
      res.status(201).json({ message: "User registered successfully" });
    } catch (error) {
      res.status(400).json({ error: error.message });
    }
  }

  async getUser(req: Request, res: Response): Promise<void> {
    try {
      const user = await this.getUserUseCase.execute(req.params.id);
      res.json(new UserResponseDTO(user));
    } catch (error) {
      res.status(404).json({ error: "User not found" });
    }
  }
}

// presentation/routes/userRoutes.ts
export function setupUserRoutes(
  app: Express,
  userController: UserController
): void {
  app.post("/users/register", (req, res) =>
    userController.register(req, res)
  );
  app.get("/users/:id", (req, res) => userController.getUser(req, res));
}
```

**特徴:**
- Controllers（HTTPハンドラー）
- Routes（ルーティング）
- Middlewares（バリデーション、認証等）
- HTTPエラーハンドリング

---

#### 4️⃣ Infrastructure（インフラ層）

**責務:** 外部リソース設定・実装

**特性:** 最も変更する可能性が高い層

**構成と何を置くか:**

```typescript
// infrastructure/repositories/UserRepository.ts
export class UserRepository implements IUserRepository {
  constructor(private database: Database) {}

  async save(user: User): Promise<void> {
    await this.database.execute(
      `INSERT INTO users (id, email, password, name, created_at)
       VALUES (?, ?, ?, ?, ?)`,
      [
        user.getId(),
        user.getEmail().getValue(),
        user.getPassword(),
        user.getName(),
        user.getCreatedAt()
      ]
    );
  }

  async findById(id: string): Promise<User | null> {
    const row = await this.database.query(
      "SELECT * FROM users WHERE id = ?",
      [id]
    );
    if (!row) return null;
    return this.mapRowToUser(row);
  }

  private mapRowToUser(row: any): User {
    return new User(
      row.id,
      new Email(row.email),
      row.password,
      row.name,
      new Date(row.created_at)
    );
  }
}

// infrastructure/database/connection.ts
// MySQL接続設定
export const createConnection = async (): Promise<Database> => {
  return mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
  });
};

// infrastructure/external-services/EmailAdapter.ts
export class EmailAdapter implements IEmailSendingService {
  async send(to: string, subject: string, body: string): Promise<void> {
    // SendGrid APIやSMTPを使用
    await sendEmail({ to, subject, body });
  }
}
```

**特徴:**
- リポジトリ実装（DB操作）
- DB接続設定
- 外部API統合
- キャッシュ層

---

#### 5️⃣ Config（DI設定）

**責務:** 依存性の紐付け

**特性:** アプリケーション起動時に依存関係を組み立てる

```typescript
// config/Container.ts
export class Container {
  private instances: Map<string, any> = new Map();

  // リポジトリ
  registerUserRepository(db: Database): void {
    this.instances.set("UserRepository", new UserRepository(db));
  }

  // ユースケース
  registerRegisterUserUseCase(): void {
    const userRepository = this.instances.get("UserRepository");
    const emailService = this.instances.get("EmailSendingService");
    const passwordHasher = this.instances.get("PasswordHasher");

    this.instances.set(
      "RegisterUserUseCase",
      new RegisterUserUseCase(userRepository, emailService, passwordHasher)
    );
  }

  // コントローラー
  registerUserController(): void {
    const registerUseCase = this.instances.get("RegisterUserUseCase");
    const getUseCase = this.instances.get("GetUserUseCase");
    const updateUseCase = this.instances.get("UpdateProfileUseCase");

    this.instances.set(
      "UserController",
      new UserController(registerUseCase, getUseCase, updateUseCase)
    );
  }

  get<T>(key: string): T {
    return this.instances.get(key);
  }
}

// config/dependencies.ts
export const setupDependencies = async (): Promise<Container> => {
  const container = new Container();

  // データベース
  const db = await createConnection();

  // インフラ層
  container.registerUserRepository(db);
  container.register("Database", db);
  container.register("EmailSendingService", new EmailAdapter());
  container.register("PasswordHasher", new BcryptHasher());

  // アプリケーション層
  container.registerRegisterUserUseCase();
  container.registerGetUserUseCase();
  container.registerUpdateProfileUseCase();

  // プレゼンテーション層
  container.registerUserController();

  return container;
};

// app.ts
async function bootstrap() {
  const container = await setupDependencies();
  const app = express();

  const userController = container.get<UserController>("UserController");
  setupUserRoutes(app, userController);

  app.listen(3000, () => console.log("Server running on port 3000"));
}

bootstrap();
```

---

### 🔄 層間の依存関係

```
          Presentation
               ↓
          Application
               ↓
            Domain
               ↓
         Infrastructure
```

**重要ルール:**

- 上位層 → 下位層への依存は OK
- 下位層 → 上位層への依存は NG
- Infrastructure は他層に依存しない（インターフェース経由で逆転）

---

### 🏗️ プロジェクト初期化コマンド

```bash
# プロジェクト作成
mkdir user-management-system
cd user-management-system

# Node.js 初期化
npm init -y

# TypeScript インストール
npm install -D typescript @types/node ts-node

# Express インストール
npm install express
npm install -D @types/express

# MySQL インストール
npm install mysql2/promise

# テスト環境（Jest）
npm install -D jest @types/jest ts-jest

# 型チェック・構文チェック
npm install -D eslint @typescript-eslint/eslint-plugin

# フォルダ構成作成
mkdir -p src/{domain/{entities,interfaces,errors,services},application/{usecases,dtos,services},presentation/{controllers,middlewares,routes},infrastructure/{repositories,database,external-services,cryptography},config}
mkdir -p tests/{unit,integration,e2e}
```

---

### 📋 チェックリスト

このファイル理解後:

```
□ 5層の責務が明確
□ 各層に何を置くか理解した
□ 層間の依存関係ルールが分かった
□ フォルダ構成をプロジェクトに適用できた
```

---

**次: [エンティティ設計 →](#section-05-implementation-guide-02-entity-design)**

## 02: エンティティ設計 {#section-05-implementation-guide-02-entity-design}


ドメイン層の中核であるエンティティと値オブジェクトの設計・実装を学びます。

### 🎯 エンティティとは

**定義:** ビジネス的に意味のある、アイデンティティを持つオブジェクト

**特徴:**
- 一意な ID を持つ
- ライフサイクルがある（作成 → 変更 → 削除）
- ビジネスロジックを内包する
- DB テーブルと1対1対応（多くの場合）

---

### 📊 ユーザー管理システムの場合

```
エンティティ: User
  ↓
属性1: id（一意）
属性2: Email（メールアドレス）
属性3: Password（パスワード）
属性4: name（ユーザー名）
属性5: createdAt（作成日時）
```

---

### 💡 値オブジェクトとは

**定義:** ビジネスルールを持つ、単なる「値」

**特徴:**
- アイデンティティを持たない（値を同じなら同じ）
- 不変（immutable）
- ビジネスルールを持つ

**例：**
- `Email`: メール形式の自動チェック機能
- `Password`: パスワード強度チェック機能
- `Money`: 通貨単位と金額の検証
- `Range`: 開始日～終了日の自動検証

---

### 📝 実装例 1: Email 値オブジェクト

#### ❌ 悪い例（値オブジェクトがない）

```typescript
// ❌ NG: メールアドレスが単なる string
class User {
  private email: string;  // string のまま

  constructor(email: string) {
    // バリデーションなし
    this.email = email;
  }

  // 問題: 複数箇所でメール形式チェックが必要
  getEmail(): string {
    return this.email;
  }
}

// 使用側
const user = new User("invalid-email");  // エラーにならない！
const email = user.getEmail();

// 他の場所でもメールを扱う
function sendEmail(email: string) {
  if (!isValidEmail(email)) {  // 毎回 validation
    throw new Error("Invalid email");
  }
  // メール送信
}
```

**問題点:**
- メール形式チェックが分散
- 無効なメールアドレスが User に入る可能性
- ビジネスルールが不明確

#### ✅ 良い例（値オブジェクトを使う）

```typescript
// ✅ OK: Email 値オブジェクト
export class Email {
  private readonly value: string;

  constructor(value: string) {
    if (!Email.isValid(value)) {
      throw new InvalidEmailError(`Invalid email format: ${value}`);
    }
    this.value = value;
  }

  // ビジネスルール: メール形式チェック
  private static isValid(email: string): boolean {
    // RFC 5322 簡易版
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  // 呼び出し側は形式チェック不要
  getValue(): string {
    return this.value;
  }

  // 等値比較（値が同じなら同じ Email）
  equals(other: Email): boolean {
    return this.value === other.value;
  }

  // ドメイン部分取得（ビジネスロジック）
  getDomain(): string {
    return this.value.split("@")[1];
  }
}

// 使用側
class User {
  private email: Email;  // Email 値オブジェクト

  constructor(email: Email) {
    this.email = email;  // constructor で保証済み
  }

  getEmail(): Email {
    return this.email;
  }

  // 別のメールに変更
  changeEmail(newEmail: Email): void {
    // newEmail は既に validation済み
    this.email = newEmail;
  }
}

// 使用例
const email = new Email("user@example.com");  // ここで validation ✓
const user = new User(email);

// 無効なメール
try {
  const invalidEmail = new Email("invalid");  // 即座にエラー ✓
} catch (error) {
  console.log("Invalid email:", error.message);
}
```

**メリット:**
- メール形式チェックが一箇所に集約
- User に入る Email は必ず有効
- ビジネスルールが明確

---

### 📝 実装例 2: Password 値オブジェクト

#### ❌ 悪い例

```typescript
// ❌ NG: パスワードが string のまま
class User {
  private password: string;  // ハッシュ化されているか不明確

  setPassword(plainPassword: string) {
    this.password = plainPassword;  // 平文で保存？ハッシュ？不明確
  }
}
```

#### ✅ 良い例

```typescript
export class Password {
  private readonly hashedValue: string;

  // コンストラクタ: ハッシュ化済みパスワード
  private constructor(hashedValue: string) {
    if (hashedValue.length < 60) {
      throw new InvalidPasswordError("Password must be hashed");
    }
    this.hashedValue = hashedValue;
  }

  // 静的ファクトリメソッド1: 平文から作成
  static async fromPlainText(plainPassword: string): Promise<Password> {
    // 1. 強度チェック
    this.validateStrength(plainPassword);

    // 2. ハッシュ化（bcrypt）
    const hashedValue = await bcrypt.hash(plainPassword, 10);

    // 3. Password インスタンス生成
    return new Password(hashedValue);
  }

  // 静的ファクトリメソッド2: ハッシュ化済みから生成（DB読み込み）
  static fromHash(hash: string): Password {
    return new Password(hash);
  }

  // ビジネスロジック: パスワード検証
  async matches(plainPassword: string): Promise<boolean> {
    return bcrypt.compare(plainPassword, this.hashedValue);
  }

  // ハッシュ値取得（DB保存用）
  getHashedValue(): string {
    return this.hashedValue;
  }

  // ビジネスルール: パスワード強度チェック
  private static validateStrength(password: string): void {
    const errors: string[] = [];

    if (password.length < 8) {
      errors.push("Password must be at least 8 characters");
    }
    if (!/[A-Z]/.test(password)) {
      errors.push("Password must contain uppercase letter");
    }
    if (!/[a-z]/.test(password)) {
      errors.push("Password must contain lowercase letter");
    }
    if (!/[0-9]/.test(password)) {
      errors.push("Password must contain number");
    }

    if (errors.length > 0) {
      throw new WeakPasswordError(errors.join(", "));
    }
  }
}

// 使用例
// 新規登録時
const password1 = await Password.fromPlainText("MyPassword123");

// ログイン検証時
const matches = await password1.matches("MyPassword123");  // true

// DB から読み込み
const hashFromDb = "$2b$10$...";
const password2 = Password.fromHash(hashFromDb);

// 弱いパスワード
try {
  await Password.fromPlainText("weak");  // エラー
} catch (error) {
  console.log(error.message);
}
```

---

### 📝 実装例 3: User エンティティ（完全版）

```typescript
import { v4 as uuid } from "uuid";

export class User {
  private readonly id: string;
  private email: Email;
  private password: Password;
  private name: string;
  private readonly createdAt: Date;
  private updatedAt: Date;
  private isActive: boolean;

  // プライベートコンストラクタ（直接生成不可）
  private constructor(
    id: string,
    email: Email,
    password: Password,
    name: string,
    createdAt: Date,
    updatedAt: Date,
    isActive: boolean
  ) {
    this.id = id;
    this.email = email;
    this.password = password;
    this.name = name;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
    this.isActive = isActive;
  }

  // ファクトリメソッド1: 新規ユーザー作成
  static async create(
    email: Email,
    plainPassword: string,
    name: string
  ): Promise<User> {
    // ビジネスロジック: ユーザー名の長さチェック
    if (name.length < 2 || name.length > 100) {
      throw new InvalidNameError("Name must be 2-100 characters");
    }

    // パスワード生成（強度チェック含む）
    const password = await Password.fromPlainText(plainPassword);

    return new User(
      uuid(),
      email,
      password,
      name,
      new Date(),
      new Date(),
      true
    );
  }

  // ファクトリメソッド2: DB から復元
  static reconstruct(
    id: string,
    email: Email,
    hashedPassword: string,
    name: string,
    createdAt: Date,
    updatedAt: Date,
    isActive: boolean
  ): User {
    const password = Password.fromHash(hashedPassword);
    return new User(id, email, password, name, createdAt, updatedAt, isActive);
  }

  // ビジネスロジック: ビジネスルール

  // 1. パスワード検証ロジック
  async isPasswordMatches(plainPassword: string): Promise<boolean> {
    return this.password.matches(plainPassword);
  }

  // 2. プロフィール更新ロジック
  updateProfile(newName: string, newEmail: Email): void {
    // バリデーション
    if (newName.length < 2 || newName.length > 100) {
      throw new InvalidNameError("Name must be 2-100 characters");
    }

    // ビジネスルール: メール変更時は再認証が必要（フラグ）
    const emailChanged = !this.email.equals(newEmail);

    this.name = newName;
    this.email = newEmail;
    this.updatedAt = new Date();

    if (emailChanged) {
      // この後、メール確認処理が発生することを示す
      // (他のエンティティでイベント化することも)
    }
  }

  // 3. パスワード変更ロジック
  async changePassword(newPlainPassword: string): Promise<void> {
    // 新しいパスワード生成（強度チェック含む）
    const newPassword = await Password.fromPlainText(newPlainPassword);
    this.password = newPassword;
    this.updatedAt = new Date();
  }

  // 4. アカウント無効化
  deactivate(): void {
    if (!this.isActive) {
      throw new UserAlreadyDeactivatedError();
    }
    this.isActive = false;
    this.updatedAt = new Date();
  }

  // 5. アカウント有効化
  activate(): void {
    if (this.isActive) {
      throw new UserAlreadyActiveError();
    }
    this.isActive = true;
    this.updatedAt = new Date();
  }

  // ゲッター（読み取り専用）

  getId(): string {
    return this.id;
  }

  getEmail(): Email {
    return this.email;
  }

  getPassword(): Password {
    return this.password;
  }

  getName(): string {
    return this.name;
  }

  getCreatedAt(): Date {
    return this.createdAt;
  }

  getUpdatedAt(): Date {
    return this.updatedAt;
  }

  isUserActive(): boolean {
    return this.isActive;
  }
}
```

---

### 🔍 値オブジェクトまとめ

| 値オブジェクト | 持つビジネスルール | 例 |
|-------------|-------------|-----|
| `Email` | メール形式チェック、ドメイン抽出 | `user@example.com` |
| `Password` | 強度チェック、ハッシュ化、マッチング | 8文字以上、大文字含む |
| `Money` | 通貨単位の統一、計算 | 100 JPY + 50 JPY = 150 JPY |
| `Range` | 日付範囲の妥当性チェック | 開始日 < 終了日 |
| `UserId` | ID形式チェック | UUID形式 |
| `PhoneNumber` | 電話番号形式チェック | +81-90-XXXX-XXXX |

---

### 🚀 実装チェックリスト

**エンティティ実装時:**

```
□ プライベートプロパティで不変性を確保
□ ファクトリメソッドで安全な生成
□ ビジネスロジックをメソッドに内包
□ エラーケースで例外をスロー
□ 値オブジェクトを使用（文字列/数値ではなく）
```

**値オブジェクト実装時:**

```
□ コンストラクタでバリデーション
□ immutable（変更不可）設計
□ ビジネスルールを持つメソッド
□ equals() で等値比較実装
□ toString() で文字列表現実装
```

---

### 🎯 実装例の起動コード

```typescript
// 使用例
async function exampleUserFlow() {
  try {
    // 1. 新規ユーザー作成
    const email = new Email("john@example.com");
    const user = await User.create(email, "MyPassword123", "John Doe");

    console.log(`User created: ${user.getName()}`);
    console.log(`Created at: ${user.getCreatedAt()}`);

    // 2. パスワード検証
    const isCorrect = await user.isPasswordMatches("MyPassword123");
    console.log(`Password correct: ${isCorrect}`);

    // 3. プロフィール更新
    const newEmail = new Email("john.doe@example.com");
    user.updateProfile("John Doe Jr", newEmail);
    console.log(`Updated profile`);

    // 4. パスワード変更
    await user.changePassword("NewPassword456");
    console.log(`Password changed`);

    // 5. アカウント無効化
    user.deactivate();
    console.log(`User deactivated`);

  } catch (error) {
    console.error(`Error: ${error.message}`);
  }
}

exampleUserFlow();
```

---

**次: [ユースケース設計 →](#section-05-implementation-guide-03-usecase-design)**

## 03: ユースケース設計 {#section-05-implementation-guide-03-usecase-design}


アプリケーション層の中核であるユースケース（ビジネスロジック実行層）の設計・実装を学びます。

### 🎯 ユースケースとは

**定義:** [Clean Architecture では] ビジネスロジックを実行する「アプリケーションのユースケース」を実装する層

**役割:**
1. ドメイン層（Entity）の組み合わせ
2. インフラ層（Repository）の呼び出し
3. 副作用（メール送信等）の実行
4. トランザクション管理
5. エラーハンドリング

**特徴:**
- 1 ユースケース = 1 機能
- ビジネスプロセスの流れを表現
- フレームワークに依存しない

---

### 📊 ユースケース例：ユーザー登録

```
ユースケース: RegisterUser
  ↓
入力: メール、パスワード、名前
  ↓
処理:
  1. 既存ユーザー確認
  2. ユーザーオブジェクト生成
  3. DB 保存
  4. 確認メール送信
  ↓
出力: なし（成功 or エラーをスロー）
```

---

### ❌ 悪い実装例

```typescript
// ❌ NG: ユースケースが散らばっている

// Controller に直接ビジネスロジック
express.post("/register", async (req, res) => {
  // 1. バリデーション
  if (!req.body.email || !req.body.password) {
    return res.status(400).json({ error: "Invalid input" });
  }

  // 2. ユーザー確認（リポジトリ）
  const existingUser = await userDb.query(
    "SELECT * FROM users WHERE email = ?",
    [req.body.email]
  );
  if (existingUser) {
    return res.status(400).json({ error: "User already exists" });
  }

  // 3. パスワードハッシュ化
  const hashedPassword = await bcrypt.hash(req.body.password, 10);

  // 4. DB 保存
  const userId = uuid();
  await userDb.query(
    "INSERT INTO users (id, email, password, name) VALUES (?, ?, ?, ?)",
    [userId, req.body.email, hashedPassword, req.body.name]
  );

  // 5. メール送信
  await sendEmail(req.body.email, "Welcome!");

  // 6. レスポンス
  res.status(201).json({ message: "User registered" });
});

// 問題: テストが困難、他のプレゼンテーション層から再利用不可
```

---

### ✅ 良い実装例

#### 1️⃣ ユースケース定義（リクエスト/レスポンス）

```typescript
// application/usecases/RegisterUserUseCase/RegisterUserRequest.ts
export class RegisterUserRequest {
  constructor(
    readonly email: string,
    readonly password: string,
    readonly name: string
  ) {}
}

// application/usecases/RegisterUserUseCase/RegisterUserResponse.ts
export class RegisterUserResponse {
  constructor(readonly userId: string) {}
}
```

#### 2️⃣ インターフェース定義（依存性の抽象化）

```typescript
// domain/interfaces/IUserRepository.ts
export interface IUserRepository {
  save(user: User): Promise<void>;
  findByEmail(email: Email): Promise<User | null>;
  findById(id: string): Promise<User | null>;
}

// application/interfaces/IEmailSendingService.ts
export interface IEmailSendingService {
  send(to: string, subject: string, body: string): Promise<void>;
}

// application/interfaces/IPasswordHasher.ts
export interface IPasswordHasher {
  hash(plainPassword: string): Promise<string>;
  compare(plainPassword: string, hash: string): Promise<boolean>;
}
```

#### 3️⃣ ユースケース実装

```typescript
// application/usecases/RegisterUserUseCase/RegisterUserUseCase.ts
export class RegisterUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private emailSendingService: IEmailSendingService,
    private passwordHasher: IPasswordHasher
  ) {}

  async execute(request: RegisterUserRequest): Promise<RegisterUserResponse> {
    // 1. ビジネスルール検証：ユーザー重複チェック
    const existingUser = await this.userRepository.findByEmail(
      new Email(request.email)
    );

    if (existingUser) {
      throw new UserAlreadyExistsError(
        `Email ${request.email} is already registered`
      );
    }

    // 2. ドメインオブジェクト生成
    // Email と Password は値オブジェクトで validation 済み
    const email = new Email(request.email);
    const user = await User.create(email, request.password, request.name);

    // 3. リポジトリで永続化
    try {
      await this.userRepository.save(user);
    } catch (error) {
      throw new UserSaveError(`Failed to save user: ${error.message}`);
    }

    // 4. 副作用：メール送信
    try {
      await this.emailSendingService.send(
        request.email,
        "ユーザー登録完了",
        `ようこそ、${request.name}さん！`
      );
    } catch (error) {
      // メール送信失敗はログするが、ユーザー登録は成功扱い
      console.warn(`Failed to send welcome email: ${error.message}`);
    }

    // 5. レスポンス返却
    return new RegisterUserResponse(user.getId());
  }
}
```

---

### 📝 その他のユースケース例

#### ユースケース2: ユーザーログイン

```typescript
// application/usecases/LoginUserUseCase/LoginUserRequest.ts
export class LoginUserRequest {
  constructor(readonly email: string, readonly password: string) {}
}

// application/usecases/LoginUserUseCase/LoginUserResponse.ts
export class LoginUserResponse {
  constructor(readonly userId: string, readonly token: string) {}
}

// application/usecases/LoginUserUseCase/LoginUserUseCase.ts
export class LoginUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private tokenGenerator: ITokenGenerator
  ) {}

  async execute(request: LoginUserRequest): Promise<LoginUserResponse> {
    // 1. メールでユーザー検索
    const user = await this.userRepository.findByEmail(
      new Email(request.email)
    );

    if (!user) {
      throw new UserNotFoundError(`User not found: ${request.email}`);
    }

    // 2. パスワード検証
    const passwordMatches = await user.isPasswordMatches(request.password);

    if (!passwordMatches) {
      throw new InvalidPasswordError("Password is incorrect");
    }

    // 3. アカウント状態確認
    if (!user.isUserActive()) {
      throw new UserDeactivatedError("Account is deactivated");
    }

    // 4. トークン生成
    const token = await this.tokenGenerator.generate(user.getId());

    // 5. レスポンス
    return new LoginUserResponse(user.getId(), token);
  }
}
```

#### ユースケース3: プロフィール更新

```typescript
// application/usecases/UpdateProfileUseCase/UpdateProfileRequest.ts
export class UpdateProfileRequest {
  constructor(
    readonly userId: string,
    readonly newName: string,
    readonly newEmail: string
  ) {}
}

// application/usecases/UpdateProfileUseCase/UpdateProfileUseCase.ts
export class UpdateProfileUseCase {
  constructor(
    private userRepository: IUserRepository,
    private emailSendingService: IEmailSendingService
  ) {}

  async execute(request: UpdateProfileRequest): Promise<void> {
    // 1. ユーザー取得
    const user = await this.userRepository.findById(request.userId);
    if (!user) {
      throw new UserNotFoundError(`User not found: ${request.userId}`);
    }

    // 2. 新しいメールの重複チェック
    const newEmail = new Email(request.newEmail);
    const existingUserWithEmail = await this.userRepository.findByEmail(newEmail);

    if (existingUserWithEmail && existingUserWithEmail.getId() !== request.userId) {
      throw new EmailAlreadyInUseError(
        `Email ${request.newEmail} is already in use`
      );
    }

    // 3. プロフィール更新（ドメインロジック）
    const oldEmail = user.getEmail().getValue();
    user.updateProfile(request.newName, newEmail);

    // 4. DB 更新
    await this.userRepository.save(user);

    // 5. メール変更時のみ確認メール送信
    if (oldEmail !== request.newEmail) {
      await this.emailSendingService.send(
        request.newEmail,
        "メールアドレス変更確認",
        "このメールアドレスでプロフィールが更新されました"
      );
    }
  }
}
```

---

### 🔄 Request → Response フロー

```
Controller
  ↓ (HTTP Request から Request オブジェクト生成)
  ↓
UseCase.execute(Request)
  ↓
  1. ビジネスルール検証
  2. ドメインオブジェクト操作
  3. リポジトリで永続化
  4. 副作用（メール等）実行
  ↓
Response オブジェクト返却
  ↓ (Response から HTTP Response に変換)
Controller
```

---

### 🌐 Controller から ユースケース呼び出し

```typescript
// presentation/controllers/UserController.ts
export class UserController {
  constructor(
    private registerUserUseCase: RegisterUserUseCase,
    private loginUserUseCase: LoginUserUseCase,
    private updateProfileUseCase: UpdateProfileUseCase
  ) {}

  // POST /users/register
  async register(req: Request, res: Response): Promise<void> {
    try {
      // 1. HTTP リクエストを Request オブジェクトに変換
      const request = new RegisterUserRequest(
        req.body.email,
        req.body.password,
        req.body.name
      );

      // 2. ユースケース実行
      const response = await this.registerUserUseCase.execute(request);

      // 3. Response를 HTTP レスポンスに変換
      res.status(201).json({
        message: "User registered successfully",
        userId: response.userId
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  // POST /auth/login
  async login(req: Request, res: Response): Promise<void> {
    try {
      const request = new LoginUserRequest(
        req.body.email,
        req.body.password
      );

      const response = await this.loginUserUseCase.execute(request);

      res.status(200).json({
        message: "Login successful",
        userId: response.userId,
        token: response.token
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  // PUT /users/:id/profile
  async updateProfile(req: Request, res: Response): Promise<void> {
    try {
      const request = new UpdateProfileRequest(
        req.params.id,
        req.body.name,
        req.body.email
      );

      await this.updateProfileUseCase.execute(request);

      res.status(200).json({ message: "Profile updated successfully" });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  // エラーハンドリング
  private handleError(error: any, res: Response): void {
    if (error instanceof UserAlreadyExistsError) {
      res.status(400).json({ error: error.message });
    } else if (error instanceof UserNotFoundError) {
      res.status(404).json({ error: error.message });
    } else if (error instanceof InvalidPasswordError) {
      res.status(401).json({ error: error.message });
    } else {
      res.status(500).json({ error: "Internal server error" });
    }
  }
}
```

---

### 🧩 ユースケースの層間依存関係

```
Presentation
    ↓
UseCase ← Interface (IUserRepository / IEmailService)
    ↓
Domain (Entity, ValueObject)

Infrastructure (実装)
    ↓
（IUserRepository の実装 = MySQL用リポジトリ）
```

**重要:** ユースケースは Infrastructure に直接依存 しない → インターフェース経由

---

### ✅ ユースケース実装チェックリスト

```
□ Request / Response クラス定義
□ 依存性をコンストラクタで受け取る（DI）
□ ビジネスルール検証を最初に
□ ドメインオブジェクトを生成・操作
□ リポジトリで永続化
□ 副作用（メール等）を実行
□ エラーケースで適切な Exception をスロー
□ 単一責任の原則に従う（1 UseCase = 1 機能）
□ 同期・非同期ロジックが明確
```

---

### 🎯 ベストプラクティス

#### 1️⃣ トランザクション管理

```typescript
export class UpdateProfileUseCase {
  constructor(
    private userRepository: IUserRepository,
    private unitOfWork: IUnitOfWork  // トランザクション管理
  ) {}

  async execute(request: UpdateProfileRequest): Promise<void> {
    // トランザクション開始
    const transaction = await this.unitOfWork.begin();

    try {
      // ユーザー取得
      const user = await this.userRepository.findById(request.userId);

      // プロフィール更新
      user.updateProfile(request.newName, new Email(request.newEmail));

      // 保存
      await this.userRepository.save(user);

      // コミット
      await transaction.commit();
    } catch (error) {
      // ロールバック
      await transaction.rollback();
      throw error;
    }
  }
}
```

#### 2️⃣ 副作用の分離

```typescript
export class RegisterUserUseCase {
  async execute(request: RegisterUserRequest): Promise<RegisterUserResponse> {
    // ... ユーザー作成・保存 ...

    // メール送信は「副作用」としてログ出力
    // 実際の送信は非同期で別途実行
    await this.eventBus.publish(new UserRegisteredEvent(userId, email));

    return new RegisterUserResponse(userId);
  }
}

// 別処理で非同期実行
eventBus.subscribe(UserRegisteredEvent, (event) => {
  emailService.send(event.email, "Welcome!").catch(err => {
    logger.warn(`Failed to send email: ${err}`);
  });
});
```

---

**次: [完全実装例 →](#section-05-implementation-guide-04-implementation-example)**

## 04: 完全な実装例 {#section-05-implementation-guide-04-implementation-example}


01 ~ 03 で学んだ知識を、実際に動く完全なコード例として示します。

ユーザー管理システム（ユーザー登録・ログイン）の全層実装です。

---

### 🗂️ ファイル構成（完全版）

```
src/
├── domain/
│   ├── entities/
│   │   └── User.ts          # User エンティティ
│   ├── value-objects/
│   │   ├── Email.ts         # Email 値オブジェクト
│   │   └── Password.ts      # Password 値オブジェクト
│   ├── interfaces/
│   │   └── IUserRepository.ts
│   └── errors/
│       ├── DomainError.ts
│       ├── InvalidEmailError.ts
│       └── UserAlreadyExistsError.ts
│
├── application/
│   ├── usecases/
│   │   ├── RegisterUserUseCase.ts
│   │   └── LoginUserUseCase.ts
│   ├── dtos/
│   │   ├── RegisterUserRequest.ts
│   │   └── LoginUserRequest.ts
│   ├── interfaces/
│   │   ├── IEmailSendingService.ts
│   │   └── IPasswordHasher.ts
│   └── errors/
│       └── ApplicationError.ts
│
├── presentation/
│   ├── controllers/
│   │   └── UserController.ts
│   ├── routes/
│   │   └── userRoutes.ts
│   └── middlewares/
│       └── ErrorHandlerMiddleware.ts
│
├── infrastructure/
│   ├── repositories/
│   │   └── UserRepository.ts   # MySQL 実装
│   ├── services/
│   │   ├── BcryptHasher.ts
│   │   └── EmailAdapter.ts
│   └── database/
│       └── MySQLConnection.ts
│
├── config/
│   ├── Container.ts            # DI コンテナ
│   └── dependencies.ts         # 依存性設定
│
└── app.ts                       # Express アプリケーション
```

---

### 💾 01: Domain 層の実装

#### domain/errors/DomainError.ts

```typescript
export abstract class DomainError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class InvalidEmailError extends DomainError {}
export class InvalidPasswordError extends DomainError {}
export class UserAlreadyExistsError extends DomainError {}
export class UserNotFoundError extends DomainError {}
```

#### domain/value-objects/Email.ts

```typescript
import { InvalidEmailError } from "../errors/DomainError";

export class Email {
  private readonly value: string;

  constructor(value: string) {
    if (!Email.isValid(value)) {
      throw new InvalidEmailError(`Invalid email format: ${value}`);
    }
    this.value = value.toLowerCase();
  }

  static isValid(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  getValue(): string {
    return this.value;
  }

  equals(other: Email): boolean {
    return this.value === other.value;
  }

  getDomain(): string {
    return this.value.split("@")[1];
  }

  toString(): string {
    return this.value;
  }
}
```

#### domain/value-objects/Password.ts

```typescript
import * as bcrypt from "bcrypt";
import { InvalidPasswordError } from "../errors/DomainError";

export class Password {
  private readonly hashedValue: string;

  private constructor(hashedValue: string) {
    if (hashedValue.length < 60) {
      throw new InvalidPasswordError("Password must be hashed");
    }
    this.hashedValue = hashedValue;
  }

  static async fromPlainText(plainPassword: string): Promise<Password> {
    this.validateStrength(plainPassword);
    const hashedValue = await bcrypt.hash(plainPassword, 10);
    return new Password(hashedValue);
  }

  static fromHash(hash: string): Password {
    return new Password(hash);
  }

  async matches(plainPassword: string): Promise<boolean> {
    return bcrypt.compare(plainPassword, this.hashedValue);
  }

  getHashedValue(): string {
    return this.hashedValue;
  }

  private static validateStrength(password: string): void {
    const errors: string[] = [];

    if (password.length < 8) {
      errors.push("At least 8 characters");
    }
    if (!/[A-Z]/.test(password)) {
      errors.push("Uppercase letter required");
    }
    if (!/[a-z]/.test(password)) {
      errors.push("Lowercase letter required");
    }
    if (!/[0-9]/.test(password)) {
      errors.push("Number required");
    }

    if (errors.length > 0) {
      throw new InvalidPasswordError(`Password must contain: ${errors.join(", ")}`);
    }
  }
}
```

#### domain/entities/User.ts

```typescript
import { v4 as uuid } from "uuid";
import { Email } from "../value-objects/Email";
import { Password } from "../value-objects/Password";
import { UserAlreadyExistsError, UserNotFoundError } from "../errors/DomainError";

export class User {
  private readonly id: string;
  private email: Email;
  private password: Password;
  private name: string;
  private readonly createdAt: Date;
  private updatedAt: Date;
  private isActive: boolean;

  private constructor(
    id: string,
    email: Email,
    password: Password,
    name: string,
    createdAt: Date,
    updatedAt: Date,
    isActive: boolean
  ) {
    this.id = id;
    this.email = email;
    this.password = password;
    this.name = name;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
    this.isActive = isActive;
  }

  static async create(
    email: Email,
    plainPassword: string,
    name: string
  ): Promise<User> {
    if (name.length < 2 || name.length > 100) {
      throw new Error("Name must be 2-100 characters");
    }

    const password = await Password.fromPlainText(plainPassword);
    return new User(uuid(), email, password, name, new Date(), new Date(), true);
  }

  static reconstruct(
    id: string,
    email: Email,
    hashedPassword: string,
    name: string,
    createdAt: Date,
    updatedAt: Date,
    isActive: boolean
  ): User {
    const password = Password.fromHash(hashedPassword);
    return new User(id, email, password, name, createdAt, updatedAt, isActive);
  }

  async isPasswordMatches(plainPassword: string): Promise<boolean> {
    return this.password.matches(plainPassword);
  }

  getId(): string {
    return this.id;
  }

  getEmail(): Email {
    return this.email;
  }

  getName(): string {
    return this.name;
  }

  getCreatedAt(): Date {
    return this.createdAt;
  }

  getUpdatedAt(): Date {
    return this.updatedAt;
  }

  isUserActive(): boolean {
    return this.isActive;
  }

  getHashedPassword(): string {
    return this.password.getHashedValue();
  }
}
```

#### domain/interfaces/IUserRepository.ts

```typescript
import { User } from "../entities/User";
import { Email } from "../value-objects/Email";

export interface IUserRepository {
  save(user: User): Promise<void>;
  findById(id: string): Promise<User | null>;
  findByEmail(email: Email): Promise<User | null>;
}
```

---

### 🔄 02: Application 層の実装

#### application/errors/ApplicationError.ts

```typescript
export abstract class ApplicationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class UserAlreadyExistsApplicationError extends ApplicationError {}
export class UserNotFoundApplicationError extends ApplicationError {}
export class InvalidCredentialsError extends ApplicationError {}
```

#### application/dtos/RegisterUserRequest.ts

```typescript
export class RegisterUserRequest {
  constructor(
    readonly email: string,
    readonly password: string,
    readonly name: string
  ) {}
}

export class RegisterUserResponse {
  constructor(readonly userId: string) {}
}
```

#### application/dtos/LoginUserRequest.ts

```typescript
export class LoginUserRequest {
  constructor(readonly email: string, readonly password: string) {}
}

export class LoginUserResponse {
  constructor(readonly userId: string, readonly token: string) {}
}
```

#### application/interfaces/

```typescript
// application/interfaces/IEmailSendingService.ts
export interface IEmailSendingService {
  send(to: string, subject: string, body: string): Promise<void>;
}

// application/interfaces/IPasswordHasher.ts
export interface IPasswordHasher {
  hash(plainPassword: string): Promise<string>;
  compare(plainPassword: string, hash: string): Promise<boolean>;
}

// application/interfaces/ITokenGenerator.ts
export interface ITokenGenerator {
  generate(userId: string): Promise<string>;
  verify(token: string): Promise<string>;
}
```

#### application/usecases/RegisterUserUseCase.ts

```typescript
import { IUserRepository } from "../../domain/interfaces/IUserRepository";
import { IEmailSendingService } from "../interfaces/IEmailSendingService";
import { Email } from "../../domain/value-objects/Email";
import { User } from "../../domain/entities/User";
import {
  UserAlreadyExistsError,
  InvalidEmailError,
} from "../../domain/errors/DomainError";
import {
  RegisterUserRequest,
  RegisterUserResponse
} from "../dtos/RegisterUserRequest";

export class RegisterUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private emailSendingService: IEmailSendingService
  ) {}

  async execute(request: RegisterUserRequest): Promise<RegisterUserResponse> {
    try {
      // 1. Email 値オブジェクト生成（バリデーション）
      const email = new Email(request.email);

      // 2. 既存ユーザー確認
      const existingUser = await this.userRepository.findByEmail(email);
      if (existingUser) {
        throw new UserAlreadyExistsError(
          `Email ${request.email} is already registered`
        );
      }

      // 3. User エンティティ生成
      const user = await User.create(email, request.password, request.name);

      // 4. リポジトリで保存
      await this.userRepository.save(user);

      // 5. メール送信（非同期で、失敗してもユースケースは成功）
      this.emailSendingService
        .send(
          request.email,
          "Welcome to User Management System",
          `Hello ${request.name}!\n\nThank you for signing up.`
        )
        .catch((err) => {
          console.warn(`Failed to send welcome email: ${err.message}`);
        });

      // 6. レスポンス
      return new RegisterUserResponse(user.getId());
    } catch (error) {
      throw error;
    }
  }
}
```

#### application/usecases/LoginUserUseCase.ts

```typescript
import { IUserRepository } from "../../domain/interfaces/IUserRepository";
import { ITokenGenerator } from "../interfaces/ITokenGenerator";
import { Email } from "../../domain/value-objects/Email";
import { InvalidCredentialsError } from "../errors/ApplicationError";
import {
  LoginUserRequest,
  LoginUserResponse
} from "../dtos/LoginUserRequest";

export class LoginUserUseCase {
  constructor(
    private userRepository: IUserRepository,
    private tokenGenerator: ITokenGenerator
  ) {}

  async execute(request: LoginUserRequest): Promise<LoginUserResponse> {
    // 1. メールでユーザー検索
    const email = new Email(request.email);
    const user = await this.userRepository.findByEmail(email);

    if (!user) {
      throw new InvalidCredentialsError("Invalid email or password");
    }

    // 2. パスワード検証
    const passwordMatches = await user.isPasswordMatches(request.password);
    if (!passwordMatches) {
      throw new InvalidCredentialsError("Invalid email or password");
    }

    // 3. アカウント状態確認
    if (!user.isUserActive()) {
      throw new InvalidCredentialsError("Account is deactivated");
    }

    // 4. トークン生成
    const token = await this.tokenGenerator.generate(user.getId());

    // 5. レスポンス
    return new LoginUserResponse(user.getId(), token);
  }
}
```

---

### 🌐 03: Presentation 層の実装

#### presentation/controllers/UserController.ts

```typescript
import { Request, Response } from "express";
import { RegisterUserUseCase } from "../../application/usecases/RegisterUserUseCase";
import { LoginUserUseCase } from "../../application/usecases/LoginUserUseCase";
import { RegisterUserRequest } from "../../application/dtos/RegisterUserRequest";
import { LoginUserRequest } from "../../application/dtos/LoginUserRequest";

export class UserController {
  constructor(
    private registerUserUseCase: RegisterUserUseCase,
    private loginUserUseCase: LoginUserUseCase
  ) {}

  async register(req: Request, res: Response): Promise<void> {
    try {
      const request = new RegisterUserRequest(
        req.body.email,
        req.body.password,
        req.body.name
      );

      const response = await this.registerUserUseCase.execute(request);

      res.status(201).json({
        message: "User registered successfully",
        userId: response.userId
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  async login(req: Request, res: Response): Promise<void> {
    try {
      const request = new LoginUserRequest(
        req.body.email,
        req.body.password
      );

      const response = await this.loginUserUseCase.execute(request);

      res.status(200).json({
        message: "Login successful",
        userId: response.userId,
        token: response.token
      });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  private handleError(error: any, res: Response): void {
    if (error.name === "InvalidEmailError") {
      return res.status(400).json({ error: error.message });
    }
    if (error.name === "UserAlreadyExistsError") {
      return res.status(409).json({ error: error.message });
    }
    if (error.name === "InvalidCredentialsError") {
      return res.status(401).json({ error: error.message });
    }

    console.error("Unexpected error:", error);
    res.status(500).json({ error: "Internal server error" });
  }
}
```

#### presentation/routes/userRoutes.ts

```typescript
import { Express, Router } from "express";
import { UserController } from "../controllers/UserController";

export function setupUserRoutes(app: Express, userController: UserController): void {
  const router = Router();

  router.post("/register", (req, res) => userController.register(req, res));
  router.post("/login", (req, res) => userController.login(req, res));

  app.use("/users", router);
}
```

---

### 💾 04: Infrastructure 層の実装

#### infrastructure/database/MySQLConnection.ts

```typescript
import * as mysql from "mysql2/promise";

export interface Database {
  query(sql: string, params?: any[]): Promise<any[]>;
  queryOne(sql: string, params?: any[]): Promise<any | null>;
  execute(sql: string, params?: any[]): Promise<void>;
  close(): Promise<void>;
}

export class MySQLConnection implements Database {
  private connection: mysql.Connection | null = null;

  async connect(config: mysql.ConnectionOptions): Promise<void> {
    this.connection = await mysql.createConnection(config);
    console.log("Database connected");
  }

  async query(sql: string, params: any[] = []): Promise<any[]> {
    if (!this.connection) throw new Error("Database not connected");
    const [rows] = await this.connection.execute(sql, params);
    return rows as any[];
  }

  async queryOne(sql: string, params: any[] = []): Promise<any | null> {
    const results = await this.query(sql, params);
    return results[0] || null;
  }

  async execute(sql: string, params: any[] = []): Promise<void> {
    if (!this.connection) throw new Error("Database not connected");
    await this.connection.execute(sql, params);
  }

  async close(): Promise<void> {
    if (this.connection) {
      await this.connection.end();
      this.connection = null;
    }
  }
}
```

#### infrastructure/repositories/UserRepository.ts

```typescript
import { IUserRepository } from "../../domain/interfaces/IUserRepository";
import { User } from "../../domain/entities/User";
import { Email } from "../../domain/value-objects/Email";
import { Database } from "../database/MySQLConnection";

export class UserRepository implements IUserRepository {
  constructor(private database: Database) {}

  async save(user: User): Promise<void> {
    await this.database.execute(
      `INSERT INTO users (id, email, password_hash, name, created_at, updated_at, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
       email = VALUES(email), password_hash = VALUES(password_hash), name = VALUES(name), updated_at = VALUES(updated_at)`,
      [
        user.getId(),
        user.getEmail().getValue(),
        user.getHashedPassword(),
        user.getName(),
        user.getCreatedAt(),
        user.getUpdatedAt(),
        user.isUserActive() ? 1 : 0
      ]
    );
  }

  async findById(id: string): Promise<User | null> {
    const row = await this.database.queryOne(
      "SELECT * FROM users WHERE id = ?",
      [id]
    );
    if (!row) return null;
    return this.mapRowToUser(row);
  }

  async findByEmail(email: Email): Promise<User | null> {
    const row = await this.database.queryOne(
      "SELECT * FROM users WHERE email = ?",
      [email.getValue()]
    );
    if (!row) return null;
    return this.mapRowToUser(row);
  }

  private mapRowToUser(row: any): User {
    return User.reconstruct(
      row.id,
      new Email(row.email),
      row.password_hash,
      row.name,
      new Date(row.created_at),
      new Date(row.updated_at),
      row.is_active === 1
    );
  }
}
```

#### infrastructure/services/BcryptHasher.ts

```typescript
import * as bcrypt from "bcrypt";
import { IPasswordHasher } from "../../application/interfaces/IPasswordHasher";

export class BcryptHasher implements IPasswordHasher {
  async hash(plainPassword: string): Promise<string> {
    return bcrypt.hash(plainPassword, 10);
  }

  async compare(plainPassword: string, hash: string): Promise<boolean> {
    return bcrypt.compare(plainPassword, hash);
  }
}
```

#### infrastructure/services/EmailAdapter.ts

```typescript
import { IEmailSendingService } from "../../application/interfaces/IEmailSendingService";

export class EmailAdapter implements IEmailSendingService {
  async send(to: string, subject: string, body: string): Promise<void> {
    // 実装例: console に出力（本番は SendGrid / AWS SES 等）
    console.log(`Email sent:`);
    console.log(`  To: ${to}`);
    console.log(`  Subject: ${subject}`);
    console.log(`  Body: ${body}`);

    // await sendGridClient.send({ to, subject, html: body });
  }
}
```

#### infrastructure/services/JwtTokenGenerator.ts

```typescript
import * as jwt from "jsonwebtoken";
import { ITokenGenerator } from "../../application/interfaces/ITokenGenerator";

export class JwtTokenGenerator implements ITokenGenerator {
  constructor(private secret: string) {}

  async generate(userId: string): Promise<string> {
    return jwt.sign({ userId }, this.secret, { expiresIn: "24h" });
  }

  async verify(token: string): Promise<string> {
    const decoded = jwt.verify(token, this.secret) as { userId: string };
    return decoded.userId;
  }
}
```

---

### ⚙️ 05: Config 層（DI 設定）

#### config/Container.ts

```typescript
import { RegisterUserUseCase } from "../application/usecases/RegisterUserUseCase";
import { LoginUserUseCase } from "../application/usecases/LoginUserUseCase";
import { UserRepository } from "../infrastructure/repositories/UserRepository";
import { UserController } from "../presentation/controllers/UserController";
import { Database } from "../infrastructure/database/MySQLConnection";
import { IUserRepository } from "../domain/interfaces/IUserRepository";
import { IEmailSendingService } from "../application/interfaces/IEmailSendingService";
import { ITokenGenerator } from "../application/interfaces/ITokenGenerator";
import { EmailAdapter } from "../infrastructure/services/EmailAdapter";
import { JwtTokenGenerator } from "../infrastructure/services/JwtTokenGenerator";

export class Container {
  private instances: Map<string, any> = new Map();

  register<T>(key: string, instance: T): void {
    this.instances.set(key, instance);
  }

  get<T>(key: string): T {
    const instance = this.instances.get(key);
    if (!instance) {
      throw new Error(`Dependency not found: ${key}`);
    }
    return instance;
  }

  registerRepository(database: Database): void {
    const userRepository: IUserRepository = new UserRepository(database);
    this.register("UserRepository", userRepository);
  }

  registerServices(): void {
    const emailService: IEmailSendingService = new EmailAdapter();
    this.register("EmailSendingService", emailService);

    const tokenGenerator: ITokenGenerator = new JwtTokenGenerator(
      process.env.JWT_SECRET || "secret"
    );
    this.register("TokenGenerator", tokenGenerator);
  }

  registerUseCases(): void {
    const userRepository = this.get<IUserRepository>("UserRepository");
    const emailService = this.get<IEmailSendingService>("EmailSendingService");
    const tokenGenerator = this.get<ITokenGenerator>("TokenGenerator");

    this.register(
      "RegisterUserUseCase",
      new RegisterUserUseCase(userRepository, emailService)
    );

    this.register(
      "LoginUserUseCase",
      new LoginUserUseCase(userRepository, tokenGenerator)
    );
  }

  registerControllers(): void {
    const registerUseCase =
      this.get<RegisterUserUseCase>("RegisterUserUseCase");
    const loginUseCase = this.get<LoginUserUseCase>("LoginUserUseCase");

    this.register(
      "UserController",
      new UserController(registerUseCase, loginUseCase)
    );
  }
}
```

---

### 🚀 06: アプリケーション起動

#### app.ts

```typescript
import * as express from "express";
import { MySQLConnection } from "./infrastructure/database/MySQLConnection";
import { Container } from "./config/Container";
import { setupUserRoutes } from "./presentation/routes/userRoutes";
import { UserController } from "./presentation/controllers/UserController";

async function bootstrap(): Promise<void> {
  // 1. DB 接続
  const database = new MySQLConnection();
  await database.connect({
    host: process.env.DB_HOST || "localhost",
    user: process.env.DB_USER || "root",
    password: process.env.DB_PASSWORD || "password",
    database: process.env.DB_NAME || "user_management"
  });

  // 2. DI コンテナ設定
  const container = new Container();
  container.register("Database", database);
  container.registerRepository(database);
  container.registerServices();
  container.registerUseCases();
  container.registerControllers();

  // 3. Express アプリケーション
  const app = express();

  // ミドルウェア
  app.use(express.json());

  // ルート設定
  const userController = container.get<UserController>("UserController");
  setupUserRoutes(app, userController);

  // サーバー起動
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

bootstrap().catch((error) => {
  console.error("Failed to start server:", error);
  process.exit(1);
});
```

#### package.json

```json
{
  "name": "clean-architecture-example",
  "version": "1.0.0",
  "description": "User management system with clean architecture",
  "main": "dist/app.js",
  "scripts": {
    "start": "node dist/app.js",
    "dev": "ts-node-dev --respawn src/app.ts",
    "build": "tsc",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.0",
    "bcrypt": "^5.1.0",
    "jsonwebtoken": "^9.0.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0",
    "@types/express": "^4.17.17",
    "@types/bcrypt": "^5.0.0",
    "@types/jsonwebtoken": "^9.0.2",
    "ts-node-dev": "^2.0.0",
    "jest": "^29.5.0",
    "@types/jest": "^29.5.0",
    "ts-jest": "^29.1.0"
  }
}
```

#### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "tests"]
}
```

---

### 🧪 使用例

#### ユーザー登録

```bash
curl -X POST http://localhost:3000/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "MyPassword123",
    "name": "John Doe"
  }'

# レスポンス
{
  "message": "User registered successfully",
  "userId": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### ログイン

```bash
curl -X POST http://localhost:3000/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "MyPassword123"
  }'

# レスポンス
{
  "message": "Login successful",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

**次: [テスト戦略 →](#section-05-implementation-guide-05-testing-strategy)**

## 05: テスト戦略 {#section-05-implementation-guide-05-testing-strategy}


クリーンアーキテクチャで各層を効率的かつ品質高く テストする方法を学びます。

---

### 🎯 テスト戦略の方針

```
Domain（ビジネスロジック）
  └─ ユニットテスト [最重要]
  
Application（ユースケース）
  └─ ユニット + 統合テスト
  
Presentation & Infrastructure
  └─ 統合テスト + モック
```

---

### 🧪 01: Domain 層テスト（ユニットテスト）

#### Domain テストの特徴

- **外部依存なし** - DB、API 呼び出しなし
- **最も高速** - 数ミリ秒で実行
- **本数が多い** - ビジネスロジックをすべてカバー

#### Email 値オブジェクトテスト

```typescript
// tests/unit/domain/value-objects/Email.test.ts
import { Email } from "../../../../src/domain/value-objects/Email";
import { InvalidEmailError } from "../../../../src/domain/errors/DomainError";

describe("Email Value Object", () => {
  describe("constructor", () => {
    it("should create valid email", () => {
      const email = new Email("user@example.com");
      expect(email.getValue()).toBe("user@example.com");
    });

    it("should lowercase email", () => {
      const email = new Email("User@Example.Com");
      expect(email.getValue()).toBe("user@example.com");
    });

    it("should throw error for invalid format", () => {
      expect(() => new Email("invalid-email")).toThrow(InvalidEmailError);
      expect(() => new Email("@example.com")).toThrow(InvalidEmailError);
      expect(() => new Email("user@")).toThrow(InvalidEmailError);
    });
  });

  describe("equals", () => {
    it("should return true for same value", () => {
      const email1 = new Email("user@example.com");
      const email2 = new Email("user@example.com");
      expect(email1.equals(email2)).toBe(true);
    });

    it("should return false for different value", () => {
      const email1 = new Email("user1@example.com");
      const email2 = new Email("user2@example.com");
      expect(email1.equals(email2)).toBe(false);
    });

    it("should be case-insensitive", () => {
      const email1 = new Email("User@Example.Com");
      const email2 = new Email("user@example.com");
      expect(email1.equals(email2)).toBe(true);
    });
  });

  describe("getDomain", () => {
    it("should extract domain", () => {
      const email = new Email("user@example.com");
      expect(email.getDomain()).toBe("example.com");
    });
  });
});
```

#### Password 値オブジェクトテスト

```typescript
// tests/unit/domain/value-objects/Password.test.ts
import { Password } from "../../../../src/domain/value-objects/Password";
import { InvalidPasswordError } from "../../../../src/domain/errors/DomainError";

describe("Password Value Object", () => {
  describe("fromPlainText", () => {
    it("should create password from valid plain text", async () => {
      const password = await Password.fromPlainText("ValidPassword123");
      expect(password).toBeDefined();
      expect(password.getHashedValue().length).toBeGreaterThan(50);
    });

    it("should hash password using bcrypt", async () => {
      const password1 = await Password.fromPlainText("TestPassword123");
      const password2 = await Password.fromPlainText("TestPassword123");

      // ハッシュは毎回異なる（salt が異なる）
      expect(password1.getHashedValue()).not.toBe(
        password2.getHashedValue()
      );
    });

    it("should throw error for weak password", async () => {
      // 8文字未満
      await expect(
        Password.fromPlainText("weak")
      ).rejects.toThrow(InvalidPasswordError);

      // 大文字なし
      await expect(
        Password.fromPlainText("weakpassword123")
      ).rejects.toThrow(InvalidPasswordError);

      // 小文字なし
      await expect(
        Password.fromPlainText("WEAKPASSWORD123")
      ).rejects.toThrow(InvalidPasswordError);

      // 数字なし
      await expect(
        Password.fromPlainText("WeakPassword")
      ).rejects.toThrow(InvalidPasswordError);
    });
  });

  describe("matches", () => {
    it("should return true for correct password", async () => {
      const password = await Password.fromPlainText("CorrectPassword123");
      expect(await password.matches("CorrectPassword123")).toBe(true);
    });

    it("should return false for incorrect password", async () => {
      const password = await Password.fromPlainText("CorrectPassword123");
      expect(await password.matches("IncorrectPassword123")).toBe(false);
    });
  });

  describe("fromHash", () => {
    it("should create password from hash", async () => {
      const originalPassword = await Password.fromPlainText(
        "TestPassword123"
      );
      const hash = originalPassword.getHashedValue();

      const reconstructed = Password.fromHash(hash);
      expect(await reconstructed.matches("TestPassword123")).toBe(true);
    });

    it("should throw error for invalid hash", () => {
      expect(() => Password.fromHash("invalid")).toThrow(InvalidPasswordError);
    });
  });
});
```

#### User エンティティテスト

```typescript
// tests/unit/domain/entities/User.test.ts
import { User } from "../../../../src/domain/entities/User";
import { Email } from "../../../../src/domain/value-objects/Email";
import { Password } from "../../../../src/domain/value-objects/Password";

describe("User Entity", () => {
  describe("create", () => {
    it("should create user with valid data", async () => {
      const email = new Email("john@example.com");
      const user = await User.create(email, "ValidPassword123", "John Doe");

      expect(user.getId()).toBeDefined();
      expect(user.getEmail().getValue()).toBe("john@example.com");
      expect(user.getName()).toBe("John Doe");
      expect(user.isUserActive()).toBe(true);
    });

    it("should throw error for invalid name length", async () => {
      const email = new Email("john@example.com");

      // 1文字
      await expect(
        User.create(email, "ValidPassword123", "J")
      ).rejects.toThrow();

      // 101文字
      const longName = "A".repeat(101);
      await expect(
        User.create(email, "ValidPassword123", longName)
      ).rejects.toThrow();
    });

    it("should generate unique IDs", async () => {
      const email1 = new Email("user1@example.com");
      const email2 = new Email("user2@example.com");

      const user1 = await User.create(email1, "ValidPassword123", "User One");
      const user2 = await User.create(email2, "ValidPassword123", "User Two");

      expect(user1.getId()).not.toBe(user2.getId());
    });
  });

  describe("isPasswordMatches", () => {
    it("should return true for correct password", async () => {
      const email = new Email("john@example.com");
      const user = await User.create(
        email,
        "CorrectPassword123",
        "John Doe"
      );

      expect(await user.isPasswordMatches("CorrectPassword123")).toBe(true);
    });

    it("should return false for incorrect password", async () => {
      const email = new Email("john@example.com");
      const user = await User.create(
        email,
        "CorrectPassword123",
        "John Doe"
      );

      expect(await user.isPasswordMatches("IncorrectPassword123")).toBe(false);
    });
  });

  describe("reconstruct", () => {
    it("should reconstruct user from database data", async () => {
      const originalUser = await User.create(
        new Email("john@example.com"),
        "ValidPassword123",
        "John Doe"
      );

      const reconstructed = User.reconstruct(
        originalUser.getId(),
        new Email("john@example.com"),
        originalUser.getHashedPassword(),
        "John Doe",
        originalUser.getCreatedAt(),
        originalUser.getUpdatedAt(),
        true
      );

      expect(reconstructed.getId()).toBe(originalUser.getId());
      expect(await reconstructed.isPasswordMatches("ValidPassword123")).toBe(true);
    });
  });
});
```

---

### 📋 02: Application 層テスト

#### Application テストの特徴

- **モックが必要** - Repository、ExternalService をモック
- **ユースケース全体をテスト** - エンドツーエンドロジック
- **テストダブル** - Mock / Stub

#### RegisterUserUseCase テスト

```typescript
// tests/unit/application/usecases/RegisterUserUseCase.test.ts
import { RegisterUserUseCase } from "../../../../src/application/usecases/RegisterUserUseCase";
import { RegisterUserRequest } from "../../../../src/application/dtos/RegisterUserRequest";
import { IUserRepository } from "../../../../src/domain/interfaces/IUserRepository";
import { IEmailSendingService } from "../../../../src/application/interfaces/IEmailSendingService";
import { User } from "../../../../src/domain/entities/User";
import { Email } from "../../../../src/domain/value-objects/Email";
import { UserAlreadyExistsError } from "../../../../src/domain/errors/DomainError";

// モック実装
class MockUserRepository implements IUserRepository {
  private users: Map<string, User> = new Map();
  findByEmailWasCalled = false;

  async save(user: User): Promise<void> {
    this.users.set(user.getId(), user);
  }

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) || null;
  }

  async findByEmail(email: Email): Promise<User | null> {
    this.findByEmailWasCalled = true;
    for (const user of this.users.values()) {
      if (user.getEmail().equals(email)) {
        return user;
      }
    }
    return null;
  }
}

class MockEmailSendingService implements IEmailSendingService {
  sentEmails: Array<{ to: string; subject: string; body: string }> = [];

  async send(to: string, subject: string, body: string): Promise<void> {
    this.sentEmails.push({ to, subject, body });
  }
}

describe("RegisterUserUseCase", () => {
  let useCase: RegisterUserUseCase;
  let userRepository: MockUserRepository;
  let emailSendingService: MockEmailSendingService;

  beforeEach(() => {
    userRepository = new MockUserRepository();
    emailSendingService = new MockEmailSendingService();
    useCase = new RegisterUserUseCase(userRepository, emailSendingService);
  });

  it("should register new user successfully", async () => {
    const request = new RegisterUserRequest(
      "john@example.com",
      "ValidPassword123",
      "John Doe"
    );

    const response = await useCase.execute(request);

    expect(response.userId).toBeDefined();
    expect(await userRepository.findById(response.userId)).toBeDefined();
  });

  it("should throw error if email already exists", async () => {
    // 1回目：ユーザー登録
    const request1 = new RegisterUserRequest(
      "john@example.com",
      "ValidPassword123",
      "John Doe"
    );
    await useCase.execute(request1);

    // 2回目：同じメールで登録
    const request2 = new RegisterUserRequest(
      "john@example.com",
      "AnotherPassword123",
      "Another User"
    );

    await expect(useCase.execute(request2)).rejects.toThrow(
      UserAlreadyExistsError
    );
  });

  it("should send welcome email after registration", async () => {
    const request = new RegisterUserRequest(
      "john@example.com",
      "ValidPassword123",
      "John Doe"
    );

    await useCase.execute(request);

    expect(emailSendingService.sentEmails.length).toBe(1);
    expect(emailSendingService.sentEmails[0].to).toBe("john@example.com");
    expect(emailSendingService.sentEmails[0].subject).toContain("Welcome");
  });

  it("should validate email format", async () => {
    const request = new RegisterUserRequest(
      "invalid-email",
      "ValidPassword123",
      "John Doe"
    );

    await expect(useCase.execute(request)).rejects.toThrow();
  });

  it("should validate password strength", async () => {
    const request = new RegisterUserRequest(
      "john@example.com",
      "weak",  // 弱いパスワード
      "John Doe"
    );

    await expect(useCase.execute(request)).rejects.toThrow();
  });
});
```

#### LoginUserUseCase テスト

```typescript
// tests/unit/application/usecases/LoginUserUseCase.test.ts
import { LoginUserUseCase } from "../../../../src/application/usecases/LoginUserUseCase";
import { LoginUserRequest } from "../../../../src/application/dtos/LoginUserRequest";
import { IUserRepository } from "../../../../src/domain/interfaces/IUserRepository";
import { ITokenGenerator } from "../../../../src/application/interfaces/ITokenGenerator";
import { User } from "../../../../src/domain/entities/User";
import { Email } from "../../../../src/domain/value-objects/Email";
import { InvalidCredentialsError } from "../../../../src/application/errors/ApplicationError";

class MockTokenGenerator implements ITokenGenerator {
  async generate(userId: string): Promise<string> {
    return `token_${userId}`;
  }

  async verify(token: string): Promise<string> {
    return token.replace("token_", "");
  }
}

describe("LoginUserUseCase", () => {
  let useCase: LoginUserUseCase;
  let userRepository: MockUserRepository;
  let tokenGenerator: MockTokenGenerator;

  beforeEach(async () => {
    userRepository = new MockUserRepository();
    tokenGenerator = new MockTokenGenerator();
    useCase = new LoginUserUseCase(userRepository, tokenGenerator);

    // テスト用ユーザー作成
    const user = await User.create(
      new Email("john@example.com"),
      "ValidPassword123",
      "John Doe"
    );
    await userRepository.save(user);
  });

  it("should login successfully with correct credentials", async () => {
    const request = new LoginUserRequest(
      "john@example.com",
      "ValidPassword123"
    );

    const response = await useCase.execute(request);

    expect(response.userId).toBeDefined();
    expect(response.token).toBeDefined();
    expect(response.token).toContain("token_");
  });

  it("should throw error for non-existent email", async () => {
    const request = new LoginUserRequest(
      "nonexistent@example.com",
      "ValidPassword123"
    );

    await expect(useCase.execute(request)).rejects.toThrow(
      InvalidCredentialsError
    );
  });

  it("should throw error for incorrect password", async () => {
    const request = new LoginUserRequest(
      "john@example.com",
      "WrongPassword123"
    );

    await expect(useCase.execute(request)).rejects.toThrow(
      InvalidCredentialsError
    );
  });
});
```

---

### 🌐 03: Integration テスト

#### 統合テストの特徴

- **複数層をまとめてテスト** - UseCase + Repository
- **実際のDB（テストDB）を使用** - 実装を含めて検証
- **遅い可能性** - DB アクセスがある
- **本数は少なめ** - 既にユニットテストで細部は確認済み

```typescript
// tests/integration/RegisterUserUseCase.integration.test.ts
import { RegisterUserUseCase } from "../../src/application/usecases/RegisterUserUseCase";
import { UserRepository } from "../../src/infrastructure/repositories/UserRepository";
import { MySQLConnection, Database } from "../../src/infrastructure/database/MySQLConnection";
import { EmailAdapter } from "../../src/infrastructure/services/EmailAdapter";
import { RegisterUserRequest } from "../../src/application/dtos/RegisterUserRequest";

describe("RegisterUserUseCase Integration Test", () => {
  let useCase: RegisterUserUseCase;
  let database: Database;

  beforeAll(async () => {
    // テスト用 DB に接続
    const connection = new MySQLConnection();
    await connection.connect({
      host: "localhost",
      user: "test_user",
      password: "test_password",
      database: "test_user_management"
    });
    database = connection;

    // テーブル作成
    await database.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(36) PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        name VARCHAR(100) NOT NULL,
        created_at DATETIME NOT NULL,
        updated_at DATETIME NOT NULL,
        is_active TINYINT NOT NULL
      )
    `);
  });

  beforeEach(async () => {
    // 各テスト前にテーブルをクリア
    await database.execute("TRUNCATE TABLE users");

    const userRepository = new UserRepository(database);
    const emailService = new EmailAdapter();

    useCase = new RegisterUserUseCase(userRepository, emailService);
  });

  afterAll(async () => {
    await database.execute("DROP TABLE users");
    await database.close();
  });

  it("should persist user to database and retrieve it", async () => {
    const request = new RegisterUserRequest(
      "integration@example.com",
      "ValidPassword123",
      "Integration User"
    );

    const response = await useCase.execute(request);

    // DB から直接確認
    const user = await database.queryOne(
      "SELECT * FROM users WHERE id = ?",
      [response.userId]
    );

    expect(user).toBeDefined();
    expect(user.email).toBe("integration@example.com");
    expect(user.name).toBe("Integration User");
    expect(user.password_hash).toBeDefined();
  });

  it("should prevent duplicate email registration", async () => {
    const request1 = new RegisterUserRequest(
      "duplicate@example.com",
      "ValidPassword123",
      "User One"
    );
    await useCase.execute(request1);

    const request2 = new RegisterUserRequest(
      "duplicate@example.com",
      "AnotherPassword123",
      "User Two"
    );

    await expect(useCase.execute(request2)).rejects.toThrow();

    // DB には1ユーザーだけ
    const users = await database.query("SELECT * FROM users WHERE email = ?", [
      "duplicate@example.com"
    ]);
    expect(users.length).toBe(1);
  });
});
```

---

### 🧪 04: Controller（Presentation）テスト

```typescript
// tests/unit/presentation/controllers/UserController.test.ts
import { UserController } from "../../../../src/presentation/controllers/UserController";
import { RegisterUserUseCase } from "../../../../src/application/usecases/RegisterUserUseCase";
import { LoginUserUseCase } from "../../../../src/application/usecases/LoginUserUseCase";
import { Request, Response } from "express";
import { InvalidEmailError } from "../../../../src/domain/errors/DomainError";

describe("UserController", () => {
  let controller: UserController;
  let registerUseCase: RegisterUserUseCase;
  let loginUseCase: LoginUserUseCase;
  let req: Partial<Request>;
  let res: Partial<Response>;

  beforeEach(() => {
    // モック UseCase
    registerUseCase = {
      execute: jest.fn()
    } as any;

    loginUseCase = {
      execute: jest.fn()
    } as any;

    controller = new UserController(registerUseCase, loginUseCase);

    // モック Request / Response
    req = { body: {}, params: {} };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
  });

  describe("register", () => {
    it("should return 201 on successful registration", async () => {
      req.body = {
        email: "john@example.com",
        password: "ValidPassword123",
        name: "John Doe"
      };

      jest.spyOn(registerUseCase, "execute").mockResolvedValue({
        userId: "user-123"
      } as any);

      await controller.register(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          message: "User registered successfully",
          userId: "user-123"
        })
      );
    });

    it("should return 400 on invalid email", async () => {
      req.body = {
        email: "invalid-email",
        password: "ValidPassword123",
        name: "John Doe"
      };

      jest
        .spyOn(registerUseCase, "execute")
        .mockRejectedValue(new InvalidEmailError("Invalid email"));

      await controller.register(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ error: expect.any(String) })
      );
    });
  });

  describe("login", () => {
    it("should return 200 on successful login", async () => {
      req.body = {
        email: "john@example.com",
        password: "ValidPassword123"
      };

      jest.spyOn(loginUseCase, "execute").mockResolvedValue({
        userId: "user-123",
        token: "jwt-token"
      } as any);

      await controller.login(req as Request, res as Response);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          message: "Login successful",
          userId: "user-123",
          token: "jwt-token"
        })
      );
    });
  });
});
```

---

### ✅ テストチェックリスト

#### Domain テスト

```
□ Email 値オブジェクト - 有効/無効フォーマット
□ Password 値オブジェクト - 強度チェック、マッチング
□ User エンティティ - 生成、ビジネスロジック
□ エラークラス - 適切にスロー
```

#### Application テスト

```
□ RegisterUserUseCase - 成功、エラーケース
□ LoginUserUseCase - 認証ロジック
□ UseCase 間の連携
□ モック Repository/Service
```

#### Integration テスト

```
□ DB への永続化
□ 重複登録の防止
□ 複数層の連携
□ 実際のリポジトリ実装
```

#### Controller テスト

```
□ HTTP レスポンス形式
□ ステータスコード
□ エラーハンドリング
```

---

### 🚀 Jest 設定（jest.config.js）

```typescript
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/tests"],
  testMatch: ["**/__tests__/**/*.ts", "**/?(*.)+(spec|test).ts"],
  moduleFileExtensions: ["ts", "js", "json"],
  collectCoverageFrom: [
    "src/**/*.ts",
    "!src/**/*.d.ts",
    "!src/app.ts"
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70
    }
  }
};
```

---

### 🎯 テスト実行

```bash
# すべてテスト実行
npm test

# 特定ファイルテスト
npm test -- Email.test.ts

# ウォッチ模式
npm test -- --watch

# カバレッジレポート
npm test -- --coverage
```

---

**完了！クリーンアーキテクチャ完全実装ガイド終了**

---

### 📚 振り返りチェックリスト

このセクション（05-実装ガイド）を通じて：

```
□ フォルダ構造が設計できる
□ エンティティ・値オブジェクトを実装できる
□ ユースケースを実装できる
□ 4層すべてを実装できる
□ 依存性注入（DI）ができる
□ 各層を効率的にテストできる
□ 動くシステムを構築できる
```

---

### 🔗 関連セクション

**前:** [デザインパターン](#chapter-04-design-patterns)
- パターンの理論を学んだ

**ここ:** **実装ガイド**
- パターンを実装に適用 ✅

**次:** [ベストプラクティス](#chapter-06-best-practices)
- 実装品質をさらに上げる知見

**後:** [コモンピットフォール](#chapter-07-common-pitfalls)
- よくある失敗パターン

---

### 💡 さらに学ぶ

**次のステップ:**

1. **セットアップガイド を読む**
   - 実装例コードが網羅的
   - コピーして使える

2. **テストを追加する**
   - ユニットテスト完備
   - テスト駆動開発（TDD）をやってみる

3. **CI/CD パイプラインを構築**
   - GitHub Actions で自動テスト
   - デプロイメント自動化

4. **マイクロサービス化**
   - 各層を独立したサービスに
   - API ゲートウェイ

5. **キャッシング・パフォーマンス最適化**
   - Redis キャッシング
   - クエリ最適化

---

**ご質問は [ベストプラクティス](#chapter-06-best-practices) セクションで！**

# 06: ベストプラクティス - 実装品質の向上 {#chapter-06-best-practices}

## 01: 命名規則 {#section-06-best-practices-01-naming-conventions}


チーム全体で一貫した、読みやすいコードを書くための命名ルール。

---

### 🎯 命名の原則

**良い命名とは：**
- 🔹 意図が明確
- 🔹 スコープで長さが決まる
- 🔹 チーム内で統一
- 🔹 誤解の余地がない

---

### 📐 階層別の命名規則

#### クラス・インターフェース

```typescript
✅ 良い例
├─ UserRepository          // 名詞/責務が明確
├─ CreateUserUseCase       // UseCase サフィックス
├─ User                    // エンティティ
├─ Email                   // 値オブジェクト
├─ UserController          // Controller サフィックス
├─ InvalidEmailError       // Error サフィックス
├─ IUserRepository         // I プレフィックス（Java パターン）
└─ UserRepositoryImpl       // Impl サフィックス（実装）

❌ 悪い例
├─ user                    // 小文字で始まる
├─ UserRepo               // 略称（曖昧）
├─ U                      // 短すぎる（1文字）
├─ Service                // 漠然とした名前
├─ Exception              // 通用的すぎる
├─ Helper                // Helper はアンチパターン
└─ Manager               // Manager は曖昧
```

#### メソッド・関数

```typescript
✅ 良い例
// 取得系
├─ getUser(id)            // 単数取得
├─ getUserList()           // 複数取得
├─ getUsersByEmail()       // 複数取得（フィルター）
├─ findUserById()          // 検索（見つからない可能性）
└─ searchUsers()           // 全文検索

// 判定系
├─ isActive()              // boolean 返却（is/has プレフィックス）
├─ hasPermission()         // boolean
├─ canDelete()             // boolean
└─ shouldRetry()           // boolean

// 操作系
├─ createUser()            // 生成
├─ updateUser()            // 更新
├─ deleteUser()            // 削除
├─ saveUser()              // 永続化
└─ publishEvent()          // 配信

// 変換系
├─ toDTO()                 // to パターン
├─ fromEntity()            // from パターン
├─ convertToJSON()         // convert
└─ mapToServer()           // map

❌ 悪い例
├─ get_user()              // スネークケース（TypeScript では不推奨）
├─ getd()                  // 短すぎる
├─ getUserData()           // Data は冗長
├─ performUserDiscovery()  // obscure（不必要に複雑）
└─ doStuff()               // 何をしているか不明
```

#### 変数・定数

```typescript
✅ 良い例
// ループ変数（短くてOK）
for (const user of users) { }
for (const item of items) { }

// 一般変数
const userName = 'John';
const userEmail = 'john@example.com';
const isActive = true;
const count = 0;

// 定数（UPPER_SNAKE_CASE）
const MAX_RETRY_COUNT = 3;
const DEFAULT_TIMEOUT_MS = 5000;
const API_BASE_URL = 'https://api.example.com';

// Private フィールド
private userId: string;
private emailService: EmailService;
private _internalState: number;  // or 使わない

❌ 悪い例
const u = 'John';           // 1文字
const data = 'John';        // 曖昧
const temp = 'John';        // 一時的⁈
const x = 5;                // 意図が不明確
const user_name = 'John';   // スネークケース（TypeScript では非推奨）
```

---

### 🏗️ クリーンアーキテクチャ特有の命名

#### リポジトリ

```typescript
// インターフェース/抽象型
interface UserRepository {
  save(user: User): Promise<void>;
  findById(id: string): Promise<User | null>;
}

// 実装クラス
class MySQLUserRepository implements UserRepository { }
class MongoDBUserRepository implements UserRepository { }
class InMemoryUserRepository implements UserRepository { }

// 特定 DB を示す場合
class PostgreSQLUserRepository { }
class FirestoreUserRepository { }
```

#### ユースケース

```typescript
// UseCase = 1機能
class RegisterUserUseCase { }
class LoginUserUseCase { }
class UpdateProfileUseCase { }
class GetUserByIdUseCase { }

// Request/Response
class RegisterUserRequest { }
class RegisterUserResponse { }
class LoginUserRequest { }
class LoginUserResponse { }

// 複雑な場合：Input/Output パターン
class SendEmailUseCaseInput { }
class SendEmailUseCaseOutput { }
```

#### ドメイン層

```typescript
// エンティティ
class User { }
class Order { }
class Product { }

// 値オブジェクト
class Email { }
class Money { }
class PhoneNumber { }

// ドメイン例外
class DomainError extends Error { }
class InvalidEmailError extends DomainError { }
class UserAlreadyExistsError extends DomainError { }

// ドメインサービス
class PasswordHashService { }
class UserVerificationService { }
```

#### プレゼンテーション層

```typescript
// コントローラー
class UserController { }
class AuthController { }

// DTO（Data Transfer Object）
class UserDTO { }
class CreateUserDTO { }
class UpdateUserDTO { }

// ミドルウェア
class AuthenticationMiddleware { }
class ErrorHandlerMiddleware { }
class ValidationMiddleware { }

// バリデータ
class EmailValidator { }
class PasswordValidator { }
```

---

### 📋 命名パターン早見表

| パターン | 例 | 用途 |
|--------|-----|------|
| `get{Entity}` | `getUser()` | 単数取得 |
| `get{Entity}s` | `getUsers()` | 複数取得 |
| `find{Entity}` | `findUserById()` | 検索（見つからない可能性） |
| `search{Entity}s` | `searchUsers()` | 全文検索 |
| `create{Entity}` | `createUser()` | 生成 |
| `update{Entity}` | `updateUser()` | 更新 |
| `delete{Entity}` | `deleteUser()` | 削除 |
| `is{Adjective}` | `isActive()` | 状態判定 |
| `has{Property}` | `hasPermission()` | 所有判定 |
| `can{Verb}` | `canDelete()` | 可能性判定 |
| `on{Event}` | `onUserCreated()` | イベントハンドラ |
| `{Entity}UseCase` | `LoginUseCase` | ユースケース |
| `{Entity}Repository` | `UserRepository` | リポジトリI/F |
| `{Entity}DTO` | `UserDTO` | データ転送オブジェクト |

---

### 🎯 チェックリスト

```
✅ クラス・インターフェースはPascalCase
✅ メソッド・変数はcamelCase
✅ 定数はUPPER_SNAKE_CASE
✅ 意図が自明（コメント不要）
✅ スコープに応じた長さ
✅ チーム内で統一
✅ Domain/Use Case/Repository など役割が明確
✅略語を避ける（UserService ✅、UserSvc ❌）
```

---

**次: [エラーハンドリング →](#section-06-best-practices-02-error-handling)**

## 02: エラーハンドリング {#section-06-best-practices-02-error-handling}


層別のエラー処理戦略で、予測可能で回復可能なシステムを構築。

---

### 🎯 エラーハンドリングの原則

```
予測可能：何が起きるか分かる
│
回復可能：対応方法が存在する
│
可視化：ログ・監視に記録
```

---

### 🔴 エラーの分類

```
ドメイン層エラー（ビジネスエラー）
  ├─ 回復可能なエラー
  ├─ ユースケース側で処理
  └─ 例: InvalidEmailError, InsufficientBalanceError

アプリケーション層エラー（ロジックエラー）
  ├─ ユースケース実行の問題
  ├─ トランザクション失敗
  └─ 例: UserAlreadyExistsError, DataConsistencyError

システムエラー（インフラエラー）
  ├─ 回復困難なエラー
  ├─ 外部依存の失敗
  └─ 例: DatabaseConnectionError, ExternalAPIError
```

---

### 📊 階層別のエラーハンドリング

#### ドメイン層：ビジネスエラー例外

```typescript
// domain/errors/DomainError.ts
export abstract class DomainError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
    Object.setPrototypeOf(this, DomainError.prototype);
  }
}

export class InvalidEmailError extends DomainError {}
export class InvalidPasswordError extends DomainError {}
export class UserAlreadyExistsError extends DomainError {}
export class InsufficientBalanceError extends DomainError {}
export class InvalidOrderStatusError extends DomainError {}

// domain/entities/User.ts
export class User {
  constructor(email: Email) {
    // バリデーション時点でエラーをスロー
    if (!email) {
      throw new InvalidEmailError('Email is required');
    }
  }

  transfer(amount: Money): void {
    if (this.balance.isLessThan(amount)) {
      throw new InsufficientBalanceError(
        `Need ${amount.value}, have ${this.balance.value}`
      );
    }
    this.balance = this.balance.subtract(amount);
  }
}
```

#### アプリケーション層：エラー変換＆集約

```typescript
// application/errors/ApplicationError.ts
export abstract class ApplicationError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number
  ) {
    super(message);
    this.name = this.constructor.name;
  }
}

export class UserAlreadyExistsApplicationError extends ApplicationError {
  constructor(email: string) {
    super(
      `User with email ${email} already exists`,
      'USER_ALREADY_EXISTS',
      409  // Conflict
    );
  }
}

// application/usecases/RegisterUserUseCase.ts
export class RegisterUserUseCase {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService
  ) {}

  async execute(request: RegisterUserRequest): Promise<void> {
    try {
      // ドメインエラーはここで発生
      const email = new Email(request.email);
      const user = await User.create(email, request.password, request.name);

      // ビジネスロジック
      const existing = await this.userRepository.findByEmail(email);
      if (existing) {
        throw new UserAlreadyExistsApplicationError(request.email);
      }

      await this.userRepository.save(user);

      // 副作用
      await this.emailService.send(request.email, 'Welcome!');
    } catch (error) {
      // ドメインエラーをアプリケーションエラーに変換
      if (error instanceof InvalidEmailError) {
        throw new InvalidEmailApplicationError(error.message);
      }
      if (error instanceof InvalidPasswordError) {
        throw new InvalidPasswordApplicationError(error.message);
      }
      // その他のエラーはそのままスロー
      throw error;
    }
  }
}
```

#### プレゼンテーション層：HTTP応答

```typescript
// presentation/controllers/UserController.ts
export class UserController {
  constructor(private registerUseCase: RegisterUserUseCase) {}

  async register(req: Request, res: Response): Promise<void> {
    try {
      const request = new RegisterUserRequest(
        req.body.email,
        req.body.password,
        req.body.name
      );

      await this.registerUseCase.execute(request);
      res.status(201).json({ message: 'User registered' });
    } catch (error) {
      this.handleError(error, res);
    }
  }

  private handleError(error: any, res: Response): void {
    // ビジネスエラー → 4xx
    if (error instanceof InvalidEmailError) {
      return res.status(400).json({
        error: error.message,
        code: 'INVALID_EMAIL'
      });
    }

    if (error instanceof UserAlreadyExistsError) {
      return res.status(409).json({
        error: error.message,
        code: 'USER_ALREADY_EXISTS'
      });
    }

    // システムエラー → 5xx
    if (error instanceof DatabaseError) {
      logger.error('Database error', error);
      return res.status(500).json({
        error: 'Internal Server Error'
      });
    }

    if (error instanceof ExternalServiceError) {
      logger.error('External service error', error);
      return res.status(503).json({
        error: 'Service Unavailable'
      });
    }

    // 予期しないエラー
    logger.error('Unexpected error', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
}

// presentation/middlewares/ErrorHandlerMiddleware.ts
export const errorHandler = (
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  // アプリケーション層エラーをHTTPに変換
  const errorStatusMap: Record<string, number> = {
    'InvalidEmailError': 400,
    'InvalidPasswordError': 400,
    'UserAlreadyExistsError': 409,
    'UserNotFoundError': 404,
    'UnauthorizedError': 401,
    'ForbiddenError': 403,
    'DatabaseError': 500,
    'ExternalServiceError': 503,
    'ValidationError': 422
  };

  const statusCode = errorStatusMap[error.name] || 500;

  logger.error(`[${error.name}] ${error.message}`, {
    name: error.name,
    message: error.message,
    path: req.path,
    method: req.method
  });

  res.status(statusCode).json({
    error: error.message,
    code: error.name,
    timestamp: new Date().toISOString()
  });
};
```

---

### 🔄 エラーハンドリングパターン

#### パターン1: Try-Catch で回復

```typescript
async function processUser(userId: string): Promise<void> {
  try {
    const user = await userRepository.findById(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }

    await processUserData(user);
  } catch (error) {
    if (error instanceof UserNotFoundError) {
      // 処理可能 → ログして続行
      logger.warn(`User not found: ${userId}`);
      return;  // 処理を中断
    }

    if (error instanceof ValidationError) {
      // 修正可能 → デフォルト値を使用
      logger.warn(`Invalid data for ${userId}, using default`);
      await processUserData(createDefaultUser());
      return;
    }

    // 処理不可 → スロー
    throw error;
  }
}
```

#### パターン2: Result オブジェクトで結果を返す

```typescript
// Rust/Golang スタイル
export type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

export class UserService {
  async registerUser(email: string, password: string): Promise<Result<string, RegisterError>> {
    try {
      const emailObj = new Email(email);
      const user = await User.create(emailObj, password, 'User');
      await this.userRepository.save(user);
      return { ok: true, value: user.getId() };
    } catch (error) {
      if (error instanceof InvalidEmailError) {
        return {
          ok: false,
          error: { type: 'INVALID_EMAIL', message: error.message }
        };
      }
      if (error instanceof InvalidPasswordError) {
        return {
          ok: false,
          error: { type: 'INVALID_PASSWORD', message: error.message }
        };
      }
      return {
        ok: false,
        error: { type: 'UNKNOWN', message: 'Unexpected error' }
      };
    }
  }
}

// 使用側
const result = await userService.registerUser(email, password);
if (result.ok) {
  console.log(`User registered: ${result.value}`);
} else {
  console.error(`Registration failed: ${result.error.message}`);
}
```

#### パターン3: カスタムエラークラス

```typescript
// より詳細な情報を含める
export class ApiError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly code: string,
    public readonly details?: Record<string, any>
  ) {
    super(message);
    this.name = this.constructor.name;
  }

  toJSON() {
    return {
      error: this.message,
      code: this.code,
      statusCode: this.statusCode,
      details: this.details
    };
  }
}

throw new ApiError(
  'Invalid email format',
  400,
  'INVALID_EMAIL',
  { email: 'invalid-email@' }
);
```

---

### 📋 チェックリスト

```
✅ ドメイン層：DomainError 基底クラスから継承
✅ アプリケーション層：DomainError をキャッチ＆変換
✅ プレゼンテーション層：エラー名 → HTTPステータスコード
✅ 予測可能なHTTPステータスコード
✅ エラーログに十分な情報
✅ 本番環境での詳細情報は隠す
✅ エラーメッセージはユーザーフレンドリー
✅ エラーレスポンスに `code` フィールド
```

---

**次: [ロギング・監視 →](#section-06-best-practices-03-logging-monitoring)**

## 03: ロギング・監視 {#section-06-best-practices-03-logging-monitoring}


本番環境での問題調査・パフォーマンス監視を実現。

---

### 🎯 ロギング戦略

```
構造化ログ：機械可読
│
段階的：レベル別分類
│
文脈：コンテキスト情報含む
```

---

### 📊 ログレベル別使い分け

```typescript
logger.info('User registration request', { email, ip: req.ip });
logger.debug('Creating new user', { email, userId });
logger.warn('Retry attempt 2/3', { endpoint, error });
logger.error('Database query failed', { query, error });
logger.fatal('System shutdown initiated', { reason });
```

| レベル | 出力先 | 用途 |
|-------|-------|------|
| `debug` | ファイル | 開発・トラブルシューティング |
| `info` | ファイル | 正常な処理の進行状況 |
| `warn` | ファイル+Alert | 異常だが処理可能 |
| `error` | ファイル+Alert | エラー発生 |
| `fatal` | ファイル+Alert | システム停止レベル |

---

### 🏗️ 階層別ロギング

#### プレゼンテーション層：リクエスト/レスポンス

```typescript
// presentation/middlewares/LoggingMiddleware.ts
export const loggingMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const startTime = Date.now();
  const { method, path, ip } = req;

  // リクエストログ
  logger.info('Incoming request', {
    method,
    path,
    ip,
    userId: req.user?.id,
    userAgent: req.get('user-agent')
  });

  // レスポンス後
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const { statusCode } = res;

    if (statusCode >= 400) {
      logger.warn('Request failed', {
        method,
        path,
        statusCode,
        duration
      });
    } else {
      logger.debug('Request completed', {
        method,
        path,
        statusCode,
        duration
      });
    }
  });

  next();
};
```

#### アプリケーション層：ユースケース実行

```typescript
// application/usecases/RegisterUserUseCase.ts
export class RegisterUserUseCase {
  async execute(request: RegisterUserRequest): Promise<void> {
    const startTime = Date.now();

    logger.debug('RegisterUserUseCase: starting', {
      email: request.email
    });

    try {
      const email = new Email(request.email);

      // ビジネスロジック
      const existing = await this.userRepository.findByEmail(email);
      if (existing) {
        logger.warn('User already exists', { email: request.email });
        throw new UserAlreadyExistsError();
      }

      const user = await User.create(email, request.password, request.name);
      await this.userRepository.save(user);

      logger.info('User registered successfully', {
        userId: user.getId(),
        email: request.email,
        duration: Date.now() - startTime
      });
    } catch (error) {
      logger.error('User registration failed', {
        email: request.email,
        error: error.message,
        duration: Date.now() - startTime
      });
      throw error;
    }
  }
}
```

#### インフラ層：DB・API呼び出し

```typescript
// infrastructure/repositories/UserRepository.ts
export class UserRepository implements IUserRepository {
  async save(user: User): Promise<void> {
    const startTime = Date.now();

    try {
      logger.debug('Executing INSERT query', {
        table: 'users',
        userId: user.getId()
      });

      await this.db.query('INSERT INTO users ...', [user.getId(), ...]);

      logger.debug('User saved to database', {
        userId: user.getId(),
        duration: Date.now() - startTime
      });
    } catch (error) {
      logger.error('Database insert failed', {
        userId: user.getId(),
        error: error.message,
        duration: Date.now() - startTime
      });
      throw new DatabaseError('Failed to save user');
    }
  }
}

// infrastructure/adapters/EmailAdapter.ts
export class EmailAdapter implements IEmailSendingService {
  async send(to: string, subject: string, body: string): Promise<void> {
    const startTime = Date.now();

    try {
      logger.debug('Sending email', { to, subject });

      const response = await fetch('https://api.sendgrid.com/...', {
        method: 'POST',
        body: JSON.stringify({ to, subject, html: body })
      });

      if (!response.ok) {
        throw new Error(`SendGrid error: ${response.statusText}`);
      }

      logger.info('Email sent successfully', {
        to,
        subject,
        duration: Date.now() - startTime
      });
    } catch (error) {
      logger.error('Email sending failed', {
        to,
        subject,
        error: error.message,
        duration: Date.now() - startTime
      });
      // メール失敗はログするが、アプリケーションは続行
    }
  }
}
```

---

### 🔍 構造化ログの実装

#### Winston (Node.js 推奨)

```typescript
// config/logger.ts
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.splat(),
    winston.format.json()
  ),
  defaultMeta: { service: 'user-management' },
  transports: [
    // ファイルに出力
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),

    // 本番環境ではコンソール抑制
    ...(process.env.NODE_ENV !== 'production'
      ? [new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.printf(
              ({ timestamp, level, message, ...rest }) =>
                `${timestamp} [${level}] ${message} ${JSON.stringify(rest)}`
            )
          )
        })]
      : [])
  ]
});

export default logger;
```

#### Console クラスで囲む

```typescript
// イメージ: console.log はログに含めない
console.log('Debug info');  // ❌ 本番環境で見えてしまう

// `logger` を使う
logger.debug('Debug info');  // ✅ ログレベル制御
```

---

### 📈 監視・メトリクス

#### Prometheus メトリクス例

```typescript
// infrastructure/monitoring/PrometheusMetrics.ts
import { Counter, Histogram, register } from 'prom-client';

export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

export const userRegistrationCounter = new Counter({
  name: 'user_registration_total',
  help: 'Total number of user registrations',
  labelNames: ['status']
});

export const databaseQueryDuration = new Histogram({
  name: 'database_query_duration_seconds',
  help: 'Duration of database queries',
  labelNames: ['operation', 'table']
});

// 使用例
httpRequestDuration
  .labels('POST', '/users/register', '201')
  .observe(0.5);

userRegistrationCounter.labels('success').inc();
```

#### アラート設定（Grafana）

```yaml
# Example alerting rule
alert: HighErrorRate
expr: |
  (
    sum(rate(http_request_total{status=~"5.."}[5m]))
    /
    sum(rate(http_request_total[5m]))
  ) > 0.05
for: 5m
annotations:
  summary: "High error rate detected"
  description: "Error rate is {{ $value | humanizePercentage }}"
```

---

### 🔐 ログのセキュリティ

```typescript
// ❌ 危険：センシティブ情報をログに含める
logger.info('User registered', {
  email: request.email,
  password: request.password,    // 絶対禁止
  creditCard: request.creditCard  // 絶対禁止
});

// ✅ 安全：ハッシュまたは省略
logger.info('User registered', {
  email: hashEmail(request.email),
  passwordLength: request.password.length,  // 長さだけ
  creditCardLast4: request.creditCard.slice(-4)
});

// ✅ 開発環境のみセンシティブ情報
if (process.env.NODE_ENV === 'development') {
  logger.debug('User data', { ...userData });
}
```

---

### 📋 チェックリスト

```
✅ ログレベルが適切に設定されている
✅ 構造化ログ（JSON形式）
✅ タイムスタンプを含める
✅ リクエスト ID でトレーシング可能
✅ センシティブ情報を除外
✅ ロテーション設定（ファイルサイズ制限）
✅ 中央ログ管理（ELK Stack など）
✅ アラート体制
```

---

**次: [パフォーマンス最適化 →](#section-06-best-practices-04-performance-optimization)**

## 04: パフォーマンス最適化 {#section-06-best-practices-04-performance-optimization}


N+1 問題、キャッシング、クエリ最適化で高速なシステムを構築。

---

### 🎯 パフォーマンス最適化の原則

```
測定 → 分析 → 改善 → 検証
```

---

### 🔴 N+1 問題とは

#### ❌ 悪い実装例

```typescript
// N+1 問題発生
async function getUsersWithOrders(): Promise<UserWithOrders[]> {
  const users = await userRepository.findAll();  // 1回のクエリ: SELECT * FROM users

  // ユーザーごとにループで追加クエリ実行
  for (const user of users) {
    user.orders = await orderRepository.findByUserId(user.id);  // N回のクエリ
  }

  return users;
}

// 実行されるSQL
// 1. SELECT * FROM users;              (1回)
// 2. SELECT * FROM orders WHERE user_id = 1;  (N回)
// 3. SELECT * FROM orders WHERE user_id = 2;
// ... 合計: 1 + N 回
```

#### ✅ 改善例1: JOIN で取得

```typescript
// JOIN で一度に取得
async function getUsersWithOrders(): Promise<UserWithOrders[]> {
  const results = await db.query(`
    SELECT u.*, o.*
    FROM users u
    LEFT JOIN orders o ON u.id = o.user_id
  `);

  // メモリ上でマッピング
  const userMap = new Map<string, UserWithOrders>();
  for (const row of results) {
    if (!userMap.has(row.user_id)) {
      userMap.set(row.user_id, {
        ...row,
        orders: []
      });
    }
    if (row.order_id) {
      userMap.get(row.user_id)!.orders.push({
        id: row.order_id,
        ...
      });
    }
  }

  return Array.from(userMap.values());
}

// 実行されるSQL
// 1. SELECT ... FROM users LEFT JOIN orders ...  (1回だけ)
```

#### ✅ 改善例2: Batch サイズ指定

```typescript
async function getUsersWithOrders(): Promise<UserWithOrders[]> {
  const users = await userRepository.findAll();

  // バッチで取得（IDs: [1, 2, 3, 4, 5]）
  const userIds = users.map(u => u.id);
  const orders = await orderRepository.findByUserIds(userIds);

  // メモリ上でマッピング
  const ordersByUserId = new Map<string, Order[]>();
  for (const order of orders) {
    if (!ordersByUserId.has(order.userId)) {
      ordersByUserId.set(order.userId, []);
    }
    ordersByUserId.get(order.userId)!.push(order);
  }

  return users.map(user => ({
    ...user,
    orders: ordersByUserId.get(user.id) || []
  }));
}

// 実行されるSQL
// 1. SELECT * FROM users;                              (1回)
// 2. SELECT * FROM orders WHERE user_id IN (1,2,3,4,5);  (1回)
```

---

### 💾 キャッシング戦略

#### パターン1: デコレータパターン

```typescript
// infrastructure/repositories/CachedUserRepository.ts
export class CachedUserRepository implements IUserRepository {
  constructor(
    private baseRepository: IUserRepository,
    private cache: CacheProvider
  ) {}

  async findById(id: string): Promise<User | null> {
    // キャッシュキー
    const cacheKey = `user:${id}`;

    // キャッシュから取得
    const cached = await this.cache.get(cacheKey);
    if (cached) {
      return JSON.parse(cached);
    }

    // キャッシュミス時
    const user = await this.baseRepository.findById(id);
    if (user) {
      // キャッシュに保存（TTL: 1時間）
      await this.cache.set(cacheKey, JSON.stringify(user), 3600);
    }

    return user;
  }

  async save(user: User): Promise<void> {
    // DB保存
    await this.baseRepository.save(user);

    // キャッシュを更新
    const cacheKey = `user:${user.getId()}`;
    await this.cache.set(cacheKey, JSON.stringify(user), 3600);

    // ユーザーリスト用キャッシュを無効化
    await this.cache.delete('users:all');
  }
}
```

#### パターン2: キャッシュ戦略別設定

```typescript
// config/CacheConfig.ts
const cacheStrategies = {
  // 頻繁に読み取られる、変更頻度が低い
  USER_PROFILE: {
    ttl: 3600,  // 1時間
    tags: ['user']
  },

  // リアルタイム性が重要
  ORDER_STATUS: {
    ttl: 60,    // 1分
    tags: ['order']
  },

  // 変わらない
  PRODUCT_CATALOG: {
    ttl: 86400, // 24時間
    tags: ['product']
  },

  // 一時的
  TEMP_VERIFICATION_CODE: {
    ttl: 300,   // 5分
    tags: ['verification']
  }
};

// 使用例
await this.cache.set(
  `user:${userId}`,
  userData,
  cacheStrategies.USER_PROFILE.ttl
);
```

#### パターン3: キャッシュ無効化戦略

```typescript
// infrastructure/services/CacheInvalidationService.ts
export class CacheInvalidationService {
  constructor(
    private cache: CacheProvider,
    private eventPublisher: EventPublisher
  ) {
    // ユーザー更新イベントをリッスン
    this.eventPublisher.subscribe('user.updated', (event) => {
      this.invalidateUserCache(event.userId);
    });
  }

  private async invalidateUserCache(userId: string): Promise<void> {
    // 直接キャッシュ削除
    const keys = [
      `user:${userId}`,
      `user:${userId}:orders`,
      `user:${userId}:preferences`
    ];

    for (const key of keys) {
      await this.cache.delete(key);
    }

    // タグベース無効化
    await this.cache.invalidateByTag('user');
  }

  async invalidateUserListCache(): Promise<void> {
    await this.cache.delete('users:all');
    await this.cache.delete('users:active');
  }
}
```

---

### 📊 クエリ最適化

#### 早期終了（LIMIT）

```typescript
// ❌ 全件取得してから配列を切る
const topUsers = (await userRepository.findAll()).slice(0, 10);

// ✅ DB側で制限
const topUsers = await userRepository.findTopN(10);

// 実装
async findTopN(limit: number): Promise<User[]> {
  return db.query('SELECT * FROM users LIMIT ?', [limit]);
}
```

#### インデックス活用

```typescript
// DB スキーマレベル
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_created_at ON orders(created_at);

// 複合インデックス
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at);
```

#### EXPLAIN で実行計画確認

```typescript
// EXPLAIN の実行
EXPLAIN SELECT * FROM users WHERE email = 'john@example.com';

// 結果例
// id | select_type | table | type | key | rows | Extra
// 1  | SIMPLE      | users | ref  | idx_users_email | 1 | NULL

// type = ref：インデックス使用 ✅
// type = ALL：全テーブルスキャン ❌
```

---

### 🚀 Connection Pool・接続管理

```typescript
// database/ConnectionPool.ts
import { Pool } from 'mysql2/promise';

const pool = new Pool({
  host: 'localhost',
  user: 'root',
  password: 'password',
  database: 'app_db',
  waitForConnections: true,
  connectionLimit: 10,        // プール内の最大接続数
  queueLimit: 0               // キュー内の最大待機数
});

// 接続数を監視
setInterval(() => {
  const metrics = pool._connectionPromiseQueue;
  logger.info('Connection pool status', {
    queueLength: metrics.length
  });
}, 60000);
```

---

### ⏱️ パフォーマンス計測

```typescript
// utils/PerformanceMonitor.ts
export function measureTime<T>(
  operation: () => Promise<T>
): Promise<{ result: T; duration: number }> {
  const startTime = Date.now();
  const result = await operation();
  const duration = Date.now() - startTime;
  return { result, duration };
}

// 使用例
const { result: users, duration } = await measureTime(async () => {
  return userRepository.findAll();
});

logger.info('Query performance', {
  operation: 'findAll',
  duration,
  resultCount: users.length
});
```

---

### 📋 チェックリスト

```
✅ N+1 問題がない（JOIN またはバッチ取得）
✅ 適切なインデックスが設定されている
✅ キャッシング戦略が定義されている
✅ キャッシュ無効化戦略がある
✅ Connection Pool が設定されている
✅ LIMIT で取得件数制限
✅ EXPLAIN で実行計画確認
✅ パフォーマンスメトリクスを記録
```

---

**次: [セキュリティ →](#section-06-best-practices-05-security)**

## 05: セキュリティ {#section-06-best-practices-05-security}


入力検証、認証・認可、暗号化で堅牢なシステムを構築。

---

### 🎯 セキュリティの原則

```
深層防御：複数層でチェック
│
最小権限：必要最小限のアクセス
│
可視化：監視・ログで検出
```

---

### 🔐 入力検証（複数層）

#### プレゼンテーション層：型・形式チェック

```typescript
// presentation/middlewares/ValidationMiddleware.ts
import { body, validationResult } from 'express-validator';

export const validateUserRegistration = [
  body('email')
    .isEmail()
    .normalizeEmail(),

  body('password')
    .isLength({ min: 8 })
    .withMessage('At least 8 characters'),

  body('name')
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Name must be 2-100 characters'),

  (req: Request, res: Response, next: NextFunction) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(422).json({ errors: errors.array() });
    }
    next();
  }
];

// routes/userRoutes.ts
router.post('/register', validateUserRegistration, userController.register);
```

#### ドメイン層：ビジネスルール検証

```typescript
// domain/value-objects/Email.ts
export class Email {
  private readonly value: string;

  constructor(value: string) {
    // より厳密なメール形式チェック
    if (!this.isValidEmail(value)) {
      throw new InvalidEmailError(`Invalid email: ${value}`);
    }

    // DNSチェック（本番環境）
    if (process.env.NODE_ENV === 'production') {
      this.validateDNS(value);
    }

    this.value = value.toLowerCase();
  }

  private isValidEmail(email: string): boolean {
    // RFC 5322
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  private validateDNS(email: string): void {
    // DNSレコード確認
    const domain = email.split('@')[1];
    // DNS lookup implementation
  }
}

// domain/value-objects/Password.ts
export class Password {
  static async fromPlainText(plainPassword: string): Promise<Password> {
    // 強度チェック
    this.validateStrength(plainPassword);

    // ハッシュ化
    const hashedValue = await bcrypt.hash(plainPassword, 12);
    return new Password(hashedValue);
  }

  private static validateStrength(password: string): void {
    const errors: string[] = [];

    if (password.length < 8) errors.push('8文字以上');
    if (!/[A-Z]/.test(password)) errors.push('大文字を含む');
    if (!/[a-z]/.test(password)) errors.push('小文字を含む');
    if (!/[0-9]/.test(password)) errors.push('数字を含む');
    if (!/[!@#$%^&*]/.test(password)) errors.push('特殊文字を含む');

    if (errors.length > 0) {
      throw new WeakPasswordError(`パスワードは以下を満たしてください: ${errors.join(', ')}`);
    }
  }
}
```

#### インフラ層：DB スキーマ制約

```typescript
-- DDL
CREATE TABLE users (
  id VARCHAR(36) PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(100) NOT NULL,
  CHECK (LENGTH(password_hash) >= 60),  -- bcryptハッシュサイズ
  CHECK (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$')
);
```

---

### 🔑 Authentication/Authorization

#### JWT ベース認証

```typescript
// infrastructure/services/JwtTokenGenerator.ts
import * as jwt from 'jsonwebtoken';

export class JwtTokenGenerator implements ITokenGenerator {
  private readonly secret = process.env.JWT_SECRET || 'your-secret-key';
  private readonly expiresIn = '24h';

  async generate(userId: string, role: string): Promise<string> {
    return jwt.sign(
      { userId, role },
      this.secret,
      { expiresIn: this.expiresIn }
    );
  }

  async verify(token: string): Promise<{ userId: string; role: string }> {
    try {
      return jwt.verify(token, this.secret) as { userId: string; role: string };
    } catch (error) {
      throw new UnauthorizedError('Invalid or expired token');
    }
  }
}

// presentation/middlewares/AuthenticationMiddleware.ts
export const authenticate = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid token' });
  }

  const token = authHeader.slice(7);  // "Bearer " を削除

  try {
    const decoded = tokenGenerator.verify(token);
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Unauthorized' });
  }
};
```

#### Role-Based Access Control（RBAC）

```typescript
// presentation/middlewares/AuthorizationMiddleware.ts
export const authorize = (allowedRoles: string[]) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        error: 'Forbidden',
        message: `Only ${allowedRoles.join(',')} can access this resource`
      });
    }

    next();
  };
};

// routes/userRoutes.ts
router.delete('/users/:id',
  authenticate,
  authorize(['admin']),
  userController.deleteUser
);
```

---

### 🛡️ SQL インジェクション対策

#### ❌ 悪い例

```typescript
// 危険：文字列連結
const query = `SELECT * FROM users WHERE email = '${email}'`;
await db.query(query);

// 攻撃例
// email = "' OR '1'='1"
// → SELECT * FROM users WHERE email = '' OR '1'='1'  (全件取得)
```

#### ✅ 良い例

```typescript
// パラメータライズドクエリ
const query = 'SELECT * FROM users WHERE email = ?';
await db.query(query, [email]);

// または名前付きパラメータ
const query = 'SELECT * FROM users WHERE email = :email';
await db.query(query, { email });
```

---

### 🔒 パスワード・機密情報

#### bcrypt でハッシュ化

```typescript
// ❌ 悪い例
const hashedPassword = Buffer.from(password).toString('base64');

// ✅ 良い例
const hashedPassword = await bcrypt.hash(password, 12);

// 検証
const isMatch = await bcrypt.compare(plainPassword, hashedPassword);
```

#### 機密情報の管理

```typescript
// .env（コミットしない）
DB_PASSWORD=secure_password
JWT_SECRET=your-secret-key
API_KEY=12345abcde

// config/secrets.ts
export const secrets = {
  dbPassword: process.env.DB_PASSWORD,
  jwtSecret: process.env.JWT_SECRET,
  apiKey: process.env.API_KEY
};

// ❌ ログに機密情報を含めない
logger.info('User data', { password: request.password });  // 危険

// ✅
logger.info('User registered', { email: request.email });
```

---

### 📤 CORS・ヘッダーセキュリティ

```typescript
// presentation/middlewares/SecurityHeadersMiddleware.ts
import cors from 'cors';
import helmet from 'helmet';

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

// Helmet でセキュリティヘッダー自動化
app.use(helmet());

// 手動設定例
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');      // MIME Type Sniffing 防止
  res.setHeader('X-Frame-Options', 'DENY');                // Clickjacking 防止
  res.setHeader('X-XSS-Protection', '1; mode=block');      // XSS 防止
  res.setHeader('Content-Security-Policy', "default-src 'self'");
  next();
});
```

---

### 🚨 レート制限・DDoS対策

```typescript
// presentation/middlewares/RateLimitMiddleware.ts
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15分
  max: 100,                   // 100リクエスト
  message: 'Too many requests, please try again later'
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,  // ログインは厳しく制限
  skipSuccessfulRequests: true
});

app.post('/users/login', authLimiter, userController.login);
app.use(limiter);  // 他のエンドポイント
```

---

### 📋 セキュリティチェックリスト

```
入力検証
✅ 型チェック（プレゼンテーション層）
✅ ビジネスルール検証（ドメイン層）
✅ DB スキーマ制約

認証・認可
✅ JWT トークンベース認証
✅ トークン有効期限設定
✅ RBAC で権限管理
✅ ブルートフォース攻撃対策

パスワード
✅ bcrypt でハッシュ化
✅ Salt を使用
✅ 強度チェック

インジェクション対策
✅ パラメータライズドクエリ
✅ SQL エスケープ
✅ コマンドインジェクション対策

機密情報
✅ .env で環境変数管理
✅ センシティブ情報をログに出力しない
✅ HTTPS を強制

HTTP セキュリティ
✅ CORS 設定
✅ Security Headers
✅ HTTPS/TLS
✅ CSRF トークン

監視
✅ ログで不正アクセス検出
✅ レート制限
✅ WAF（Web Application Firewall）
```

---

### 🔗 関連セクション

- [エラーハンドリング](#section-06-best-practices-02-error-handling) - エラーレスポンス
- [ロギング・監視](#section-06-best-practices-03-logging-monitoring) - セキュリティイベント監視

---

**完了！ベストプラクティスマスター**

# 07: よくある間違い - アンチパターンの認識と回避 {#chapter-07-common-pitfalls}

## 01: 過度な設計（Over-Engineering） {#section-07-common-pitfalls-01-over-engineering}


プロジェクト規模に適していない複雑な設計を避ける。

---

### 🎯 問題

小規模プロジェクトに不必要なレイヤーを追加し、複雑化させる。実装効率が低下し、保守性が向上しない。

---

### 📍 具体例：不適切な設計

```typescript
// 🚫 小規模プロジェクトに対して過度に複雑
├─ presentation/
│   ├─ controllers/
│   ├─ dtos/
│   ├─ validators/
│   └─ middlewares/
├─ application/
│   ├─ usecases/
│   ├─ services/
│   └─ mappers/
├─ domain/
│   ├─ entities/
│   ├─ values/
│   ├─ services/
│   └─ repositories/
└─ infrastructure/
    ├─ repositories/
    ├─ adapters/
    ├─ cache/
    └─ config/

// 計20ファイル 20クラス
// その割に機能は：
// - ユーザー一覧表示
// - ユーザー詳細表示
// それだけ？
```

**結果：**
- 開発速度が低下
- 不要な複雑性
- チーム全体で理解困難
- テストコードが多すぎる

---

### ✅ 解決策：段階的な設計

#### フェーズ1: MVP（最小限）0-5機能

```typescript
// シンプル構成
project/
├─ src/
│   ├─ index.ts        // エントリーポイント
│   ├─ db.ts           // DB 接続
│   ├─ server.ts       // Express サーバー
│   └─ queries.ts      // SQL クエリ
└─ tests/
    └─ integration.test.ts
```

**特徴：**
- 層分離なし
- 1ファイル=1ロジック
- テストは簡易的

```typescript
// index.ts
import express from 'express';
import { Pool } from 'mysql2/promise';

const app = express();
const pool = new Pool({
  host: 'localhost',
  user: 'root',
  database: 'app'
});

// ユーザー列表
app.get('/users', async (req, res) => {
  const [rows] = await pool.query('SELECT id, email FROM users');
  res.json(rows);
});

// ユーザー詳細
app.get('/users/:id', async (req, res) => {
  const [rows] = await pool.query(
    'SELECT id, email FROM users WHERE id = ?',
    [req.params.id]
  );
  res.json(rows[0]);
});

app.listen(3000);
```

**利点：**
- 開発が迅速
- 全体構造が明確
- テストが簡潔

---

#### フェーズ2: 成長期（5-30機能）

```typescript
// 機能で分割
project/
├─ src/
│   ├─ index.ts
│   ├─ database.ts
│   ├─ users/
│   │   ├─ controller.ts
│   │   ├─ service.ts
│   │   ├─ repository.ts
│   │   └─ types.ts
│   └─ orders/
│       ├─ controller.ts
│       ├─ service.ts
│       ├─ repository.ts
│       └─ types.ts
└─ tests/
    ├─ users/
    └─ orders/
```

**特徴：**
- 機能ごとに分割
- Service/Repository の分離
- テストがモジュール毎

```typescript
// users/controller.ts
import { Router } from 'express';
import { UserService } from './service';

export const userRouter = Router();
const userService = new UserService();

userRouter.get('/', async (req, res) => {
  const users = await userService.getAllUsers();
  res.json(users);
});

// users/service.ts
import { UserRepository } from './repository';

export class UserService {
  private userRepository = new UserRepository();

  async getAllUsers() {
    return this.userRepository.findAll();
  }

  async getUserById(id: string) {
    return this.userRepository.findById(id);
  }
}

// users/repository.ts
export class UserRepository {
  async findAll() {
    const [rows] = await pool.query('SELECT * FROM users');
    return rows;
  }

  async findById(id: string) {
    const [rows] = await pool.query(
      'SELECT * FROM users WHERE id = ?',
      [id]
    );
    return rows[0];
  }
}
```

**メリット：**
- ドメイン毎に理解可能
- テストが組織的
- 複雑さが段階的に増加

---

#### フェーズ3: スケール期（30+機能）

```typescript
// フル層分離
project/
├─ src/
│   ├─ presentation/
│   │   ├─ controllers/
│   │   ├─ dtos/
│   │   ├─ middlewares/
│   │   └─ routes.ts
│   ├─ application/
│   │   ├─ usecases/
│   │   └─ mappers/
│   ├─ domain/
│   │   ├─ entities/
│   │   ├─ value-objects/
│   │   ├─ repositories/ (interface)
│   │   └─ errors/
│   ├─ infrastructure/
│   │   ├─ repositories/ (implementation)
│   │   ├─ adapters/
│   │   ├─ cache/
│   │   └─ database.ts
│   └─ config/
│       └─ container.ts (DI)
└─ tests/
    ├─ unit/
    ├─ integration/
    └─ e2e/
```

**特徴：**
- 完全な層分離
- 複雑なビジネスロジック対応
- 大規模チーム開発対応

---

### 📋 判断基準チェックリスト

| 質問 | YES | NO |
|-----|-----|-----|
| チーム規模が5名以上か | → フェーズ3検討 | → フェーズ1-2 |
| 機能が30個以上あるか | → フェーズ3 | → フェーズ1-2 |
| ビジネスロジックが複雑か | → フェーズ3 | → フェーズ1-2 |
| 複数人が並行開発するか | → フェーズ3 | → フェーズ1-2 |
| 保守期間が1年以上か | → フェーズ3 | → フェーズ1-2 |
| 自動テストが必須か | → フェーズ3, フェーズ2 | → フェーズ1 |

---

### 🔄 段階的なマイグレーション

#### フェーズ1 → フェーズ2 への移行

```typescript
// Before: すべてが index.ts

// After: 機能ごとに分割
app.use('/api/users', userRouter);
app.use('/api/orders', orderRouter);
app.use('/api/products', productRouter);
```

#### フェーズ2 → フェーズ3 への移行

```typescript
// service.ts を repository.ts に分割
export class UserService {
  constructor(private userRepository: UserRepository) {}
  // ビジネスロジックに専念
}

// さらにユースケースに分割
export class GetUserByIdUseCase {
  constructor(private userRepository: UserRepository) {}

  async execute(userId: string): Promise<User> {
    const user = await this.userRepository.findById(userId);
    // ... ビジネスロジック
    return user;
  }
}
```

---

### 📋 チェックリスト

```
✅ 現在のチーム規模に適切な設計を選択
✅ 機能数に応じてフェーズを判定
✅ 過度な抽象化を避ける
✅ チーム全体が設計を理解している
✅ 必要になってから層を追加
✅ 「YAGNI（You Aren't Gonna Need It）」原則を守る
```

---

**次: [密結合の回避 →](#section-07-common-pitfalls-02-tight-coupling)**

## 02: 密結合（Tight Coupling） {#section-07-common-pitfalls-02-tight-coupling}


層間の依存関係を逆転させて疎結合を実現する。

---

### 🎯 問題

下位層が上位層を参照する、または層間の依存が双方向になると：
- テスト困難（実装に依存）
- 変更範囲が不確定（連鎖的に影響）
- 再利用不可（依存が特定実装に限定）

---

### 📍 具体例：密結合アンチパターン

```typescript
// 🚫 ドメイン層がインフラ層に依存

// domain/User.ts（ドメイン層）
import { Database } from '../infrastructure/database';  // ❌ 上位層への参照

export class User {
  id: string;
  email: string;

  async save() {
    // DB を直接操作
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
    // インフラ層の具体的な実装に直接依存
    await user.save();

    // Service もベタ参照
    await NotificationService.send(email);
  }
}

// 🔴 テストが困難
// Domain をテストするのに、Database が必須
import { User } from '../domain/User';

describe('User', () => {
  it('should save user', async () => {
    const user = new User('john@example.com');
    await user.save();  // ← DB が必須
    // モック化不可
  });
});
```

**問題の内容：**
- ドメイン = data + behavior
- infrastructure = 実装詳細

この2つが混在すると、テストや再利用が困難になる

---

### ✅ 解決策：依存関係の逆転

#### 原則：依存は下位層（抽象度↑）へ

```
Presentation → Application → Domain ↔ Infrastructure
                                ↑
                             依存の向き
```

**各層で参照可能なもの：**
- Presentation: Application + Infrastructure
- Application: Domain + Infrastructure
- Domain: Domain のみ（他層は参照禁止）
- Infrastructure: 外部ライブラリ

#### 実装例：インターフェース経由

```typescript
// domain/ports/UserRepository.ts（インターフェース）
export interface UserRepository {
  save(user: User): Promise<void>;
  getById(id: string): Promise<User | null>;
}

// domain/User.ts（ドメイン層）
export class User {
  constructor(
    public id: string,
    public email: Email  // 値オブジェクト
  ) {}

  // ドメインロジックのみ
  isActive(): boolean {
    return this.email != null;
  }

  sendWelcomeEmail(): void {
    // ❌このロジックはドメインに含めない
    // インフラの詳細になるため
  }
}

// application/SaveUserUseCase.ts（アプリケーション層）
export class SaveUserUseCase {
  constructor(
    private userRepository: UserRepository,  // ✅ インターフェース依存
    private notificationService: NotificationService
  ) {}

  async execute(email: string): Promise<void> {
    // ドメインロジック
    const emailObj = new Email(email);
    const user = new User(uuid(), emailObj);

    // リポジトリを通じて永続化
    await this.userRepository.save(user);

    // 副作用を処理
    await this.notificationService.notifyUserCreated(user);
  }
}

// infrastructure/repositories/MySQLUserRepository.ts
export class MySQLUserRepository implements UserRepository {
  constructor(private connection: Pool) {}

  async save(user: User): Promise<void> {
    await this.connection.query(
      'INSERT INTO users (id, email) VALUES (?, ?)',
      [user.id, user.email.getValue()]
    );
  }

  async getById(id: string): Promise<User | null> {
    const [rows] = await this.connection.query(
      'SELECT * FROM users WHERE id = ?',
      [id]
    );
    if (!rows[0]) return null;

    return new User(rows[0].id, new Email(rows[0].email));
  }
}

// infrastructure/adapters/SendgridNotificationService.ts
import { httpClient } from '../http';

export class SendgridNotificationService implements NotificationService {
  async notifyUserCreated(user: User): Promise<void> {
    await httpClient.post('https://api.sendgrid.com/v3/mail/send', {
      to: user.email.getValue(),
      subject: 'Welcome!',
      html: '<h1>Welcome to our app</h1>'
    });
  }
}
```

#### テスト：インターフェース を使ったモック

```typescript
// tests/usecases/SaveUserUseCase.test.ts
describe('SaveUserUseCase', () => {
  let useCase: SaveUserUseCase;
  let mockRepository: UserRepository;
  let mockNotificationService: NotificationService;

  beforeEach(() => {
    // モック実装
    mockRepository = {
      save: jest.fn(),
      getById: jest.fn()
    };

    mockNotificationService = {
      notifyUserCreated: jest.fn()
    };

    useCase = new SaveUserUseCase(
      mockRepository,
      mockNotificationService
    );
  });

  it('should save user and send notification', async () => {
    // ✅ DB なしでテスト可能
    await useCase.execute('john@example.com');

    expect(mockRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        email: expect.any(Email)
      })
    );

    expect(mockNotificationService.notifyUserCreated).toHaveBeenCalled();
  });

  it('should throw error for invalid email', async () => {
    // ドメイン層のバリデーション
    await expect(useCase.execute('invalid-email')).rejects.toThrow(
      InvalidEmailError
    );
  });
});
```

---

### 🔄 よくある密結合パターンと修正

#### パターン1：グローバルゴブリン

```typescript
// ❌ グローバルインスタンスへの依存
// config/Database.ts
export class Database {
  static instance = new Pool();  // シングルトン
}

// domain/User.ts
import { Database } from '../config/Database';
export class User {
  async save() {
    await Database.instance.query(...);  // グローバル参照
  }
}

// ✅ コンストラクタで注入
// domain/User.ts
export class User {
  // リポジトリインターフェースとして依存
}

// application/SaveUserUseCase.ts
export class SaveUserUseCase {
  constructor(private userRepository: UserRepository) {}
  // リポジトリは DI コンテナから来る
}
```

#### パターン2：具体的なクラスに依存

```typescript
// ❌ 具体実装に依存
import { MySQLUserRepository } from '../infrastructure/MySQLUserRepository';

export class SaveUserUseCase {
  private repository = new MySQLUserRepository();
}

// ✅ インターフェースに依存
import { UserRepository } from '../domain/ports/UserRepository';

export class SaveUserUseCase {
  constructor(private userRepository: UserRepository) {}
  // MongoDB に切り替えも簡単
}
```

#### パターン3：層を超えた直接参照

```typescript
// ❌ Presentation が直接 Infrastructure を参照
import { MySQLUserRepository } from '../infrastructure/MySQLUserRepository';

export class UserController {
  private repository = new MySQLUserRepository();

  async getUser(req: Request, res: Response) {
    const user = await this.repository.getById(req.params.id);
    res.json(user);
  }
}

// ✅ Application を経由
import { GetUserUseCase } from '../application/GetUserUseCase';

export class UserController {
  constructor(private getUserUseCase: GetUserUseCase) {}

  async getUser(req: Request, res: Response) {
    const user = await this.getUserUseCase.execute(req.params.id);
    res.json(user);
  }
}
```

---

### 🔍 密結合の検出

#### madge で循環・密結合を検出

```bash
npm install --save-dev madge

# 循環依存をチェック
npx madge --circular src/

# 詳細な依存グラフを表示
npx madge src/

# グラフ画像を生成
npx madge --image graph.png src/
```

**出力例：**
```
⚠️  Circular dependencies found:
  A → B → A

❌ domain/User → infrastructure/Database → domain/User
```

---

### 📋 チェックリスト

```
✅ ドメイン層は他層を参照していない
✅ 依存関係がわかりやすい DAG（有向非巡回グラフ）
✅ インターフェース経由で層を分離
✅ DI コンテナで依存を一元管理
✅ テストでモックが使える
✅ madge で循環依存がない
✅ 層の責務が明確
```

---

**次: [貧血モデルの回避 →](#section-07-common-pitfalls-03-anemic-model)**

## 03: 貧血モデル（Anemic Model） {#section-07-common-pitfalls-03-anemic-model}


ビジネスロジックをエティティに戻す（リッチモデル設計）。

---

### 🎯 問題

エンティティがデータフィールドのみで、ビジネスロジックを持たない。

**結果：**
- ロジックが Use Case や Service に散在
- ロジックの重複
- バグが増加（検証が漏れる）
- ドメイン知識が散在

---

### 📍 具体例：貧血モデル

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

### ✅ 解決策：リッチモデル

#### ステップ1：値オブジェクトを導入

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

#### ステップ2：ロジックをエンティティに移動

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

#### ステップ3：ユースケースは層の仲介のみ

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

### 🧪 テスト：ドメイン層のテスト

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

### 📊 比較：貧血 vs リッチモデル

| 側面 | 貧血モデル | リッチモデル |
|------|----------|-----------|
| **ロジック** | Service に散在 | Entity に集約 |
| **検証** | ユースケース毎に異なる | 一貫性保証 |
| **テスト** |複雑で fragile | シンプルで堅牢 |
| **ドメイン知識** | コードとドキュメントが乖離 | 自己説明的 |
| **保守性** | 困難（重複削減） | 容易（SSOT） |
| **再利用** | 困難（ユースケース依存） | 容易（エンティティ使用） |

---

### 📋 チェックリスト

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

**次: [循環依存の回避 →](#section-07-common-pitfalls-04-circular-dependency)**

## 04: 循環依存（Circular Dependency） {#section-07-common-pitfalls-04-circular-dependency}


モジュール間の循環参照を検出・排除する。

---

### 🎯 問題

A → B → A のような循環依存があると：
- ビルドが失敗する可能性
- モジュール分離の意味がない
- 依存関係が不明確

---

### 📍 具体例：循環依存

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

### ✅ 解決策1：インターフェースで分離

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

### ✅ 解決策2：中間層で参照を遅延

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

### ✅ 解決策3：イベント駆動で分離

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

### 🔍 循環依存の検出方法

#### Tool: madge（循環依存検出）

```bash
npm install --save-dev madge
npm install --save-dev @types/madge
```

#### 使用方法

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

#### Webpack/TypeScript での検出

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

#### TypeScript での検出（tsc --diagnostics）

```bash
tsc --diagnostics --listFiles 2>&1 | grep -i circular
```

---

### 📊 依存方向の一般的なパターン

#### ✅ 良いパターン（DAG）

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

#### ❌ 悪いパターン（循環）

```
User ←→ Account       // 双方向
  ↓      ↓
Service  Adapter      // 同じインターフェース参照
  ↓      ↓
  ←---←-- (循環)
```

---

### 📋 チェックリスト

#### 設計フェーズ

```
✅ 依存方向を DAG（有向非巡回グラフ）で設計
✅ インターフェース経由の依存を使用
✅ 各モジュールの責務が明確
✅ モジュール境界が定義されている
```

#### 実装フェーズ

```
✅ madge で循環依存がない
✅ インポート文が「下位層へのみ」
✅ 相互参照がない
✅ イベント駆動で遠い層を結合しない
```

#### テスト・レビュー

```
✅ 各モジュールが独立してテスト可能
✅ モック化に支障がない
✅ コードレビューで循環参照が指摘される
✅ build に失敗することがない
```

---

### 🔗 関連セクション

- [密結合の回避](#section-07-common-pitfalls-02-tight-coupling) - インターフェース設計
- [実装ガイド](#chapter-05-implementation-guide) - 正しい層構造

---

**完了！アンチパターンマスター 🎓**

# 08: ケーススタディ - 実世界の実装例 {#chapter-08-case-studies}

## 01: ECサイト（注文・決済・在庫管理） {#section-08-case-studies-01-ecommerce-site}


複数の決済方法、在庫管理、注文フロー、トランザクション管理を扱う中規模プロジェクト。

---

### 🎯 背景

ユーザーが商品を選び、複数の決済方法で購入できるEコマースプラットフォーム。

**実装すべき機能：**
- 商品カタログ管理
- ショッピングカート
- 注文作成・確認
- 複数の決済方法対応
- 在庫管理
- 注文キャンセル・返品

---

### 🏗️ ドメイン層

#### エンティティ設計

```typescript
// domain/entities/Order.ts
export class Order {
  constructor(
    public id: string,
    public userId: string,
    public items: OrderItem[],
    public payment: Payment,
    public status: OrderStatus,
    public shippingAddress: Address
  ) {}

  addItem(product: Product, quantity: number): void {
    if (quantity <= 0) {
      throw new InvalidQuantityError('Quantity must be positive');
    }

    // ビジネスルール：在庫確認
    if (quantity > product.availableStock) {
      throw new OutOfStockError(
        `Product ${product.id} has only ${product.availableStock} in stock`
      );
    }

    const item = new OrderItem(product, quantity);
    this.items.push(item);
  }

  removeItem(itemIndex: number): void {
    if (itemIndex < 0 || itemIndex >= this.items.length) {
      throw new InvalidItemIndexError();
    }
    this.items.splice(itemIndex, 1);
  }

  getTotalPrice(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.getSubtotal()),
      Money.zero()
    );
  }

  // 状態遷移のビジネスルール
  canBeCanceled(): boolean {
    return this.status === OrderStatus.PENDING 
      || this.status === OrderStatus.CONFIRMED;
  }

  cancel(): void {
    if (!this.canBeCanceled()) {
      throw new OrderCannotBeCanceledError(this.id);
    }
    this.status = OrderStatus.CANCELED;
  }

  canBeShipped(): boolean {
    return this.status === OrderStatus.CONFIRMED 
      && this.payment.status === PaymentStatus.APPROVED;
  }

  ship(): void {
    if (!this.canBeShipped()) {
      throw new OrderCannotBeShippedError(this.id);
    }
    this.status = OrderStatus.SHIPPED;
  }
}

// domain/entities/OrderItem.ts
export class OrderItem {
  constructor(
    public product: Product,
    public quantity: number
  ) {
    if (quantity <= 0) {
      throw new InvalidQuantityError();
    }
  }

  getSubtotal(): Money {
    return this.product.price.multiply(this.quantity);
  }
}

// domain/entities/Payment.ts
export class Payment {
  constructor(
    public id: string,
    public method: PaymentMethod,
    public amount: Money,
    public status: PaymentStatus,
    public transactionId?: string
  ) {}

  approve(): void {
    if (this.status !== PaymentStatus.PENDING) {
      throw new PaymentAlreadyProcessedError(this.id);
    }
    this.status = PaymentStatus.APPROVED;
  }

  decline(): void {
    if (this.status !== PaymentStatus.PENDING) {
      throw new PaymentAlreadyProcessedError(this.id);
    }
    this.status = PaymentStatus.DECLINED;
  }

  refund(): void {
    if (this.status !== PaymentStatus.APPROVED) {
      throw new PaymentCannotBeRefundedError(this.id);
    }
    this.status = PaymentStatus.REFUNDED;
  }
}

// domain/value-objects
export enum PaymentMethod {
  CREDIT_CARD = 'CREDIT_CARD',
  DEBIT_CARD = 'DEBIT_CARD',
  PAYPAL = 'PAYPAL',
  BANK_TRANSFER = 'BANK_TRANSFER'
}

export enum OrderStatus {
  PENDING = 'PENDING',
  CONFIRMED = 'CONFIRMED',
  SHIPPED = 'SHIPPED',
  DELIVERED = 'DELIVERED',
  CANCELED = 'CANCELED',
  REFUNDED = 'REFUNDED'
}

export enum PaymentStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  DECLINED = 'DECLINED',
  REFUNDED = 'REFUNDED'
}

// domain/value-objects/Address.ts
export class Address {
  constructor(
    public street: string,
    public city: string,
    public postalCode: string,
    public country: string
  ) {
    if (!street || !city || !postalCode) {
      throw new InvalidAddressError('Address is incomplete');
    }
  }
}
```

---

### 💼 アプリケーション層

#### 複雑なユースケース

```typescript
// application/usecases/CreateOrderUseCase.ts
export class CreateOrderUseCase {
  constructor(
    private orderRepository: OrderRepository,
    private productRepository: ProductRepository,
    private paymentService: PaymentService,
    private inventoryService: InventoryService,
    private notificationService: NotificationService,
    private transactionManager: TransactionManager
  ) {}

  async execute(request: CreateOrderRequest): Promise<CreateOrderResponse> {
    // トランザクション内で実行
    return await this.transactionManager.run(async () => {
      // 1. ユーザーと商品を検証
      const user = await this.validateUser(request.userId);
      const products = await this.validateProducts(request.items);

      // 2. 注文を作成
      const order = new Order(
        uuid(),
        user.id,
        [],
        null,
        OrderStatus.PENDING,
        request.shippingAddress
      );

      // 3. アイテムを追加（ドメインロジック）
      for (const item of request.items) {
        const product = products.find(p => p.id === item.productId);
        order.addItem(product, item.quantity);
      }

      // 4. 在庫を予約
      const reservationId = await this.inventoryService.reserve(
        order.id,
        request.items
      );

      // 5. 決済を処理
      let payment: Payment;
      try {
        payment = await this.paymentService.processPayment(
          request.paymentMethod,
          order.getTotalPrice()
        );
      } catch (error) {
        // 決済失敗時は在庫予約をキャンセル
        await this.inventoryService.cancelReservation(reservationId);
        throw new PaymentFailedError(error.message);
      }

      order.payment = payment;
      payment.approve();  // 決済承認

      // 6. 注文を確定
      order.status = OrderStatus.CONFIRMED;
      await this.orderRepository.save(order);

      // 7. 確認メール送信（非同期、失敗しても続行）
      try {
        await this.notificationService.sendOrderConfirmation(order);
      } catch (error) {
        logger.error('Failed to send confirmation email', { orderId: order.id });
      }

      return { orderId: order.id, totalPrice: order.getTotalPrice() };
    });
  }

  private async validateUser(userId: string): Promise<User> {
    const user = await this.userRepository.getById(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }
    return user;
  }

  private async validateProducts(items: { productId: string; quantity: number }[]): Promise<Product[]> {
    const productIds = items.map(i => i.productId);
    const products = await this.productRepository.getByIds(productIds);

    if (products.length !== productIds.length) {
      throw new ProductNotFoundError();
    }

    return products;
  }
}

// application/usecases/CancelOrderUseCase.ts
export class CancelOrderUseCase {
  constructor(
    private orderRepository: OrderRepository,
    private paymentService: PaymentService,
    private inventoryService: InventoryService,
    private notificationService: NotificationService,
    private transactionManager: TransactionManager
  ) {}

  async execute(orderId: string): Promise<void> {
    return await this.transactionManager.run(async () => {
      const order = await this.orderRepository.getById(orderId);
      if (!order) {
        throw new OrderNotFoundError(orderId);
      }

      // ビジネスルール：キャンセル可否を確認
      if (!order.canBeCanceled()) {
        throw new OrderCannotBeCanceledError(orderId);
      }

      // 在庫を解放
      await this.inventoryService.releaseReservation(orderId);

      // 支払いを払戻
      if (order.payment.status === PaymentStatus.APPROVED) {
        await this.paymentService.refundPayment(order.payment.id);
        order.payment.refund();
      }

      // 注文をキャンセル状態に
      order.cancel();
      await this.orderRepository.save(order);

      // キャンセル通知を送信
      await this.notificationService.sendCancelConfirmation(order);
    });
  }
}
```

---

### 🗄️ インフラ層

#### リレーショナルDB実装

```typescript
// infrastructure/repositories/MySQLOrderRepository.ts
export class MySQLOrderRepository implements OrderRepository {
  constructor(private connection: Pool) {}

  async save(order: Order): Promise<void> {
    await this.connection.query('BEGIN');
    try {
      // orders テーブル
      await this.connection.query(
        `INSERT INTO orders (id, user_id, status, shipping_address, created_at) 
         VALUES (?, ?, ?, ?, NOW())`,
        [
          order.id,
          order.userId,
          order.status,
          JSON.stringify(order.shippingAddress)
        ]
      );

      // order_items テーブル
      for (const item of order.items) {
        await this.connection.query(
          `INSERT INTO order_items (order_id, product_id, quantity, unit_price) 
           VALUES (?, ?, ?, ?)`,
          [
            order.id,
            item.product.id,
            item.quantity,
            item.product.price.value
          ]
        );
      }

      // payments テーブル
      await this.connection.query(
        `INSERT INTO payments (id, order_id, method, amount, status, transaction_id) 
         VALUES (?, ?, ?, ?, ?, ?)`,
        [
          order.payment.id,
          order.id,
          order.payment.method,
          order.getTotalPrice().value,
          order.payment.status,
          order.payment.transactionId || null
        ]
      );

      await this.connection.query('COMMIT');
    } catch (error) {
      await this.connection.query('ROLLBACK');
      throw new DatabaseError('Failed to save order');
    }
  }

  async getById(id: string): Promise<Order | null> {
    // N+1問題を避けるため JOIN で一度に取得
    const [results] = await this.connection.query(`
      SELECT 
        o.id, o.user_id, o.status, o.shipping_address,
        oi.product_id, oi.quantity, oi.unit_price,
        p.id as payment_id, p.method, p.amount, p.status as payment_status,
        p.transaction_id,
        pr.id as product_id_2, pr.name, pr.price as product_price
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN products pr ON oi.product_id = pr.id
      LEFT JOIN payments p ON o.id = p.order_id
      WHERE o.id = ?
    `, [id]);

    if (!results.length) {
      return null;
    }

    // 結果を集約ルート（Order）に再構築
    return this.reconstructOrder(results);
  }

  private reconstructOrder(rows: any[]): Order {
    const firstRow = rows[0];
    const order = new Order(
      firstRow.id,
      firstRow.user_id,
      [],
      null,
      firstRow.status,
      JSON.parse(firstRow.shipping_address)
    );

    // アイテムを集約
    const itemMap = new Map();
    rows.forEach(row => {
      if (row.product_id && !itemMap.has(row.product_id)) {
        const product = new Product(
          row.product_id_2,
          row.name,
          new Money(row.product_price)
        );
        itemMap.set(row.product_id, new OrderItem(product, row.quantity));
      }
    });

    order.items = Array.from(itemMap.values());

    // 支払い情報を集約
    if (firstRow.payment_id) {
      order.payment = new Payment(
        firstRow.payment_id,
        firstRow.method,
        new Money(firstRow.amount),
        firstRow.payment_status,
        firstRow.transaction_id
      );
    }

    return order;
  }
}
```

#### 決済サービスアダプター

```typescript
// infrastructure/adapters/StripePaymentAdapter.ts
export class StripePaymentAdapter implements PaymentService {
  constructor(private stripeClient: Stripe) {}

  async processPayment(
    method: PaymentMethod,
    amount: Money
  ): Promise<Payment> {
    try {
      const charge = await this.stripeClient.charges.create({
        amount: amount.value * 100,  // セント単位
        currency: 'usd',
        source: method
      });

      if (charge.status !== 'succeeded') {
        throw new PaymentFailedError('Payment was not successful');
      }

      return new Payment(
        charge.id,
        method,
        amount,
        PaymentStatus.APPROVED,
        charge.id
      );
    } catch (error) {
      throw new PaymentFailedError(error.message);
    }
  }

  async refundPayment(paymentId: string): Promise<void> {
    try {
      await this.stripeClient.refunds.create({
        charge: paymentId
      });
    } catch (error) {
      throw new PaymentRefundFailedError(error.message);
    }
  }
}
```

---

### 🎯 重要な設計ポイント

#### 1. 集約設計

**Order** を集約の根として、OrderItem と Payment は Order を通じて管理。
- 直接 Payment を削除できない（Order から削除）
- 直接 OrderItem を作成できない（Order.addItem() 経由）

#### 2. トランザクション管理

複数テーブルの変更は必ずトランザクション内で。ロールバック戦略も重要。

#### 3. N+1 問題を避ける

リポジトリは JOIN でデータを一度に取得し、メモリ上で再構築。

#### 4. ドメインルールの一貫性

支払い承認条件、キャンセル可否などは全て Entity が責任を持つ。

---

### 📋 チェックリスト

```
ドメイン設計
✅ 集約が明確（Order が根）
✅ ビジネスルールが Entity に
✅ 値オブジェクトで型安全性確保
✅ 状態遷移ルールを定義

トランザクション
✅ 複数テーブル更新は同一トランザクション
✅ ロールバック戦略がある
✅ 部分的な失敗時の回復処理

データアクセス
✅ N+1 問題なし
✅ 適切なインデックス
✅ JOIN で効率的に取得
```

---

**次: [SNS プラットフォーム →](#section-08-case-studies-02-sns-platform)**

## 02: SNS プラットフォーム（フィード生成・キャッシング） {#section-08-case-studies-02-sns-platform}


高スループット、リアルタイムフィード、大量のユーザーを扱うSNS。重点：スケーラビリティとキャッシング。

---

### 🎯 背景

ユーザーが投稿を作成・かんて、フォロワーのタイムラインにフィードが表示されるSNS。

**物になす必要な機能：**
- 投稿作成・削除
- いいね・コメント
- フォロー・フォロー解除
- パーソナライズされたフィード生成
- キャッシング・最適化
- リアルタイム通知

---

### 🏗️ ドメイン層

#### エンティティ設計

```typescript
// domain/entities/Post.ts
export class Post {
  constructor(
    public id: string,
    public authorId: string,
    public content: PostContent,
    public likeCount: number = 0,
    public commentCount: number = 0,
    public createdAt: Date = new Date()
  ) {}

  // ビジネスロジック
  like(): void {
    this.likeCount++;
  }

  unlike(): void {
    if (this.likeCount > 0) {
      this.likeCount--;
    }
  }

  addComment(): void {
    this.commentCount++;
  }

  removeComment(): void {
    if (this.commentCount > 0) {
      this.commentCount--;
    }
  }

  isLikedBy(userId: string): boolean {
    // リポジトリから取得するのではなく、
    // Application層から渡された情報で判定
    // （パフォーマンスのため）
    return false;  // 実装は Application層で
  }
}

// domain/value-objects/PostContent.ts
export class PostContent {
  constructor(public text: string) {
    if (!text || text.length === 0) {
      throw new InvalidPostContentError('Content cannot be empty');
    }
    if (text.length > 280) {
      throw new InvalidPostContentError('Content must be 280 characters or less');
    }
  }

  getText(): string {
    return this.text;
  }
}

// domain/entities/User.ts（フォロー関連）
export class User {
  private followingIds: Set<string> = new Set();
  private followerIds: Set<string> = new Set();

  constructor(
    public id: string,
    public username: string,
    public email: Email
  ) {}

  follow(userId: string): void {
    if (userId === this.id) {
      throw new CannotFollowYourselfError();
    }
    this.followingIds.add(userId);
  }

  unfollow(userId: string): void {
    this.followingIds.delete(userId);
  }

  isFollowing(userId: string): boolean {
    return this.followingIds.has(userId);
  }

  getFollowingCount(): number {
    return this.followingIds.size;
  }

  getFollowerCount(): number {
    return this.followerIds.size;
  }
}

// domain/services/FeedService.ts（ドメインサービス）
export class FeedService {
  // フィード生成ロジック（複雑なビジネスルール）
  generateFeed(posts: Post[], userPreferences: UserPreferences): Post[] {
    return posts
      .filter(post => this.matchesUserInterests(post, userPreferences))
      .sort((a, b) => {
        // 新順（最新がトップ）
        const dateCompare = b.createdAt.getTime() - a.createdAt.getTime();
        if (dateCompare !== 0) return dateCompare;

        // 日時が同じ場合はいいね数でソート
        return b.likeCount - a.likeCount;
      })
      .slice(0, 50);
  }

  private matchesUserInterests(post: Post, prefs: UserPreferences): boolean {
    // ビジネスルール：フォローしているユーザーの投稿
    return prefs.followingUserIds.includes(post.authorId) ||
           prefs.interests.some(interest => post.content.getText().includes(interest));
  }

  // トレンド判定
  isTrending(post: Post): boolean {
    return post.likeCount > 100 && this.isRecent(post);
  }

  private isRecent(post: Post): boolean {
    const oneDayMs = 24 * 60 * 60 * 1000;
    return Date.now() - post.createdAt.getTime() < oneDayMs;
  }
}
```

---

### 💼 アプリケーション層

#### フィード取得ユースケース（キャッシング統合）

```typescript
// application/usecases/GetUserFeedUseCase.ts
export class GetUserFeedUseCase {
  constructor(
    private postRepository: PostRepository,
    private feedService: FeedService,
    private cacheService: CacheService,
    private userRepository: UserRepository
  ) {}

  async execute(
    userId: string,
    params: { page: number; limit: number } = { page: 1, limit: 20 }
  ): Promise<PostDTO[]> {
    // キャッシュキーを生成
    const cacheKey = `feed:${userId}:${params.page}:${params.limit}`;

    // キャッシュから取得を試みる
    const cached = await this.cacheService.get<PostDTO[]>(cacheKey);
    if (cached) {
      logger.debug('Cache hit', { cacheKey });
      return cached;
    }

    logger.debug('Cache miss', { cacheKey });

    // ユーザーの基本情報と設定を取得
    const user = await this.userRepository.getById(userId);
    if (!user) {
      throw new UserNotFoundError(userId);
    }

    const userPrefs = await this.getUserPreferences(userId);

    // ページングで投稿を取得
    const posts = await this.postRepository.findByUserIds(
      Array.from(userPrefs.followingUserIds),
      {
        offset: (params.page - 1) * params.limit,
        limit: params.limit * 2  // バッファを持たせる
      }
    );

    // ドメインサービスでフィード生成
    const feedPosts = this.feedService.generateFeed(posts, userPrefs);
    const dtos = feedPosts
      .slice(0, params.limit)
      .map(post => this.postToDTO(post, userId));

    // キャッシュに保存（60秒）
    await this.cacheService.set(cacheKey, dtos, 60);

    return dtos;
  }

  private async getUserPreferences(userId: string): Promise<UserPreferences> {
    // キャッシュキー
    const prefsCacheKey = `user:prefs:${userId}`;

    // キャッシュから取得
    const cached = await this.cacheService.get<UserPreferences>(prefsCacheKey);
    if (cached) {
      return cached;
    }

    // キャッシュミス → DB から取得
    const preferences = await this.userRepository.getPreferences(userId);

    // キャッシュに保存（24時間）
    await this.cacheService.set(prefsCacheKey, preferences, 86400);

    return preferences;
  }

  private postToDTO(post: Post, userId: string): PostDTO {
    return {
      id: post.id,
      authorId: post.authorId,
      content: post.content.getText(),
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      createdAt: post.createdAt,
      isLikedByUser: false  // 別途クエリで取得
    };
  }
}

// application/usecases/CreatePostUseCase.ts
export class CreatePostUseCase {
  constructor(
    private postRepository: PostRepository,
    private cacheService: CacheService,
    private notificationService: NotificationService
  ) {}

  async execute(request: CreatePostRequest): Promise<PostDTO> {
    // 投稿を作成
    const post = new Post(
      uuid(),
      request.userId,
      new PostContent(request.content)
    );

    // DB に保存
    await this.postRepository.save(post);

    // フォロワーのフィードキャッシュを無効化
    const followers = await this.getFollowers(request.userId);
    
    for (const followerId of followers) {
      // そのユーザーのフィードキャッシュを全ページ削除
      await this.invalidateFeedCache(followerId);
    }

    // フォロワーに通知（非同期）
    this.notificationService.notifyFollowers(post);

    return {
      id: post.id,
      authorId: post.authorId,
      content: post.content.getText(),
      likeCount: 0,
      commentCount: 0,
      createdAt: post.createdAt,
      isLikedByUser: false
    };
  }

  private async invalidateFeedCache(userId: string): Promise<void> {
    // ユーザーのすべてのフィードページを無効化
    const pattern = `feed:${userId}:*`;
    await this.cacheService.deleteByPattern(pattern);
  }

  private async getFollowers(userId: string): Promise<string[]> {
    // `followers:${userId}` で保存されている配列を取得
    return await this.cacheService.get(`followers:${userId}`) || [];
  }
}
```

---

### 🗄️ インフラ層

#### レイヤー化されたキャッシング戦略

```typescript
// infrastructure/repositories/RedisPostRepository.ts
export class RedisPostRepository implements PostRepository {
  constructor(
    private redis: Redis,
    private mysql: Pool
  ) {}

  async save(post: Post): Promise<void> {
    // 両方に書き込み
    await Promise.all([
      // MySQL
      this.mysql.query(
        `INSERT INTO posts (id, author_id, content, created_at) 
         VALUES (?, ?, ?, NOW())`,
        [post.id, post.authorId, post.content.getText()]
      ),

      // Redis キャッシュ（1時間）
      this.redis.setex(
        `post:${post.id}`,
        3600,
        JSON.stringify({
          id: post.id,
          authorId: post.authorId,
          content: post.content.getText(),
          likeCount: post.likeCount,
          commentCount: post.commentCount,
          createdAt: post.createdAt
        })
      )
    ]);

    // 最新投稿リストに追加
    await this.redis.lpush(`posts:latest`, post.id);
    await this.redis.ltrim(`posts:latest`, 0, 1000);  // 最新1000件を保持
  }

  async getById(id: string): Promise<Post | null> {
    // Redis から優先的に取得
    const cached = await this.redis.get(`post:${id}`);

    if (cached) {
      logger.debug('Post cache hit', { postId: id });
      const data = JSON.parse(cached);
      return this.reconstructPost(data);
    }

    logger.debug('Post cache miss', { postId: id });

    // MySQL から取得
    const [rows] = await this.mysql.query(
      'SELECT * FROM posts WHERE id = ?',
      [id]
    );

    if (!rows.length) {
      return null;
    }

    const post = this.reconstructPost(rows[0]);

    // キャッシュに保存
    await this.redis.setex(`post:${id}`, 3600, JSON.stringify(rows[0]));

    return post;
  }

  async findByUserIds(
    userIds: string[],
    pagination: { offset: number; limit: number }
  ): Promise<Post[]> {
    // N+1を避けるため、複数ユーザーの投稿を一度に取得
    const [rows] = await this.mysql.query(
      `SELECT * FROM posts 
       WHERE author_id IN (?)
       ORDER BY created_at DESC
       LIMIT ? OFFSET ?`,
      [userIds, pagination.limit, pagination.offset]
    );

    return rows.map(row => this.reconstructPost(row));
  }

  private reconstructPost(data: any): Post {
    return new Post(
      data.id,
      data.author_id,
      new PostContent(data.content),
      data.like_count || 0,
      data.comment_count || 0,
      new Date(data.created_at)
    );
  }
}

// infrastructure/cache/RedisLikeCache.ts（いいね情報キャッシング）
export class RedisLikeCache {
  constructor(private redis: Redis) {}

  async addLike(postId: string, userId: string): Promise<void> {
    // `post:${postId}:likes` に user ID をセットで保存
    await this.redis.sadd(`post:${postId}:likes`, userId);
    
    // ユーザーが いいねした投稿リスト
    await this.redis.sadd(`user:${userId}:liked-posts`, postId);

    // TTL: 24時間
    await this.redis.expire(`post:${postId}:likes`, 86400);
  }

  async removeLike(postId: string, userId: string): Promise<void> {
    await Promise.all([
      this.redis.srem(`post:${postId}:likes`, userId),
      this.redis.srem(`user:${userId}:liked-posts`, postId)
    ]);
  }

  async getLikeCount(postId: string): Promise<number> {
    return await this.redis.scard(`post:${postId}:likes`);
  }

  async isLikedBy(postId: string, userId: string): Promise<boolean> {
    return await this.redis.sismember(`post:${postId}:likes`, userId) === 1;
  }
}
```

---

### 📊 キャッシング戦略

| キャッシュ対象 | 保存先 | TTL | インバリデータ時期 |
|------------|-------|-----|-----------------|
| ユーザープロフィール | Redis | 24時間 | プロフィール更新時 |
| フィード | Redis | 60秒 | 新投稿作成時 |
| 個別投稿 | Redis | 3600秒 | 削除/編集時 |
| いいね情報 | Redis Set | 86400秒 | いいね追加/削除時 |
| フォロー情報 | Redis Set | 永続 | フォロー変更時 |

---

### 🎯 重要な設計ポイント

#### 1. キャッシュインバリデータ戦略

キャッシュを無効化する時期を明確に：
- 投稿作成 → フォロワーのフィードキャッシュ削除
- フォロー追加 → ユーザーのフィードキャッシュ削除
- いいね → フィード再計算が必要か判定

#### 2. キャッシュ一貫性

MySQL と Redis が乖離しないよう、更新時は両方を更新。

#### 3. 大量データの効率的な取得

フォロワー一覧、フォロー中の投稿リストは Redis のセット構造を活用。

---

### 📋 チェックリスト

```
キャッシング戦略
✅ キャッシュキーの命名が一貫
✅ TTL が適切（リアルタイム性 vs キャッシュ効率）
✅ インバリデータ戦略がある
✅ キャッシュミス時のDB負荷が考慮

パフォーマンス
✅ N+1 が存在しない
✅ パジングが実装されている
✅ 大量データのソート・フィルタリングが効率的

ドメイン設計
✅ ビジネスロジックが Entity/Service に
✅ Cache層 にはロジックなし
```

---

**次: [マイクロサービス →](#section-08-case-studies-03-microservices)**

## 03: マイクロサービス（サービス分割・イベント駆動） {#section-08-case-studies-03-microservices}


複数の独立したサービスが協調する大規模分散システム。重点：サービス分割、非同期通信、強い一貫性。

---

### 🎯 背景

ユーザー管理、注文処理、決済、在庫管理が のを独立したサービスとして運用される大規模ECプラットフォーム。

**サービス一覧：**
- User Service：ユーザー認証・プロフィール
- Order Service：注文管理
- Payment Service：決済処理
- Inventory Service：在庫管理
- Notification Service：通知

---

### 🏗️ サービス分割設計

#### 各サービスのドメイン境界

```typescript
// user-service/domain/entities/User.ts
export class User {
  constructor(
    public id: string,
    public email: Email,
    public profile: Profile,
    public role: UserRole
  ) {}

  isAdmin(): boolean {
    return this.role === UserRole.ADMIN;
  }

  updateProfile(profile: Profile): void {
    this.profile = profile;
  }
}

// order-service/domain/entities/Order.ts
// ⚠️ 他サービスへの参照は ID のみ
export class Order {
  constructor(
    public id: string,
    public userId: string,  // User Service への外部キー
    public items: OrderItem[],
    public status: OrderStatus
  ) {}

  canBeCreated(): boolean {
    // Order Service のルール（User の詳細は不要）
    return this.items.length > 0;
  }
}

// payment-service/domain/entities/Payment.ts
export class Payment {
  constructor(
    public id: string,
    public orderId: string,  // Order Service への外部キー
    public amount: Money,
    public method: PaymentMethod,
    public status: PaymentStatus
  ) {}

  canBeProcessed(): boolean {
    return this.status === PaymentStatus.PENDING;
  }
}

// inventory-service/domain/entities/Stock.ts
export class Stock {
  constructor(
    public id: string,
    public productId: string,
    public quantity: number,
    public reservedQuantity: number = 0
  ) {}

  getAvailable(): number {
    return this.quantity - this.reservedQuantity;
  }

  canReserve(amount: number): boolean {
    return this.getAvailable() >= amount;
  }

  reserve(amount: number): void {
    if (!this.canReserve(amount)) {
      throw new InsufficientStockError();
    }
    this.reservedQuantity += amount;
  }

  release(amount: number): void {
    this.reservedQuantity -= amount;
  }
}
```

---

### 💼 イベント駆動アーキテクチャ

#### イベント定義

```typescript
// shared/events/index.ts（すべてのサービスが参照）

export abstract class DomainEvent {
  public readonly eventId: string;
  public readonly occurredAt: Date;

  constructor() {
    this.eventId = uuid();
    this.occurredAt = new Date();
  }

  abstract getAggregateId(): string;
}

// ユーザー作成イベント
export class UserCreatedEvent extends DomainEvent {
  constructor(
    public readonly userId: string,
    public readonly email: string
  ) {
    super();
  }

  getAggregateId(): string {
    return this.userId;
  }
}

// 注文作成イベント（サービス間通信の中心）
export class OrderCreatedEvent extends DomainEvent {
  constructor(
    public readonly orderId: string,
    public readonly userId: string,
    public readonly items: Array<{
      productId: string;
      quantity: number;
      price: number;
    }>,
    public readonly totalAmount: number
  ) {
    super();
  }

  getAggregateId(): string {
    return this.orderId;
  }
}

// 決済承認イベント
export class PaymentApprovedEvent extends DomainEvent {
  constructor(
    public readonly paymentId: string,
    public readonly orderId: string,
    public readonly amount: number
  ) {
    super();
  }

  getAggregateId(): string {
    return this.paymentId;
  }
}

// 決済失敗イベント
export class PaymentFailedEvent extends DomainEvent {
  constructor(
    public readonly orderId: string,
    public readonly reason: string
  ) {
    super();
  }

  getAggregateId(): string {
    return this.orderId;
  }
}

// 在庫予約イベント
export class InventoryReservedEvent extends DomainEvent {
  constructor(
    public readonly orderId: string,
    public readonly items: Array<{
      productId: string;
      quantity: number;
    }>
  ) {
    super();
  }

  getAggregateId(): string {
    return this.orderId;
  }
}

// 在庫予約失敗イベント
export class InventoryReservationFailedEvent extends DomainEvent {
  constructor(
    public readonly orderId: string,
    public readonly failedProductId: string
  ) {
    super();
  }

  getAggregateId(): string {
    return this.orderId;
  }
}
```

#### Order Service：イベント配信

```typescript
// order-service/application/CreateOrderUseCase.ts
export class CreateOrderUseCase {
  constructor(
    private orderRepository: OrderRepository,
    private eventPublisher: EventPublisher,
    private inventoryServiceClient: InventoryServiceClient
  ) {}

  async execute(request: CreateOrderRequest): Promise<CreateOrderResponse> {
    // 1. 注文を作成
    const order = new Order(
      uuid(),
      request.userId,
      request.items.map(item => new OrderItem(item.productId, item.quantity, item.price)),
      OrderStatus.PENDING
    );

    // ビジネスルール確認
    if (!order.canBeCreated()) {
      throw new InvalidOrderError('Order must have at least one item');
    }

    // 2. DB に保存
    await this.orderRepository.save(order);

    // 3. イベントをパブリッシュ（他サービスがアクション起こす）
    const event = new OrderCreatedEvent(
      order.id,
      request.userId,
      request.items,
      request.items.reduce((sum, item) => sum + item.price * item.quantity, 0)
    );

    await this.eventPublisher.publish(event);

    logger.info('Order created and event published', { orderId: order.id });

    return { orderId: order.id };
  }
}
```

#### Inventory Service：イベントリスナー

```typescript
// inventory-service/application/EventHandlers.ts
export class OrderCreatedEventHandler {
  constructor(
    private stockRepository: StockRepository,
    private eventPublisher: EventPublisher,
    private transactionManager: TransactionManager
  ) {}

  @OnEvent('order.created')
  async handle(event: OrderCreatedEvent): Promise<void> {
    try {
      await this.transactionManager.run(async () => {
        // 1. 在庫確認
        for (const item of event.items) {
          const stock = await this.stockRepository.getByProductId(item.productId);

          if (!stock || !stock.canReserve(item.quantity)) {
            throw new InsufficientStockError(item.productId);
          }
        }

        // 2. 在庫予約
        for (const item of event.items) {
          const stock = await this.stockRepository.getByProductId(item.productId);
          stock.reserve(item.quantity);
          await this.stockRepository.update(stock);
        }

        // 3. 成功イベントを配信
        await this.eventPublisher.publish(
          new InventoryReservedEvent(
            event.orderId,
            event.items
          )
        );

        logger.info('Inventory reserved', { orderId: event.orderId });
      });
    } catch (error) {
      // 在庫不足 → 失敗イベント配信
      await this.eventPublisher.publish(
        new InventoryReservationFailedEvent(event.orderId, error.productId)
      );

      logger.warn('Inventory reservation failed', {
        orderId: event.orderId,
        reason: error.message
      });
    }
  }
}
```

#### Payment Service：イベントリスナー

```typescript
// payment-service/application/EventHandlers.ts
export class InventoryReservedEventHandler {
  constructor(
    private paymentService: PaymentGateway,
    private paymentRepository: PaymentRepository,
    private eventPublisher: EventPublisher
  ) {}

  @OnEvent('inventory.reserved')
  async handle(event: InventoryReservedEvent): Promise<void> {
    try {
      // 注文情報を取得（Order Service に同期呼び出し）
      const order = await this.orderServiceClient.getOrder(event.orderId);

      // 決済処理
      const payment = await this.paymentService.authorize(
        order.userId,
        order.totalAmount
      );

      await this.paymentRepository.save(payment);

      // 成功イベント配信
      await this.eventPublisher.publish(
        new PaymentApprovedEvent(
          payment.id,
          event.orderId,
          order.totalAmount
        )
      );

      logger.info('Payment approved', { orderId: event.orderId });
    } catch (error) {
      // 決済失敗 → ロールバック開始
      await this.eventPublisher.publish(
        new PaymentFailedEvent(event.orderId, error.message)
      );

      logger.error('Payment failed', { orderId: event.orderId, error });
    }
  }
}
```

---

### 🔄 Saga パターン（オーケストレーション）

```typescript
// order-service/sagas/CreateOrderSaga.ts
@Injectable()
export class CreateOrderSaga {
  constructor(
    private commandBus: CommandBus,
    private eventBus: EventBus
  ) {}

  @Saga()
  orderCreated = (events$: Observable<IEvent>) => {
    return events$.pipe(
      ofType(OrderCreatedEvent),
      
      // Step 1: 在庫予約
      mergeMap((event: OrderCreatedEvent) =>
        of(new ReserveInventoryCommand(event.orderId, event.items)).pipe(
          mergeMap(cmd => this.commandBus.execute(cmd)),
          timeout(5000),  // 5秒でタイムアウト
          catchError(() => of(new CancelOrderCommand(event.orderId)))
        )
      ),

      // Step 2: 決済処理
      mergeMap((result: any) => {
        if (result instanceof CancelOrderCommand) {
          return of(result);  // ロールバック
        }

        return of(
          new ProcessPaymentCommand(event.orderId, event.totalAmount)
        ).pipe(
          mergeMap(cmd => this.commandBus.execute(cmd)),
          timeout(5000),
          catchError(() => of(new CancelOrderCommand(event.orderId)))
        );
      }),

      // Step 3: 配送手配
      mergeMap((result: any) => {
        if (result instanceof CancelOrderCommand) {
          return of(result);  // ロールバック
        }

        return of(
          new ArrangeShipmentCommand(event.orderId)
        ).pipe(
          mergeMap(cmd => this.commandBus.execute(cmd))
        );
      }),

      // エラー処理：サガ失敗時のキャンセルフローを発行
      catchError((error: any) =>
        of(new CancelOrderCommand(event.orderId))
      )
    );
  };

  @EventPattern('payment.failed')
  handlePaymentFailed(event: PaymentFailedEvent) {
    // Payment Service から通知（イベント）
    // Inventory のロックを解除
    this.commandBus.execute(
      new ReleaseInventoryCommand(event.orderId)
    );
  }
}
```

---

### 🗄️ イベントソーシング（オプション）

```typescript
// shared/event-store/EventStore.ts
export class EventStore {
  async append(event: DomainEvent): Promise<void> {
    // イベントログテーブルに append only で追加
    await this.db.query(`
      INSERT INTO events (aggregate_id, event_type, payload, created_at)
      VALUES (?, ?, ?, NOW())
    `, [
      event.getAggregateId(),
      event.constructor.name,
      JSON.stringify(event)
    ]);
  }

  async getEvents(aggregateId: string): Promise<DomainEvent[]> {
    // aggregateId のイベント履歴を取得
    const [rows] = await this.db.query(`
      SELECT payload FROM events
      WHERE aggregate_id = ?
      ORDER BY created_at ASC
    `, [aggregateId]);

    return rows.map(row => JSON.parse(row.payload));
  }

  // イベント再生で状態を復元
  async rebuild(aggregateId: string): Promise<Order> {
    const events = await this.getEvents(aggregateId);
    let order = null;

    for (const event of events) {
      if (event instanceof OrderCreatedEvent) {
        order = new Order(event.orderId, event.userId, [], OrderStatus.PENDING);
      } else if (event instanceof PaymentApprovedEvent) {
        order.status = OrderStatus.CONFIRMED;
      } else if (event instanceof OrderShippedEvent) {
        order.status = OrderStatus.SHIPPED;
      }
    }

    return order;
  }
}
```

---

### 📋 チェックリスト

```
サービス分割
✅ 各サービスが独立して展開可能
✅ データベースが独立
✅ サービス間は ID のみで参照

イベント駆動
✅ メッセージブローカー（RabbitMQ/Kafka）で通信
✅ イベントスキーマが版管理されている
✅ 非同期処理のタイムアウト設定

可用性・回復
✅ サガパターンでロールバック戦略がある
✅ デッドレターキューで失敗メッセージ保管
✅ リトライ戦略が定義されている
✅ Circuit Breaker パターン実装

監視
✅ サービス間の遅延を監視
✅ イベント配信遅延を監視
✅ デッドレターキュー監視アラート
```

---

### 関連リソース

- **メッセージング：** RabbitMQ, Apache Kafka, AWS SQS
- **マイクロサービスフレームワーク：** NestJS, Spring Cloud, Express + Decorators
- **分散トレーシング：** Jaeger, Zipkin

---

**完了！マイクロサービス構築マスター 🏭**

# 09: ツール・リソース - 実装支援 {#chapter-09-tools-and-resources}

## 01: フレームワーク比較 {#section-09-tools-and-resources-01-frameworks}


Web フレームワーク、CLI ツール、API フレームワークの比較と選定ガイド。

---

### 🎯 フレームワークの選定方法

| 判断軸 | 選定ポイント |
|-------|----------|
| **プロジェクト規模** | 小：Express, 中：NestJS, 大：Spring/NestJS |
| **チーム規模** | 小：シンプル, 大：ガイデッド（DI組込） |
| **学習曲線** | 急・緩かで判定 |
| **成熟度** | 本番運用経験・コミュニティサイズ |
| **エコシステム** | ライブラリ・親切の豊富さ |

---

### 🔷 Node.js / TypeScript フレームワーク

#### ① Express.js + Type-DI

**推奨度：⭐⭐⭐⭐⭐（初心者向け最適）**

```typescript
// インストール
npm install express type-di reflect-metadata

// 基本使用例
import { Container, Service, Inject } from 'typedi';
import express, { Request, Response } from 'express';

@Service()
export class UserService {
  constructor(@Inject() private userRepository: UserRepository) {}

  async getUser(id: string) {
    return this.userRepository.getById(id);
  }
}

@Service()
export class UserController {
  constructor(@Inject() private userService: UserService) {}

  async get(req: Request, res: Response) {
    const user = await this.userService.getUser(req.params.id);
    res.json(user);
  }
}

const app = express();
const userController = Container.get(UserController);

app.get('/users/:id', (req, res) => userController.get(req, res));
app.listen(3000);
```

**メリット：**
- シンプル（学習曲線が緩）
- ミニマル（不要機能がない）
- カスタマイズ性が高い
- 小〜中規模プロジェクトに最適

**デメリット：**
- 各機能を自分で組むことが多い
- Validation, Logging など標準機能がない

**適用ケース：**
- プロトタイプ・MVP
- チーム未経験者が多い
- 小規模スタートアップ

---

#### ② NestJS（推奨度：⭐⭐⭐⭐★）

**完全な DI・Validation・Testing が組み込まれた企業向けフレームワーク。**

```typescript
import { Controller, Get, Param, Injectable } from '@nestjs/common';

@Injectable()
export class UserService {
  constructor(
    private readonly userRepository: UserRepository
  ) {}

  async getUser(id: string) {
    return this.userRepository.findById(id);
  }
}

@Controller('users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Get(':id')
  async get(@Param('id') id: string) {
    return this.userService.getUser(id);
  }
}

// モジュール定義
import { Module } from '@nestjs/common';

@Module({
  controllers: [UserController],
  providers: [
    UserService,
    { provide: 'UserRepository', useClass: MySQLUserRepository }
  ]
})
export class UserModule {}
```

**メリット：**
- フル装備（DI, Validation, Logging, Guard など）
- デコレータベース（装飾的で読みやすい）
- テスティングが最初から設計
- エンタープライズ対応

**デメリット：**
- セットアップが複雑
- オーバーエンジニアリング可能性
- 学習曲線が急

**適用ケース：**
- 大規模・長期メンテナンスプロジェクト
- エンタープライズアプリケーション
- チームに経験者がいる

---

#### ③ Fastify + Awilix（推奨度：⭐⭐⭐⭐☆）

**最高速 HTTP サーバー + 軽量 DI。**

```typescript
import Fastify from 'fastify';
import { createContainer, asClass } from 'awilix';

const container = createContainer();
container.register({
  userService: asClass(UserService).singleton(),
  userRepository: asClass(MySQLUserRepository).singleton()
});

const fastify = Fastify();
const { userService } = container.cradle;

fastify.get('/users/:id', async (request, reply) => {
  const user = await userService.getUser(request.params.id);
  reply.send(user);
});

fastify.listen({ port: 3000 });
```

**メリット：**
- Express より3〜4倍高速
- Awilix は軽量かつ柔軟
- マイクロサービスに最適

**デメリット：**
- エコシステムが Express より小さい
- プラグインが少なめ

**適用ケース：**
- 高性能 API サーバー
- マイクロサービス
- IoT・組み込みシステム

---

### 🟠 Java フレームワーク

#### ① Spring Boot

**推奨度：⭐⭐⭐⭐⭐（エンタープライズ標準）**

```java
@SpringBootApplication
public class Application {
  public static void main(String[] args) {
    SpringApplication.run(Application.class, args);
  }
}

@Service
public class UserService {
  @Autowired
  private UserRepository userRepository;

  public User getUser(String id) {
    return userRepository.findById(id);
  }
}

@RestController
@RequestMapping("/users")
public class UserController {
  @Autowired
  private UserService userService;

  @GetMapping("/{id}")
  public User getUser(@PathVariable String id) {
    return userService.getUser(id);
  }
}
```

**メリット：**
- 成熟度が最高
- エンタープライズ機能が豊富
- 大規模チーム向けガイドラインが充実

**デメリット：**
- 学習曲線が急
- セットアップが複雑

**適用ケース：**
- 大規模エンタープライズ
- 金融・保険・行政システム

---

#### ② Quarkus

**推奨度：⭐⭐⭐⭐☆（クラウドネイティブ）**

```java
@Path("/users")
@Transactional
public class UserResource {
  @Inject
  UserService userService;

  @GET
  @Path("/{id}")
  public User getUser(@PathParam String id) {
    return userService.getUser(id);
  }
}
```

**メリット：**
- コンテナ最適化（超軽量・高速起動）
- Kubernetes に最適
- Spring Boot より小さいバイナリ

**デメリット：**
- 比較的新しい（2019年）
- エコシステムが成長中

**適用ケース：**
- クラウドネイティブ・Kubernetes
- マイクロサービス
- サーバーレス

---

### 🐍 Python フレームワーク

#### ① FastAPI + Dependency Injector

**推奨度：⭐⭐⭐⭐⭐（モダン）**

```python
from fastapi import FastAPI, Depends
from dependency_injector import containers, providers
from dependency_injector.wiring import Provide, inject

class Container(containers.DeclarativeContainer):
    user_repository = providers.Singleton(UserRepository)
    user_service = providers.Factory(
        UserService,
        repository=user_repository
    )

container = Container()
app = FastAPI()

@app.get("/users/{user_id}")
@inject
async def get_user(
    user_id: str,
    service: UserService = Depends(Provide[Container.user_service])
):
    return service.get_user(user_id)
```

**メリット：**
- 型安全（Python 3.10+）
- 非同期対応（async/await）
- 高性能（uvicorn）

**デメリット：**
- Python 特有（ポータビリティ）
- Web 以外のツール向き

**適用ケース：**
- 高性能 API
- データ分析・ML バックエンド
- 既存 Python コードベース

---

### 📊 フレームワーク比較表

| 項目 | Express | NestJS | Fastify | Spring Boot | Quarkus | FastAPI |
|------|---------|--------|---------|-----------|---------|---------|
| **学習曲線** | ⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| **性能** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **DI組込** | ❌ | ✅ | △ | ✅ | ✅ | ✅ |
| **Validation** | ❌ | ✅ | △ | ✅ | ✅ | ✅ |
| **本番実績** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **エコシステム** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

---

### 🎯 選定フローチャート

```
プロジェクトを始める
│
├─ MVP・プロトタイプ？
│  ├─ YES → Express + Type-DI
│  └─ NO ↓
│
├─ チーム規模 5名以上？
│  ├─ YES → NestJS（TypeScript）or Spring Boot（Java）
│  └─ NO → Express + Type-DI
│
├─ 高性能 API が必須？
│  ├─ YES → Fastify or FastAPI
│  └─ NO ↓
│
└─ エンタープライズ・金融系？
   ├─ YES → Spring Boot
   └─ NO → NestJS（TypeScript推奨）
```

---

### 📋 チェックリスト

```
フレームワーク選定
✅ プロジェクト規模を判定
✅ チーム経験度を考慮
✅ 学習曲線を確認
✅ エコシステム・ライブラリを調査
✅ 本番運用実績を確認
✅ DI・Validation が組み込まれているか
✅ テスティングサポートを確認
```

---

**次: [DI コンテナー →](#section-09-tools-and-resources-02-di-containers)**

## 02: DI コンテナー・IoC フレームワーク {#section-09-tools-and-resources-02-di-containers}


依存関係管理ツールの比較と実装方法。

---

### 🎯 DI コンテナーの役割

```
DI コンテナー = 自動依存関係管理ツール

機能：
  1. オブジェクトの生成（インスタンス化）
  2. 依存関係の自動注入
  3. ライフサイクル管理（singleton, 一時的など）
  4. 循環依存の検出
```

---

### 🔷 TypeScript 推奨 3選

#### ① Type-DI（最もシンプル）

**推奨度：⭐⭐⭐⭐⭐（初心者向け）**

```typescript
npm install typedi reflect-metadata

// reflect-metadata を最初に import
import 'reflect-metadata';
import { Container, Service, Inject } from 'typedi';

// サービスの定義
@Service()
export class UserRepository {
  async getById(id: string) {
    // DB接続などの実装
  }
}

@Service()
export class UserService {
  // 自動で UserRepository が注入される
  constructor(
    @Inject() private userRepository: UserRepository
  ) {}

  async getUser(id: string) {
    return this.userRepository.getById(id);
  }
}

// 使用
const userService = Container.get(UserService);
```

**メリット：**
- セットアップが簡単
- デコレータベース（読みやすい）
- TypeScript ネイティブ

**デメリット：**
- 複雑な設定には向かない
- インターフェース型の注入が難しい

**適用場面：**
- Express + DI の組み合わせ
- 小〜中規模プロジェクト

---

#### ② InversifyJS（複雑な設定向け）

**推奨度：⭐⭐⭐⭐☆（大規模向け）**

```typescript
npm install inversify reflect-metadata
npm install --save-dev @types/inversify

import 'reflect-metadata';
import { Container, injectable, inject } from 'inversify';

// インターフェース定義
interface IUserRepository {
  getById(id: string): Promise<User>;
}

// 実装
@injectable()
export class MySQLUserRepository implements IUserRepository {
  async getById(id: string) {
    // DB接続
  }
}

@injectable()
export class UserService {
  constructor(
    @inject('UserRepository')
    private userRepository: IUserRepository
  ) {}

  async getUser(id: string) {
    return this.userRepository.getById(id);
  }
}

// 設定
const TYPES = {
  UserRepository: Symbol.for('UserRepository'),
  UserService: Symbol.for('UserService')
};

const container = new Container();
container.bind<IUserRepository>(TYPES.UserRepository)
  .to(MySQLUserRepository);
container.bind<UserService>(TYPES.UserService)
  .to(UserService);

// 使用
const userService = container.get<UserService>(TYPES.UserService);
```

**メリット：**
- インターフェース型の注入が容易
- 複雑な設定に対応
- Transient / Singleton 詳細制御

**デメリット：**
- セットアップが複雑
- Symbol を使った設定が煩雑

**適用場面：**
- マイクロサービス
- プラグインアーキテクチャ

---

#### ③ Awilix（関数型好み向け）

**推奨度：⭐⭐⭐⭐☆（関数型プログラミング向け）**

```typescript
npm install awilix

import { createContainer, asClass, asFunction } from 'awilix';

const container = createContainer();

// 登録パターン色々
container.register({
  // ✅ Singleton（1回だけ作成）
  userRepository: asClass(MySQLUserRepository).singleton(),

  // ✅ Transient（毎回作成）
  userService: asClass(UserService).transient(),

  // ✅ Factory function
  config: asFunction(() => ({
    dbUrl: process.env.DATABASE_URL
  })).singleton(),

  // ✅ Value
  logger: asValue(console)
});

// 自動解決（引数名で依存関係を判定）
class UserService {
  constructor(userRepository, config, logger) {
    this.userRepository = userRepository;
    this.config = config;
    this.logger = logger;
  }
}

// 使用
const { userService } = container.cradle;
```

**メリット：**
- 設定がシンプル（引数名がキー）
- オブジェクト分割代入で使える
- Fastify と相性良い

**デメリット：**
- 引数名に依存（リファクタリングで不可視）
- 型安全性が低い（any）

**適用場面：**
- Fastify プロジェクト
- 小〜中規模 CLI
- 関数型プログラミング重視

---

### 🟠 Java 推奨 2選

#### ① Spring DI（Spring Boot 組み込み）

**推奨度：⭐⭐⭐⭐⭐（標準）**

```java
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;

@Service
public class UserRepository {
  // DB 接続コード
}

@Service
public class UserService {
  // 自動で UserRepository が注入される
  @Autowired
  private UserRepository userRepository;

  public User getUser(String id) {
    return userRepository.getById(id);
  }
}

// または コンストラクタ注入（推奨）
@Service
public class UserService {
  private final UserRepository userRepository;

  @Autowired
  public UserService(UserRepository userRepository) {
    this.userRepository = userRepository;
  }
}

// 使用
@Configuration
public class AppConfig {
  @Bean
  public UserRepository userRepository() {
    return new MySQLUserRepository();
  }

  @Bean
  public UserService userService(UserRepository repo) {
    return new UserService(repo);
  }
}
```

**メリット：**
- Spring Boot に統合
- 大規模エコシステム
- 成熟度が最高

**デメリット：**
- 自動配線の魔法性（追跡困難）
- セットアップが複雑

---

#### ② Guice（軽量代替）

**推奨度：⭐⭐⭐⭐☆（軽量志向）**

```java
import com.google.inject.*;

// インターフェース定義
public interface UserRepository {
  User getById(String id);
}

// 実装
public class MySQLUserRepository implements UserRepository {
  public User getById(String id) { ... }
}

@Singleton
public class UserService {
  private final UserRepository repo;

  @Inject
  public UserService(UserRepository repo) {
    this.repo = repo;
  }
}

// 設定
public class AppModule extends AbstractModule {
  @Override
  protected void configure() {
    bind(UserRepository.class)
      .to(MySQLUserRepository.class)
      .in(Scopes.SINGLETON);
    
    bind(UserService.class);
  }
}

// 使用
Injector injector = Guice.createInjector(new AppModule());
UserService service = injector.getInstance(UserService.class);
```

**メリット：**
- Spring より軽量
- 設定が明示的
- 小規模プロジェクトに最適

**デメリット：**
- Spring Boot より機能が少ない
- エコシステムが小さい

---

### 🐍 Python 推奨

#### Dependency Injector

**推奨度：⭐⭐⭐⭐☆**

```python
from dependency_injector import containers, providers

class Container(containers.DeclarativeContainer):
    # Config
    config = providers.Configuration()
    
    # Repositories
    user_repository = providers.Singleton(
        UserRepository,
        db_url=config.db.url
    )
    
    # Services
    user_service = providers.Factory(
        UserService,
        repository=user_repository
    )

# 使用
container = Container()
user_service = container.user_service()
```

---

### 📊 DI コンテナー比較表

| 項目 | Type-DI | InversifyJS | Awilix | Spring | Guice |
|------|---------|-----------|--------|--------|-------|
| **学習曲線** | ⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **セットアップ** | ⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ |
| **複雑設定対応** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **型安全性** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **エコシステム** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

### 🎯 選定フロー

```
プロジェクトでDI容器を選ぶ
│
├─ TypeScript プロジェクト？
│  ├─ 小規模・Express
│  │  └─> Type-DI ✅
│  │
│  ├─ 中規模・複雑
│  │  └─> InversifyJS or Awilix ✅
│  │
│  └─ 大規模・NestJS
│     └─> NestJS組込DI ✅
│
├─ Java プロジェクト？
│  ├─ Spring Boot
│  │  └─> Spring DI ✅
│  │
│  └─ 軽量志向
│     └─> Guice ✅
│
└─ Python プロジェクト？
   └─> dependency-injector ✅
```

---

### 📋 チェックリスト

```
DI設定
✅ 循環依存がない
✅ ライフサイクル（Singleton/Transient）が適切
✅ 自動解決可能か明示的か が一貫
✅ テストでモック化可能

設定管理
✅ 本番・開発で設定を切り替え
✅ 環境変数から読み込み
✅ 設定がシングルソース・オブ・トゥルース（SSOT）
```

---

**次: [開発ツール →](#section-09-tools-and-resources-03-development-tools)**

## 03: 開発ツール（テスト・分析・ビルド） {#section-09-tools-and-resources-03-development-tools}


プロジェクト品質を高めるための開発支援ツール。

---

### 🧪 テストツール

#### ユニットテスト：Jest（Node.js 標準）

```bash
npm install --save-dev jest @types/jest ts-jest

# jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.ts', '**/?(*.)+(spec|test).ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.interface.ts',
    '!src/main.ts'
  ],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 80,
      lines: 80,
      statements: 80
    }
  }
};
```

**テスト例：ドメイン層**

```typescript
// src/domain/Email.test.ts
describe('Email', () => {
  it('should validate email format', () => {
    expect(() => new Email('invalid')).toThrow(InvalidEmailError);
    expect(() => new Email('valid@example.com')).not.toThrow();
  });

  it('should normalize email', () => {
    const email = new Email('USER@EXAMPLE.COM');
    expect(email.getValue()).toBe('user@example.com');
  });
});

describe('Money', () => {
  it('should not allow negative amounts', () => {
    expect(() => new Money(-100)).toThrow();
  });

  it('should add amounts correctly', () => {
    const m1 = new Money(100);
    const m2 = new Money(50);
    expect(m1.add(m2).value).toBe(150);
  });

  it('should throw error when subtracting more than available', () => {
    const m1 = new Money(100);
    const m2 = new Money(150);
    expect(() => m1.subtract(m2)).toThrow();
  });
});
```

**テスト例：ユースケース層（Mock利用）**

```typescript
// src/application/CreateUserUseCase.test.ts
describe('CreateUserUseCase', () => {
  let useCase: CreateUserUseCase;
  let mockUserRepository: jest.Mocked<UserRepository>;
  let mockEmailService: jest.Mocked<EmailService>;

  beforeEach(() => {
    // Mock 実装
    mockUserRepository = {
      save: jest.fn(),
      getByEmail: jest.fn(),
      getById: jest.fn(),
      findAll: jest.fn()
    };

    mockEmailService = {
      send: jest.fn()
    };

    useCase = new CreateUserUseCase(
      mockUserRepository,
      mockEmailService
    );
  });

  it('should create user successfully', async () => {
    const request = {
      email: 'user@example.com',
      password: 'StrongPass123!',
      name: 'John Doe'
    };

    mockUserRepository.getByEmail.mockResolvedValue(null);

    const response = await useCase.execute(request);

    expect(response.userId).toBeDefined();
    expect(mockUserRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        email: expect.any(Email)
      })
    );
    expect(mockEmailService.send).toHaveBeenCalledWith(
      'user@example.com',
      expect.stringContaining('Welcome')
    );
  });

  it('should throw error if user already exists', async () => {
    const request = {
      email: 'existing@example.com',
      password: 'StrongPass123!',
      name: 'Existing User'
    };

    mockUserRepository.getByEmail.mockResolvedValue(
      new User('1', new Email('existing@example.com'), 'Existing User')
    );

    await expect(useCase.execute(request)).rejects.toThrow(
      UserAlreadyExistsError
    );
  });
});
```

**実行コマンド**

```bash
npm test                    # すべてのテスト実行
npm test -- --coverage     # カバレッジ計測
npm test -- --watch        # ウォッチモード
npm test -- --bail         # 最初の失敗で停止
```

---

#### 統合テスト：Supertest（HTTP テスト）

```typescript
// src/presentation/controllers/UserController.test.ts
import request from 'supertest';
import { createApp } from '../../../app';

describe('GET /users/:id', () => {
  let app: Express.Application;

  beforeAll(() => {
    app = createApp();
  });

  it('should return user by id', async () => {
    const response = await request(app)
      .get('/users/1')
      .expect(200);

    expect(response.body).toHaveProperty('id', '1');
    expect(response.body).toHaveProperty('email');
  });

  it('should return 404 for non-existent user', async () => {
    await request(app)
      .get('/users/999')
      .expect(404);
  });
});

describe('POST /users', () => {
  let app: Express.Application;

  beforeAll(() => {
    app = createApp();
  });

  it('should create user with valid data', async () => {
    const response = await request(app)
      .post('/users')
      .send({
        email: 'newuser@example.com',
        password: 'StrongPass123!',
        name: 'New User'
      })
      .expect(201);

    expect(response.body).toHaveProperty('id');
  });

  it('should return 422 for invalid email', async () => {
    await request(app)
      .post('/users')
      .send({
        email: 'invalid-email',
        password: 'StrongPass123!',
        name: 'User'
      })
      .expect(422);
  });
});
```

---

#### E2E テスト：TestContainers（本物の DB でテスト）

```typescript
// integration test with real database
import { GenericContainer, StartedTestContainer } from 'testcontainers';

describe('User Integration Tests', () => {
  let container: StartedTestContainer;
  let connection: mysql.Connection;

  beforeAll(async () => {
    // MySQL コンテナ起動
    container = await new GenericContainer('mysql:8')
      .withExposedPorts(3306)
      .withEnvironment({
        MYSQL_ROOT_PASSWORD: 'root',
        MYSQL_DATABASE: 'test_db'
      })
      .start();

    const host = container.getHost();
    const port = container.getMappedPort(3306);

    // コネクション作成
    connection = await mysql.createConnection({
      host,
      port,
      user: 'root',
      password: 'root',
      database: 'test_db'
    });

    // スキーマ実行
    await connection.query(`
      CREATE TABLE users (
        id VARCHAR(36) PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL
      )
    `);
  });

  afterAll(async () => {
    await connection.end();
    await container.stop();
  });

  it('should save and retrieve user from DB', async () => {
    const userRepository = new MySQLUserRepository(connection);
    const user = new User('1', new Email('test@example.com'), 'Test User');

    await userRepository.save(user);
    const retrieved = await userRepository.getById('1');

    expect(retrieved).toBeDefined();
    expect(retrieved?.email.getValue()).toBe('test@example.com');
  });
});
```

---

### 📊 コード品質ツール

#### 静的解析：ESLint + TypeScript Plugin

```bash
npm install --save-dev eslint @typescript-eslint/eslint-plugin @typescript-eslint/parser

# .eslintrc.json
{
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "extends": ["plugin:@typescript-eslint/recommended"],
  "rules": {
    "no-console": "warn",
    "prefer-const": "error",
    "@typescript-eslint/explicit-function-return-types": "error",
    "@typescript-eslint/no-explicit-any": "error"
  },
  "env": {
    "node": true,
    "es2022": true
  }
}

npx eslint src/**/*.ts
```

#### 循環依存检出：madge

```bash
npm install --save-dev madge

# 循環依存を検出
npx madge --circular src/

# グラフを画像出力
npx madge --image graph.png src/

# 詳細情報
npx madge --list src/
```

#### セキュリティスキャン：Snyk

```bash
npm install --save-dev snyk

# 脆弱性をスキャン
npx snyk test

# 修正提案を表示
npx snyk fix
```

---

### 🔨 ビルド・パッケージング

#### TypeScript コンパイル

```bash
npm install --save-dev typescript

# tsconfig.json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "sourceMap": true,
    "declaration": true
  }
}

# コンパイル
npx tsc

# package.json scripts
{
  "scripts": {
    "build": "tsc",
    "start": "node dist/main.js",
    "dev": "ts-node src/main.ts"
  }
}
```

---

### 📈 パフォーマンス計測

#### Clinic.js（本番問題診断）

```bash
npm install --save-dev clinic

# CPU, メモリ, 遅延を計測
clinic doctor -- npm start

# グラフで可視化
clinic doctor -- npm test
```

---

### 📋 チェックリスト

```
テスト
✅ ユニットテスト：80%+ カバレッジ
✅ 統合テスト：主要フロー
✅ E2E テスト：ユーザーシナリオ
✅ テストが CI/CD に統合

品質
✅ ESLint で文法チェック
✅ 循環依存なし（madge）
✅ セキュリティスキャン（Snyk）
✅ パフォーマンスモニタリング

ビルド
✅ TypeScript コンパイルエラーなし
✅ ビルドサイズが許容範囲
✅ ソースマップが生成
```

---

**次: [学習リソース →](#section-09-tools-and-resources-04-learning-resources)**

## 04: 学習リソース {#section-09-tools-and-resources-04-learning-resources}


Clean Architecture と DDD の学習に役立つ本、コース、コミュニティ。

---

### 📚 必読書籍

#### 第1順位：「Clean Architecture」 Robert C. Martin

```
タイトル: Clean Architecture: 
          A Craftsman's Guide to Software Structure and Design

著者: Robert C. Martin（Uncle Bob）
出版社: Prentice Hall
初版: 2017年
言語: 英語・日本語
推奨度: ⭐⭐⭐⭐⭐

内容：
- Clean Architecture の背景・哲学
- 5つの層（データ、境界、ユースケース、エンティティ、フレームワーク）
- 依存関係の方向（外 → 内）
- 実装パターン・テスト戦略

いつ読むべき？
→ Clean Architecture を理解し始めたら必読

Amazon リンク：
https://amazon.co.jp/s?k=Clean+Architecture+Robert+Martin
```

#### 第2順位：「Domain-Driven Design」Eric Evans

```
タイトル: Domain-Driven Design:
          Tackling Complexity in the Heart of Software

著者: Eric Evans
出版社: Addison-Wesley
初版: 2003年
言語: 英語・日本語
推奨度: ⭐⭐⭐⭐⭐

内容：
- Ubiquitous Language（共通言語）
- Bounded Context（境界のあるコンテキスト）
- エンティティ・値オブジェクト設計
- ドメインサービス・リポジトリ
- ドメイン駆動型アーキテクチャ

いつ読むべき？
→ ドメイン層設計が複雑になったら

Amazon リンク：
https://amazon.co.jp/s?k=Domain-Driven+Design+Eric+Evans
```

#### 第3順位：「Building Microservices」Sam Newman

```
タイトル: Building Microservices:
          Designing Fine-Grained Systems (2nd Edition)

著者: Sam Newman
出版社: O'Reilly Media
初版: 2015年（第2版: 2021年）
言語: 英語・日本語
推奨度: ⭐⭐⭐⭐★

内容：
- サービス分割戦略
- サービス間通信（RESTful, gRPC, イベント駆動）
- 分散トランザクション・Saga パターン
- デプロイ・監視・トレーシング

いつ読むべき？
→ マイクロサービス化を検討する場面

Amazon リンク：
https://amazon.co.jp/Building-Microservices-Sam-Newman/dp/4873117606
```

#### 番外編：「Refactoring」Martin Fowler

```
タイトル: Refactoring: Improving the Design of Existing Code (2nd Edition)

著者: Martin Fowler
出版社: Addison-Wesley
初版: 1999年（第2版: 2018年）
推奨度: ⭐⭐⭐⭐★

内容：
- リファクタリング手法
- テスト駆動開発との組み合わせ
- コード臭い（Code Smells）の検出
- 段階的な設計改善

いつ読むべき？
→ 既存コードをクリーンアップしたい時
```

---

### 🎓 オンラインコース

#### Udemy

```
コース1: "Clean Architecture: Applying Domain Driven Design"
講師: Mosh Hamedani
対象: JavaScript/TypeScript
価格: $14.99 - $99.99
推奨度: ⭐⭐⭐⭐⭐

特徴：
- 実装中心
- 日本語字幕あり
- 4時間のビデオ
- 演習付き

Link: https://www.udemy.com/course/clean-code-in-javascript/

---

コース2: "Microservices Architecture"
講師: Sam Newman (提供フォーマット: Pluralsight)
対象: Java / Go / Python
推奨度: ⭐⭐⭐⭐★

特徴：
- マイクロサービス設計
- 実装パターン
- トラブルシューティング
```

#### Pluralsight

```
コース: "Clean Code: Writing Code for Humans"
講師: Cory House
対象: C# / Java / JavaScript
推奨度: ⭐⭐⭐⭐★

特徴：
- 多言語対応
- テスト駆動開発
- リファクタリング
- 実装例豊富
```

---

### 📝 ブログ・記事

#### Uncle Bob's Blog

```
URL: https://blog.cleancoder.com/

主要記事：
- "The Clean Architecture"
- "Screaming Architecture"
- "The Dependency Rule"

更新頻度: 月1-2回
対象: エンジニア全般
```

#### Martin Fowler's Blog

```
URL: https://martinfowler.com/

主要セクション：
- Articles（建築パターン・デザイン）
- Microservices（マイクロサービス）
- Testing（テスト戦略）

推奨記事：
- "Microservice Prerequisites"
- "Event Sourcing"
- "CQRS"

更新頻度: 月2-3回
対象: アーキテクト・Lead Engineer
```

#### DDD Community

```
URL: https://ddd-community.org/

コンテンツ：
- Domain-Driven Design の解説
- 実装パターン
- ケーススタディ
- コミュニティイベント

推奨：
- "DDD in a Nutshell"
- "Bounded Contexts"
- ドメインモデリングワークショップ
```

---

### 🏢 実装テンプレート・サンプル

#### GitHub リポジトリ

##### ① clean-architecture-manga

```
Repository: https://github.com/joeyhu/clean-architecture-manga

特徴：
- マンガで Learn Clean Architecture
- 視覚的に理解しやすい
- ビギナー向け
- 言語: 日本語
```

##### ② nestjs-clean-architecture-example

```
Repository: https://github.com/rmanguinho/clean-node-api

特徴：
- Node.js + Express + Clean Architecture
- 完全な実装例
- テストカバレッジ 100%
- CI/CD パイプライン

フォルダ構造：
src/
├─ domain/
├─ presentation/
├─ data/（データベース層）
├─ main/（Bootstrap）
└─ validation/

対象: TypeScript/JavaScript
```

##### ③ typescript-clean-architecture-examples

```
Repository: https://github.com/wanghao1993/clean-architecture-typescript

特徴：
- TypeScript native
- 複数のドメイン例
- マイクロサービス例
- Docker 設定

提供例：
- 基本的な CRUD
- ユーザー管理
- 注文処理
```

#### プロジェクト生成コマンド

```bash
# Express + Clean Architecture テンプレート
npx create-clean-app my-app

# NestJS + 標準的なフォルダ構造
nest new my-app
cd my-app
nest generate module users
nest generate service domain/users/user.service
```

---

### 💬 コミュニティ

#### チャット・フォーラム

```
Slack チャンネル：
- DDD Community Slack
  → https://ddd-community.slack.com/
  メンバー: 12,000+ (2024)

Discord サーバー：
- Node.js Japan
  → https://discord.gg/invite-link
  主催: Node.js コミュニティ

Reddit（英語）：
- r/webdev
  → https://reddit.com/r/webdev
- r/typescript
  → https://reddit.com/r/typescript
```

#### GitHub Discussions

```
クリーンアーキテクチャに関する質問：
- clean-architecture リポジトリの Discussions
- Node.js/TypeScript 関連リポジトリ

投稿例：
- ベストプラクティス相談
- アーキテクチャレビュー
- 設計パターン質問
```

---

### 🎉 カンファレンス

#### Node.js・Web 系

```
📅 JSConf JP
   会期: 毎年11月
   開催地: 日本（東京/大阪）
   URL: https://jsconf.jp/
   特徴: 国内最大級 JavaScript カンファレンス

📅 NodeFest
   会期: 毎年9月
   開催地: 日本
   特徴: Node.js 専門

📅 Web Directions Summit
   会期: 毎年12月
   開催地: オーストラリア（オンライン参加可）
   特徴: Web design・フロントエンド
```

#### アーキテクチャ・システム設計

```
📅 CraftConf
   会期: 毎年4月
   開催地: ハンガリー・ブダペスト
   URL: https://craft-conf.com/
   特徴: アーキテクチャ・デザイン重視

📅 DDD Europe
   会期: 毎年10月
   開催地: バルセロナ（オンライン開催も）
   URL: https://ddd-eu.com/
   特徴: Domain-Driven Design 専門

📅 GOTO Conferences
   会期: 通年開催
   開催地: 複数地点
   URL: https://goto.con/
   特徴: トップエンジニアの講演
```

---

### 📋 学習パス

#### ビギナー向け（週１時間 × 4 週間）

```
Week 1: 基礎理解
   - 「Clean Architecture」 の概要（YouTube動画5分）
   - Udemy コース第1〜3章

Week 2: ドメイン層
   - Domain-Driven Design 初章
   - 値オブジェクト・エンティティの実装

Week 3: 実装
   - サンプルリポジトリ（clean-architecture-manga）を読む
   - 簡単な CRUD アプリを実装

Week 4: テスト・チューニング
   - ユニットテスト・統合テスト実装
   - コードレビュー・改善
```

#### 中級者向け（週２時間 × 8 週間）

```
Week 1-2: 「Clean Architecture」 完読
Week 3-4: 「Domain-Driven Design」 第一部
Week 5-6: 実装テンプレート徹底研究
Week 7-8: マイクロサービス設計（Building Microservices）
```

---

### 📋 チェックリスト

```
学習リソース選定
✅ 自分の現在レベルを把握
✅ 目標（基礎/実装/アーキテクチャ設計）を明確化
✅ 本・動画・コミュニティをバランスよく利用
✅ 定期的に実装して手を動かす
✅ コミュニティで他者の知見を吸収

知識定着
✅ インプット後に実装練習
✅ 同僚にアウトプット・説明
✅ プロジェクトで実践
✅ 定期的に見直し
```

---

**完了！ Clean Architecture マスターへようこそ 🎓**

**次のアクション：**
1. 推奨書籍を1冊選んで読む
2. サンプルリポジトリをクローンして研究
3. 小規模プロジェクトで実装してみる
4. コミュニティに参加して知見共有

**本ガイドの各セクションをもう一度確認：**
- [実装ガイド](#chapter-05-implementation-guide) ← 実装開始
- [ベストプラクティス](#chapter-06-best-practices) ← 品質向上
- [よくある間違い](#chapter-07-common-pitfalls) ← アンチパターン回避
- [ケーススタディ](#chapter-08-case-studies) ← 実装例学習
