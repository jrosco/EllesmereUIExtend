$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Add-Type -AssemblyName System.IO.Compression.FileSystem
$checks = 0
function Check([bool] $value, [string] $label) {
    $script:checks++
    if (-not $value) { throw $label }
}
Check (-not (Test-Path (Join-Path $root 'Core/EllesmereUIExtend.toc'))) 'No separately installed Core addon'
$archives = @(& (Join-Path $root 'tools/Package.ps1'))
Check ($archives.Count -eq 2) 'Two independently installable feature archives'
foreach ($path in $archives) {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($path)
    try {
        $name = if ([System.IO.Path]::GetFileName($path) -match 'Nameplates') { 'Nameplates' } else { 'QuestTracker' }
        $identity = "EllesmereUIExtend$name"
        $entries = @($archive.Entries | ForEach-Object { $_.FullName })
        Check (-not ($entries | Where-Object { $_ -notlike "$identity/*" })) 'ZIP has only the chosen addon folder; uninstall cannot delete another addon code folder'
        Check ($entries -contains "$identity/$identity.toc") 'Feature TOC matches installed folder'
        Check ($entries -contains "$identity/LICENSE") 'License included'
        Check (-not ($entries | Where-Object { $_ -match '/tests/|\.git|^Nameplates/|^QuestTracker/' })) 'No development source paths or tests bundled'
        $toc = Get-Content -LiteralPath (Join-Path $root "$name/$identity.toc") -Raw
        Check ($toc -match "## Dependencies: EllesmereUI, EllesmereUI$name\r?\n") 'Only corresponding upstream dependencies'
        Check ($toc -match "## SavedVariables: ${identity}Profiles\r?\n") 'Each feature saves its own profile snapshot'
        Check ($toc -match '## Interface: .*16001') 'Forever interface included'
        Check ($toc.IndexOf('Shared/Core.lua') -ge 0 -and $toc.IndexOf('Shared/Core.lua') -lt $toc.IndexOf('Shared/Sync.lua') -and
            $toc.IndexOf('Shared/Sync.lua') -lt $toc.IndexOf('Shared/Options.lua') -and
            $toc.IndexOf('Shared/Options.lua') -lt $toc.IndexOf("$name.lua")) 'All embedded modules load in order before feature code'
        foreach ($file in @('Core.lua', 'Sync.lua', 'Options.lua')) {
            $entry = $archive.GetEntry("$identity/Shared/$file")
            Check ($null -ne $entry) "Embedded shared file: $file"
            $reader = New-Object System.IO.StreamReader($entry.Open())
            try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
            Check ($content -ceq (Get-Content -LiteralPath (Join-Path $root "Core/$file") -Raw)) 'Embedded code matches the single shared source'
        }
        foreach ($match in [regex]::Matches($toc, '(?m)^((?:Shared/)?[A-Za-z]+\.lua)\r?$')) {
            Check ($null -ne $archive.GetEntry("$identity/$($match.Groups[1].Value)")) 'Every TOC Lua entry is packaged'
        }
    } finally { $archive.Dispose() }
}
$sourceTocs = @{}
foreach ($name in @('Nameplates', 'QuestTracker')) {
    $sourceTocs[$name] = Get-Content -LiteralPath (Join-Path $root "$name/EllesmereUIExtend$name.toc") -Raw
}
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { Join-Path $env:LOCALAPPDATA 'Temp/opencode' }
$output = Join-Path $tempRoot ('extend-package-check-' + [guid]::NewGuid().ToString('N'))
$alphaArchives = @(& (Join-Path $root 'tools/Package.ps1') -Version '0.1.0-alpha.1' -Interface '16001' -OutputDirectory $output)
foreach ($path in $alphaArchives) {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($path)
    try {
        $name = if ([System.IO.Path]::GetFileName($path) -match 'Nameplates') { 'Nameplates' } else { 'QuestTracker' }
        $identity = "EllesmereUIExtend$name"
        Check ([System.IO.Path]::GetFileName($path) -eq "$identity-0.1.0-alpha.1.zip") 'Local alpha filename uses override'
        $reader = New-Object System.IO.StreamReader($archive.GetEntry("$identity/$identity.toc").Open())
        try { $toc = $reader.ReadToEnd() } finally { $reader.Dispose() }
        Check ($toc -match '(?m)^## Version: 0\.1\.0-alpha\.1\r?$' -and $toc -match '(?m)^## Interface: 16001\r?$') 'Packaged TOC has alpha/Forever overrides'
        Check ($null -ne $archive.GetEntry("$identity/Shared/Sync.lua")) 'Override packages retain synchronization code'
        Check ($sourceTocs[$name] -ceq (Get-Content -LiteralPath (Join-Path $root "$name/$identity.toc") -Raw)) 'Overrides do not change source TOCs'
    } finally { $archive.Dispose() }
}
Write-Output "PASS: $checks embedded-core ownership, identity and ZIP packaging checks"
