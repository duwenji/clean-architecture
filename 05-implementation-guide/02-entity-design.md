# 02: エンティティ設計

ドメイン層の中核であるエンティティと値オブジェクトの設計・実装を学びます。

## 🎯 エンティティとは

**定義:** ビジネス的に意味のある、アイデンティティを持つオブジェクト

**特徴:**
- 一意な ID を持つ
- ライフサイクルがある（作成 → 変更 → 削除）
- ビジネスロジックを内包する
- DB テーブルと1対1対応（多くの場合）

---

## 📊 ユーザー管理システムの場合

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

## 💡 値オブジェクトとは

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

## 📝 実装例 1: Email 値オブジェクト

### ❌ 悪い例（値オブジェクトがない）

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

### ✅ 良い例（値オブジェクトを使う）

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

## 📝 実装例 2: Password 値オブジェクト

### ❌ 悪い例

```typescript
// ❌ NG: パスワードが string のまま
class User {
  private password: string;  // ハッシュ化されているか不明確

  setPassword(plainPassword: string) {
    this.password = plainPassword;  // 平文で保存？ハッシュ？不明確
  }
}
```

### ✅ 良い例

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

## 📝 実装例 3: User エンティティ（完全版）

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

## 🔍 値オブジェクトまとめ

| 値オブジェクト | 持つビジネスルール | 例 |
|-------------|-------------|-----|
| `Email` | メール形式チェック、ドメイン抽出 | `user@example.com` |
| `Password` | 強度チェック、ハッシュ化、マッチング | 8文字以上、大文字含む |
| `Money` | 通貨単位の統一、計算 | 100 JPY + 50 JPY = 150 JPY |
| `Range` | 日付範囲の妥当性チェック | 開始日 < 終了日 |
| `UserId` | ID形式チェック | UUID形式 |
| `PhoneNumber` | 電話番号形式チェック | +81-90-XXXX-XXXX |

---

## 🚀 実装チェックリスト

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

## 🎯 実装例の起動コード

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

**次: [ユースケース設計 →](./03-usecase-design.md)**
