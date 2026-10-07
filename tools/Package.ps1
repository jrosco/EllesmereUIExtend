param(
    [ValidateSet('Nameplates', 'QuestTracker', 'All')]
    [string] $Feature = 'All',
    [string] $OutputDirectory
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'dist' }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-AddonFiles([string] $source, [string] $identity) {
    $directory = Join-Path $root $source
    $tocName = "$identity.toc"
    $toc = Get-Content -LiteralPath (Join-Path $directory $tocName) -Raw
    $files = @($tocName, 'README.md')
    $files += @([regex]::Matches($toc, '(?m)^([A-Za-z]+\.lua)\r?$') | ForEach-Object { $_.Groups[1].Value })
    foreach ($file in $files) {
        $path = Join-Path $directory $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing package file: $path" }
        [pscustomobject] @{ Path = $path; Entry = "$identity/$file" }
    }
    [pscustomobject] @{ Path = (Join-Path $root 'LICENSE'); Entry = "$identity/LICENSE" }
}

$features = if ($Feature -eq 'All') { @('Nameplates', 'QuestTracker') } else { @($Feature) }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
foreach ($name in $features) {
    $identity = "EllesmereUIExtend$name"
    $toc = Get-Content -LiteralPath (Join-Path $root "$name/$identity.toc") -Raw
    $version = [regex]::Match($toc, '(?m)^## Version: ([\w.-]+)\r?$').Groups[1].Value
    if (-not $version) { throw "No package version in $identity.toc" }
    $files = @(Get-AddonFiles 'Core' 'EllesmereUIExtend') + @(Get-AddonFiles $name $identity)
    $destination = Join-Path $OutputDirectory "$identity-$version.zip"
    $stream = [System.IO.File]::Open($destination, [System.IO.FileMode]::Create)
    try {
        $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($file in $files) {
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $archive, $file.Path, $file.Entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }
        } finally { $archive.Dispose() }
    } finally { $stream.Dispose() }
    Write-Output $destination
}
