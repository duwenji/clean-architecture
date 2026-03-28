[CmdletBinding()]
param(
    [ValidateSet('metadata', 'quiz', 'normalize', 'all')]
    [string]$Mode = 'all',
    [string]$ConfigFile = '.github/skills-config/quiz-generator/quiz-generator.config.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Node {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )

    & node $ScriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Node script failed with exit code ${LASTEXITCODE}: $ScriptPath"
    }
}

function Resolve-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
}

function Get-SharedSkillRoot {
    param([string]$RepoRoot)

    $candidates = @(
        (Join-Path $RepoRoot '.github/skills/shared-skills/quiz-generator'),
        (Join-Path $RepoRoot '.github/skills/shared-copilot-skills/quiz-generator'),
        (Join-Path $RepoRoot '.github/skills/quiz-generator'),
        (Join-Path $RepoRoot '../shared-copilot-skills/quiz-generator')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    throw "Shared quiz-generator skill not found. Checked: $($candidates -join ', ')"
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
    return (Join-Path $BasePath $Value)
}

$repoRoot = Resolve-RepoRoot
$configPath = Resolve-ConfiguredPath -BasePath $repoRoot -Value $ConfigFile
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$sharedSkillRoot = Get-SharedSkillRoot -RepoRoot $repoRoot

$metadataPath = Resolve-ConfiguredPath -BasePath $repoRoot -Value $config.metadataPath
$normalizeDataDir = Resolve-ConfiguredPath -BasePath $repoRoot -Value $config.normalizeDataDir
$questionGlobs = @()
if ($null -ne $config.questionGlobs) {
    $questionGlobs = @($config.questionGlobs)
}

$metadataScript = Join-Path $sharedSkillRoot 'scripts/validate-quiz-metadata.mjs'
$questionScript = Join-Path $sharedSkillRoot 'scripts/validate-quiz-questions.mjs'
$normalizeScript = Join-Path $sharedSkillRoot 'scripts/normalize-quiz-ids.mjs'

$metadataSchema = Join-Path $sharedSkillRoot 'schemas/quizset-metadata-schema.json'
$questionSchema = Join-Path $sharedSkillRoot 'schemas/question-schema.json'
$ajvModule = Join-Path $repoRoot 'node_modules/ajv/dist/ajv.js'

if ($Mode -eq 'metadata' -or $Mode -eq 'all') {
    Invoke-Node -ScriptPath $metadataScript -Arguments @('--metadata', $metadataPath, '--schema', $metadataSchema, '--ajv', $ajvModule)
}

if ($Mode -eq 'quiz' -or $Mode -eq 'all') {
    if ($questionGlobs.Count -eq 0) {
        throw 'questionGlobs is empty in config file.'
    }

    $matched = 0
    foreach ($glob in $questionGlobs) {
        $resolvedGlob = Resolve-ConfiguredPath -BasePath $repoRoot -Value $glob
        $files = Get-ChildItem -Path $resolvedGlob -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            if ($file.Name -eq 'metadata.json' -or $file.Name -eq 'quizSets.json' -or $file.Name.EndsWith('.analysis.json')) {
                continue
            }
            Invoke-Node -ScriptPath $questionScript -Arguments @('--quiz', $file.FullName, '--schema', $questionSchema, '--ajv', $ajvModule)
            $matched++
        }
    }

    if ($matched -eq 0) {
        throw 'No quiz files matched questionGlobs.'
    }
}

if ($Mode -eq 'normalize') {
    if ([string]::IsNullOrWhiteSpace($normalizeDataDir)) {
        throw 'normalizeDataDir is required for normalize mode.'
    }
    Invoke-Node -ScriptPath $normalizeScript -Arguments @('--dataDir', $normalizeDataDir)
}

Write-Host "quiz-generator validation wrapper completed: Mode=$Mode"

