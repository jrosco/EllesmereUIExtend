param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[1-9]\d*$')] [string] $ProjectId,
    [Parameter(Mandatory = $true)] [string] $ZipPath,
    [Parameter(Mandatory = $true)] [ValidatePattern('^\d+\.\d+\.\d+-alpha\.\d+$')] [string] $Version,
    [Parameter(Mandatory = $true)] [string] $ChangelogPath,
    [string] $ResultPath,
    [switch] $ValidateOnly
)

$ErrorActionPreference = 'Stop'
$token = $env:CF_API_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) { throw 'Set CF_API_TOKEN through a GitHub Actions secret, never in source or command arguments.' }
if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) { throw 'Release ZIP does not exist.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ZipPath).Path)
try {
    foreach ($identity in @('EllesmereUIExtendNameplates')) {
        $entry = $archive.GetEntry("$identity/$identity.toc")
        if (-not $entry) { throw "Missing bundled addon TOC: $identity" }
        $reader = New-Object System.IO.StreamReader($entry.Open())
        try { $toc = $reader.ReadToEnd() } finally { $reader.Dispose() }
        if ($toc -notmatch '(?m)^## Interface: 16001\r?$' -or
            $toc -notmatch ('(?m)^## Version: ' + [regex]::Escape($Version) + '\r?$')) {
            throw 'Only a matching-version Forever-only Nameplates TOC may be uploaded.'
        }
    }
    foreach ($file in @('Core.lua', 'Options.lua')) {
        if (-not $archive.GetEntry("EllesmereUIExtendNameplates/Shared/$file")) { throw "Missing embedded core file: $file" }
    }
    if ($archive.Entries | Where-Object { $_.FullName -notmatch '^EllesmereUIExtendNameplates/' }) {
        throw 'The Nameplates upload must contain only its own addon folder.'
    }
} finally { $archive.Dispose() }
$changelog = Get-Content -LiteralPath $ChangelogPath -Raw
if ([string]::IsNullOrWhiteSpace($changelog)) { throw 'A release changelog is required.' }

# Resolve the actual game-version ID instead of confusing WoW Interface 16001
# with CurseForge numeric IDs. Fail closed if the name is absent/ambiguous.
$base = 'https://wow.curseforge.com/api'
$headers = @{ 'X-Api-Token' = $token }
try { $versions = Invoke-RestMethod -Uri "$base/game/versions" -Headers $headers -Method Get }
catch { throw 'Could not retrieve CurseForge WoW versions. Check the API token and service availability.' }
$forever = @($versions | Where-Object { $_.name -eq '1.60.1' })
if ($forever.Count -ne 1 -or [string] $forever[0].id -notmatch '^[1-9]\d*$') {
    throw 'CurseForge must return one valid game-version entry for Forever 1.60.1. No Retail or Classic fallback will be uploaded.'
}
$metadata = [ordered] @{
    changelog = $changelog
    changelogType = 'markdown'
    displayName = "Nameplates $Version (Forever)"
    gameVersions = @([int] $forever[0].id)
    releaseType = 'alpha'
}
if ($ValidateOnly) {
    Write-Output ($metadata | ConvertTo-Json -Depth 5)
    return
}

Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromMinutes(5)
$client.DefaultRequestHeaders.Add('X-Api-Token', $token)
$multipart = New-Object System.Net.Http.MultipartFormDataContent
$stream = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $ZipPath).Path)
try {
    $json = New-Object System.Net.Http.StringContent(($metadata | ConvertTo-Json -Depth 5 -Compress))
    $multipart.Add($json, 'metadata')
    $file = New-Object System.Net.Http.StreamContent($stream)
    $file.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue('application/zip')
    $multipart.Add($file, 'file', [System.IO.Path]::GetFileName($ZipPath))
    # Never automatically retry an upload: a timeout may still have created a file.
    try { $response = $client.PostAsync("$base/projects/$ProjectId/upload-file", $multipart).GetAwaiter().GetResult() }
    catch { throw 'CurseForge upload did not return a result. Check the project Files page before retrying to avoid duplicate uploads.' }
    try {
        if (-not $response.IsSuccessStatusCode) {
            throw "CurseForge upload returned HTTP $([int] $response.StatusCode). Check project permissions and Files before retrying."
        }
        $result = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
        if ([string] $result.id -notmatch '^[1-9]\d*$') { throw 'CurseForge did not return a file ID. Check Files before retrying.' }
        if ($ResultPath) {
            [ordered] @{ projectId = $ProjectId; fileId = $result.id; version = $Version;
                releaseType = 'alpha'; gameVersion = '1.60.1' } |
                ConvertTo-Json | Out-File -LiteralPath $ResultPath -Encoding utf8
        }
        Write-Output "Uploaded Alpha file ID $($result.id) to CurseForge project $ProjectId (Forever 1.60.1). Moderation may still be pending."
    } finally { $response.Dispose() }
} finally { $multipart.Dispose(); $stream.Dispose(); $client.Dispose() }
