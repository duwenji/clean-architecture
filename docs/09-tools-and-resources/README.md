# 09: ツール・リソース - 実装支援

クリーンアーキテクチャを効果的に実装するための、推奨ツール・フレームワーク・リソースをまとめます。

---

## 📚 セクション構成

| # | カテゴリ | 内容 |
|---|---------|---|
| [01](./01-frameworks.md) | **フレームワーク** | Express, NestJS, Spring Boot, FastAPI 比較 |
| [02](./02-di-containers.md) | **DI/IoC Container** | Type-DI, InversifyJS, Awilix, Spring DI |
| [03](./03-development-tools.md) | **開発ツール** | Jest, Supertest, TestContainers, ESLint, madge, Snyk |
| [04](./04-learning-resources.md) | **学習リソース** | 書籍、Udemy/Pluralsight、ブログ、GitHub、コミュニティ |

---

## 🔧 推奨フレームワーク

### Node.js / TypeScript

```yaml
🥇 Express + Type-DI
  利点: シンプル、学習曲線が緩い、カスタマイズ性
  欠点: 機能が最小限
  用途: 小〜中規模プロジェクト
  例: const app = express(); app.use('/user', new UserController());

🥈 NestJS
  利点: フル装備（DI, Validation, Testing）、エンタープライズ対応
  欠点: セットアップが複雑
  用途: 大規模・スケーラブルなプロジェクト
  例: @Controller('users') class UserController { ... }

🥉 Fastify + Awilix
  利点: 超高速、堅牢な DI
  欠点: エコシステムが小さい
  用途: 高速API、マイクロサービス
  例: fastify.register(require('fastify-awilix'));
```

### Java

```yaml
🥇 Spring Boot + Spring Framework
  利点: 成熟、豊富なライブラリエコシステム
  用途: エンタープライズアプリケーション
  例: @Service public class UserService { @Autowired UserRepository repo; }

🥈 Quarkus
  利点: コンテナ最適化、高速起動
  用途: クラウドネイティブ・マイクロサービス
  例: @ApplicationScoped public class UserService { ... }
```

### Python

```yaml
🥇 FastAPI + Dependency Injector
  利点: モダン、型安全、高速
  用途: 高性能 API
  例: app = FastAPI(); @app.get("/users/{id}") async def get_user(id: str) ...

🥈 Django + dependency-injector
  利点: 成熟、多機能
  用途: フルスタック webアプリ
  例: class UserView(View): def __init__(self, service: UserService) ...
```

---

## 💉 DI Container・IoC フレームワーク

### TypeScript 推奨

```typescript
// ① Type-DI（最もシンプル）
import { Container, Service, Inject } from 'typedi';

@Service()
export class UserService {
  constructor(@Inject() private repo: UserRepository) {}
}

const userService = Container.get(UserService);

// ② InversifyJS（複雑な設定向け）
import { Container, injectable, inject } from 'inversify';

container.bind<UserService>(TYPES.UserService)
  .to(UserService);
container.bind<UserRepository>(TYPES.UserRepository)
  .to(MySQLUserRepository);

const userService = container.get<UserService>(TYPES.UserService);

// ③ Awilix（関数型好み向け）
const container = createContainer();
container.register({
  userService: asClass(UserService).singleton(),
  userRepository: asClass(MySQLUserRepository).singleton()
});

const { userService } = container.cradle;
```

### Java 推奨

```java
// Spring DI（標準）
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

// Guice（軽量な代替）
Injector injector = Guice.createInjector(new AbstractModule() {
  @Override
  protected void configure() {
    bind(UserRepository.class).to(MySQLUserRepository.class);
    bind(UserService.class);
  }
});

UserService service = injector.getInstance(UserService.class);
```

---

## 🧪 テストツール

### ユニットテスト

```typescript
// Node.js
┌─ Jest （推奨）
│  ✅ マッ ク機能組み込み
│  ✅ Snapshot テスト対応
│  ✅ カバレッジ自動計算
│  例: npm test -- --coverage
│
├─ Vitest （Vite統合）
│  ✅ 高速
│  ✅ ESM対応
│  例: npm run test
│
└─ Mocha + Chai
   ✅ 柔軟性
   例: describe('UserService', () => { ... })

// 実装例：ドメイン層テスト
describe('Email', () => {
  it('should validate email format', () => {
    expect(() => new Email('invalid')).toThrow(InvalidEmailError);
    expect(() => new Email('valid@example.com')).not.toThrow();
  });
});

// 実装例：USE CASE テスト（Mock 活用）
describe('CreateUserUseCase', () => {
  let useCase: CreateUserUseCase;
  let mockRepository: jest.Mocked<UserRepository>;

  beforeEach(() => {
    mockRepository = {
      save: jest.fn(),
      getByEmail: jest.fn(),
    };
    useCase = new CreateUserUseCase(mockRepository);
  });

  it('should save user', async () => {
    const request = { email: 'user@example.com', password: 'pass123' };
    await useCase.execute(request);
    
    expect(mockRepository.save).toHaveBeenCalled();
  });
});
```

### 統合テスト

```typescript
// Supertest（HTTP API テスト）
import request from 'supertest';
import app from '../app';

describe('POST /users', () => {
  it('should create user', async () => {
    const response = await request(app)
      .post('/users')
      .send({ email: 'test@example.com', password: 'pass123' })
      .expect(201);

    expect(response.body).toHaveProperty('id');
  });
});

// TestContainers（本物のDB でテスト）
const container = new GenericContainer('mysql:8')
  .withExposedPorts(3306)
  .withEnvironment({
    MYSQL_ROOT_PASSWORD: 'root',
    MYSQL_DATABASE: 'test'
  });

const startedContainer = await container.start();
const host = startedContainer.getHost();
const port = startedContainer.getMappedPort(3306);

// テスト用DBに接続
const connection = await mysql.createConnection({
  host, port,
  user: 'root', password: 'root', database: 'test'
});

await startedContainer.stop();
```

---

## 📊 分析・品質ツール

```bash
# 依存関係分析
npm install --save-dev madge
npx madge --circular src/        # 循環依存を検出
npx madge --image graph.png src/  # グラフを可視化

# 静的解析
npm install --save-dev eslint @typescript-eslint/eslint-plugin
npx eslint src/**/*.ts

# テストカバレッジ
npm test -- --coverage
# Coverage キー指標（目標値）
# Statements: 80%+
# Branches: 75%+
# Functions: 80%+
# Lines: 80%+

# パフォーマンス測定
npm install --save-dev clinic
clinic doctor -- npm start
# CPU, メモリ, 遅延を可視化

# セキュリティスキャン
npm install --save-dev snyk
npx snyk test  # 脆弱性をスキャン
```

---

## 🔨 開発支援ツール

### プロジェクト生成テンプレート

```bash
# Express + Clean Architecture テンプレート
git clone https://github.com/YOUR_ORG/clean-arch-template
cd clean-arch-template
npm install

# 構造
src/
├─ presentation/
│  └─ controllers/
├─ application/
│  └─ usecases/
├─ domain/
│  ├─ entities/
│  └─ services/
└─ infrastructure/
   ├─ repositories/
   └─ adapters/
```

### 自動生成ツール

```bash
# TypeORM エンティティジェネレータ
npm install -g @typeorm/cli
typeorm-cli migration:generate -n CreateUserTable

# Swagger/OpenAPI ジェネレータ
npm install --save-dev @nestjs/swagger swagger-ui-express
# NestJS は @swagger デコレータで自動生成

# GraphQL スキーマジェネレータ
npm install graphql-code-generator
graphql-codegen --config codegen.yml
```

---

## 📚 学習リソース

### 必読書籍

```
1️⃣ 「Clean Architecture」Robert C. Martin
   出版: 2017年
   言語: 英語・日本語
   内容: 本ガイドの理論的基盤
   推奨: 最初に読むべき書籍

2️⃣ 「Domain-Driven Design」Eric Evans
   出版: 2003年（新版:2014）
   言語: 英語・日本語
   内容: ドメイン層の設計・言語化
   推奨: ドメイン複雑度が高い場合

3️⃣ 「Building Microservices」Sam Newman
   出版: 2015年（新版:2021）
   言語: 英語・日本語
   内容: サービス分割、イベント駆動設計
   推奨: マイクロサービス化を検討する場合
```

### 高品質オンラインコース

```
🎓 Udemy
  "Clean Architecture: Applying Domain Driven Design"
  講師: Mosh Hamedani
  対象: JavaScript/TypeScript

🎓 Pluralsight
  "Clean Code: Writing Code for Humans"
  講師: Cory House
  対象: C# / Java
```

### ブログ・記事

```
📝 Uncle Bob's Blog
   https://blog.cleancoder.com/
   著者: Robert C. Martin
   内容: Clean Architecture に関する最新考察

📝 DDD Community
   https://ddd-community.org/
   内容: Domain-Driven Design の実装例

📝 Martin Fowler's Blog
   https://martinfowler.com/
   内容: 建築パターン、リファクタリング
```

### GitHub リポジトリ（実装例）

```
⭐ clean-architecture-manga
   https://github.com/joeyhu/clean-architecture-manga
   内容: マンガで学ぶ Clean Architecture

⭐ node-ts-ddd-boilerplate
   https://github.com/Gotham/node-ts-ddd-boilerplate
   内容: TypeScript + DDD テンプレート

⭐ nestjs-clean-architecture
   https://github.com/rmanguinho/clean-node-api
   内容: NestJS + Clean Architecture 完全例
```

---

## 🔗 コミュニティ

### チャット・フォーラム

```
💬 DDD Community Slack
   https://ddd-community.slack.com/

💬 Node.js Japan ユーザグループ
   https://nodefest.jp/

💬 Reddit: r/webdev, r/typescript
   https://reddit.com/r/webdev/
```

### カンファレンス

```
🎉 JSConf
   https://jsconf.jp/
   期間: 毎年11月（日本）

🎉 CraftConf
   https://craft-conf.com/
   期間: 毎年4月（ハンガリー）
   内容: アーキテクチャ・システム設計

🎉 DDD Europe
   https://ddd-eu.com/
   期間: 毎年10月
```

---

## 📋 推奨スタック例

### スタートアップ向け（シンプル重視）

```
Backend:
  - Express.js + TypeScript
  - Type-DI（DI）
  - Jest（テスト）
  - MySQL + TypeORM

Frontend:
  - React + TypeScript
  - Redux Toolkit
  - Axios

DevOps:
  - Docker + Docker Compose
  - GitHub Actions
```

### スケール重視（エンタープライズ）

```
Backend:
  - NestJS
  - InversifyJS（複雑なDI）
  - Jest + Supertest
  - PostgreSQL + TypeORM

Frontend:
  - Next.js + TypeScript
  - Redux / Recoil

DevOps:
  - Kubernetes
  - CI/CD: Jenkins / GitLab CI
  - Monitoring: Prometheus + Grafana
```

---

## 📋 次のステップ

✅ 本ガイドを読み終えた
→ **推奨行動**

1. **プロジェクトを選ぶ**
   - 既存プロジェクト（既にある）
   - 新規プロジェクト（今から始める）

2. **適切なテンプレートを選ぶ**
   - Small: Express + Simple DI
   - Medium: NestJS
   - Large: NestJS + Event Sourcing

3. **段階的に導入**
   - Phase 1: ドメイン層を設計
   - Phase 2: リポジトリパターンで DB 抽象化
   - Phase 3: ユースケースで業務ロジック整理
   - Phase 4: エラーハンドリング・テストを統一

4. **チーム内で共有**
   - 設計原則を文書化
   - コードレビューで一貫性を保証
   - 定期的に見直し

---

## 🔗 各セクションへのリンク

| セクション | 目的 |
|-----------|------|
| [実装ガイド](../05-implementation-guide/) | 実装開始 |
| [ベストプラクティス](../06-best-practices/) | 品質向上 |
| [よくある間違い](../07-common-pitfalls/) | アンチパターン回避 |
| [ケーススタディ](../08-case-studies/) | 実装例学習 |

---

**🎓 本ガイドをマスターしました!**

次は実プロジェクトで Clean Architecture を適用してみてください。
