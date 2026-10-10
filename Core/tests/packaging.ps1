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
Check ($archives.Count -eq 3) 'Three independently installable feature archives'
foreach ($path in $archives) {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($path)
    try {
        $name = [regex]::Match([System.IO.Path]::GetFileName($path), '^EllesmereUIExtend(Nameplates|QuestTracker|Bags)-').Groups[1].Value
        $identity = "EllesmereUIExtend$name"
        $entries = @($archive.Entries | ForEach-Object { $_.FullName })
        Check (-not ($entries | Where-Object { $_ -notlike "$identity/*" })) 'ZIP has only the chosen addon folder; uninstall cannot delete another addon code folder'
        Check ($entries -contains "$identity/$identity.toc") 'Feature TOC matches installed folder'
        Check ($entries -contains "$identity/LICENSE") 'License included'
        Check (-not ($entries | Where-Object { $_ -match '/tests/|\.git|^Nameplates/|^QuestTracker/|^Bags/' })) 'No development source paths or tests bundled'
        $pkgmetaName = $name.ToLowerInvariant()
        $pkgmeta = Get-Content -LiteralPath (Join-Path $root ".pkgmeta-$pkgmetaName") -Raw
        Check ($pkgmeta -match '(?m)^\s+- \.agents\r?$') 'Release metadata excludes agent skills'
        $toc = Get-Content -LiteralPath (Join-Path $root "$name/$identity.toc") -Raw
        Check ($toc -match "## Dependencies: EllesmereUI, EllesmereUI$name\r?\n") 'Only corresponding upstream dependencies'
        $savedVariables = if ($name -eq 'Bags') { "${identity}Profiles, ${identity}DB" } else { "${identity}Profiles" }
        Check ($toc -match "## SavedVariables: $savedVariables\r?\n") 'Each feature saves its own profile snapshot and only its own inventory database'
        Check ($toc -match '(?m)^## Interface: 120100, 16001\r?$') 'Only Retail 12.1 and Forever interfaces advertised'
        $reader = New-Object System.IO.StreamReader($archive.GetEntry("$identity/$identity.toc").Open())
        try { $packagedToc = $reader.ReadToEnd() } finally { $reader.Dispose() }
        Check ($packagedToc -ceq $toc) 'Default ZIP preserves the dual-client source TOC'
        $iconPath = [regex]::Match($toc, '(?m)^## IconTexture: ([^\r\n]+)').Groups[1].Value
        Check ($iconPath -ceq "Interface\AddOns\$identity\Media\Icon.tga") 'Addon-list icon belongs to its own installed addon'
        $icon = $archive.GetEntry("$identity/Media/Icon.tga")
        Check ($null -ne $icon) 'Custom addon-list icon is packaged'
        $iconStream = $icon.Open()
        $buffer = New-Object System.IO.MemoryStream
        try { $iconStream.CopyTo($buffer); $iconBytes = $buffer.ToArray() } finally { $iconStream.Dispose(); $buffer.Dispose() }
        $sourceIcon = [System.IO.File]::ReadAllBytes((Join-Path $root "$name/Media/Icon.tga"))
        Check ([Convert]::ToBase64String($iconBytes) -ceq [Convert]::ToBase64String($sourceIcon)) 'Packaged icon matches source artwork'
        Check ($iconBytes.Length -eq (18 + 128 * 128 * 4) -and $iconBytes[0] -eq 0 -and $iconBytes[1] -eq 0 -and
            $iconBytes[2] -eq 2 -and [BitConverter]::ToUInt16($iconBytes, 12) -eq 128 -and
            [BitConverter]::ToUInt16($iconBytes, 14) -eq 128 -and $iconBytes[16] -eq 32 -and
            $iconBytes[17] -eq 8) 'Icon is an uncompressed bottom-origin 128x128 TGA with eight alpha bits'
        $workflow = Get-Content -LiteralPath (Join-Path $root '.github/workflows/create-releases.yaml') -Raw
        Check ($workflow -match '(?m)^  workflow_dispatch:') 'Release creation remains manually dispatched'
        Check ($workflow -match '-m \.pkgmeta-\$\{\{ matrix\.feature \}\}') 'Release matrix selects feature packaging metadata'
        Check ($workflow -notmatch 's/\^## Interface:') 'Release preparation does not overwrite client interfaces'
        $argsLine = [regex]::Match($workflow, '(?m)^\s+args: .+$').Value
        Check ($argsLine -ne '' -and $argsLine -notmatch '(?:^|\s)-g(?:\s|$)') 'Packager derives supported versions from TOCs'
        Check ($argsLine -match '\(Retail \+ Forever\)') 'Published file label names both supported clients'
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
foreach ($name in @('Nameplates', 'QuestTracker', 'Bags')) {
    $sourceTocs[$name] = Get-Content -LiteralPath (Join-Path $root "$name/EllesmereUIExtend$name.toc") -Raw
}
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { Join-Path $env:LOCALAPPDATA 'Temp/opencode' }
$output = Join-Path $tempRoot ('extend-package-check-' + [guid]::NewGuid().ToString('N'))
$alphaArchives = @(& (Join-Path $root 'tools/Package.ps1') -Version '0.1.0-alpha.1' -Interface '16001' -OutputDirectory $output)
foreach ($path in $alphaArchives) {
    $archive = [System.IO.Compression.ZipFile]::OpenRead($path)
    try {
        $name = [regex]::Match([System.IO.Path]::GetFileName($path), '^EllesmereUIExtend(Nameplates|QuestTracker|Bags)-').Groups[1].Value
        $identity = "EllesmereUIExtend$name"
        Check ([System.IO.Path]::GetFileName($path) -eq "$identity-0.1.0-alpha.1.zip") 'Local alpha filename uses override'
        $reader = New-Object System.IO.StreamReader($archive.GetEntry("$identity/$identity.toc").Open())
        try { $toc = $reader.ReadToEnd() } finally { $reader.Dispose() }
        Check ($toc -match '(?m)^## Version: 0\.1\.0-alpha\.1\r?$' -and $toc -match '(?m)^## Interface: 16001\r?$') 'Packaged TOC has alpha/Forever overrides'
        Check ($null -ne $archive.GetEntry("$identity/Shared/Sync.lua")) 'Override packages retain synchronization code'
        Check ($null -ne $archive.GetEntry("$identity/Media/Icon.tga")) 'Override packages retain custom addon-list artwork'
        Check ($sourceTocs[$name] -ceq (Get-Content -LiteralPath (Join-Path $root "$name/$identity.toc") -Raw)) 'Overrides do not change source TOCs'
    } finally { $archive.Dispose() }
}
Write-Output "PASS: $checks embedded-core ownership, identity and ZIP packaging checks"
