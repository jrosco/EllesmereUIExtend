$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$checks = 0
function Check([bool] $value, [string] $label) {
    $script:checks++
    if (-not $value) { throw $label }
}
function Reject([scriptblock] $action, [string] $label) {
    $rejected = $false
    try { & $action | Out-Null } catch { $rejected = $true }
    Check $rejected $label
}
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { Join-Path $env:LOCALAPPDATA 'Temp/opencode' }
$work = Join-Path $tempRoot ('extend-release-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$eventPath = Join-Path $work 'event.json'
$event = @{ action = 'published'; release = @{ draft = $false; prerelease = $true;
    tag_name = 'nameplates-v0.1.0-alpha.1'; id = 42 } }
function WriteEvent { $event | ConvertTo-Json | Set-Content -LiteralPath $eventPath -Encoding utf8 }
WriteEvent
$outputPath = Join-Path $work 'outputs.txt'
$release = & (Join-Path $root 'tools/ReleaseMetadata.ps1') -EventPath $eventPath -OutputPath $outputPath
Check ($release.version -eq '0.1.0-alpha.1' -and $release.zip -eq 'EllesmereUIExtendNameplates-0.1.0-alpha.1.zip') 'Version comes from feature-specific alpha tag'
Check ((Get-Content -LiteralPath $outputPath -Raw) -match 'release_id=42') 'Workflow outputs contain validated release ID'
foreach ($badTag in @('v0.1.0-alpha.1', 'questtracker-v0.1.0-alpha.1', 'nameplates-v0.1.0', 'nameplates-v0.1.0-beta.1', "nameplates-v0.1.0-alpha.1`ninjected=value")) {
    $event.release.tag_name = $badTag; WriteEvent
    Reject { & (Join-Path $root 'tools/ReleaseMetadata.ps1') -EventPath $eventPath } "Invalid tag blocked: $badTag"
}
$event.release.tag_name = 'nameplates-v0.1.0-alpha.1'
$event.release.prerelease = $false; WriteEvent
Reject { & (Join-Path $root 'tools/ReleaseMetadata.ps1') -EventPath $eventPath } 'Stable GitHub release cannot deploy an alpha'
$event.release.prerelease = $true; $event.release.draft = $true; WriteEvent
Reject { & (Join-Path $root 'tools/ReleaseMetadata.ps1') -EventPath $eventPath } 'Draft cannot deploy'
$sourceTOCs = @{}
foreach ($path in @('Nameplates/EllesmereUIExtendNameplates.toc')) {
    $sourceTOCs[$path] = Get-Content -LiteralPath (Join-Path $root $path) -Raw
}
$zip = & (Join-Path $root 'tools/Package.ps1') -Feature Nameplates -Version '0.1.0-alpha.1' -Interface '16001' -OutputDirectory $work
Check ([System.IO.Path]::GetFileName($zip) -eq $release.zip) 'Release ZIP uses alpha version'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
try {
    foreach ($identity in @('EllesmereUIExtendNameplates')) {
        $reader = New-Object System.IO.StreamReader($archive.GetEntry("$identity/$identity.toc").Open())
        try { $toc = $reader.ReadToEnd() } finally { $reader.Dispose() }
        Check ($toc -match '(?m)^## Interface: 16001\r?$') 'Release does not advertise untested Retail support'
        Check ($toc -match '(?m)^## Version: 0\.1\.0-alpha\.1\r?$') 'Feature has the generated release version'
    }
    Check (-not ($archive.Entries | Where-Object { $_.FullName -like 'EllesmereUIExtendQuestTracker/*' })) 'Nameplates release excludes QuestTracker'
} finally { $archive.Dispose() }
foreach ($path in $sourceTOCs.Keys) {
    Check ((Get-Content -LiteralPath (Join-Path $root $path) -Raw) -ceq $sourceTOCs[$path]) 'Release overrides leave source TOCs untouched'
}

# Mock only the read-only HTTP request. ValidateOnly must never POST a file.
$oldToken = $env:CF_API_TOKEN
$env:CF_API_TOKEN = 'test-token-not-a-real-secret'
$global:releaseTestVersions = @([pscustomobject] @{ id = 123; name = '1.60.1' }, [pscustomobject] @{ id = 999; name = '12.1.5' })
function Invoke-RestMethod {
    param($Uri, $Headers, $Method)
    Check ($Uri -eq 'https://wow.curseforge.com/api/game/versions' -and $Method -eq 'Get') 'Only version resolution is requested in validation mode'
    return $global:releaseTestVersions
}
$changelog = Join-Path $work 'CHANGELOG.md'
'Forever-only alpha testing.' | Set-Content -LiteralPath $changelog -Encoding utf8
$uploadArgs = @{ ProjectId = '42'; ZipPath = $zip; Version = '0.1.0-alpha.1'; ChangelogPath = $changelog; ValidateOnly = $true }
try {
    $metadata = (& (Join-Path $root 'tools/Upload-CurseForge.ps1') @uploadArgs) | ConvertFrom-Json
    Check ($metadata.releaseType -eq 'alpha' -and $metadata.gameVersions.Count -eq 1 -and $metadata.gameVersions[0] -eq 123) 'Upload resolves Forever ID and always selects Alpha'
    Check ($null -eq $metadata.visibility -and $null -eq $metadata.status) 'Upload cannot alter project visibility'
    $global:releaseTestVersions = @([pscustomobject] @{ id = 999; name = '12.1.5' })
    Reject { & (Join-Path $root 'tools/Upload-CurseForge.ps1') @uploadArgs } 'Missing Forever version fails closed instead of uploading Retail'
    $global:releaseTestVersions = @([pscustomobject] @{ id = 123; name = '1.60.1' }, [pscustomobject] @{ id = 456; name = '1.60.1' })
    Reject { & (Join-Path $root 'tools/Upload-CurseForge.ps1') @uploadArgs } 'Ambiguous Forever version fails closed'
    $uploadArgs.Version = '0.1.0'
    Reject { & (Join-Path $root 'tools/Upload-CurseForge.ps1') @uploadArgs } 'Stable version cannot reach upload API'
    $uploadArgs.Version = '0.1.0-alpha.1'
    $retailZip = & (Join-Path $root 'tools/Package.ps1') -Feature Nameplates -Version '0.1.0-alpha.1' -OutputDirectory (Join-Path $work 'untested-retail')
    $uploadArgs.ZipPath = $retailZip
    Reject { & (Join-Path $root 'tools/Upload-CurseForge.ps1') @uploadArgs } 'Multi-client source TOCs cannot be uploaded as a Forever-only alpha'
    $uploadArgs.ZipPath = $zip
    $env:CF_API_TOKEN = ''
    Reject { & (Join-Path $root 'tools/Upload-CurseForge.ps1') @uploadArgs } 'Missing API token blocked'
} finally {
    $env:CF_API_TOKEN = $oldToken
    Remove-Variable -Name releaseTestVersions -Scope Global
}
Write-Output "PASS: $checks alpha tag, workflow metadata, package overrides and mocked CurseForge validation checks"
