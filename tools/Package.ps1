param(
    [ValidateSet('Nameplates', 'QuestTracker', 'Bags', 'All')]
    [string] $Feature = 'All',
    [string] $OutputDirectory,
    [ValidatePattern('^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$')]
    [string] $Version,
    [ValidatePattern('^\d+(?:,\s*\d+)*$')]
    [string] $Interface
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
    $files += @([regex]::Matches($toc, '(?m)^((?:Shared/)?[A-Za-z]+\.lua)\r?$') | ForEach-Object { $_.Groups[1].Value })
    foreach ($file in $files) {
        $path = if ($file.StartsWith('Shared/')) { Join-Path $root ('Core/' + $file.Substring(7)) } else { Join-Path $directory $file }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing package file: $path" }
        [pscustomobject] @{ Path = $path; Entry = "$identity/$file" }
    }
    $media = Join-Path $directory 'Media'
    if (Test-Path -LiteralPath $media -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $media -File -Recurse) {
            $relative = $file.FullName.Substring($directory.Length + 1).Replace('\', '/')
            [pscustomobject] @{ Path = $file.FullName; Entry = "$identity/$relative" }
        }
    }
    [pscustomobject] @{ Path = (Join-Path $root 'LICENSE'); Entry = "$identity/LICENSE" }
}

$features = if ($Feature -eq 'All') { @('Nameplates', 'QuestTracker', 'Bags') } else { @($Feature) }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
foreach ($name in $features) {
    $identity = "EllesmereUIExtend$name"
    $toc = Get-Content -LiteralPath (Join-Path $root "$name/$identity.toc") -Raw
    $packageVersion = $Version
    if (-not $packageVersion) { $packageVersion = [regex]::Match($toc, '(?m)^## Version: ([\w.-]+)\r?$').Groups[1].Value }
    if (-not $packageVersion) { throw "No package version in $identity.toc" }
    $files = @(Get-AddonFiles $name $identity)
    $destination = Join-Path $OutputDirectory "$identity-$packageVersion.zip"
    $stream = [System.IO.File]::Open($destination, [System.IO.FileMode]::Create)
    try {
        $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($file in $files) {
                if ($file.Entry.EndsWith('.toc') -and ($Version -or $Interface)) {
                    $content = Get-Content -LiteralPath $file.Path -Raw
                    if ($Version) { $content = [regex]::Replace($content, '(?m)^## Version: [^\r\n]+', "## Version: $Version") }
                    if ($Interface) { $content = [regex]::Replace($content, '(?m)^## Interface: [^\r\n]+', "## Interface: $Interface") }
                    $entry = $archive.CreateEntry($file.Entry)
                    $writer = New-Object System.IO.StreamWriter($entry.Open(), (New-Object System.Text.UTF8Encoding($false)))
                    try { $writer.Write($content) } finally { $writer.Dispose() }
                } else {
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                        $archive, $file.Path, $file.Entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
                }
            }
        } finally { $archive.Dispose() }
    } finally { $stream.Dispose() }
    Write-Output $destination
}
