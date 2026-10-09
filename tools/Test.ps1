param([string] $EUIRoot, [switch] $UnitOnly)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if ($EUIRoot) { $env:EUI_TEST_ROOT = $EUIRoot }
Push-Location $root
try {
    $tests = @(Get-ChildItem 'Nameplates/tests/*.lua' | Where-Object {
        $_.BaseName -notin @('upstream', 'glow-mocks', 'border-mocks')
    } | ForEach-Object { 'Nameplates/tests/' + $_.Name })
    $tests += @('Core/tests/runtime.lua', 'Core/tests/persistence.lua')
    $tests += @(Get-ChildItem 'QuestTracker/tests/*.lua' | ForEach-Object { 'QuestTracker/tests/' + $_.Name })
    if ($UnitOnly) {
        $integration = @('Nameplates/tests/scaling.lua', 'Nameplates/tests/rendering.lua',
            'Nameplates/tests/cast-colors.lua', 'Nameplates/tests/cooldown-transitions.lua',
            'Nameplates/tests/options-search.lua', 'QuestTracker/tests/visibility.lua')
        $tests = @($tests | Where-Object { $_ -notin $integration })
        Write-Output 'Unit-only mode: six read-only upstream integration suites excluded; no EUI checkout required.'
    }
    foreach ($test in $tests) {
        $output = (& npx.cmd --yes --package fengari-node-cli fengari $test 2>&1 | Out-String)
        Write-Output ($test + "`n" + $output.Trim())
        # Fengari may return exit code zero after a Lua failure. Inspect output.
        if ($LASTEXITCODE -ne 0 -or $output -notmatch '(?m)^PASS(?:[: ]|$)' -or
            $output -match 'stack traceback:|(?m)^FAIL:') { throw "Failed Lua suite: $test" }
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'Core/tests/packaging.ps1'
    if ($LASTEXITCODE -ne 0) { throw 'Core packaging checks failed' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'QuestTracker/tests/packaging.ps1'
    if ($LASTEXITCODE -ne 0) { throw 'QuestTracker packaging checks failed' }
    & git diff --check
    if ($LASTEXITCODE -ne 0) { throw 'Whitespace checks failed' }
    Write-Output "PASS: $($tests.Count) Lua suites, two packaging suites and git diff --check"
} finally { Pop-Location }
