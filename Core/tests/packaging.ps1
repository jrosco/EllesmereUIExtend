$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Add-Type -AssemblyName System.IO.Compression.FileSystem
$checks = 0
function Check([bool] $value, [string] $label) {
    $script:checks++
    if (-not $value) { throw $label }
}
$coreToc = Get-Content -LiteralPath (Join-Path $root 'Core/EllesmereUIExtend.toc') -Raw
Check ($coreToc -match '## Dependencies: EllesmereUI\r?\n') 'Core requires EUI alone'
Check ($coreToc -match '## SavedVariables: EllesmereUIExtendDB\r?\n') 'Core owns shared SavedVariables'
Check ($coreToc -match '## Interface: .*16001') 'Core supports Forever interface'
$archives = @(& (Join-Path $root 'tools/Package.ps1'))
Check ($archives.Count -eq 2) 'Two independently installable feature archives'
$coreSources = @{}
foreach ($path in $archives) {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($path)
    try {
        $name = if ([System.IO.Path]::GetFileName($path) -match 'Nameplates') { 'Nameplates' } else { 'QuestTracker' }
        $identity = "EllesmereUIExtend$name"
        $entries = @($archive.Entries | ForEach-Object { $_.FullName })
        Check ($entries -contains 'EllesmereUIExtend/EllesmereUIExtend.toc') 'Core TOC is bundled under its installed identity'
        Check ($entries -contains "$identity/$identity.toc") 'Feature TOC matches installed folder'
        Check ($entries -contains 'EllesmereUIExtend/LICENSE' -and $entries -contains "$identity/LICENSE") 'Licenses included'
        Check (-not ($entries | Where-Object { $_ -match '/tests/|\.git|^Nameplates/|^QuestTracker/' })) 'No development source paths or tests bundled'
        $other = if ($name -eq 'Nameplates') { 'QuestTracker' } else { 'Nameplates' }
        Check (-not ($entries | Where-Object { $_ -like "EllesmereUIExtend$other/*" })) 'Other feature is not bundled'
        $toc = Get-Content -LiteralPath (Join-Path $root "$name/$identity.toc") -Raw
        Check ($toc -match "## Dependencies: EllesmereUI, EllesmereUIExtend, EllesmereUI$name\r?\n") 'Feature has core and corresponding EUI dependencies'
        Check ($toc -notmatch '## SavedVariables:') 'Feature does not own a second SavedVariables file'
        foreach ($entry in $archive.Entries | Where-Object { $_.FullName -like 'EllesmereUIExtend/*' }) {
            $reader = New-Object System.IO.StreamReader($entry.Open())
            try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
            if ($coreSources.ContainsKey($entry.FullName)) {
                Check ($coreSources[$entry.FullName] -ceq $content) "Identical shared core file: $($entry.FullName)"
            } else { $coreSources[$entry.FullName] = $content }
        }
    } finally { $archive.Dispose() }
}
Write-Output "PASS: $checks shared-core dependency, identity and ZIP packaging checks"
