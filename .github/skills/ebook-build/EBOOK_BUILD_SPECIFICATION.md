# Ebook Build Specification

## Goal

Provide a reusable, agent-friendly, self-contained ebook build workflow for clean-architecture.

## Source Discovery

Given `sourceRoot`:

1. If `sourceRoot` contains chapter directories matching `chapterDirPattern`, use `sourceRoot`.
2. Otherwise, if `sourceRoot/docs` contains matching chapter directories, use `sourceRoot/docs`.
3. Otherwise, fail with a clear diagnostic.

## Chapter Contract

- Chapter directories: `chapterDirPattern` (default `^\\d{2}-`)
- Section markdown files: `chapterFilePattern` (default `^\\d{2}-.*\\.md$`)
- Cover file: `coverFile` (default `00-COVER.md`, optional)
- Root `README.md`: optional, copied into staging when present so the converter can refresh AUTO-TOC safely

## Staging Contract

The runner creates an isolated temporary workspace:

- `temp/book/`                      staged source root
- `temp/book/kindle/`               staged conversion scripts + metadata + stylesheet
- `temp/book/kindle/output/`        intermediate outputs

## Build Steps

1. Validate required toolchain and configured file paths.
2. Stage source markdown content from the detected content root.
3. Copy `scripts/convert-to-kindle.ps1` into the staging area.
4. Copy `scripts/add-pagelist-functions.ps1` into the staging area when available.
5. Copy skill-scoped metadata and stylesheet files into the staging area.
6. Patch the staged converter for non-interactive execution.
7. Run the staged converter.
8. Copy selected format outputs into `outputDir` using `projectName` as the filename base.
9. Clean the temporary workspace unless `preserveTemp` is enabled.

## Page-List Behavior

- `enablePageList: true` is the clean-architecture Skill default.
- If `enablePageList: true` but `add-pagelist-functions.ps1` is not found in `kindleTemplateDir`, the runner logs a warning and continues with page-list disabled.

## Format Behavior

- `epub`: expected if Pandoc is available
- `azw3`: expected when `ebook-convert` is available
- `mobi`: expected when `ebook-convert` is available

Missing optional formats produce warnings, not hard failures.

## Error Strategy

Hard fail:

- source root not found
- metadata or stylesheet file not found
- conversion core script missing
- no chapter content found
- staged converter exits with non-zero status
- no requested artifacts copied to the output directory

Soft warnings:

- optional output format not produced
- page-list requested but helper script missing

## Reuse Scope

Reusable for repositories that satisfy the chapter contract and either use the bundled conversion scripts or override them with a compatible PowerShell conversion core.
