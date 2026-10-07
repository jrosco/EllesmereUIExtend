param(
    [Parameter(Mandatory = $true)] [string] $EventPath,
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$event = Get-Content -LiteralPath $EventPath -Raw | ConvertFrom-Json
if ($event.action -ne 'published' -or $event.release.draft -or -not $event.release.prerelease) {
    throw 'Only published GitHub prereleases can deploy Nameplates alpha builds.'
}
$tag = [string] $event.release.tag_name
if ($tag -notmatch '^nameplates-v(\d+\.\d+\.\d+-alpha\.\d+)$') {
    throw 'Use a Nameplates alpha tag such as nameplates-v0.1.0-alpha.1.'
}
$version = $Matches[1]
$releaseId = [string] $event.release.id
if ($releaseId -notmatch '^[1-9]\d*$') { throw 'Missing numeric GitHub release ID.' }
$result = [ordered] @{ tag = $tag; version = $version; release_id = $releaseId;
    zip = "EllesmereUIExtendNameplates-$version.zip" }
if ($OutputPath) {
    foreach ($key in $result.Keys) { "$key=$($result[$key])" | Out-File -LiteralPath $OutputPath -Encoding utf8 -Append }
}
[pscustomobject] $result
