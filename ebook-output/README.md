# ebook-output

このディレクトリには、電子書籍形式の出力を格納します。

## 生成方法

```bash
# Step 1: 原稿生成・アセット収集
npm run ebook:step1

# Step 2: EPUB 生成
npm run ebook:step2

# Step 2b: PDF 生成
npm run ebook:step2b

# Step 3: KDP 登録パッケージ生成
npm run ebook:step3
```

## 出力ファイル

| ファイル | 説明 |
|---------|------|
| `clean-architecture.epub` | EPUB 形式の電子書籍 |
| `clean-architecture.pdf` | PDF 形式の電子書籍 |
| `clean-architecture.print.html` | 印刷用 HTML |
| `clean-architecture.manuscript.md` | 全章を結合した原稿 |
| `clean-architecture-kdp-registration.md` | KDP 登録用パッケージ |
| `cover.jpg` | カバー画像 |
| `paperback-cover.pdf` | ペーパーバックカバー |
