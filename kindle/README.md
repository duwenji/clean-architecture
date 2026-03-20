# 📖 Clean Architecture を Kindle 形式に変換

このフォルダには、**clean-architecture** マークダウン教材を **Kindle 互換形式（EPUB / AZW3 / MOBI）** に自動変換するための完全なツールセットが含まれています。

---

## 📋 フォルダ構成

```
kindle/
├── README.md                              ← このファイル（使い方ガイド）
├── convert-to-kindle.ps1                  ← 自動変換スクリプト（メインツール）
├── metadata.yaml                          ← 書籍メタデータ設定
├── style.css                              ← EPUB スタイルシート
├── KINDLE-COMPATIBILITY-CHECKLIST.md      ← 互換性チェックリスト
└── output/                                ← 変換済みファイル出力先（実行後に自動作成）
    ├── clean-architecture.epub            ← EPUB 3.0 形式
    ├── clean-architecture.azw3            ← Kindle デバイス対応
    └── clean-architecture.mobi            ← 旧式 Kindle デバイス対応
```

---

## 🎯 各ファイルの役割

### 1. **convert-to-kindle.ps1** - メイン自動変換スクリプト

**何をするのか:**
- すべてのマークダウン（`*.md`）ファイルを 1 つの統合された電子書籍に変換
- 自動的に目次（Table of Contents）を生成
- 複数の形式（EPUB → AZW3 → MOBI）に自動変換
- エラーハンドリングと詳細なログを表示

**依存ツール:**
- ✅ **Pandoc** 必須（Markdown→EPUB 変換用）
- ⚠️ **Calibre（ebook-convert）** オプション（EPUB→AZW3/MOBI 変換用）

**実行方法:**
```powershell
# PowerShell を開く
cd c:\dev\apps\clean-architecture\kindle

# 実行ポリシー確認（初回のみ）
Get-ExecutionPolicy

# 必要に応じて一時的に変更
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# スクリプト実行
.\convert-to-kindle.ps1
```

**処理フロー:**
```
入力（マークダウンファイル）
    ↓
[1] Pandoc で EPUB に変換
    ↓ metadata.yaml と style.css を適用
    ↓
[2] Calibre で AZW3 に変換（オプション）
    ├→ EPUB → AZW3（最新 Kindle 形式）
    └→ EPUB → MOBI（旧式形式）
    ↓
出力フォルダ：output/
    ├── clean-architecture.epub ✅
    ├── clean-architecture.azw3 ✅
    └── clean-architecture.mobi ✅
```

---

### 2. **metadata.yaml** - 書籍のメタデータ設定

**何をするのか:**
電子書籍の「属性情報」を定義します。Pandoc がこれを EPUB に埋め込みます。

**主要な設定項目:**

```yaml
title: クリーンアーキテクチャ完全ガイド
subtitle: 実務で使える設計原則と実装パターン
author: Architecture Guide Contributors
date: 2026-03-19
language: ja                              ← 日本語を指定（重要）
```

**カスタマイズ例:**

```yaml
# 著者を変更
author: あなたの名前

# 日付を更新
date: 2026-04-01

# 出版社を追加（オプション）
publisher: Your Company Name

# ISBN を設定（Kindle ストア販売用）
isbn: 978-1234567890
```

**EPUB 設定項目:**

```yaml
toc: true                    ← 目次を自動生成
toc-depth: 2                 ← 見出しレベル 2 まで含める
number-sections: false       ← Pandoc 自動採番は使わない（見出し番号は変換スクリプトで付与）
shift-heading-level-by: -1   ← 見出しレベルを 1 段上げる
```

補足:
- EPUB の章・節見出し番号は `01-`, `02-` のようなファイル名接頭辞を `convert-to-kindle.ps1` が取り込み、目次と本文に同じ表記で出力します。

---

### 3. **style.css** - EPUB スタイルシート

**何をするのか:**
Kindle デバイス上での見た目や表示を制御します。

**対応要素:**

| 要素 | 設定される内容 |
|------|----------------|
| `h1, h2, h3, ...` | 見出し（フォントサイズ、余白、ページ分断） |
| `p` | 段落（テキスト字下げ、行間） |
| `code, pre` | コードブロック（背景色、フォント） |
| `table` | テーブル（枠線、背景色） |
| `blockquote` | 引用（左枠線、斜体） |
| `.note, .warning` | 特殊ボックス（メモ、警告） |

**Kindle 最適化機能:**

```css
/* 見出しの前でページ分断 */
h1 { page-break-before: always; }

/* テーブル内でページ分断を避ける */
table { page-break-inside: avoid; }

/* 日本語フォント対応 */
body { font-family: Georgia, serif; }
```

**カスタマイズ例:**

フォントサイズを大きくしたい場合：
```css
body {
  font-size: 1.1em;  /* デフォルト 1em から増加 */
}
```

見出しの色を変更したい場合：
```css
h1, h2 {
  color: #0066cc;  /* 青色に */
}
```

---

### 4. **KINDLE-COMPATIBILITY-CHECKLIST.md** - 互換性チェックリスト

**何をするのか:**
変換後の EPUB/AZW3 が Kindle デバイスで正しく表示されるかを確認するための **30+ 項目のチェックリスト**。

**主要なチェック項目:**

✅ **変換前の検証**
- マークダウン構文（見出し、リスト、コード）
- テーブルとリンク
- 画像ファイルのパス

✅ **EPUB 検証**
- 目次が自動生成されているか
- スタイルが正しく適用されているか
- テーブル・コードが崩れていないか

✅ **Kindle デバイス確認**
- 実機で日本語が正しく表示されるか
- 目次からのリンク機能が動作するか
- フォント・レイアウトが最適か

✅ **よくある問題と解決策**
- 文字化け → UTF-8 エンコード確認
- テーブル崩れ → 列数を減らす
- 日本語表示エラー → metadata.yaml で `language: ja` 確認

---

## 🚀 クイックスタート（5ステップ）

### ステップ 1️⃣: 前提ツールのインストール

**A. Pandoc をインストール（必須）**

```powershell
# 方法①：公式サイトから手動ダウンロード
# https://pandoc.org/installing.html

# 方法②：Chocolatey を使用（推奨）
choco install -y pandoc

# インストール確認
pandoc --version
```

**B. Calibre をインストール（推奨：AZW3/MOBI 変換用）**

```powershell
# 方法①：公式ダウンロード
# https://calibre-ebook.com/download

# 方法②：Chocolatey を使用
choco install -y calibre

# インストール確認
ebook-convert --version
```

### ステップ 2️⃣: メタデータをカスタマイズ（オプション）

```yaml
# metadata.yaml を開いて編集
author: あなたの名前       # デフォルト: Architecture Guide Contributors
date: 2026-04-01           # 本日の日付に更新
title: あなたのタイトル    # カスタムタイトル
```

### ステップ 3️⃣: スタイルを調整（オプション）

```css
/* style.css を開いて調整 */
/* 例：本文フォントサイズを大きく */
body {
  font-size: 1.1em;  /* 10% 増加 */
}
```

### ステップ 4️⃣: 変換スクリプトを実行

```powershell
# PowerShell を開く
cd c:\dev\apps\clean-architecture\kindle

# スクリプト実行
.\convert-to-kindle.ps1

# 出力をチェック
dir output/
```

**期待される出力：**
```
📦 生成されたファイル:
  ✓ clean-architecture.epub (2.5 MB)
  ✓ clean-architecture.azw3 (2.3 MB)
  ✓ clean-architecture.mobi (2.1 MB)
```

### ステップ 5️⃣: Kindle互換性をチェック

**A. EPUB リーダーで確認**

```
推奨リーダー:
- Apple Books（macOS/iPhone）
- Google Play Books（Android）
- Calibre E-book Viewer（Windows/Mac）
```

**B. 実際の Kindle デバイスで確認**

```
1. Amazon Kindle Cloud Reader（ブラウザ版）
   https://read.amazon.com

2. Kindle for iOS/Android アプリ
   - AZW3 をアップロード
   - レイアウト・フォントが最適か確認

3. Kindle 物理デバイス
   - Paperwhite / Oasis / Voyage
   - AZW3 をケーブル/WiFi で転送
```

**チェックリスト:**

- [ ] テキストが読みやすいか
- [ ] 目次から章へリンクする
- [ ] テーブルが正しく表示される
- [ ] コードが折り返されていない
- [ ] 日本語が文字化けしていない

---

## 📊 処理結果の確認

スクリプト実行後、以下の情報が表示されます：

```
============================================================
✅ 変換処理が完了しました
============================================================

📦 生成されたファイル:
  ✓ clean-architecture.epub (2.5 MB)
  ✓ clean-architecture.azw3 (2.3 MB)
  ✓ clean-architecture.mobi (2.1 MB)

📂 出力フォルダ: c:\dev\apps\clean-architecture\kindle\output

📖 次のステップ:
  1. EPUB ファイルで内容確認
  2. Kindle互換性チェック (KINDLE-COMPATIBILITY-CHECKLIST.md 参照)
  3. AZW3 を Kindle デバイスに転送
```

---

## ⚙️ トラブルシューティング

### 🔴 エラー：Pandoc が見つからない

```
❌ エラー: Pandoc がインストールされていません
```

**解決策:**
```powershell
# Pandoc をインストール
choco install -y pandoc

# または公式サイトからダウンロード
# https://pandoc.org/installing.html

# インストール後、PowerShell を再起動して実行
.\convert-to-kindle.ps1
```

---

### 🟡 警告：Calibre が見つからない

```
⚠️  ebook-convert が見つかりません (Calibre をインストールすれば AZW3 変換可)
```

**説明:**
Pandoc のみで EPUB は生成されましたが、AZW3/MOBI はスキップされています。

**解決策:**
```powershell
# Calibre をインストール
choco install -y calibre

# スクリプトを再実行
.\convert-to-kindle.ps1
```

---

### 🔴 エラー：想定したファイルが変換対象に入らない

```
📚 処理するファイル数: 期待より少ない
```

**説明:**
現在の `convert-to-kindle.ps1` は `$files` の手動配列ではなく、
フォルダ/ファイル名を走査して変換対象を自動決定します。

- 章フォルダ: `^\d{2}-` に一致するディレクトリ
- 章内ファイル: `^\d{2}-.*\.md` に一致するファイル
- `README.md` は変換対象外

**解決策:**

1. 章フォルダ名とファイル名が命名規則に合っているか確認
2. 必要に応じてファイル名をリネーム（例: `appendix.md` → `10-appendix.md`）
3. `convert-to-kindle.ps1` を再実行

**カスタム取り込み例（命名規則を拡張する場合）:**
```powershell
# Get-ChapterEntries 内の条件を調整
$chapterDirs = Get-ChildItem -Path $RootPath -Directory |
  Where-Object { $_.Name -match '^\d{2}-|^appendix-' } |
  Sort-Object Name
```

---

### 🔴 エラー：日本語が文字化け

```
❌ EPUB を開くと日本語が読めない
```

**原因と解決策:**

| 原因 | 解決策 |
|------|--------|
| マークダウンファイルが UTF-8 でない | VS Code で UTF-8 で保存（画面右下） |
| metadata.yaml に `language: ja` がない | metadata.yaml で `language: ja` を確認 |
| CSS が日本語フォントに対応していない | style.css の `font-family` を確認 |

**確認手順:**
```powershell
# VS Code でマークダウンを開く
code c:\dev\apps\clean-architecture\00-COVER.md

# 右下の「UTF-8」確認 → もし違う形式なら「UTF-8」をクリック
```

---

### 🟡 警告：生成されたファイルが非常に大きい

```
❌ EPUB ファイルが 100MB を超えている
```

**原因と解決策:**

| 原因 | 解決策 |
|------|--------|
| 高解像度画像が多数含まれている | 画像を圧縮（JPEG で 300x400px 程度） |
| マークダウンに大量のコードが含まれている | 長いコードを複数のセクションに分割 |
| テーブルが非常に複雑 | テーブルを簡潔にするか、複数に分割 |

---

## 🔧 カスタマイズ例

### 例 1️⃣: 著者名をカスタマイズ

```yaml
# metadata.yaml を編集
author: John Smith
```

### 例 2️⃣: 見出しのスタイルを変更

```css
/* style.css の h1 セクションを編集 */
h1 {
  color: #0066cc;           /* 青色に */
  font-size: 2em;           /* より大きく */
  text-align: center;       /* 中央配置 */
}
```

### 例 3️⃣: ファイル変換順序をカスタマイズ

```powershell
# デフォルトでは番号付きファイル名順（01-, 02-, ...）で処理される
# 順序を変えたい場合はファイル名の番号を変更する
# 例: 05-implementation-guide/01-project-structure.md
#  -> 05-implementation-guide/00-project-structure.md

# 例外的に固定順を実装したい場合は Get-ChapterEntries の
# Sort-Object 条件をカスタマイズする
```

### 例 4️⃣: 出力ファイル名をカスタマイズ

```powershell
# convert-to-kindle.ps1 を編集

# デフォルト
# $epubOutput = Join-Path $outputDir "clean-architecture.epub"

# カスタム
$epubOutput = Join-Path $outputDir "my-custom-book.epub"
```

---

## 📱 Kindle デバイス別対応表

| デバイス | EPUB | MOBI | AZW3 | 日本語 | 備考 |
|---------|------|------|------|--------|------|
| **Kindle Paperwhite** | ✅ 変換後 | ✅ | ✅ | ✅ | 最も一般的 |
| **Kindle Oasis** | ✅ 変換後 | ✅ | ✅ | ✅ | 高級モデル |
| **Kindle Voyage** | ✅ 変換後 | ✅ | ✅ | ✅ | 旧モデル |
| **Kindle Basic** | ✅ 変換後 | ✅ | ⚠️△ | ✅ | 基本モデル |
| **Kindle Fire** | ✅ | ❌ | ✅ | ✅ | タブレット |
| **Kindle Cloud Reader** | ✅ | ✅ | ✅ | ✅ | ブラウザ版 |
| **Kindle for iOS** | ✅ | ⚠️△ | ✅ | ✅ | iPhone/iPad |
| **Kindle for Android** | ✅ | ⚠️△ | ✅ | ✅ | Android 端末 |

**凡例**: ✅ = 完全対応 | △ = 部分対応 | ❌ = 非対応

---

## 💡 ベストプラクティス

### ✅ 推奨される作業フロー

```
1. 最初に Pandoc だけで EPUB を生成
   └→ 変換スクリプト実行
      └→ EPUB を複数のリーダーで確認

2. EPUB が問題なく表示されたら Calibre をインストール
  └→ 再度スクリプトを実行
      └→ AZW3/MOBI を生成

3. Kindle デバイスで AZW3 を確認
   └→ 必要に応じて CSS を調整
      └→ スクリプト再実行
```

### ✅ マークダウン作成時の注意点

```markdown
# ❌ 避けるべき

1. 非常に長い段落（Kindle では高さが無制限）
2. 複雑なネストされたテーブル（セル > 5 列）
3. 高解像度画像（ファイル > 1MB/画像）
4. 不規則な見出しレベル（H1 → H3 にジャンプ）

# ✅ 推奨される方法

1. 短い段落（1～3 文）で分割
2. シンプルなテーブル（最大 4～5 列）
3. 圧縮された画像（300～500px 幅）
4. 規則的な見出し（H1 → H2 → H3）
```

---

## 📚 参考リソース

| リソース | URL | 用途 |
|---------|-----|------|
| **Pandoc Manual** | https://pandoc.org/MANUAL.html | Pandoc の詳細設定 |
| **EPUB 仕様** | https://www.w3.org/publishing/epub32/ | EPUB 3.2 標準仕様 |
| **Calibre ドキュメント** | https://manual.calibre-ebook.com/ | ebook-convert の詳細 |
| **Amazon KDP ヘルプ** | https://kdp.amazon.com/help | Kindle 本の販売方法 |
| **Markdown 仕様** | https://commonmark.org/ | Markdown 標準 |
| **CSS リファレンス** | https://developer.mozilla.org/en-US/docs/Web/CSS | CSS プロパティ詳細 |

---

## 🎯 次のステップ

### 短期（今日）
- [ ] Pandoc をインストール
- [ ] `convert-to-kindle.ps1` を実行
- [ ] EPUB を生成
- [ ] Calibre E-book Viewer で確認

### 中期（1 週間）
- [ ] 実際の Kindle デバイスで確認
- [ ] CSS を微調整
- [ ] metadata.yaml をカスタマイズ
- [ ] 再度変換・確認

### 長期（1 ヶ月）
- [ ] Amazon KDP へ申請（販売予定の場合）
- [ ] 専門家によるレビューを取得
- [ ] フィードバックに基づいて修正

---

## 📞 よくある質問（FAQ）

**Q: EPUB と AZW3 の違いは？**

A: 
- **EPUB** = 標準電子書籍形式（Apple Books、Google Play Books など、どのリーダーでも読める）
- **AZW3** = Amazon Kindle の最新フォーマット（Kindle 固有の機能や最適化）

推奨：両方生成して、用途に応じて使い分ける（個人利用なら EPUB、Kindle ストアなら AZW3）

---

**Q: 修正後、再度変換するには？**

A:
1. マークダウン（`.md`）ファイルを編集
2. metadata.yaml または style.css をカスタマイズ（必要に応じて）
3. `convert-to-kindle.ps1` を再実行
4. output/ フォルダが上書きされます

---

**Q: Kindle ストアで販売できる？**

A:
はい、可能です。以下の手順：

1. `convert-to-kindle.ps1` で AZW3 を生成
2. [Amazon KDP コンソール](https://kdp.amazon.com)にログイン
3. 「新規タイトル」を作成
4. メタデータを入力
5. AZW3 ファイルをアップロード
6. 『本を確認』で内容をプレビュー
7. 公開ボタンをクリック

詳細は [KINDLE-COMPATIBILITY-CHECKLIST.md](./KINDLE-COMPATIBILITY-CHECKLIST.md) の「Amazon Kindle Direct Publishing への申請」セクションを参照。

---

**Q: トラブルが発生した場合どうする？**

A:
1. このファイルの「⚙️ トラブルシューティング」セクションを確認
2. [KINDLE-COMPATIBILITY-CHECKLIST.md](./KINDLE-COMPATIBILITY-CHECKLIST.md) で互換性をチェック
3. 上記参考リソースの公式ドキュメントを参照

---

## 📝 更新履歴

| 日付 | 内容 | バージョン |
|------|------|-----------|
| 2026-03-20 | 初回リリース | 1.0 |
| | Pandoc + Calibre 統合 | |
| | EPUB 3.0 対応 | |
| | 日本語完全サポート | |

---

## 📄 ライセンス

このツールセットは **MIT License** のもとで公開されています。
自由に使用、修正、配布できます。

---

**最後に:** このツール群を使用して Kindle 形式に変換できるようになりました。
何かご不明な点や改善提案があれば、お気軽にお問い合わせください！

**Happy Reading! 📚**
