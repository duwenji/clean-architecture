# 01: 命名規則

チーム全体で一貫した、読みやすいコードを書くための命名ルール。

---

## 🎯 命名の原則

**良い命名とは：**
- 🔹 意図が明確
- 🔹 スコープで長さが決まる
- 🔹 チーム内で統一
- 🔹 誤解の余地がない

---

## 📐 階層別の命名規則

### クラス・インターフェース

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

### メソッド・関数

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

### 変数・定数

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

## 🏗️ クリーンアーキテクチャ特有の命名

### リポジトリ

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

### ユースケース

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

### ドメイン層

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

### プレゼンテーション層

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

## 📋 命名パターン早見表

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

## 🎯 チェックリスト

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

**次: [エラーハンドリング →](./02-error-handling.md)**
