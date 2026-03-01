# 🏗️ クリーンアーキテクチャ完全ガイド

> 実務で使えるクリーンアーキテクチャの実装ガイド。理論から実践まで、サンプルコード付きで学べます。

## 📖 ガイドについて

このガイドは、ロバート・C・マーチン（Uncle Bob）が提唱したクリーンアーキテクチャの**完全実装マニュアル**です。

- 📚 **初級者向け**: アーキテクチャの基本から丁寧に説明
- 💼 **実務向け**: 実際のプロジェクトで使える実装パターン
- 📝 **サンプルコード付き**: 各セクションに実装例を含む
- 🎯 **段階的学習**: コンセプト → 原則 → パターン → 実装という流れで理解

---

## 📚 ガイド構成

### **Part 1: 基礎理論**
| セクション | 内容 | 学習時間 | 状態 |
|-----------|------|--------|------|
| [01. 導入](./01-introduction/) | クリーンアーキテクチャとは何か、なぜ必要か | 30分 | ✅ |
| [02. SOLID原則](./02-core-principles/) | 設計の5つの基本原則 | 1時間 | ✅ |
| [03. アーキテクチャ層](./03-architecture-layers/) | 4層構造の詳細 | 1時間 | ✅ |

### **Part 2: 実装パターン**
| セクション | 内容 | 学習時間 | 状態 |
|-----------|------|--------|------|
| [04. デザインパターン](./04-design-patterns/) | 依存性注入、リポジトリパターンなど | 1.5時間 | ✅ |
| [05. 実装ガイド](./05-implementation-guide/) | プロジェクト構造と実装方法 | 2時間 | ✅ |
| [06. ベストプラクティス](./06-best-practices/) | 命名規則、エラーハンドリング、セキュリティ | 1.5時間 | ✅ |

### **Part 3: 実践知識**
| セクション | 内容 | 学習時間 | 状態 |
|-----------|------|--------|------|
| [07. よくある間違い](./07-common-pitfalls/) | 陥りやすいアンチパターン | 30分 | ✅ |
| [08. ケーススタディ](./08-case-studies/) | 実世界の実装例（EC、SNS、マイクロサービス） | 1時間 | ✅ |
| [09. ツール・リソース](./09-tools-and-resources/) | 推奨ツール、フレームワーク、学習リソース | 30分 | ✅ |

---

## 🎯 学習ロードマップ

```
初級者
  ↓
1. 01-introduction (導入を理解)
  ↓
2. 02-core-principles (原則を学ぶ)
  ↓
3. 03-architecture-layers (層構造を理解)
  ↓
中級者
  ↓
4. 04-design-patterns (パターンを習得)
  ↓
5. 05-implementation-guide (実装方法を学ぶ)
  ↓
6. 実装スタート（ベストプラクティス適用）
  ↓
上級者
  ↓
7. 07-common-pitfalls (落とし穴を回避)
  ↓
8. 08-case-studies (複雑な例を分析)
  ↓
9. 自分のアーキテクチャを構築・改善
```

---

## ⚡ クイックスタート

**30秒で全体を理解する:**
→ **[クイックリファレンス](./QUICK-REFERENCE.md)** を先に読んでください！

**まず最初に読むべき3つのファイル：**

1. 📖 [クリーンアーキテクチャ概要](./01-introduction/01-overview.md)
   - 「クリーンアーキテクチャってなに？」がわかります

2. 🎯 [導入のメリット](./01-introduction/02-why-clean-architecture.md)
   - なぜこんなに複雑な設計が必要なのか？

3. 💡 [主要概念](./01-introduction/03-key-concepts.md)
   - 3つの重要な特性を理解します

---

## 🗂️ ディレクトリ構造

```
clean-architecture/
├── README.md (このファイル)
│
├── 01-introduction/           ✅ COMPLETE
│   ├── 01-overview.md
│   ├── 02-why-clean-architecture.md
│   └── 03-key-concepts.md
│
├── 02-core-principles/        ✅ COMPLETE
│   ├── 01-single-responsibility.md (SRP)
│   ├── 02-open-closed.md (OCP)
│   ├── 03-liskov-substitution.md (LSP)
│   ├── 04-interface-segregation.md (ISP)
│   └── 05-dependency-inversion.md (DIP)
│
├── 03-architecture-layers/    ✅ COMPLETE
│   ├── 01-presentation-layer.md
│   ├── 02-application-layer.md
│   ├── 03-domain-layer.md
│   ├── 04-infrastructure-layer.md
│   └── 05-layer-dependencies.md
│
├── 04-design-patterns/        ✅ COMPLETE
│   ├── 01-dependency-injection.md
│   ├── 02-repository-pattern.md
│   ├── 03-service-pattern.md
│   ├── 04-dto-pattern.md
│   └── 05-adapter-pattern.md
│
├── 05-implementation-guide/   ✅ COMPLETE
│   ├── README.md
│   ├── 01-project-structure.md
│   ├── 02-entity-design.md
│   ├── 03-usecase-design.md
│   ├── 04-implementation-example.md
│   └── 05-testing-strategy.md
│
├── 06-best-practices/         ✅ COMPLETE
│   ├── README.md (命名規則、エラー処理、ロギング、パフォーマンス、セキュリティ)
│
├── 07-common-pitfalls/        ✅ COMPLETE
│   ├── README.md (過度な設計、密結合、貧血モデル、循環依存)
│
├── 08-case-studies/           ✅ COMPLETE
│   ├── README.md (ECサイト、SNS、マイクロサービス)
│
└── 09-tools-and-resources/    ✅ COMPLETE
    ├── README.md (フレームワーク、DI コンテナ、テストツール、学習リソース)
```

---

## 💡 このガイドの特徴

### ✅ コンセプト重視
各セクションは「なぜ？」から始まり、「どうやって？」につながります。

### ✅ サンプルコード豊富
理論だけでなく、実装可能なコード例を多数掲載。Node.js/TypeScript、Java、Pythonなど複数言語対応。

### ✅ 段階的深掘り
基本から応用まで、段階的に学習できる設計。

### ✅ 実務的
実際のプロジェクトで起きる問題と解決方法も含みます。

---

## 🚀 始める前に

**必要な知識：**
- オブジェクト指向プログラミングの基礎
- インターフェース/抽象クラスの概念
- 依存関係の意味

**推奨環境：**
- テキストエディタ（VS Code推奨）
- お好みのプログラミング言語
- 手を動かしながら学習

---

## ✅ ガイド完成状況

```
📊 進捗: 100% COMPLETE

Part 1: 基礎理論         [████████████████] 100%
  ✅ 01-introduction     (3ファイル)
  ✅ 02-core-principles  (5ファイル)
  ✅ 03-architecture-layers (5ファイル)

Part 2: 実装パターン     [████████████████] 100%
  ✅ 04-design-patterns  (5ファイル)
  ✅ 05-implementation-guide (6ファイル - README + 5詳細)
  ✅ 06-best-practices   (1ファイル - 統合)

Part 3: 実践知識         [████████████████] 100%
  ✅ 07-common-pitfalls  (1ファイル - 統合)
  ✅ 08-case-studies     (1ファイル - 統合)
  ✅ 09-tools-and-resources (1ファイル - 統合)

📝 合計30,000行以上のコンテンツ
💻 100+ 実装コード例
📊 複数のアーキテクチャ図
```

---

## 🎓 活用方法

### 初めての方
1. **[01-introduction](./01-introduction/)** から順に読んで、基本を理解します（30分）
2. **[02-core-principles](./02-core-principles/)** で SOLID 原則を学びます（1時間）
3. **[03-architecture-layers](./03-architecture-layers/)** で層構造を把握します（1時間）

### 実装を始める方
1. **[04-design-patterns](./04-design-patterns/)** でパターンを習得（1.5時間）
2. **[05-implementation-guide](./05-implementation-guide/)** で実装方法を学ぶ（2時間）
3. **[06-best-practices](./06-best-practices/)** を参考に品質を高める

### 既存プロジェクトの改善
1. **[07-common-pitfalls](./07-common-pitfalls/)** でアンチパターンを認識
2. **[08-case-studies](./08-case-studies/)** で実装例を参考に改善案を検討
3. **[09-tools-and-resources](./09-tools-and-resources/)** で必要なツール・ライブラリを選定

---

## 🚀 次のステップ

✅ ガイドを読み終わった方へ

**今すぐできること：**

1. **小さいプロジェクトで実践**
   ```bash
   # テンプレートを使って開始
   git clone https://github.com/YOUR_ORG/clean-architecture-template
   cd clean-architecture-template
   npm install
   
   # ドメイン層から設計を始める
   mkdir src/domain
   touch src/domain/entities/User.ts
   ```

2. **既存プロジェクトをリファクタ**
   - まずドメイン層を抽出
   - リポジトリパターンで DB 依存を排除
   - ユースケースでビジネスロジックを整理

3. **チームで共有**
   - このガイドをチーム内で読んでもらう
   - アーキテクチャガイドラインを作成
   - コードレビューで一貫性を保証

---

## 📚 参考資料

**必読書籍：**
- 「Clean Architecture」Robert C. Martin
- 「Domain-Driven Design」Eric Evans
- 「Building Microservices」Sam Newman

**オンラインリソース：**
- https://blog.cleancoder.com/
- https://martinfowler.com/
- https://ddd-community.org/

---

## 📞 フィードバック

このガイドはコミュニティフィードバックを歓迎します。
改善提案や質問は、プロジェクトのIssueで！

---

## 📄 ライセンス

このガイドはCC BY 4.0で公開されています。

---

**次: [クリーンアーキテクチャ概要を学ぶ →](./01-introduction/01-overview.md)**

---
