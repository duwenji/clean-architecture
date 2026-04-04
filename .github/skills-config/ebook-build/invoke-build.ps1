[CmdletBinding()]
param(
    [string]$ConfigFile = '.github/skills-config/ebook-build/clean-architecture.build.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
}

function Resolve-ConfiguredPath {
    param(
        [string]$BasePath,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($Value)) {
        return $Value
    }
    (Join-Path $BasePath $Value)
}

function Get-ConfigValue {
    param(
        [object]$Config,
        [string]$Name
    )

    if ($null -eq $Config) {
        return $null
    }

    $property = $Config.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-SharedSkillRoot {
    param([string]$RepoRoot)

    $candidates = @(
        (Join-Path $RepoRoot '.github/skills/shared-skills/ebook-build'),
        (Join-Path $RepoRoot '.github/skills/shared-copilot-skills/ebook-build'),
        (Join-Path $RepoRoot '.github/skills/ebook-build'),
        (Join-Path $RepoRoot '../shared-copilot-skills/ebook-build')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    throw "Shared ebook-build skill not found. Checked: $($candidates -join ', ')"
}

$repoRoot = Resolve-RepoRoot
$configPath = Resolve-ConfiguredPath -BasePath $repoRoot -Value $ConfigFile
$config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$sharedSkillRoot = Get-SharedSkillRoot -RepoRoot $repoRoot

$projectNameValue = Get-ConfigValue -Config $config -Name 'projectName'
$sourceRootValue = Get-ConfigValue -Config $config -Name 'sourceRoot'
$outputDirValue = Get-ConfigValue -Config $config -Name 'outputDir'
$metadataFileValue = Get-ConfigValue -Config $config -Name 'metadataFile'
$styleFileValue = Get-ConfigValue -Config $config -Name 'styleFile'
$formatsValue = Get-ConfigValue -Config $config -Name 'formats'
$chapterDirPatternValue = Get-ConfigValue -Config $config -Name 'chapterDirPattern'
$chapterFilePatternValue = Get-ConfigValue -Config $config -Name 'chapterFilePattern'
$coverFileValue = Get-ConfigValue -Config $config -Name 'coverFile'
$mermaidModeValue = Get-ConfigValue -Config $config -Name 'mermaidMode'
$mermaidFormatValue = Get-ConfigValue -Config $config -Name 'mermaidFormat'
$failOnMermaidErrorValue = Get-ConfigValue -Config $config -Name 'failOnMermaidError'

$projectName = if ($projectNameValue) { [string]$projectNameValue } else { Split-Path -Leaf $repoRoot }
$sourceRoot = Resolve-ConfiguredPath -BasePath $repoRoot -Value $sourceRootValue
if (-not $sourceRoot) { $sourceRoot = $repoRoot }
$outputDir = Resolve-ConfiguredPath -BasePath $repoRoot -Value $outputDirValue
if (-not $outputDir) { $outputDir = Join-Path $repoRoot 'ebook-output' }

$metadataFile = Resolve-ConfiguredPath -BasePath $repoRoot -Value $metadataFileValue
if (-not $metadataFile) { $metadataFile = Join-Path $repoRoot ".github/skills-config/ebook-build/$projectName.metadata.yaml" }

$styleFile = Resolve-ConfiguredPath -BasePath $repoRoot -Value $styleFileValue
if (-not $styleFile) { $styleFile = Join-Path $sharedSkillRoot 'assets/style.css' }

$invokeScript = Join-Path $sharedSkillRoot 'scripts/invoke-ebook-build.ps1'
$kindleTemplateDir = Join-Path $sharedSkillRoot 'scripts'

$formats = if ($null -ne $formatsValue) { @($formatsValue) } else { @('epub') }
$chapterDirPattern = if ($chapterDirPatternValue) { [string]$chapterDirPatternValue } else { '^\d{2}-' }
$chapterFilePattern = if ($chapterFilePatternValue) { [string]$chapterFilePatternValue } else { '^\d{2}-.*\.md$' }
$coverFile = if ($coverFileValue) { [string]$coverFileValue } else { '00-COVER.md' }
$mermaidMode = if ($mermaidModeValue) { [string]$mermaidModeValue } else { 'auto' }
$mermaidFormat = if ($mermaidFormatValue) { [string]$mermaidFormatValue } else { 'svg' }
$failOnMermaidError = if ($null -ne $failOnMermaidErrorValue) { [bool]$failOnMermaidErrorValue } else { $false }

$params = @{
        SourceRoot = $sourceRoot
        OutputDir = $outputDir
        ProjectName = $projectName
        KindleTemplateDir = $kindleTemplateDir
        MetadataFile = $metadataFile
        StyleFile = $styleFile
        Formats = $formats
        ChapterDirPattern = $chapterDirPattern
        ChapterFilePattern = $chapterFilePattern
        CoverFile = $coverFile
        MermaidMode = $mermaidMode
        MermaidFormat = $mermaidFormat
        FailOnMermaidError = $failOnMermaidError
}

& $invokeScript @params

if ($LASTEXITCODE -ne 0) {
    throw "ebook build failed with exit code $LASTEXITCODE"
}


