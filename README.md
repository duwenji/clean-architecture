# 🏗️ クリーンアーキテクチャ完全ガイド

> 実務で使えるクリーンアーキテクチャの実装ガイド。理論から実践まで、サンプルコード付きで学べます。

> 💡 ブラウザで https://duwenji.github.io/spa-quiz-app/ を開くと、関連トピックをクイズ形式で復習できます。

## 📖 ガイドについて

このガイドは、ロバート・C・マーチン（Uncle Bob）が提唱したクリーンアーキテクチャの**完全実装マニュアル**です。

- 📚 **初級者向け**: アーキテクチャの基本から丁寧に説明
- 💼 **実務向け**: 実際のプロジェクトで使える実装パターン
- 📝 **サンプルコード付き**: 各セクションに実装例を含む
- 🎯 **段階的学習**: コンセプト → 原則 → パターン → 実装という流れで理解

---

## 📚 ガイド構成（表紙 + 本編9章）

この目次はフォルダ/ファイル構造から自動生成されます。

- 生成元: `../shared-copilot-skills/ebook-build/scripts/convert-to-kindle.ps1`
- 対象フォルダ: `^\d{2}-`
- 対象ファイル: `^\d{2}-.*\.md`（`README.md`は除外）

<!-- AUTO-TOC:START -->
- [00. Cover](./docs/00-COVER.md)
- [01. Introduction](./docs/01-introduction/)
  - [01. Overview](./docs/01-introduction/01-overview.md)
  - [02. Why Clean Architecture](./docs/01-introduction/02-why-clean-architecture.md)
  - [03. Key Concepts](./docs/01-introduction/03-key-concepts.md)
- [02. Core Principles](./docs/02-core-principles/)
  - [01. Single Responsibility](./docs/02-core-principles/01-single-responsibility.md)
  - [02. Open Closed](./docs/02-core-principles/02-open-closed.md)
  - [03. Liskov Substitution](./docs/02-core-principles/03-liskov-substitution.md)
  - [04. Interface Segregation](./docs/02-core-principles/04-interface-segregation.md)
  - [05. Dependency Inversion](./docs/02-core-principles/05-dependency-inversion.md)
- [03. Architecture Layers](./docs/03-architecture-layers/)
  - [01. Presentation Layer](./docs/03-architecture-layers/01-presentation-layer.md)
  - [02. Application Layer](./docs/03-architecture-layers/02-application-layer.md)
  - [03. Domain Layer](./docs/03-architecture-layers/03-domain-layer.md)
  - [04. Infrastructure Layer](./docs/03-architecture-layers/04-infrastructure-layer.md)
  - [05. Layer Dependencies](./docs/03-architecture-layers/05-layer-dependencies.md)
- [04. Design Patterns](./docs/04-design-patterns/)
  - [01. Dependency Injection](./docs/04-design-patterns/01-dependency-injection.md)
  - [02. Repository Pattern](./docs/04-design-patterns/02-repository-pattern.md)
  - [03. Service Pattern](./docs/04-design-patterns/03-service-pattern.md)
  - [04. DTO Pattern](./docs/04-design-patterns/04-dto-pattern.md)
  - [05. Adapter Pattern](./docs/04-design-patterns/05-adapter-pattern.md)
- [05. Implementation Guide](./docs/05-implementation-guide/)
  - [01. Project Structure](./docs/05-implementation-guide/01-project-structure.md)
  - [02. Entity Design](./docs/05-implementation-guide/02-entity-design.md)
  - [03. Use Case Design](./docs/05-implementation-guide/03-usecase-design.md)
  - [04. Implementation Example](./docs/05-implementation-guide/04-implementation-example.md)
  - [05. Testing Strategy](./docs/05-implementation-guide/05-testing-strategy.md)
- [06. Best Practices](./docs/06-best-practices/)
  - [01. Naming Conventions](./docs/06-best-practices/01-naming-conventions.md)
  - [02. Error Handling](./docs/06-best-practices/02-error-handling.md)
  - [03. Logging Monitoring](./docs/06-best-practices/03-logging-monitoring.md)
  - [04. Performance Optimization](./docs/06-best-practices/04-performance-optimization.md)
  - [05. Security](./docs/06-best-practices/05-security.md)
- [07. Common Pitfalls](./docs/07-common-pitfalls/)
  - [01. Over Engineering](./docs/07-common-pitfalls/01-over-engineering.md)
  - [02. Tight Coupling](./docs/07-common-pitfalls/02-tight-coupling.md)
  - [03. Anemic Model](./docs/07-common-pitfalls/03-anemic-model.md)
  - [04. Circular Dependency](./docs/07-common-pitfalls/04-circular-dependency.md)
- [08. Case Studies](./docs/08-case-studies/)
  - [01. Ecommerce Site](./docs/08-case-studies/01-ecommerce-site.md)
  - [02. SNS Platform](./docs/08-case-studies/02-sns-platform.md)
  - [03. Microservices](./docs/08-case-studies/03-microservices.md)
- [09. Tools and Resources](./docs/09-tools-and-resources/)
  - [01. Frameworks](./docs/09-tools-and-resources/01-frameworks.md)
  - [02. DI Containers](./docs/09-tools-and-resources/02-di-containers.md)
  - [03. Development Tools](./docs/09-tools-and-resources/03-development-tools.md)
  - [04. Learning Resources](./docs/09-tools-and-resources/04-learning-resources.md)
<!-- AUTO-TOC:END -->

---

## 📘 Kindle変換時の目次運用

- Kindle 出力の目次生成ロジックは `../shared-copilot-skills/ebook-build/scripts/convert-to-kindle.ps1` を正とし、推奨実行入口は `.github/skills-config/ebook-build/invoke-build.ps1` とします。
- `00-COVER.md` には手動の章一覧テーブルを置かず、見出し構造で目次を表現します。
- 章フォルダ/章内ファイルの追加・改名は、命名規則（`^\d{2}-`）に従えば README 目次と変換順に自動反映されます。
- 目次の深さは `.github/skills-config/ebook-build/clean-architecture.metadata.yaml` の `toc-depth` で管理します。

---

## 🎯 学習ロードマップ

```
スタート
  ↓
0. [表紙を確認](./docs/00-COVER.md) （全体像の把握 - 5分）
  ↓
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

### 電子書籍ビルド

推奨コマンド:

```powershell
cd c:\dev\apps\clean-architecture
.\.github\skills-config\ebook-build\invoke-build.ps1
```

関連ファイル:
- `../shared-copilot-skills/ebook-build/SKILL.md`
- `../shared-copilot-skills/ebook-build/EBOOK_BUILD_SPECIFICATION.md`
- `ebook-output/`

submodule 運用コマンド:

```powershell
# 初回 clone 後
git submodule update --init --recursive

# 共有 Skill の更新取り込み
git submodule update --remote --merge .github/skills
```

共有 Skill リポジトリ:
- https://github.com/duwenji/shared-copilot-skills

## 🧩 Shared Skill 統一導線（Ebook）

このリポジトリでは `shared-copilot-skills` を共通ソースとして利用します。
submodule 方式はリポジトリ単位の導入になるため、個別スキルのみを選択して導入することはできません。

- Ebook build wrapper: `./.github/skills-config/ebook-build/invoke-build.ps1`

実行例:

```powershell
cd c:\dev\apps\clean-architecture

# Ebook build
.\.github\skills-config\ebook-build\invoke-build.ps1
```

shared skill の探索順:
1. `../shared-copilot-skills/*`
2. `./.github/skills/shared-skills/*`
3. `./.github/skills/shared-copilot-skills/*`

**1分で全体像を把握する:**
→ **[表紙で全体像を確認](./docs/00-COVER.md)** してください！

**30秒で重要ポイントをおさらい:**
→ **[クイックリファレンス](./QUICK-REFERENCE.md)** を参照してください！

**まず最初に読むべき3つのファイル：**

1. 📖 [クリーンアーキテクチャ概要](./docs/01-introduction/01-overview.md)
   - 「クリーンアーキテクチャってなに？」がわかります

2. 🎯 [導入のメリット](./docs/01-introduction/02-why-clean-architecture.md)
   - なぜこんなに複雑な設計が必要なのか？

3. 💡 [主要概念](./docs/01-introduction/03-key-concepts.md)
   - 3つの重要な特性を理解します

---

## 🗂️ ディレクトリ構造

```
clean-architecture/
├── .github/
│   └── skills-config/
│       └── ebook-build/
├── README.md
├── MASTER-INDEX.md
├── QUICK-REFERENCE.md
├── COMPLETION-REPORT.md
├── ebook-output/
└── docs/
    ├── 00-COVER.md
    ├── index.md
    ├── _config.yml
    ├── 01-introduction/
    ├── 02-core-principles/
    ├── 03-architecture-layers/
    ├── 04-design-patterns/
    ├── 05-implementation-guide/
    ├── 06-best-practices/
    ├── 07-common-pitfalls/
    ├── 08-case-studies/
    └── 09-tools-and-resources/
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
📊 進捗: 100% COMPLETE ✨

Part 0: スタート地点
  ✅ 00-COVER.md             (1ファイル - 新規)

Part 1: 基礎理論         [████████████████] 100%
  ✅ 01-introduction     (3ファイル)
  ✅ 02-core-principles  (5ファイル)
  ✅ 03-architecture-layers (5ファイル)

Part 2: 実装パターン     [████████████████] 100%
  ✅ 04-design-patterns  (5ファイル)
  ✅ 05-implementation-guide (6ファイル - README + 5詳細)
  ✅ 06-best-practices   (6ファイル - README + 5詳細)

Part 3: 実践知識         [████████████████] 100%
  ✅ 07-common-pitfalls  (5ファイル - README + 4詳細)
  ✅ 08-case-studies     (4ファイル - README + 3詳細)
  ✅ 09-tools-and-resources (5ファイル - README + 4詳細)

その他ドキュメント
  ✅ QUICK-REFERENCE.md  (クイックリファレンス)
  ✅ COMPLETION-REPORT.md (完成報告書)

📝 合計50ファイル、15,000行以上のコンテンツ
💻 100+ 実装コード例
📊 複数のアーキテクチャ図
🎨 美しい表紙デザイン
```

---

## 🎓 活用方法

### 初めての方
0. **[表紙を確認](./docs/00-COVER.md)** して全体像を理解します（5分）
1. **[01-introduction](./docs/01-introduction/)** から順に読んで、基本を理解します（30分）
2. **[02-core-principles](./docs/02-core-principles/)** で SOLID 原則を学びます（1時間）
3. **[03-architecture-layers](./docs/03-architecture-layers/)** で層構造を把握します（1時間）

### 実装を始める方
1. **[04-design-patterns](./docs/04-design-patterns/)** でパターンを習得（1.5時間）
2. **[05-implementation-guide](./docs/05-implementation-guide/)** で実装方法を学ぶ（2時間）
3. **[06-best-practices](./docs/06-best-practices/)** を参考に品質を高める

### 既存プロジェクトの改善
1. **[07-common-pitfalls](./docs/07-common-pitfalls/)** でアンチパターンを認識
2. **[08-case-studies](./docs/08-case-studies/)** で実装例を参考に改善案を検討
3. **[09-tools-and-resources](./docs/09-tools-and-resources/)** で必要なツール・ライブラリを選定

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

**次: [表紙で全体像を確認 →](./docs/00-COVER.md)** または **[クリーンアーキテクチャ概要を学ぶ →](./docs/01-introduction/01-overview.md)**

---

