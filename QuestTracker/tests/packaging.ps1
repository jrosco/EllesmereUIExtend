# Fengari does not implement io.open; inspect packaging/source invariants here.
$ErrorActionPreference = 'Stop'
$addonRoot = Split-Path $PSScriptRoot -Parent
$tocPath = Join-Path $addonRoot 'EllesmereUIExtendQuestTracker.toc'
$toc = Get-Content -LiteralPath $tocPath -Raw
$script:checks = 0
function Check([bool] $condition, [string] $label) {
    $script:checks++
    if (-not $condition) { throw $label }
}
Check ($toc -match '## Dependencies: EllesmereUI, EllesmereUIQuestTracker\r?\n') 'Independent addon dependencies'
Check ($toc -match '## SavedVariables: EllesmereUIExtendQuestTrackerDB\r?\n') 'Independent SavedVariables identity'
Check ($toc -match '## Interface: .*16001') 'Forever interface included'
$files = @([regex]::Matches($toc, '(?m)^([A-Za-z]+\.lua)\r?$') | ForEach-Object { $_.Groups[1].Value })
Check ($files.Count -eq 10) 'All ten runtime modules are in the TOC'
foreach ($file in $files) {
    $path = Join-Path $addonRoot $file
    Check (Test-Path -LiteralPath $path) "Packaged runtime file: $file"
    $source = Get-Content -LiteralPath $path -Raw
    Check ($source -notmatch ':(Update|SetCollapsed|ToggleCollapsed)\s*\(') "No direct native layout/collapse calls: $file"
    Check ($source -notmatch '(AddQuestWatch|RemoveQuestWatch|StartTracking|StopTracking)\s*\(') "No tracking writes: $file"
    Check ($source -notmatch ':SetParent\s*\(') "No native reparenting: $file"
    Check ($source -notmatch 'Nameplates|_ModuleNS|_EQT') "No cross-addon dependencies/private registry use: $file"
}
Write-Output "PASS: $script:checks QuestTracker packaging and native-ownership invariants"
