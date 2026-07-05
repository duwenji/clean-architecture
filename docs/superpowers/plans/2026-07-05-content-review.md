# クリーンアーキテクチャ教材 コンテンツレビュー Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `clean-architecture` リポジトリの `docs/` 配下にある日本語教材（全9章）を、正確性・一貫性・読みやすさの3観点でレビューし、その場で修正する。

**Architecture:** これはコード実装ではなく文章レビュー・編集タスクである。そのため本プランでは、通常のTDDサイクル（テスト作成→実装→テスト実行）の代わりに「チェックリストに基づくレビュー→Editによる修正→ASCII安全なgrep/リンクチェックによる検証→ユーザーへの簡潔な報告」を1タスクの反復単位とする。1タスク=1章。最後に章をまたぐ数値・用語の整合性を解消する後始末タスクを置く。

**Tech Stack:** Markdown（docs/ 配下）、Bash（grep によるASCII安全な検証、リンク存在チェック）、git（コミットはユーザー指示があった場合のみ）

## Global Constraints

- 一次情報源: Robert C. Martin, "The Clean Architecture", blog.cleancoder.com, 2012-08-13（主）、書籍『Clean Architecture』の一般に知られる内容（補助）— 詳細は下記「Reference」参照
- レビュー対象は `docs/` 配下の全ファイルのみ。`ebook-output/` は対象外（再ビルドしない）
- リポジトリには mermaid化に関する既存の未コミット変更（20ファイル）がある。これらには一切触れない・上書きしない。作業前に毎回 `git status` で確認し、対象外ファイルが変更されていないことを確かめる
- 4層モデル（Presentation/Application/Domain/Infrastructure）は実務的変形として維持する。原典の4重円（Entities/Use Cases/Interface Adapters/Frameworks & Drivers）への書き換えは行わない
- **git commit は各タスクの末尾では行わない。** ユーザーから明示的な指示があった場合のみコミットする（実行系スキルのデフォルトの自動コミット挙動を上書きする）
- 日本語の文章として不自然な表現・簡体字混入は、目視での読み込みで検出する（マルチバイト文字はこの環境のgrepでは文字クラスの誤検出が起きるため、機械的な簡体字検出には頼らない）
- 各タスク完了時、チャットで「見つけた問題→修正内容」を簡潔に報告する（章ごとの独立したレビューログファイルは作らない）

---

## Reference: Clean Architecture 原典の要点（全タスク共通の照合基準）

出典: Robert C. Martin, "The Clean Architecture", blog.cleancoder.com, 2012-08-13。

- **4つの同心円（内側から）**
  - **Entities**: "Enterprise wide business rules" をカプセル化。最も変更されにくい層
  - **Use Cases**: "application specific business rules"。エンティティと外部システム間のデータフローを orchestrate する
  - **Interface Adapters**: MVC の Presenter・View・Controller が属する層。内部フォーマットと外部フォーマット間のデータ変換を行う
  - **Frameworks and Drivers**: "all the details go"。DB、Webフレームワークなど実装の詳細がすべてここに配置される
- **The Dependency Rule**: "source code dependencies can only point inwards"（ソースコードの依存性は常に内側にのみ向かう）。外側の円にあるコードは内側の円の名前（クラス名・関数名など）を参照してはならない
- **円をまたぐデータの受け渡し**: "isolated, simple, data structures are passed across the boundaries"。フレームワーク固有の構造体をそのまま渡さず、内側の円にとって最も都合の良い形でデータを受け渡す（DTO的な考え方）
- **書籍の基本情報**（`09-tools-and-resources/04-learning-resources.md` 等で言及）: 『Clean Architecture: A Craftsman's Guide to Software Structure and Design』, Robert C. Martin, Prentice Hall, 初版2017年 — 教材内の記載はこの情報と一致しており、変更不要

この教材の4層モデル（Presentation/Application/Domain/Infrastructure）と原典の4重円の対応関係:

| 教材の4層 | 原典の4重円（対応関係の目安） |
|---|---|
| プレゼンテーション層 | Interface Adapters（の一部：Controller/View） |
| アプリケーション層 | Use Cases |
| ドメイン層 | Entities |
| インフラストラクチャ層 | Frameworks and Drivers + Interface Adapters（の一部：Repository実装など） |

※ 教材の4層は実務でよく使われる簡略版であり、原典のInterface Adaptersは「外側と内側の変換」を担う層としてプレゼンテーション層とインフラ層の双方にまたがる点に注意。Task 1でこの対応関係を導入文として追記する。

---

### Task 1: 01-introduction（導入）+ 表紙・索引ファイル

**Files:**
- Modify: `docs/00-COVER.md`
- Modify: `docs/index.md`
- Modify: `docs/01-introduction/01-overview.md`
- Modify: `docs/01-introduction/02-why-clean-architecture.md`
- Modify: `docs/01-introduction/03-key-concepts.md`

**チェックリスト（正確性/一貫性/読みやすさ）:**
- [ ] `01-overview.md`: 「変更对応」の「对」は中国語簡体字であり日本語として誤り。「変更対応」に修正する
- [ ] `01-overview.md`: 4層モデルの説明の直後に、上記Referenceの対応表を要約した1〜2文（原典の4重円との対応関係）を追記し、この教材が実務的な簡略版であることを明記する
- [ ] `01-overview.md` / `02-why-clean-architecture.md` / `03-key-concepts.md` を通読し、Clean Architecture の説明が Reference の内容（Dependency Rule、データ受け渡しの原則）と矛盾していないか確認する
- [ ] 3ファイル内の相互リンク（`[次: ...]` 等）が実在するファイルを指しているか確認する
- [ ] 誤字脱字・不自然な日本語表現を目視で修正する

- [ ] **Step 1: 対象ファイルを読み込む**

`docs/00-COVER.md`、`docs/index.md`、`docs/01-introduction/` 配下の3ファイルをReadツールで読み込み、上記チェックリストと照合する。

- [ ] **Step 2: 「変更对応」を修正する**

`docs/01-introduction/01-overview.md` の該当箇所:

```diff
-| **変更对応** | 影響大きい | 局所的な影響 |
+| **変更対応** | 影響大きい | 局所的な影響 |
```

- [ ] **Step 3: 4重円との対応関係を追記する**

`docs/01-introduction/01-overview.md` の「📋 まとめ」セクション（4層構造の表がある箇所）の直後に、Reference の対応表を要約した短い節を追加する:

```markdown
### 🔍 原典（Uncle Bob）の4重円との関係

本ガイドの4層（Presentation/Application/Domain/Infrastructure）は、実務でよく使われる簡略版です。
Robert C. Martin の原典「The Clean Architecture」では Entities / Use Cases / Interface Adapters /
Frameworks and Drivers の4重円で説明されており、対応の目安は次の通りです。

| 本ガイドの4層 | 原典の4重円（目安） |
|---|---|
| プレゼンテーション層 | Interface Adapters（Controller/View） |
| アプリケーション層 | Use Cases |
| ドメイン層 | Entities |
| インフラストラクチャ層 | Frameworks and Drivers ＋ Interface Adapters（Repository実装等） |
```

- [ ] **Step 4: チェックリストの残り項目を確認・修正する**

`02-why-clean-architecture.md`、`03-key-concepts.md`、`00-COVER.md`、`index.md` を読み、矛盾・リンク切れ・誤字があればEditで直接修正する（この時点で見つかる具体的な誤りは実際に読んでから対応するため、見つけ次第その場で修正する）。

- [ ] **Step 5: 検証（ASCII安全なチェック）**

```bash
cd "c:/Dev/tutorials/clean-architecture"
grep -c "变" docs/00-COVER.md docs/index.md docs/01-introduction/*.md 2>/dev/null
```

Expected: 各ファイルとも `0`（誤ってさらに簡体字を混入させていないことの確認。ゼロ件でなければ該当箇所を見直す）

```bash
grep -o '\](\.\/[^)]*\.md[^)]*)' docs/01-introduction/*.md
```

Expected: 出力された各相対パスに対応するファイルが実在すること（目視で確認）

- [ ] **Step 6: 影響範囲の確認**

```bash
git status --short
```

Expected: 変更ファイルが `docs/00-COVER.md`, `docs/index.md`, `docs/01-introduction/*.md` のみであること（mermaid化の既存差分ファイルが誤って追加変更されていないこと）

- [ ] **Step 7: ユーザーへの報告**

チャットで「Task 1で見つけた問題→修正内容」を箇条書きで簡潔に報告する。git commit は行わない（ユーザーの指示があった場合のみ）。

---

### Task 2: 02-core-principles（SOLID原則）

**Files:**
- Modify: `docs/02-core-principles/01-single-responsibility.md`
- Modify: `docs/02-core-principles/02-open-closed.md`
- Modify: `docs/02-core-principles/03-liskov-substitution.md`
- Modify: `docs/02-core-principles/04-interface-segregation.md`
- Modify: `docs/02-core-principles/05-dependency-inversion.md`

**チェックリスト:**
- [ ] 各原則（SRP/OCP/LSP/ISP/DIP）の定義文が一般的なSOLID原則の定義と矛盾していないか
- [ ] `05-dependency-inversion.md`: DIP の説明が Reference の Dependency Rule（依存は内側にのみ向かう）と整合しているか。原典の「抽象に依存する」という原則と、Clean Architectureの層間依存ルールを混同していないか確認する
- [ ] 5ファイル間で「違反例→改善例→テスト例」という構成が統一されているか
- [ ] 誤字脱字・不自然な日本語表現、章内・章間リンクの有効性

- [ ] **Step 1: 対象ファイルを読み込む**

5ファイルをReadツールで読み込み、チェックリストと照合する。

- [ ] **Step 2: 発見した問題を修正する**

読み込みで見つかった誤字・矛盾・構成の不統一を、各ファイルにEditで直接修正する。

- [ ] **Step 3: 検証**

```bash
cd "c:/Dev/tutorials/clean-architecture"
grep -o '\](\.\/[^)]*\.md[^)]*)\|\](\.\.\/[^)]*\.md[^)]*)' docs/02-core-principles/*.md
```

Expected: 出力された相対パスがすべて実在するファイルを指していること

```bash
git status --short
```

Expected: 変更ファイルが `docs/02-core-principles/*.md` のみ

- [ ] **Step 4: ユーザーへの報告**

Task 2で見つけた問題と修正内容を簡潔に報告する。

---

### Task 3: 03-architecture-layers（4層構造）

**Files:**
- Modify: `docs/03-architecture-layers/01-presentation-layer.md`
- Modify: `docs/03-architecture-layers/02-application-layer.md`
- Modify: `docs/03-architecture-layers/03-domain-layer.md`
- Modify: `docs/03-architecture-layers/04-infrastructure-layer.md`
- Modify: `docs/03-architecture-layers/05-layer-dependencies.md`

**チェックリスト:**
- [ ] 各層の責務説明が Reference の4重円の役割（特にInterface AdaptersがController/View/Presenterを含み、内外のフォーマット変換を担うこと）と矛盾しないか
- [ ] `05-layer-dependencies.md`: Dependency Rule（"source code dependencies can only point inwards"）の説明が正確か。インフラ層がドメイン層のインターフェースを実装する（依存性逆転）という説明が一貫しているか
- [ ] Task 1で追加した「4重円との対応表」と、本章内の層の説明が矛盾していないか（用語の整合性）
- [ ] 誤字脱字・不自然な日本語表現、リンクの有効性

- [ ] **Step 1: 対象ファイルを読み込む**

5ファイルをReadツールで読み込み、チェックリストと照合する。Task 1で追加した対応表の内容もあわせて参照する。

- [ ] **Step 2: 発見した問題を修正する**

読み込みで見つかった誤字・矛盾・層責務の説明の不正確さを、各ファイルにEditで直接修正する。

- [ ] **Step 3: 検証**

```bash
cd "c:/Dev/tutorials/clean-architecture"
grep -o '\](\.\/[^)]*\.md[^)]*)\|\](\.\.\/[^)]*\.md[^)]*)' docs/03-architecture-layers/*.md
```

Expected: 相対パスがすべて実在すること

```bash
git status --short
```

Expected: 変更ファイルが `docs/03-architecture-layers/*.md` のみ

- [ ] **Step 4: ユーザーへの報告**

Task 3で見つけた問題と修正内容を簡潔に報告する。

---

### Task 4: 04-design-patterns（デザインパターン）

**Files:**
- Modify: `docs/04-design-patterns/01-dependency-injection.md`
- Modify: `docs/04-design-patterns/02-repository-pattern.md`
- Modify: `docs/04-design-patterns/03-service-pattern.md`
- Modify: `docs/04-design-patterns/04-dto-pattern.md`
- Modify: `docs/04-design-patterns/05-adapter-pattern.md`

**チェックリスト:**
- [ ] `04-dto-pattern.md`: Reference の「円をまたぐデータの受け渡し（isolated, simple, data structures）」の説明と整合しているか
- [ ] `05-adapter-pattern.md`: Reference の Interface Adapters 層（MVC/Presenter/Controller）の説明との関係が正確か。GoF の Adapter パターンと Clean Architecture の Interface Adapters 層を混同していないか（別概念であることを明確にする）
- [ ] `02-repository-pattern.md`: Reference の「インフラ層はドメイン層のインターフェースを実装する」という依存性逆転の説明と一貫しているか
- [ ] 5パターンで「問題設定→実装例→テスト→チェックリスト」の構成が統一されているか
- [ ] 誤字脱字・不自然な日本語表現、リンクの有効性

- [ ] **Step 1: 対象ファイルを読み込む**

5ファイルをReadツールで読み込み、チェックリストと照合する。

- [ ] **Step 2: 発見した問題を修正する**

読み込みで見つかった誤字・矛盾・構成の不統一を、各ファイルにEditで直接修正する。

- [ ] **Step 3: 検証**

```bash
cd "c:/Dev/tutorials/clean-architecture"
grep -o '\](\.\/[^)]*\.md[^)]*)\|\](\.\.\/[^)]*\.md[^)]*)' docs/04-design-patterns/*.md
```

Expected: 相対パスがすべて実在すること

```bash
git status --short
```

Expected: 変更ファイルが `docs/04-design-patterns/*.md` のみ

- [ ] **Step 4: ユーザーへの報告**

Task 4で見つけた問題と修正内容を簡潔に報告する。

---

### Task 5: 05-implementation-guide（実装ガイド）

**Files:**
- Modify: `docs/05-implementation-guide/README.md`
- Modify: `docs/05-implementation-guide/01-project-structure.md`
- Modify: `docs/05-implementation-guide/02-entity-design.md`
- Modify: `docs/05-implementation-guide/03-usecase-design.md`
- Modify: `docs/05-implementation-guide/04-implementation-example.md`
- Modify: `docs/05-implementation-guide/05-testing-strategy.md`

**チェックリスト:**
- [ ] `01-project-structure.md`: ディレクトリ構成が Task 3 で扱った層構造・Task 1 の4重円対応表と用語レベルで一致しているか
- [ ] `02-entity-design.md`: Reference の Entities（enterprise-wide business rules）の定義と一致しているか
- [ ] `03-usecase-design.md`: Reference の Use Cases（application-specific business rules、データフローのorchestration）の定義と一致しているか
- [ ] `04-implementation-example.md`: 提示コード例が `02-entity-design.md`/`03-usecase-design.md` で説明した設計と矛盾しないか（クラス名・インターフェース名の一貫性）
- [ ] README.md がこの章の概要として6ファイルの内容を過不足なく要約しているか
- [ ] 誤字脱字・不自然な日本語表現、リンクの有効性

- [ ] **Step 1: 対象ファイルを読み込む**

6ファイルをReadツールで読み込み、チェックリストと照合する。特にファイル間でのクラス名・インターフェース名の一貫性に注意する。

- [ ] **Step 2: 発見した問題を修正する**

読み込みで見つかった誤字・矛盾・命名の不一致を、各ファイルにEditで直接修正する。

- [ ] **Step 3: 検証**

```bash
cd "c:/Dev/tutorials/clean-architecture"
grep -o '\](\.\/[^)]*\.md[^)]*)\|\](\.\.\/[^)]*\.md[^)]*)' docs/05-implementation-guide/*.md
```

Expected: 相対パスがすべて実在すること

```bash
git status --short
```

Expected: 変更ファイルが `docs/05-implementation-guide/*.md` のみ

- [ ] **Step 4: ユーザーへの報告**

Task 5で見つけた問題と修正内容を簡潔に報告する。

---

### Task 6: 06-best-practices（ベストプラクティス）

**Files:**
- Modify: `docs/06-best-practices/README.md`
- Modify: `docs/06-best-practices/01-naming-conventions.md`
- Modify: `docs/06-best-practices/02-error-handling.md`
- Modify: `docs/06-best-practices/03-logging-monitoring.md`
- Modify: `docs/06-best-practices/04-performance-optimization.md`
- Modify: `docs/06-best-practices/05-security.md`

**チェックリスト:**
- [ ] 各ベストプラクティスがClean Architectureの層構造（Task 3の内容）を前提にした説明になっているか（例: エラーハンドリングがどの層の責務かが明確か）
- [ ] コード例（Node.js/Java/Pythonなど）が技術的に妥当か（構文・API呼び出しが現実的か）
- [ ] README.md が5つのプラクティスを過不足なく要約しているか
- [ ] 誤字脱字・不自然な日本語表現、リンクの有効性

- [ ] **Step 1: 対象ファイルを読み込む**

6ファイルをReadツールで読み込み、チェックリストと照合する。

- [ ] **Step 2: 発見した問題を修正する**

読み込みで見つかった誤字・技術的な誤り・構成の不統一を、各ファイルにEditで直接修正する。

- [ ] **Step 3: 検証**

```bash
cd "c:/Dev/tutorials/clean-architecture"
grep -o '\](\.\/[^)]*\.md[^)]*)\|\](\.\.\/[^)]*\.md[^)]*)' docs/06-best-practices/*.md
```

Expected: 相対パスがすべて実在すること

```bash
git status --short
```

Expected: 変更ファイルが `docs/06-best-practices/*.md` のみ

- [ ] **Step 4: ユーザーへの報告**

Task 6で見つけた問題と修正内容を簡潔に報告する。

---

### Task 7: 07-common-pitfalls（アンチパターン）

**Files:**
- Modify: `docs/07-common-pitfalls/README.md`
- Modify: `docs/07-common-pitfalls/01-over-engineering.md`
- Modify: `docs/07-common-pitfalls/02-tight-coupling.md`
- Modify: `docs/07-common-pitfalls/03-anemic-model.md`
- Modify: `docs/07-common-pitfalls/04-circular-dependency.md`

**チェックリスト:**
- [ ] `03-anemic-model.md`: 「ドメインモデル貧血症」の説明が、Reference の Entities（ビジネスルールをカプセル化する）という定義との対比で正確に説明されているか
- [ ] `04-circular-dependency.md`: 循環依存の説明が Dependency Rule（内側にのみ依存）と整合しているか
- [ ] 4つのアンチパターンで「問題の根因→検出方法→修正方法→予防策」の構成が統一されているか
- [ ] README.md が4パターンを過不足なく要約しているか
- [ ] 誤字脱字・不自然な日本語表現、リンクの有効性

- [ ] **Step 1: 対象ファイルを読み込む**

5ファイルをReadツールで読み込み、チェックリストと照合する。

- [ ] **Step 2: 発見した問題を修正する**

読み込みで見つかった誤字・矛盾・構成の不統一を、各ファイルにEditで直接修正する。

- [ ] **Step 3: 検証**

```bash
cd "c:/Dev/tutorials/clean-architecture"
grep -o '\](\.\/[^)]*\.md[^)]*)\|\](\.\.\/[^)]*\.md[^)]*)' docs/07-common-pitfalls/*.md
```

Expected: 相対パスがすべて実在すること

```bash
git status --short
```

Expected: 変更ファイルが `docs/07-common-pitfalls/*.md` のみ

- [ ] **Step 4: ユーザーへの報告**

Task 7で見つけた問題と修正内容を簡潔に報告する。

---

### Task 8: 08-case-studies（ケーススタディ）

**Files:**
- Modify: `docs/08-case-studies/README.md`
- Modify: `docs/08-case-studies/01-ecommerce-site.md`
- Modify: `docs/08-case-studies/02-sns-platform.md`
- Modify: `docs/08-case-studies/03-microservices.md`

**チェックリスト:**
- [ ] 3つのケーススタディが、これまでの章（層構造・パターン・実装ガイド）で説明した用語・構成と一致しているか
- [ ] 実装例のコードが技術的に妥当か
- [ ] README.md が3つのケースを過不足なく要約しているか
- [ ] 誤字脱字・不自然な日本語表現、リンクの有効性

- [ ] **Step 1: 対象ファイルを読み込む**

4ファイルをReadツールで読み込み、チェックリストと照合する。

- [ ] **Step 2: 発見した問題を修正する**

読み込みで見つかった誤字・矛盾・技術的な誤りを、各ファイルにEditで直接修正する。

- [ ] **Step 3: 検証**

```bash
cd "c:/Dev/tutorials/clean-architecture"
grep -o '\](\.\/[^)]*\.md[^)]*)\|\](\.\.\/[^)]*\.md[^)]*)' docs/08-case-studies/*.md
```

Expected: 相対パスがすべて実在すること

```bash
git status --short
```

Expected: 変更ファイルが `docs/08-case-studies/*.md` のみ

- [ ] **Step 4: ユーザーへの報告**

Task 8で見つけた問題と修正内容を簡潔に報告する。

---

### Task 9: 09-tools-and-resources（ツール・リソース）

**Files:**
- Modify: `docs/09-tools-and-resources/README.md`
- Modify: `docs/09-tools-and-resources/01-frameworks.md`
- Modify: `docs/09-tools-and-resources/02-di-containers.md`
- Modify: `docs/09-tools-and-resources/03-development-tools.md`
- Modify: `docs/09-tools-and-resources/04-learning-resources.md`

**チェックリスト:**
- [ ] `04-learning-resources.md`: 書籍・URL等の事実情報（著者名、出版社、年、URLの形式）が正しいか。Reference に記載の書籍情報と一致しているか
- [ ] 紹介されているツール・フレームワーク・GitHubリポジトリの説明が最新の一般的な認識と大きく矛盾していないか（バージョン依存の記述は「執筆時点」等の注記があるか）
- [ ] README.md が4ファイルの内容を過不足なく要約しているか
- [ ] 誤字脱字・不自然な日本語表現、リンクの有効性

- [ ] **Step 1: 対象ファイルを読み込む**

5ファイルをReadツールで読み込み、チェックリストと照合する。

- [ ] **Step 2: 発見した問題を修正する**

読み込みで見つかった誤字・事実誤認・構成の不統一を、各ファイルにEditで直接修正する。

- [ ] **Step 3: 検証**

```bash
cd "c:/Dev/tutorials/clean-architecture"
grep -o '\](\.\/[^)]*\.md[^)]*)\|\](\.\.\/[^)]*\.md[^)]*)' docs/09-tools-and-resources/*.md
```

Expected: 相対パスがすべて実在すること

```bash
git status --short
```

Expected: 変更ファイルが `docs/09-tools-and-resources/*.md` のみ

- [ ] **Step 4: ユーザーへの報告**

Task 9で見つけた問題と修正内容を簡潔に報告する。

---

### Task 10: 章をまたぐ整合性の解消（README / COMPLETION-REPORT / MASTER-INDEX / QUICK-REFERENCE）

**Files:**
- Modify: `README.md`
- Modify: `COMPLETION-REPORT.md`
- Modify: `MASTER-INDEX.md`
- Modify: `QUICK-REFERENCE.md`

**背景（既に確認済みの矛盾）:**
- `README.md:278`: 「合計50ファイル、15,000行以上のコンテンツ」
- `COMPLETION-REPORT.md:309`: 「合計: 25ファイル, 30,000行以上」
- 両者は同じガイドの規模を指しているにもかかわらず、ファイル数・行数が食い違っている

**チェックリスト:**
- [ ] `docs/` 配下の実ファイル数を数え、README.md・COMPLETION-REPORT.md の「ファイル数」記載をこの実数に合わせて修正する
- [ ] 行数はセクションごとの概算（`≈`）であることを明記し、両ファイルで矛盾する断定的な数値を避ける（概数であることが分かる書き方に統一する）
- [ ] `COMPLETION-REPORT.md`「完成日: 2024年」のような古い日付表記がある場合、内容の実態（Task 1〜9で更新された最新の状態）と矛盾しないか確認する
- [ ] `MASTER-INDEX.md`・`QUICK-REFERENCE.md` が指すリンク・章立てがTask 1〜9修正後の構成と一致しているか

- [ ] **Step 1: 実ファイル数を数える**

```bash
cd "c:/Dev/tutorials/clean-architecture"
find docs -iname "*.md" | wc -l
```

出力された実数を記録する。

- [ ] **Step 2: README.md の記載を実数に合わせて修正する**

`README.md` の「✅ ガイド完成状況」セクション末尾（278行目付近）:

```diff
-📝 合計50ファイル、15,000行以上のコンテンツ
+📝 合計{Step 1で確認した実数}ファイル、docs/配下全体で約15,000〜20,000行のコンテンツ（概算）
```

（{Step 1で確認した実数}は実行時にStep 1の出力値に置き換える）

- [ ] **Step 3: COMPLETION-REPORT.md の記載を整合させる**

`COMPLETION-REPORT.md` の合計行（309行目付近）を README.md と矛盾しない概数表現に修正する:

```diff
-合計: 25ファイル, 30,000行以上
+合計: {Step 1で確認した実数}ファイル, 各セクションの概算行数の合計（約20,000〜25,000行、概数）
```

セクション別の内訳（287〜302行目付近）も「概算」であることが分かるよう、「≈」がすでに付いていることを確認し、断定的な表現になっていないか確認する。

- [ ] **Step 4: MASTER-INDEX.md / QUICK-REFERENCE.md のリンク確認**

```bash
grep -o '`docs/[^`]*`' MASTER-INDEX.md
```

Expected: 出力された各パスのファイルが実在すること（Task 1〜9で章構成に変更がないため、原則そのまま一致するはず）

- [ ] **Step 5: 検証**

```bash
cd "c:/Dev/tutorials/clean-architecture"
git status --short
```

Expected: 変更ファイルが `README.md`, `COMPLETION-REPORT.md`, `MASTER-INDEX.md`, `QUICK-REFERENCE.md`（変更があった場合のみ）に限られること

- [ ] **Step 6: ユーザーへの最終報告**

全10タスクを通じて見つかった問題の総括（章ごとの件数感）と、README/COMPLETION-REPORT間の整合性解消の内容を報告する。`ebook-output/` の再ビルドが必要であること、git commit はユーザーの指示があれば行うことを案内する。

---

## Self-Review Notes

- **Spec coverage**: 一次情報源の確認（Reference節）、全9章のレビュー（Task 1〜9）、章をまたぐ整合性解消（Task 10）、ebook-output対象外・既存差分に触れないことをGlobal Constraintsで明記——spec の全項目に対応済み
- **Placeholder scan**: Task 1・Task 10 は事前に具体的な修正内容が判明しているため diff を明記した。Task 2〜9 は「読んでから見つけ次第その場で修正する」という性質上、対象ファイル・チェックリスト・検証コマンドを具体的に明記し、TBD等のプレースホルダーは使用していない
- **Type consistency**: 各タスクの検証コマンド（相対リンクチェック・`git status --short`）は共通形式で統一している
