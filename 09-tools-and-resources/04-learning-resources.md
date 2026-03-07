# 04: 学習リソース

Clean Architecture と DDD の学習に役立つ本、コース、コミュニティ。

---

## 📚 必読書籍

### 第1順位：「Clean Architecture」 Robert C. Martin

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

### 第2順位：「Domain-Driven Design」Eric Evans

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

### 第3順位：「Building Microservices」Sam Newman

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

### 番外編：「Refactoring」Martin Fowler

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

## 🎓 オンラインコース

### Udemy

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

### Pluralsight

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

## 📝 ブログ・記事

### Uncle Bob's Blog

```
URL: https://blog.cleancoder.com/

主要記事：
- "The Clean Architecture"
- "Screaming Architecture"
- "The Dependency Rule"

更新頻度: 月1-2回
対象: エンジニア全般
```

### Martin Fowler's Blog

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

### DDD Community

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

## 🏢 実装テンプレート・サンプル

### GitHub リポジトリ

#### ① clean-architecture-manga

```
Repository: https://github.com/joeyhu/clean-architecture-manga

特徴：
- マンガで Learn Clean Architecture
- 視覚的に理解しやすい
- ビギナー向け
- 言語: 日本語
```

#### ② nestjs-clean-architecture-example

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

#### ③ typescript-clean-architecture-examples

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

### プロジェクト生成コマンド

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

## 💬 コミュニティ

### チャット・フォーラム

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

### GitHub Discussions

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

## 🎉 カンファレンス

### Node.js・Web 系

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

### アーキテクチャ・システム設計

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

## 📋 学習パス

### ビギナー向け（週１時間 × 4 週間）

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

### 中級者向け（週２時間 × 8 週間）

```
Week 1-2: 「Clean Architecture」 完読
Week 3-4: 「Domain-Driven Design」 第一部
Week 5-6: 実装テンプレート徹底研究
Week 7-8: マイクロサービス設計（Building Microservices）
```

---

## 📋 チェックリスト

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
- [実装ガイド](../05-implementation-guide/) ← 実装開始
- [ベストプラクティス](../06-best-practices/) ← 品質向上
- [よくある間違い](../07-common-pitfalls/) ← アンチパターン回避
- [ケーススタディ](../08-case-studies/) ← 実装例学習
