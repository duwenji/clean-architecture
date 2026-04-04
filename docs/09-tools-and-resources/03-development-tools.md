# 03: 開発ツール（テスト・分析・ビルド）

プロジェクト品質を高めるための開発支援ツール。

---

## 🧪 テストツール

### ユニットテスト：Jest（Node.js 標準）

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

### 統合テスト：Supertest（HTTP テスト）

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

### E2E テスト：TestContainers（本物の DB でテスト）

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

## 📊 コード品質ツール

### 静的解析：ESLint + TypeScript Plugin

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

### 循環依存检出：madge

```bash
npm install --save-dev madge

# 循環依存を検出
npx madge --circular src/

# グラフを画像出力
npx madge --image graph.png src/

# 詳細情報
npx madge --list src/
```

### セキュリティスキャン：Snyk

```bash
npm install --save-dev snyk

# 脆弱性をスキャン
npx snyk test

# 修正提案を表示
npx snyk fix
```

---

## 🔨 ビルド・パッケージング

### TypeScript コンパイル

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

## 📈 パフォーマンス計測

### Clinic.js（本番問題診断）

```bash
npm install --save-dev clinic

# CPU, メモリ, 遅延を計測
clinic doctor -- npm start

# グラフで可視化
clinic doctor -- npm test
```

---

## 📋 チェックリスト

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

**次: [学習リソース →](./04-learning-resources.md)**
