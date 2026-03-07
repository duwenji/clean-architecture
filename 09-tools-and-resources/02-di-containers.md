# 02: DI コンテナー・IoC フレームワーク

依存関係管理ツールの比較と実装方法。

---

## 🎯 DI コンテナーの役割

```
DI コンテナー = 自動依存関係管理ツール

機能：
  1. オブジェクトの生成（インスタンス化）
  2. 依存関係の自動注入
  3. ライフサイクル管理（singleton, 一時的など）
  4. 循環依存の検出
```

---

## 🔷 TypeScript 推奨 3選

### ① Type-DI（最もシンプル）

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

### ② InversifyJS（複雑な設定向け）

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

### ③ Awilix（関数型好み向け）

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

## 🟠 Java 推奨 2選

### ① Spring DI（Spring Boot 組み込み）

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

### ② Guice（軽量代替）

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

## 🐍 Python 推奨

### Dependency Injector

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

## 📊 DI コンテナー比較表

| 項目 | Type-DI | InversifyJS | Awilix | Spring | Guice |
|------|---------|-----------|--------|--------|-------|
| **学習曲線** | ⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **セットアップ** | ⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ |
| **複雑設定対応** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **型安全性** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **エコシステム** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 🎯 選定フロー

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

## 📋 チェックリスト

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

**次: [開発ツール →](./03-development-tools.md)**
