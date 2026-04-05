# Copilot Instructions

このリポジトリでは、電子書籍生成を shared-copilot-skills 経由で実行する。

## Ebook Build
- 入口: `.github/skills-config/ebook-build/invoke-build.ps1`
- 設定: `.github/skills-config/ebook-build/clean-architecture.build.json`
- メタデータ: `.github/skills-config/ebook-build/clean-architecture.metadata.yaml`

## Shared skill discovery order
1. `.github/skills/shared-skills/*`
2. `.github/skills/*`
3. `../shared-copilot-skills/*`

Copilot は上記順で skill root を探索し、見つかった shared スクリプトを実行する。
