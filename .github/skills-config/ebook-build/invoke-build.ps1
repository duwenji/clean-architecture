# Consumer repository wrapper for ebook-build skill.
# Delegates all build logic to the shared dispatcher in shared-copilot-skills.
#
# Usage:
#   pwsh invoke-build.ps1 -BuildStep step1
#   pwsh invoke-build.ps1 -BuildStep step2
#   pwsh invoke-build.ps1 -BuildStep step3

[CmdletBinding()]
param(
    [string]$ConfigFile = '.github/skills-config/ebook-build/clean-architecture.build.json',
    [Parameter(Mandatory = $true)]
    [ValidateSet('step1', 'step2', 'step3')]
    [string]$BuildStep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

$sharedCandidates = @(
    (Join-Path $repoRoot '../shared-copilot-skills/ebook-build'),
    (Join-Path $repoRoot '.github/skills/shared-skills/ebook-build'),
    (Join-Path $repoRoot '.github/skills/shared-copilot-skills/ebook-build')
)

$sharedSkillRoot = $null
foreach ($candidate in $sharedCandidates) {
    if (Test-Path $candidate) {
        $sharedSkillRoot = (Resolve-Path $candidate).Path
        break
    }
}
if (-not $sharedSkillRoot) {
    throw "Shared ebook-build skill not found. Checked: $($sharedCandidates -join ', ')"
}

$dispatcherScript = Join-Path $sharedSkillRoot 'scripts/invoke-build.ps1'
if (-not (Test-Path $dispatcherScript)) {
    throw "Shared dispatcher not found: $dispatcherScript"
}

& pwsh -NoProfile -ExecutionPolicy Bypass -File $dispatcherScript `
    -RepoRoot   $repoRoot `
    -ConfigFile $ConfigFile `
    -BuildStep  $BuildStep

exit $LASTEXITCODE