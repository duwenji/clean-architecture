# 01: 過度な設計（Over-Engineering）

プロジェクト規模に適していない複雑な設計を避ける。

---

## 🎯 問題

小規模プロジェクトに不必要なレイヤーを追加し、複雑化させる。実装効率が低下し、保守性が向上しない。

---

## 📍 具体例：不適切な設計

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

## ✅ 解決策：段階的な設計

### フェーズ1: MVP（最小限）0-5機能

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

### フェーズ2: 成長期（5-30機能）

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

### フェーズ3: スケール期（30+機能）

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

## 📋 判断基準チェックリスト

| 質問 | YES | NO |
|-----|-----|-----|
| チーム規模が5名以上か | → フェーズ3検討 | → フェーズ1-2 |
| 機能が30個以上あるか | → フェーズ3 | → フェーズ1-2 |
| ビジネスロジックが複雑か | → フェーズ3 | → フェーズ1-2 |
| 複数人が並行開発するか | → フェーズ3 | → フェーズ1-2 |
| 保守期間が1年以上か | → フェーズ3 | → フェーズ1-2 |
| 自動テストが必須か | → フェーズ3, フェーズ2 | → フェーズ1 |

---

## 🔄 段階的なマイグレーション

### フェーズ1 → フェーズ2 への移行

```typescript
// Before: すべてが index.ts

// After: 機能ごとに分割
app.use('/api/users', userRouter);
app.use('/api/orders', orderRouter);
app.use('/api/products', productRouter);
```

### フェーズ2 → フェーズ3 への移行

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

## 📋 チェックリスト

```
✅ 現在のチーム規模に適切な設計を選択
✅ 機能数に応じてフェーズを判定
✅ 過度な抽象化を避ける
✅ チーム全体が設計を理解している
✅ 必要になってから層を追加
✅ 「YAGNI（You Aren't Gonna Need It）」原則を守る
```

---

**次: [密結合の回避 →](./02-tight-coupling.md)**
