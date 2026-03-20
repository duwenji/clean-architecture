# Ebook Build Usage Guide

このドキュメントは、clean-architecture の電子書籍変換フローを Skill として運用するための実行ガイドです。

---

## フォルダ構成

```text
.github/skills/ebook-build/
├── SKILL.md                                  Skill 定義
├── EBOOK_BUILD_SPECIFICATION.md              実装仕様
├── VALIDATION_CHECKLIST.md                   検証チェックリスト
├── configs/
│   ├── clean-architecture.build.json         clean-architecture 用実行設定
│   └── clean-architecture.metadata.yaml      書籍メタデータ
├── assets/
│   └── style.css                             EPUB スタイルシート
├── docs/
│   ├── README.md                             このファイル
│   └── KINDLE-COMPATIBILITY-CHECKLIST.md     Kindle 互換性チェック
└── scripts/
  ├── invoke-ebook-build.ps1                実行エントリポイント
  ├── convert-to-kindle.ps1                 変換コア
  └── add-pagelist-functions.ps1            page-list 補助

ebook-output/
├── clean-architecture.epub
├── clean-architecture.azw3
└── clean-architecture.mobi
```

---

## 実行方法

```powershell
cd c:\dev\apps\clean-architecture
.\.github\skills\ebook-build\scripts\invoke-ebook-build.ps1 `
  -ConfigFile .\.github\skills\ebook-build\configs\clean-architecture.build.json
```

---

## ビルド前提

- Pandoc が PATH にあること
- AZW3 / MOBI も生成する場合は Calibre の `ebook-convert` が PATH にあること

確認:

```powershell
pandoc --version
ebook-convert --version
```

---

## clean-architecture 向けの構成

- 章ソース: リポジトリ直下の `00-COVER.md` と `01-` から `09-` の章フォルダ
- 変換コア: `.github/skills/ebook-build/scripts/convert-to-kindle.ps1`
- page-list 補助: `.github/skills/ebook-build/scripts/add-pagelist-functions.ps1`
- Skill のメタデータ: `.github/skills/ebook-build/configs/clean-architecture.metadata.yaml`
- Skill のスタイル: `.github/skills/ebook-build/assets/style.css`
- 出力先: `ebook-output/`

標準のビルド資産は Skill 配下に集約しています。

---

## カスタマイズ

### メタデータ

編集対象:

```text
.github/skills/ebook-build/configs/clean-architecture.metadata.yaml
```

### スタイル

編集対象:

```text
.github/skills/ebook-build/assets/style.css
```

### 出力設定

編集対象:

```text
.github/skills/ebook-build/configs/clean-architecture.build.json
```

---

## 出力確認

生成後に確認する主な成果物:

- `ebook-output/clean-architecture.epub`
- `ebook-output/clean-architecture.azw3`
- `ebook-output/clean-architecture.mobi`

---

## コミット方針

- `ebook-output/` 配下の更新はビルド結果の一部として扱います
- 本文、メタデータ、スタイル、変換スクリプト、ビルド設定を変更して再生成した場合は、生成物もコミット対象に含めます
- レビュー時は設定差分だけでなく、生成物の更新有無も確認します

---

## 検証

変換後は以下を確認します。

- `../VALIDATION_CHECKLIST.md`
- `./KINDLE-COMPATIBILITY-CHECKLIST.md`

特に以下を確認してください。

- 目次が正しい
- 内部リンクが機能する
- 見出し階層が崩れていない
- コードブロックが正しく表示される

---

## トラブルシューティング

### Pandoc が見つからない

- Pandoc をインストール
- PowerShell を再起動

### ebook-convert が見つからない

- Calibre をインストール
- PowerShell を再起動

### markdown が検出されない

- 章フォルダ名が `^\\d{2}-` に一致しているか
- ファイル名が `^\\d{2}-.*\\.md$` に一致しているか
- `sourceRoot` がリポジトリ直下を指しているか
