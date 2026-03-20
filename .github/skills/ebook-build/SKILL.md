---
name: ebook-build
description: Build Kindle-compatible ebooks for clean-architecture from numbered markdown chapters using PowerShell. Use when generating EPUB, AZW3, or MOBI, or when updating ebook build metadata, stylesheet, output settings, page-list behavior, or validation flow.
license: MIT
---

# Ebook Build Skill

## Overview

This skill provides the standard ebook build entrypoint for the clean-architecture repository.

The workflow is self-contained under `.github/skills/ebook-build` and no longer depends on `kindle/` as its default conversion source.

## What This Skill Does

1. Loads build settings from `./configs/clean-architecture.build.json`
2. Detects chapter folders and stages markdown into a temporary workspace
3. Uses `./scripts/convert-to-kindle.ps1` as the conversion core
4. Uses `./scripts/add-pagelist-functions.ps1` when page-list is enabled
5. Applies skill-scoped metadata and stylesheet files
6. Builds EPUB and optional AZW3/MOBI artifacts
7. Copies generated files into `ebook-output/`

## Requirements

- Windows PowerShell 5.1+
- Pandoc installed and available in PATH
- Calibre (`ebook-convert`) available in PATH for AZW3/MOBI generation

## Quick Usage

```powershell
cd c:\dev\apps\clean-architecture
.\.github\skills\ebook-build\scripts\invoke-ebook-build.ps1 `
  -ConfigFile .\.github\skills\ebook-build\configs\clean-architecture.build.json
```

## Skill Files

- Runner: `./scripts/invoke-ebook-build.ps1`
- Conversion core: `./scripts/convert-to-kindle.ps1`
- Page-list helper: `./scripts/add-pagelist-functions.ps1`
- Build configuration: `./configs/clean-architecture.build.json`
- Metadata: `./configs/clean-architecture.metadata.yaml`
- Stylesheet: `./assets/style.css`
- Usage guide: `./docs/README.md`
- Kindle compatibility checklist: `./docs/KINDLE-COMPATIBILITY-CHECKLIST.md`
- Specification: `./EBOOK_BUILD_SPECIFICATION.md`
- Validation checklist: `./VALIDATION_CHECKLIST.md`

## Notes

- `enablePageList` is enabled by default in the Skill configuration.
- Final artifacts are written to `ebook-output/`.
