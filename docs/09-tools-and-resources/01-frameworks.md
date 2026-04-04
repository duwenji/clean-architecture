# 01: フレームワーク比較

Web フレームワーク、CLI ツール、API フレームワークの比較と選定ガイド。

---

## 🎯 フレームワークの選定方法

| 判断軸 | 選定ポイント |
|-------|----------|
| **プロジェクト規模** | 小：Express, 中：NestJS, 大：Spring/NestJS |
| **チーム規模** | 小：シンプル, 大：ガイデッド（DI組込） |
| **学習曲線** | 急・緩かで判定 |
| **成熟度** | 本番運用経験・コミュニティサイズ |
| **エコシステム** | ライブラリ・親切の豊富さ |

---

## 🔷 Node.js / TypeScript フレームワーク

### ① Express.js + Type-DI

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

### ② NestJS（推奨度：⭐⭐⭐⭐★）

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

### ③ Fastify + Awilix（推奨度：⭐⭐⭐⭐☆）

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

## 🟠 Java フレームワーク

### ① Spring Boot

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

### ② Quarkus

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

## 🐍 Python フレームワーク

### ① FastAPI + Dependency Injector

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

## 📊 フレームワーク比較表

| 項目 | Express | NestJS | Fastify | Spring Boot | Quarkus | FastAPI |
|------|---------|--------|---------|-----------|---------|---------|
| **学習曲線** | ⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| **性能** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **DI組込** | ❌ | ✅ | △ | ✅ | ✅ | ✅ |
| **Validation** | ❌ | ✅ | △ | ✅ | ✅ | ✅ |
| **本番実績** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **エコシステム** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 🎯 選定フローチャート

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

## 📋 チェックリスト

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

**次: [DI コンテナー →](./02-di-containers.md)**
