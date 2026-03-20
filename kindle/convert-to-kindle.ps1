# ============================================
# Clean Architecture を Kindle 形式に自動変換
# PowerShell スクリプト
# ============================================
# 
# 使用方法:
#   1. このスクリプトを実行
#   2. EPUB、MOBI、AZW3形式に自動変換
#   3. output フォルダに生成
#

# 設定
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$outputDir = Join-Path $scriptDir "output"
$metadataFile = Join-Path $scriptDir "metadata.yaml"
$styleFile = Join-Path $scriptDir "style.css"

# 出力フォルダを作成
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
    Write-Host "📁 出力フォルダを作成: $outputDir" -ForegroundColor Green
}

# ファイルリスト（変換順序）
$files = @(
    "$projectRoot/00-COVER.md",
    "$projectRoot/01-introduction/01-overview.md",
    "$projectRoot/01-introduction/02-why-clean-architecture.md",
    "$projectRoot/01-introduction/03-key-concepts.md",
    "$projectRoot/02-core-principles/01-single-responsibility.md",
    "$projectRoot/02-core-principles/02-open-closed.md",
    "$projectRoot/02-core-principles/03-liskov-substitution.md",
    "$projectRoot/02-core-principles/04-interface-segregation.md",
    "$projectRoot/02-core-principles/05-dependency-inversion.md",
    "$projectRoot/03-architecture-layers/01-presentation-layer.md",
    "$projectRoot/03-architecture-layers/02-application-layer.md",
    "$projectRoot/03-architecture-layers/03-domain-layer.md",
    "$projectRoot/03-architecture-layers/04-infrastructure-layer.md",
    "$projectRoot/03-architecture-layers/05-layer-dependencies.md",
    "$projectRoot/04-design-patterns/01-dependency-injection.md",
    "$projectRoot/04-design-patterns/02-repository-pattern.md",
    "$projectRoot/04-design-patterns/03-service-pattern.md",
    "$projectRoot/04-design-patterns/04-dto-pattern.md",
    "$projectRoot/04-design-patterns/05-adapter-pattern.md",
    "$projectRoot/05-implementation-guide/01-project-structure.md",
    "$projectRoot/05-implementation-guide/02-entity-design.md",
    "$projectRoot/05-implementation-guide/03-usecase-design.md",
    "$projectRoot/05-implementation-guide/04-implementation-example.md",
    "$projectRoot/05-implementation-guide/05-testing-strategy.md",
    "$projectRoot/06-best-practices/01-naming-conventions.md",
    "$projectRoot/06-best-practices/02-error-handling.md",
    "$projectRoot/06-best-practices/03-logging-monitoring.md",
    "$projectRoot/06-best-practices/04-performance-optimization.md",
    "$projectRoot/06-best-practices/05-security.md",
    "$projectRoot/07-common-pitfalls/01-over-engineering.md",
    "$projectRoot/07-common-pitfalls/02-tight-coupling.md",
    "$projectRoot/07-common-pitfalls/03-anemic-model.md",
    "$projectRoot/07-common-pitfalls/04-circular-dependency.md",
    "$projectRoot/08-case-studies/01-ecommerce-site.md",
    "$projectRoot/08-case-studies/02-sns-platform.md",
    "$projectRoot/08-case-studies/03-microservices.md"
)

# 不足しているファイルをチェック
$missingFiles = @()
foreach ($file in $files) {
    if (-not (Test-Path $file)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "⚠️  見つからないファイル:" -ForegroundColor Yellow
    $missingFiles | ForEach-Object { Write-Host "   - $_" }
    Write-Host "🔄 既存ファイルのみで処理を続行します..." -ForegroundColor Yellow
    
    # 存在するファイルのみにフィルター
    $files = $files | Where-Object { Test-Path $_ }
}

# 絶対パスに変換して、Pandoc に渡す前のパス変換を正しくする
$files = $files | ForEach-Object {
    try {
        (Resolve-Path $_ -ErrorAction Stop).ProviderPath
    } catch {
        throw "ファイルパスの解決に失敗しました: $_"
    }
}

# metadata.yaml が cover-image: null などを含むとPandocがopenBinaryFileエラーを出す場合があるためクリーンコピーを作成
$effectiveMetadataFile = $metadataFile
$hasNullCover = Select-String -Path $metadataFile -Pattern '^\s*(cover-image|epub-cover-image):\s*null\s*$' -Quiet
if ($hasNullCover) {
    $cleanLines = Get-Content $metadataFile | Where-Object { $_ -notmatch '^\s*(cover-image|epub-cover-image):\s*null\s*$' }
    $effectiveMetadataFile = Join-Path $outputDir "metadata.cleaned.yaml"
    $cleanLines | Set-Content -Path $effectiveMetadataFile -Encoding UTF8
    Write-Host "ℹ️ メタデータファイルをクリーンコピーして処理: $effectiveMetadataFile" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📚 処理するファイル数: $($files.Count)" -ForegroundColor Cyan
Write-Host ""

function Test-ValidPath {
    param(
        [Parameter(Mandatory=$true)] [string]$Path,
        [Parameter(Mandatory=$true)] [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Name が空です。"
    }

    $invalidChars = [System.IO.Path]::GetInvalidPathChars()
    if ($Path.IndexOfAny($invalidChars) -ge 0) {
        throw "$Name に不正な文字が含まれています: $Path"
    }

    if (-not (Test-Path $Path)) {
        throw "$Name が見つかりません: $Path"
    }
}

# Pandoc がインストールされているかチェック
$pandocPath = Get-Command pandoc -ErrorAction SilentlyContinue
if (-not $pandocPath) {
    Write-Host "❌ エラー: Pandoc がインストールされていません" -ForegroundColor Red
    Write-Host "   以下から Pandoc をダウンロードしてください:" -ForegroundColor Yellow
    Write-Host "   https://pandoc.org/installing.html" -ForegroundColor Cyan
    exit 1
}

try {
    Test-ValidPath -Path $metadataFile -Name 'metadata.yaml'
    Test-ValidPath -Path $styleFile -Name 'style.css'
    $files | ForEach-Object { Test-ValidPath -Path $_ -Name "入力ファイル" }
} catch {
    Write-Host "❌ ファイルパス検証エラー: $_" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Pandoc を検出しました: $(pandoc --version | Select-Object -First 1)" -ForegroundColor Green
Write-Host ""

# ============================================
# 1. EPUB 形式に変換
# ============================================
Write-Host "🔄 EPUB 形式に変換中..." -ForegroundColor Cyan

$epubOutput = Join-Path $outputDir "clean-architecture.epub"

# 目次をコンパクトにするには 1 を使用（現在は 2）
# 1: H1 のみ
# 2: H1/H2
# 3+: H1/H2/H3...
$tocDepth = 3

$pandocArgs = @()
$pandocArgs += $files
$pandocArgs += @(
    "--from=markdown+auto_identifiers",
    "--to=epub3",
    "--metadata-file=$effectiveMetadataFile",
    "--css=$styleFile",
    "--standalone",
    "--output=$epubOutput",
    "--top-level-division=chapter",
    "--table-of-contents",
    "--toc-depth=$tocDepth"
)

try {
    & pandoc @pandocArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ EPUB 作成成功: $epubOutput" -ForegroundColor Green
    } else {
        Write-Host "❌ EPUB 作成失敗 (エラーコード: $LASTEXITCODE)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ EPUB 作成エラー: $_" -ForegroundColor Red
}

Write-Host ""

# ============================================
# 2. Calibre (ebook-convert) で AZW3 に変換
# ============================================
Write-Host "🔄 AZW3 形式に変換中..." -ForegroundColor Cyan

$azw3Output = Join-Path $outputDir "clean-architecture.azw3"
$ebookConvert = Get-Command ebook-convert -ErrorAction SilentlyContinue

if ($ebookConvert) {
    try {
        & ebook-convert $epubOutput $azw3Output `
            --language ja `
            --margin-left 0 `
            --margin-right 0 `
            --margin-top 0 `
            --margin-bottom 0
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ AZW3 作成成功: $azw3Output" -ForegroundColor Green
        } else {
            Write-Host "⚠️  AZW3 作成スキップ (Calibreが見つかりません)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  AZW3 作成スキップ: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  ebook-convert が見つかりません (Calibre をインストールすれば AZW3 変換可)" -ForegroundColor Yellow
    Write-Host "   https://calibre-ebook.com/download" -ForegroundColor Cyan
}

Write-Host ""

# ============================================
# 3. MOBI 形式に変換（オプション）
# ============================================
Write-Host "🔄 MOBI 形式に変換中..." -ForegroundColor Cyan

$mobiOutput = Join-Path $outputDir "clean-architecture.mobi"

if ($ebookConvert) {
    try {
        & ebook-convert $epubOutput $mobiOutput `
            --language ja
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ MOBI 作成成功: $mobiOutput" -ForegroundColor Green
        } else {
            Write-Host "⚠️  MOBI 作成スキップ" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  MOBI 作成スキップ: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  MOBI 作成スキップ (Calibre が必要)" -ForegroundColor Yellow
}

Write-Host ""

# ============================================
# 完了報告
# ============================================
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "✅ 変換処理が完了しました" -ForegroundColor Green
Write-Host "=" * 60

Write-Host ""
Write-Host "📦 生成されたファイル:" -ForegroundColor Cyan
$outputs = Get-ChildItem $outputDir -Include '*.epub','*.azw3','*.mobi' -File -ErrorAction SilentlyContinue

if ($outputs -and $outputs.Count -gt 0) {
    $outputs | ForEach-Object {
        $sizeKB = [math]::Round($_.Length / 1KB, 2)
        Write-Host "  ✓ $($_.Name) ($sizeKB KB)" -ForegroundColor Green
    }
} else {
    Write-Host "  (出力フォルダを確認してください)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📂 出力フォルダ: $outputDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "📖 次のステップ:" -ForegroundColor Cyan
Write-Host "  1. EPUB ファイルで内容確認"
Write-Host "  2. Kindle互換性チェック (KINDLE-COMPATIBILITY-CHECKLIST.md 参照)"
Write-Host "  3. AZW3 を Kindle デバイスに転送"
Write-Host ""

# 出力フォルダをエクスプローラーで開く
if ($outputs) {
    Write-Host "📂 出力フォルダを開きますか? (Y/n)" -ForegroundColor Cyan
    $response = Read-Host
    if ($response -ne 'n' -and $response -ne 'N') {
        Invoke-Item $outputDir
    }
}
