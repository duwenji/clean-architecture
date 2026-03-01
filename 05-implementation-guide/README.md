# 05: 実装ガイド - 完全マニュアル

このセクションでは、クリーンアーキテクチャを実際のプロジェクトにどう適用するかを学びます。

> 実装例：ユーザー管理システム（CRUD + 認認証）

## 📖 セクション構成

| ファイル | 内容 |
|---------|------|
| [01-project-structure.md](./01-project-structure.md) | プロジェクトフォルダ構成 |
| [02-entity-design.md](./02-entity-design.md) | エンティティ設計の実装 |
| [03-usecase-design.md](./03-usecase-design.md) | ユースケース設計と実装 |
| [04-implementation-example.md](./04-implementation-example.md) | 完全な実装例 |
| [05-testing-strategy.md](./05-testing-strategy.md) | テスト戦略 |

---

## 🎯 このセクションのゴール

```
理論を学んだ → 実装できる

前セクション：「なぜ？」「どう動く？」
このセクション：「どう作る？」
```

---

## 📚 段階的な学習

### Level 1: 基本構造の理解
[01-project-structure.md](./01-project-structure.md) で、プロジェクトをどのようにフォルダを整理するか学びます。

### Level 2: ドメインモデルの実装
[02-entity-design.md](./02-entity-design.md) で、エンティティと値オブジェクトの具体的な設計方法を学びます。

### Level 3: ユースケースの実装
[03-usecase-design.md](./03-usecase-design.md) で、ビジネスロジック実行層の設計と実装を学びます。

### Level 4: 統合実装例
[04-implementation-example.md](./04-implementation-example.md) で、全層を統合した完全な実装例を見ます。

### Level 5: テスト戦略
[05-testing-strategy.md](./05-testing-strategy.md) で、各層のテスト方法を学びます。

---

## 🗂️ 実装例プロジェクト概要

**特徴：**
- TypeScript + Node.js（Express）
- MySQL データベース
- ユーザー登録、ログイン、プロフィール更新
- メール送信
- エラーハンドリング

**使用パターン：**
- 依存性注入（DI）
- リポジトリパターン
- DTO パターン
- アダプタパターン

---

## 💡 クイックリファレンス

### ファイルの役割

```
src/
├── domain/          # ビジネスロジック（フレームワーク独立）
├── application/     # ユースケース実行
├── presentation/    # UI（Express Controller）
├── infrastructure/  # DB、外部API実装
└── config/          # DI設定
```

### 層間のデータフロー

```
HTTP Request
     ↓
Presentation (Controller)
     ↓ バリデーション & マッピング
Application (UseCase)
     ↓ 
Domain (Entity)
     ↓ ビジネスロジック実行
Infrastructure (Repository, Service)
     ↓
    DB
```

---

## 🚀 始める前に

**推奨知識：**
- TypeScript の基礎
- async/await
- クラスベースの OOP
- インターフェース概念

**推奨ツール：**
- Node.js 14以上
- TypeScript 4以上
- Jest（テスティング）
- MySQL 5.7以上

---

## 📌 各ファイルへのナビゲーション

**まず最初に読むべき:**
1. [プロジェクト構造](./01-project-structure.md) - 全体像を把握
2. [エンティティ設計](./02-entity-design.md) - ドメインモデル実装
3. [完全実装例](./04-implementation-example.md) - 動く全体例を見る

**次に深掘り:**
4. [ユースケース設計](./03-usecase-design.md) - アプリケーション層の詳細
5. [テスト戦略](./05-testing-strategy.md) - 品質確保の方法

---

## 🎬 実装フロー

```
1️⃣  プロジェクト構造を作成
     └─ フォルダ/ファイル配置
     
2️⃣  ドメインエンティティを定義
     └─ User, Password, Email等
     
3️⃣  リポジトリインターフェース定義
     └─ UserRepository etc.
     
4️⃣  ユースケースを実装
     └─ RegisterUser, GetUser等
     
5️⃣  Controller を実装
     └─ HTTP エンドポイント
     
6️⃣  リポジトリ実装
     └─ MySQL 実装
     
7️⃣  テストを書く
     └─ ユニット、統合テスト
     
8️⃣  起動して動作確認
```

---

## ✅ チェックリスト

このセクション完了時に確認:

```
□ フォルダ構造が理解できた
□ エンティティを設計・実装できる
□ ユースケースを実装できる
□ 4層すべてを実装できた
□ テストが書ける
□ 疑問点を 05-testing-strategy.md で解決できた
```

---

## 🔗 前後のセクション

**前**: [デザインパターン](../04-design-patterns/)
→ パターンの理論を学んだ

**ここ**: **実装ガイド**
→ パターンを実装に適用

**後**: [ベストプラクティス](../06-best-practices/)
→ 実装品質を上げる知見

---

## 📖 各ファイルの詳細

### [01-project-structure.md](./01-project-structure.md)
- フォルダ構成図
- ファイル配置の意図
- モノレポ vs マイクロサービス対応

### [02-entity-design.md](./02-entity-design.md)
- User エンティティの完全実装
- Email、Password 値オブジェクト
- バリデーション戦略

### [03-usecase-design.md](./03-usecase-design.md)
- RegisterUserUseCase 実装
- トランザクション管理
- エラーハンドリング

### [04-implementation-example.md](./04-implementation-example.md)
- 全層を含む完全例
- お金を返すコードを見ながら学ぶ
- 実際に動かせるコード

### [05-testing-strategy.md](./05-testing-strategy.md)
- ユニットテスト（各層）
- 統合テスト
- E2E テスト
- テストダブル（モック）

---

## 🤔 よくある質問

**Q1: どこから始めるべき?**
A: フォルダ構造 → エンティティ設計 の順でいきましょう

**Q2: すべてを実装する必要がある?**
A: 最初は基本部分（ユーザー登録）だけでOK

**Q3: 既存プロジェクトに適用できる?**
A: 段階的に適用できます。[07-common-pitfalls](../07-common-pitfalls/) を参照

---

**次: [プロジェクト構造 →](./01-project-structure.md)**
